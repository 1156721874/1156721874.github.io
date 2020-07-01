---
title: concurrency(15)ThreadLocalRandom在多线程竞争环境下的实现策略
date: 2020-07-01 21:05:00
tags: [ThreadLocalRandom]
categories: concurrency
---

### 随机数
我们在实际开发过程中，不可避免的会使用随机数，jdk提供了Random类用来实现随机数的生成：
```
public class MyTest5 {
    public static void main(String[] args) {
        Random random = new Random();
        IntStream.range(0,10).forEach(i -> {
            System.out.println(random.nextInt(10));
        });
    }
}
```
看一下Random的nextInt：
```
public class Random implements java.io.Serializable {
  private final AtomicLong seed;

  public int nextInt(int bound) {
      if (bound <= 0)
          throw new IllegalArgumentException(BadBound);

      int r = next(31);
      int m = bound - 1;
      if ((bound & m) == 0)  // i.e., bound is a power of 2
          r = (int)((bound * (long)r) >> 31);
      else {
          for (int u = r;
               u - (r = u % bound) + m < 0;
               u = next(31))
              ;
      }
      return r;
  }
}
```
每次生成随机数的时候，都会生成一个种子，然后使用这个种子再去做一些运算得到的结果作为随机数的返回结果，
nextInt当中的next方法就是我了得到种子：
```
protected int next(int bits) {
    long oldseed, nextseed;
    //this.seed是原始的种子，是一个原子性的
    AtomicLong seed = this.seed;
    do {
        oldseed = seed.get();
        //对种子的生成使用cas的方式进行更新
        nextseed = (oldseed * multiplier + addend) & mask;
    } while (!seed.compareAndSet(oldseed, nextseed));
    return (int)(nextseed >>> (48 - bits));
}
```
老的种子被更新后，原来的种子的引用重新指向新的种子。
在多线程的情况下，保证了每个线程得到的种子都是不同的，在正确性上是没有任何问题的，但是问题是这样做的性能是很差的，当线程非常多的时候，会有大量的cas，接下来 就是ThreadLocalRandom登场的时候了。

### ThreadLocalRandom
```
public class MyTest5 {
    public static void main(String[] args) {
      ThreadLocalRandom threadLocalRandom = ThreadLocalRandom.current();
      IntStream.range(0,10).forEach(i -> {
          System.out.println(threadLocalRandom.nextInt(10));
      });
    }
 ```

A random number generator isolated to the current thread. Like the global Random generator used by the Math class, a ThreadLocalRandom is initialized with an internally generated seed that may not otherwise be modified. When applicable, use of ThreadLocalRandom rather than shared Random objects in concurrent programs will typically encounter much less overhead and contention. Use of ThreadLocalRandom is particularly appropriate when multiple tasks (for example, each a ForkJoinTask) use random numbers in parallel in thread pools.
一个线程隔离的随机数生成器。就像全局的生成器一样被Math类所使用的。ThreadLocalRandom也是通过内部的种子生成器来初始化的，但是不能被其他的线程修改，更多的可能下，在并发的情况下，使用ThreadLocalRandom比共享的Random，特别是在ForkJoinTask这种情况当中，会表现出很好的性能。

ThreadLocalRandom只在一个线程里边使用，不会出现线程的切换。

对于一个随机数生成器来说，有2个要素需要考量：
1. 随机数生成器的种子
2. 具体的随机数生成算法（函数）

对于ThreadLocalRandom来说，器随机数生成器的种子是存放在每个线程的ThreadLocal中的。
```
public class ThreadLocalRandom extends Random {
  ...
    // 在同一个jvm 应用里边只有一个ThreadLocalRandom实例
    static final ThreadLocalRandom instance = new ThreadLocalRandom();
    public static ThreadLocalRandom current() {
    if (UNSAFE.getInt(Thread.currentThread(), PROBE) == 0)
        localInit();
        return instance;
    }

    public int nextInt(int bound) {
      if (bound <= 0)
          throw new IllegalArgumentException(BadBound);
      int r = mix32(nextSeed());
      int m = bound - 1;
      if ((bound & m) == 0) // power of two
          r &= m;
      else { // reject over-represented candidates
          for (int u = r >>> 1;
               u + m - (r = u % bound) < 0;
               u = mix32(nextSeed()) >>> 1)
              ;
      }
      return r;
    }

    final long nextSeed() {
        Thread t; long r; // read and update per-thread seed
        //对当前线程进行操作更新
        UNSAFE.putLong(t = Thread.currentThread(), SEED,
                       r = UNSAFE.getLong(t, SEED) + GAMMA);
        return r;
    }

    // Unsafe mechanics
    private static final sun.misc.Unsafe UNSAFE;
    private static final long SEED;
    private static final long PROBE;
    private static final long SECONDARY;
    static {
        try {
            UNSAFE = sun.misc.Unsafe.getUnsafe();
            Class<?> tk = Thread.class;
            //对种子的更新是修改的Thread类里边的成员变量
            SEED = UNSAFE.objectFieldOffset
                (tk.getDeclaredField("threadLocalRandomSeed"));
            PROBE = UNSAFE.objectFieldOffset
                (tk.getDeclaredField("threadLocalRandomProbe"));
            SECONDARY = UNSAFE.objectFieldOffset
                (tk.getDeclaredField("threadLocalRandomSecondarySeed"));
        } catch (Exception e) {
            throw new Error(e);
        }
    }

    ...
}
```

Thread类的部分代码:
```
/** The current seed for a ThreadLocalRandom */
@sun.misc.Contended("tlr")
long threadLocalRandomSeed;

/** Probe hash value; nonzero if threadLocalRandomSeed initialized */
@sun.misc.Contended("tlr")
int threadLocalRandomProbe;

/** Secondary seed isolated from public ThreadLocalRandom sequence */
@sun.misc.Contended("tlr")
int threadLocalRandomSecondarySeed;
```
我们发现Thread类里边的threadLocalRandomSeed、threadLocalRandomProbe、threadLocalRandomProbe都是原生类型的long，而在Random里边的AtomicLong类型。因为threadLocalRandomSeed、threadLocalRandomProbe、threadLocalRandomProbe都是定义在线程里边的，不会发生多线程并发的问题。
