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
3. 资源角度：线程在执行更新操作时，是否需要利用锁来锁住同步资源：需要：悲观锁，不需要：乐观锁。
4. 多线程在竞争锁资源时是否需要排队等待：排队：公平锁，不排队：非公平锁。
5. 当线程尝试锁住同步资源，但却失败了，那么线程是否需要阻塞：阻塞：，不阻塞：自旋锁。如果线程在自旋过程中一直没有获取到同步资源，那么该线程最终还是会被阻塞，进入到内核态（自适应自旋）
6. 多线程在竞争同步资源的过程中的区别，无锁：多线程会同时进行资源的修改，并且不锁住资源，在这种情况下，某一个时刻只会有一个线程对资源的修改是成功的，其他线程均会失败，失败的线程则会进行不断的重试（CAS）；同一个线程在执行时，如果遇到了同步资源，那么它会自动的获取到这个锁资源，而不必进行其他任何操作（偏向锁）;多个线程同时在尝试竞争锁资源，同一时刻，只会有一个线程能够获取到锁，那么其他没有获取到锁的线程就会进行自旋等待锁的释放(轻量级锁);多个线程同时在尝试竞争锁资源，并且进行了自旋，但是经过一段时间后，线程依然无法获取到锁资源，这个时候，没有获取到锁资源的线程将会进入到阻塞状态，等待cpu的唤醒(重量级锁)。
