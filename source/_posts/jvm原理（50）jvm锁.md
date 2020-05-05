---
title: jvm原理（50）jvm锁
date: 2020-04-8 21:27:13
tags: [CAS、锁升级、重入锁、公平锁、非公平锁]
categories: jvm
---


### synchronized关键字
```
/**
 * 当我们使用synchronized关键字来修饰同步代码块时，本质上在字节码层面上是通过monitorenter
 * 与monitorexit指令来实现同步的，当进入monitorenter指令后，线程将会持有monitor对象，
 * 当退出monitorexit后，线程将会释放掉该monitor对象，在线程整个执行过程中，他会始终持有monitor对象的，
 * 这样就确保了共享资源的同步访问。
 *
 * monitor对象到底是什么？
 *
 * 当我们使用new关键字创建一个java对象时，底层的jvm会自动为该创建的对象创建一个所谓的object header，并且
 * 将该object header附加到该对象上，java中的每个对象在创建后，都会拥有一个与之相关联的monitor对象，
 * 这也是为什么我们synchronized关键字修饰同步代码块时，我们使用什么对象（如Object，string，Date）都可以的原因所在。
 *
 * Object Header里面包含了很多信息，如monitor信息，锁相关的信息等。
 *
 *  对于同步方法的字节码来说，在反编译的字节码中并没有出现monitor与monitor相关的指令，
 *  而是出现了一个ACC_SYNCHRONIZED标记。
 *
 *  本质上，jvm使用ACC_SYNCHRONIZED访问标记来判断某个方法是否是一个同步方法。
 *
 *  当方法调用时，调用指令会先检查该方法是否拥有ACC_SYNCHRONIZED访问标记，如果发现了该标记，那么执行的线程
 *  将会首先持有monitor对象，接下来再去执行方法；在该方法运行期间，其他任何线程都将无法获取到monitor对象，
 *  当方法执行完毕后，线程会释放掉所有持有的monitor对象。
 *
 *  那么线程所持有的的monitor对象又是什么呢？
 *  1、如果被synchronized修饰的方法是普通实例方法，那么monitor对象就是当前被调用方法所在的那个对象。
 *  2、如果被synchronized修饰的方法是静态方法，那么monitor对象就是当前类所对应的class对象。
 *
 */
public class MyTest1 {
    private Object object = new Object();

    public void myMethod(){
        synchronized (object){
            System.out.println("hello world");
        }
    }

    public synchronized void method2(){
        System.out.println("hello world");
    }
}

```
反编译：
```
Compiled from "MyTest1.java"
public class com.twodragonlake.jvm.lock.MyTest1 {
  public com.twodragonlake.jvm.lock.MyTest1();
    Code:
       0: aload_0
       1: invokespecial #1                  // Method java/lang/Object."<init>":()V
       4: aload_0
       5: new           #2                  // class java/lang/Object
       8: dup
       9: invokespecial #1                  // Method java/lang/Object."<init>":()V
      12: putfield      #3                  // Field object:Ljava/lang/Object;
      15: return

  public void myMethod();
    Code:
       0: aload_0
       1: getfield      #3                  // Field object:Ljava/lang/Object;
       4: dup
       5: astore_1
       6: monitorenter
       7: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
      10: ldc           #5                  // String hello world
      12: invokevirtual #6                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
      15: aload_1
      16: monitorexit
      17: goto          25
      20: astore_2
      21: aload_1
      22: monitorexit
      23: aload_2
      24: athrow
      25: return
    Exception table:
       from    to  target type
           7    17    20   any
          20    23    20   any
}

```

### java锁的分类维度
1. 共享角度：多个线程是否可以共享同一把锁，能：共享锁，不能：排它锁。
2. 同一个线程在执行过程中是否可以获取到同一把锁：能：可重入锁，不能：非可重入锁。
3. 资源角度：线程在执行更新操作时，是否需要利用锁来锁住同步资源：需要：悲观锁，不需要：乐观锁(CAS)。
4. 多线程在竞争锁资源时是否需要排队等待：排队：公平锁，不排队：非公平锁。
5. 当线程尝试锁住同步资源，但却失败了，那么线程是否需要阻塞：阻塞：，不阻塞：自旋锁。如果线程在自旋过程中一直没有获取到同步资源，那么该线程最终还是会被阻塞，进入到内核态（自适应自旋）
6. 多线程在竞争同步资源的过程中的区别，无锁：多线程会同时进行资源的修改，并且不锁住资源，在这种情况下，某一个时刻只会有一个线程对资源的修改是成功的，其他线程均会失败，失败的线程则会进行不断的重试（CAS）；同一个线程在执行时，如果遇到了同步资源，那么它会自动的获取到这个锁资源，而不必进行其他任何操作（偏向锁）;多个线程同时在尝试竞争锁资源，同一时刻，只会有一个线程能够获取到锁，那么其他没有获取到锁的线程就会进行自旋等待锁的释放(轻量级锁);多个线程同时在尝试竞争锁资源，并且进行了自旋，但是经过一段时间后，线程依然无法获取到锁资源，这个时候，没有获取到锁资源的线程将会进入到阻塞状态，等待cpu的唤醒(重量级锁)。
7. 关于悲观锁和乐观锁的适用场景:
  - 乐观锁：非常适合读操作非常多的场景，因为本身不加锁，所以可以使得操作的性能有非常明显的提升。
  - 悲观锁：非常适合写操作非常多的场景，因为首先需要对资源进行加锁操作，所以完全可以保证写入操作的正确性和健壮。

#### CAS (campare and swap)，比较与交换

##### CAS算法本质上涉及到三个数字:
1. 需要进行读写的内存值V
2. 需要进行比较的值A
3. 需要进行写入的新的值B
如果V和A相等，那么当前线程将B写入，否则当前线程会进行重试。
比较与更新本质上是一个原子操作，它在cpu层面上是一个指令来完成。

##### CAS的主要问题:ABA
  AtomaticStampedReference

#### 自旋
  减少cpu状态的切换，从而减少线程在用户与内核态之间的切换，从而达到提升效率的目的。
  自旋会有一个上限(阈值)，默认情况下，线程会自旋10次，PreBlockSpin参数来设置线程默认的自旋次数。
  自旋锁是在jdk1.4中引入的，我们可以通过UseSpinning来开启自旋，从jdk1.6开始，自旋是默认开启的，同时该版本的jdk又引入了适应性自旋锁。
  适应性自旋锁：前边的线程或者大部分的线程自旋拿到了锁，那么当前线程在自旋的时候会大概率的自旋成功，因此可以放大自旋的次数，如果之前的线程或者大部分的线程自旋失败，那么本次线程自旋大概率也会是失败，那么本次自旋可能会让线程进入阻塞状态。

#### 无锁、偏向锁、轻量级锁与重量级锁
  这几种本质上都是针对于synchronized关键字的。
  关于java对象头：
   Mark Word:
   1. 无锁标记
   2. 偏向锁标记
   3. 轻量级锁标记
   4. 重量级锁标记
   5. GC标记
   锁升级的功能主要是依赖于Mark Word中的锁标记位与是否偏向锁来达成的，synchronized关键字其实就是从偏向锁开始，然后升级为轻量级锁，最终升级为重量级锁。
   Monitor中拥有一个owner字段，用来标示持有该锁的线程的唯一标识，表示这个锁被该线程所持有。
   synchronized本质上是通过Monitor来实现的，Monitor本质上又是依赖底层操作系统的互斥锁(mutex lock)来实现的。
  Klaass Pointer: 指向当前对象的类的指针。

##### 偏向锁
  针对于同一个线程访问一个同步代码块的场景，减少了频繁获取与释放锁的代价。 UseBiaseLocking = false
##### 轻量级锁
  jvm会在Stack Frame中建立一个名为Lock Record的空间，用于存储锁对象目前的Mark Word的副本，同时它会将对象头中的Mark Word复制到锁记录中；如果成功，那么jvm会将对象的Mark Word更新为指向Lock record的指针，同时会将Lock Record中的owner指针指向对象的Mark word，如果该操作成功，就表示线程拥有了对象的锁，这样，对象就会处于轻量级锁的状态之中。
  如果当前只有一个线程等待，那么这个线程会自旋，当前自旋是由次数限制的；如果有三个线程在争夺锁资源，这个时候会升级为重量级锁；
##### 重量级锁
  是锁的最终状态。等待的线程会进入到阻塞状态(内核态)。

#### JIT来实现一些优化措施：
  逃逸分析的技术。
  锁粗化：
  ```
  public void Method(){
    synchronized(object){}
    synchronized(object){}
    synchronized(object){}
  }
  ```
   会将三个synchronized合并为一个synchronized
  减小锁的粒度：
  ConcurrentHashMap

#### 公平锁与非公平锁
  ReetrantLock提供了公平锁与非公平锁的实现，默认使用的是非公平锁。

  公平锁的获取：
  ```

  protected final boolean tryAcquire(int acquires) {
      final Thread current = Thread.currentThread();
      int c = getState();
      if (c == 0) {
        //判断当前线程是否是队列的第一个
          if (!hasQueuedPredecessors() &&
              compareAndSetState(0, acquires)) {
              setExclusiveOwnerThread(current);
              return true;
          }
      }
      else if (current == getExclusiveOwnerThread()) {
          int nextc = c + acquires;
          if (nextc < 0)
              throw new Error("Maximum lock count exceeded");
          setState(nextc);
          return true;
      }
      return false;
  }
  ```
  非公平锁的获取：
  ```
  final boolean nonfairTryAcquire(int acquires) {
      final Thread current = Thread.currentThread();
      int c = getState();
      if (c == 0) {
        //没有判断当前线程是否是队列的第一个
          if (compareAndSetState(0, acquires)) {
              setExclusiveOwnerThread(current);
              return true;
          }
      }
      else if (current == getExclusiveOwnerThread()) {
          int nextc = c + acquires;
          if (nextc < 0) // overflow
              throw new Error("Maximum lock count exceeded");
          setState(nextc);
          return true;
      }
      return false;
  }
  ```
  判断当前线程是不是队列的第一个线程：
  ```
  public final boolean hasQueuedPredecessors() {
      // The correctness of this depends on head being initialized
      // before tail and on head.next being accurate if the current
      // thread is first in queue.
      Node t = tail; // Read fields in reverse initialization order
      Node h = head;
      Node s;
      return h != t &&
          ((s = h.next) == null || s.thread != Thread.currentThread());
  }
  ```


### 可重入锁与非可重入锁
java中的reentrantLock与synchronized都是可重入锁，他最大的优势在于防止死锁的出现。

### 共享锁和排它锁
reentrantLock 是排它锁的典型实现，如果reentrantLock拿到锁之后，其他线程无论是读还是写都是拿不到这个对象的锁。

ReentrantReadWriteLock 是共享锁的实现，里边有读锁和写锁，只有所有的线程度都是读取操作的时候，是共享的，如果都是
写的操作，那么就是排他的。

AQS中：状态字段，高16位表示读状态，低16位表示写状态。
