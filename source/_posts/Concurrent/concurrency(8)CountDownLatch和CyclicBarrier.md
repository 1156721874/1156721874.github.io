---
title: concurrency(8)CountDownLatch和CyclicBarrier
date: 2020-05-05 14:00:45
tags: [CountDownLatch CyclicBarrier]
categories: concurrency
---

### CountDownLatch
exanple1:主线程等待3个子线程执行完毕，主线程才继续执行
<!-- more -->
```
public class MyTest1 {
    public static void main(String[] args) {
        CountDownLatch countDownLatch  =  new CountDownLatch(3);
        IntStream.range(0,3).forEach(i -> new Thread(() ->{
            try{
                Thread.sleep(2000);
                System.out.println("hello");
            }catch (Exception e){
                e.printStackTrace();
            }finally {
              //countDown有减计数器和触发的作用
                countDownLatch.countDown();
            }
        }));
        System.out.println("启动子线程完毕");
        try {
            countDownLatch.await();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.out.println("主线程执行完毕");
    }
}

```
输出：
启动子线程完
hello
hello
hello
主线程执行完


打开CountDownLatch的await方法：
Causes the current thread to wait until the latch has counted down to zero, unless the thread is interrupted.
线程等待直到计数器 白为零，或者被中断。
```
public void await() throws InterruptedException {
     sync.acquireSharedInterruptibly(1);
 }
```
AbstractQueuedSynchronizer
```
public final void acquireSharedInterruptibly(int arg)
        throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (tryAcquireShared(arg) < 0)
        doAcquireSharedInterruptibly(arg);
}
```
CountDownLatch.Sync重写了tryAcquireShared方法：
```
protected int tryAcquireShared(int acquires) {
            return (getState() == 0) ? 1 : -1;
        }
```
如果tryAcquireShared返回-1那么执行doAcquireSharedInterruptibly，doAcquireSharedInterruptibly会进行阻塞，否则acquireSharedInterruptibly执行完毕，如果acquireSharedInterruptibly执行完毕意味着示例的主线程继续执行。

CountDownLatch的countDown方法：
```
public void countDown() {
    sync.releaseShared(1);
}
```
即，对计数器减一。
AbstractQueuedSynchronizer:
```
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
      //某一个子线程判断计数器变为了0（tryReleaseShared方法返回true），那么这个线程会唤醒被wait的线程，这里主线程在wait，///那么主线程会被唤醒。
        doReleaseShared();
        return true;
    }
    return false;
}
```
tryReleaseShared被重写：
```
protected boolean tryReleaseShared(int releases) {
    // Decrement count; signal when transition to zero
    for (;;) {
        int c = getState();
        if (c == 0)
        //计数器已经归零，不需要再减
            return false;
        int nextc = c-1;
        if (compareAndSetState(c, nextc))
        //减一之后是否为0
            return nextc == 0;
    }
}
```
CountDownLatch是一次性的。

### CyclicBarrier
等待3个线程都达到一个屏障，然后同时一块执行。
```
public interface MyTest2 {
    public static void main(String[] args) {
        CyclicBarrier cyclicBarrier = new CyclicBarrier(3);
        for(int i=0;i<3;i++){
            new Thread(() ->{
                try{
                    Thread.sleep((long )Math.random()*2000);
                    int random = new Random().nextInt(500);
                    System.out.println("hello" + random);
                    cyclicBarrier.await();
                    System.out.println("world" + random);
                }catch (Exception e){
                    e.printStackTrace();
                }
            }).start();
        }
    }
}
```

运行结果：
hello19
hello135
hello169
world169
world19
world135

CyclicBarrier是可以重复使用的。因为CyclicBarrier的所有线程冲破屏障之后，会将计数器重置为3.
重用实例：
```

public interface MyTest2 {
    public static void main(String[] args) {
        CyclicBarrier cyclicBarrier = new CyclicBarrier(3);
        for(int i=0;i<2;i++){   //重用2次
            for(int n=0;n<3;n++){//每次等待3个线程
                new Thread(() ->{
                    try{
                        Thread.sleep((long )Math.random()*2000);
                        int random = new Random().nextInt(500);
                        System.out.println("hello"+ random);
                        cyclicBarrier.await();
                        System.out.println("world"+random);
                    }catch (Exception e){
                        e.printStackTrace();
                    }
                }).start();
            }
        }
    }
}
```
输出：
hello388
hello446
hello66
hello119
hello188
hello362
world362
world66
world388
world188
world119
world446

另一个构造器：
```
CyclicBarrier cyclicBarrier = new CyclicBarrier(3, ()->{
           System.out.println("hello wold..........");
       });
```
第二个参数是一个runnable，当所有的线程到达屏障的时候，就会执行这个runnable。

CyclicBarrier的await方法还有一个带超时时间的await方法：
```
public int await(long timeout, TimeUnit unit)
    throws InterruptedException,
           BrokenBarrierException,
           TimeoutException {
    return dowait(true, unit.toNanos(timeout));
}
```
如果超时，那么屏障就会破坏掉，同时抛出BrokenBarrierException，await方法后边的代码不会执行，而CountDownLatch的await方法超时会继续执行。

另外看一下构造器：
```
private final int parties;
private int count;
public CyclicBarrier(int parties, Runnable barrierAction) {
    if (parties <= 0) throw new IllegalArgumentException();
    this.parties = parties;
    this.count = parties;
    this.barrierCommand = barrierAction;
}
```
CyclicBarrier里边有parties和count同时被参数parties赋值，目的是：parties是不可变的final的，如果一轮屏障使用完毕，复用CyclicBarrier的时候，会重新赋值给count，而count是一个计数器，会随时改变。

#### Generation
```
private static class Generation {
    boolean broken = false;
}
```
用来分代的，冲破屏障的时候，意味着进入了下一代的运作。broken会重置。

#### CyclicBarrier的dowait
  dowait是CyclicBarrier的await方法调用的方法，也是CyclicBarrier的核心逻辑都在这个dowait里边。
  ```
  /**
      * Main barrier code, covering the various policies.
      */
     private int dowait(boolean timed, long nanos)
         throws InterruptedException, BrokenBarrierException,
                TimeoutException {
                  / 获取锁/
         final ReentrantLock lock = this.lock;
         lock.lock();
         try {
             final Generation g = generation;

             if (g.broken)
                 throw new BrokenBarrierException();

             if (Thread.interrupted()) {
                 breakBarrier();
                 throw new InterruptedException();
             }

             int index = --count;
             //count==0意味着最后一个线程的到来
             if (index == 0) {  // tripped 所有的线程都已经到达屏障
               //是否执行完命令
                 boolean ranAction = false;
                 try {
                     final Runnable command = barrierCommand;
                     if (command != null)
                        //执行构造器传递的Runnable
                         command.run();
                     ranAction = true;
                     //
                     nextGeneration();
                     /**
                     *private void nextGeneration() {
                     *    // signal completion of last generation
                     *    当最后一个线程没有达到之前，当前到达屏障的线程都在等待trip上，当最后一个线程来了之后
                     *    trip就会唤醒所有等待在屏障的线程继续执行。
                     *    trip.signalAll();
                     *     // set up next generation
                     *    count = parties;
                     *     generation = new Generation();
                     * }
                     */
                     return 0;
                 } finally {
                     if (!ranAction)
                         breakBarrier();
                 }
             }

             // loop until tripped, broken, interrupted, or timed out
             // 非最后一个线程的到来需要等待，直到屏障被冲破，或者终止，线程中断，以及超时才会退出
             for (;;) {
                 try {
                     //是否配置了超时时间
                     if (!timed)
                     //没有配置超时时间，直接等待
                         trip.await();
                     else if (nanos > 0L)
                     //配置了超时时间，调用trip的awaitNanos方法
                         nanos = trip.awaitNanos(nanos);
                 } catch (InterruptedException ie) {
                     if (g == generation && ! g.broken) {
                         breakBarrier();
                         throw ie;
                     } else {
                         // We're about to finish waiting even if we had not
                         // been interrupted, so this interrupt is deemed to
                         // "belong" to subsequent execution.
                         Thread.currentThread().interrupt();
                     }
                 }

                 if (g.broken)
                     throw new BrokenBarrierException();

                 if (g != generation)
                     return index;

                 if (timed && nanos <= 0L) {
                     breakBarrier();
                     throw new TimeoutException();
                 }
             }
         } finally {
           //解锁
             lock.unlock();
         }
     }
  ```

关于CyclicBarrier的底层执行流程：
1. 初始化CyclicBarrier中的各种成员变量，包括parties、count以及Runnable（可选）
2. 当调用await方法时，底层会先检查计数器是否已经归零，如果是的话，那么就首先执行可选的Runnable，接下来开始下一个genaration;
3. 在下一个分代中，将会重置count值为parties，，唤醒所有在屏障前面等待的线程，让其开始等待执行。
4. 如果计数器没有归零，那么当前的调用线程就会通过Condation方法，在屏障前进行等待。
6. 以上 所有执行流程均在lock锁的控制范围内，不会出现并发情况。

### 区别

![CountDownLatch-CyclicBarrier.png](CountDownLatch-CyclicBarrier.png)
