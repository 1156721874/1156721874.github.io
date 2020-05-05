---
title: concurrency(9)CAS详解及透过字节码分析变量操作的原子性&底层实现与源码剖析
date: 2020-05-05 14:43:45
tags: [cas]
categories: concurrency
---

### CAS
1. synchronized关键字与lock等锁机制都是悲观锁：无论做任何操作，首先都需要先上锁，接下来再去执行后续操作，从而确保了接下来的所有操作都是由当前这个线程来执行的。
2. 乐观锁：线程在操作之前不会做任何预先的处理，而是直接去执行；当在最后执行变量更新的时候，当前线程需要一种机制来确保当前被操作的变量是没有被其他线程修改的；CAS是乐观锁的一种极为重要的实现方式。

CAS(Compare And Swap)
比较与交换：这是一个不断循环的过程，一直到变量值修改成功为止。CAS本身是有硬件指令来提供支持的，换句话说，硬件是通过一个原子指令来实现比较与交换的；因此，CAS可以确保变量操作的原子性的。
在IA64，x86 指令集中有 cmpxchg 指令完成 CAS 功能，在 sparc-TSO 也有 casa 指令实现，而在 ARM 和 PowerPC 架构下，则需要使用一对 ldrex/strex 指令来完成 LL/SC 的功能。在精简指令集的体系架构中，则通常是靠一对儿指令，如：load and reserve 和 store conditional 实现的，在大多数处理器上 CAS 都是个非常轻量级的操作，这也是其优势所在。

### 计数器
编写一个计数器的程序，如下：
```
public class MyTest1 {
    private int count;

    public int getCount() {
        return count;
    }

    public void incrementCount(){
        ++this.count;
    }
}
```
这个程序在多线程的情况下会存在问题，问题就在【++this.count;】这行代码。
那么我们看一下这个程序incrementCount方法的字节码：
```
public void incrementCount();
  descriptor: ()V
  flags: ACC_PUBLIC
  Code:
    stack=3, locals=1, args_size=1
       0: aload_0
       1: dup
       2: getfield      #2                  // Field count:I 读取count的值，放到栈顶
       5: iconst_1                          //数字1放入栈顶
       6: iadd                              // 在当前栈顶的2个数字求和 this.count+1
       7: putfield      #2                  // Field count:I 将加1之后的和放在栈顶，赋值给count
      10: return
    LineNumberTable:
      line 11: 0
      line 12: 10
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      11     0  this   Lcom/twodragonlake/concurrency6/MyTest1;

```
//读取 -> 修改 -> 写入: 这三个操作并非原子性
public void incrementCount(){
    ++this.count;
}
**怎么解决？**
1. 使用synchronized关键字
```
public synchronized int getCount() {
    return count;
}
public synchronized void incrementCount(){
    ++this.count;
}
```
但这不是最佳的解决方案。
我们在getCount方法也加锁了，导致写的时候无法读。
如果我们把getCount的synchronized去掉是否可行呢？
也是不行的。。
synchronized会增加内存屏障，会将保证内存的可见性和原子性。
monitorenter
  内存屏障(Acquire Barrier,获取屏障)
  ......
  内存屏障(Release Barrier,释放屏障)
monitorexit
如果我们把getCount的synchronized去掉，那么getCount得到值可能数老的值，导致数据的不一致性。

### CAS的操作数
对于CAS来说，器操作数主要涉及到如下三个：
1. 需要被操作的内存值V。
2. 需要进行比较的值A。
3. 需要进行写入的值B

只有当V==A 的时候，CAS才会通过原子操作的手段来将V的值更新为B。

实例：
```
public class MyTest2 {
    public static void main(String[] args) {
        AtomicInteger atomicInteger = new AtomicInteger(5);
        System.out.println(atomicInteger.get());
        System.out.println(atomicInteger.getAndSet(8));
        System.out.println(atomicInteger.get());
        System.out.println(atomicInteger.getAndIncrement());
        System.out.println(atomicInteger.get());
    }
}
```
输出：
5
5
8
8
9

#### AtomicInteger实现
```
public class AtomicInteger extends Number implements java.io.Serializable {
  // Unsafe非开源的，只能在jkd内部调用
  private static final Unsafe unsafe = Unsafe.getUnsafe();
  //值在对象里边的内存偏移量，即 value在AtomicInteger对象里边的内存偏移量。
  private static final long valueOffset;
  //AtomicInteger包装的数值，比如实例包装的是数字5，volatile为了保证可见性
  private volatile int value;

  public final int getAndSet(int newValue) {
    //this是AtomicInteger对象，valueOffset是偏移量，将要写入的值是newValue
    return unsafe.getAndSetInt(this, valueOffset, newValue);
  }
}
```
unsafe的getAndAddLong：
```
public final long getAndAddLong(Object var1, long var2, long var4) {
    long var6;
    //循环重试【循环开销问题】
    do {
        var6 = this.getLongVolatile(var1, var2);
    } while(!this.compareAndSwapLong(var1, var2, var6, var6 + var4));
    return var6;
}
//var1：我们号操作的对象，AtomicInteger对象，在C++里边就是AtomicInteger的内存位置
//var2：要操作的变量在AtomicInteger里边内存便宜位置，即valueOffset。
//var6：变量的预期的值
//var6 + var4：将要写入的新的值
// 此方法是通过一个cpu指令来完成的，是可以保证原子性。
this.compareAndSwapLong(var1, var2, var6, var6 + var4)
```

#### Unsafe
```
//构造器是私有的，不能通过new得到对象
private Unsafe() {
}
public static Unsafe getUnsafe() {
    //获取调用此getUnsafe方法的对象的Class对象
    Class var0 = Reflection.getCallerClass();
    //调用者类的类加载器不是启动类加载器，则抛出异常
    if (!VM.isSystemDomainLoader(var0.getClassLoader())) {
        throw new SecurityException("Unsafe");
    } else {
        //正常返回
        return theUnsafe;
    }
}
```

#### CAS的限制或者问题

1. 循环开销问题
  并发量大的情况会导致线程一直自旋
2. 只能保证一个变量的原子操作，但是可以使用AtomicReference，来保证对象的原子操作。
3. ABA问题：从程序正确度来说是可以的，但是从CAS语义来说是不OK的，可以使用AtomicStampedReference解决，即增加了一个版本号（或者说是时间戳）来区分。
