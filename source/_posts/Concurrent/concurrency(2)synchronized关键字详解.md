---
title: concurrency(2)synchronized关键字详解
date: 2019-08-21 14:05:45
tags: [synchronized 并发]
categories: concurrency
---

### 变量在多线程之间的影响
编写程序：
<!-- more -->
```

public class MyThreadTest{

    public static void main(String[] args) {
        Runnable r = new MyThread();
        Thread t1 = new Thread(r);
        Thread t2 = new Thread(r);
        t1.start();
        t2.start();
    }
}

 class MyThread implements  Runnable {
    int x;

    @Override
    public void run() {
        x= 0;
        while(true){
            System.out.println("result:" + x++);
            try {
                Thread.sleep((long)Math.random() * 1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            if(x == 30){
                break;
            }
        }
    }
}

```
输出的可能有多种：
A：
result:0
result:1
result:2
result:3
result:5

B：
result:1
result:0
result:2
result:3
result:4

即0和1的先后顺序是不确定的。
我们创建了2个线程但是他们都会执行同一个r对象的run方法，，而变量x又是公共的变量，在多线程之间都是可见的，这在多线程里边会有一些影响，这样导致了输出的不确定性。


### synchronized加锁对象导致的线程执行的不同
编写程序

```
public class MyThreadTest2 {

    public static void main(String[] args) {
        MyClass myClass = new MyClass();
        Thread t1 = new Thread1(myClass);
        Thread t2 = new Thread2(myClass);

        t1.start();

        try {
            Thread.sleep(700);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        t2.start();
    }

}

class MyClass{

    public synchronized void hello(){
        try {
            Thread.sleep(4000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.out.println("hello");
    }

    public synchronized void world(){
        System.out.println("world");
    }
}

class Thread1 extends Thread{
    private MyClass myClass;

    public  Thread1(MyClass myClass){
        this.myClass = myClass;
    }

    @Override
    public void run(){
        this.myClass.hello();
    }

}


class Thread2 extends Thread{
    private MyClass myClass;

    public  Thread2(MyClass myClass){
        this.myClass = myClass;
    }

    @Override
    public void run(){
        this.myClass.world();
    }

}

```

输出：
hello
world

即 hello先于world打印。
现在我们修改main函数：
```
public static void main(String[] args) {
    MyClass myClass = new MyClass();
    MyClass myClass2 = new MyClass();
    Thread t1 = new Thread1(myClass);
    Thread t2 = new Thread2(myClass2);

    t1.start();

    try {
        Thread.sleep(700);
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
    t2.start();
}
```

输出：
world
hello

由于t1和t2使用了2个不同的MyClass，那么synchronized锁住的对象也就不一样，线程之间互不影响，因为world首先打印出来。


### 结论
如果一个对象它里边有若干个synchronized方法，那么在某一时刻，只有一个线程能进入这里边的某一个synchronized方法，而其他线程想要进入其他的任意synchronized方法也要等待。
如果synchronized修饰static的方法，那么锁住的就是class对象。


### synchronized的几种不同的用法


#### 显式加锁对象

```
public class MyTest1 {

    private Object object = new Object();

    public void method(){
        synchronized (object){
            System.out.println("hello world");
        }
    }
}

```
查看字节码：
javap -c  com.twodragonlake.concurrency3.MyTest1

```
public void method();
  Code:
     0: aload_0
     1: getfield      #3                  // Field object:Ljava/lang/Object;
     4: dup
     5: astore_1
     6: monitorenter                      //进入监视器（获取锁）
     7: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
    10: ldc           #5                  // String hello world
    12: invokevirtual #6                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
    15: aload_1
    16: monitorexit                       //退出监视器（释放锁）
    17: goto          25
    20: astore_2
    21: aload_1
    22: monitorexit                       //防止异常的情况下保证锁一定能释放掉
    23: aload_2
    24: athrow
    25: return
  Exception table:
     from    to  target type
         7    17    20   any
        20    23    20   any
}

```

当我们使用synchronized关键字来修饰代码块时，字节码层面上是通过monitorenter和monitorexit指令来实现的锁的获取与释放动作。

修改method方法：
```
public void method(){
    synchronized (object){
        System.out.println("hello world");
        throw new RuntimeException();
    }
}
```

查看字节码：
```
public void method();
  Code:
     0: aload_0
     1: getfield      #3                  // Field object:Ljava/lang/Object;
     4: dup
     5: astore_1
     6: monitorenter                      //进入监视器
     7: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
    10: ldc           #5                  // String hello world
    12: invokevirtual #6                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
    15: new           #7                  // class java/lang/RuntimeException
    18: dup
    19: invokespecial #8                  // Method java/lang/RuntimeException."<init>":()V
    22: athrow
    23: astore_2
    24: aload_1
    25: monitorexit                      //退出监视器，因为肯定会抛出异常，所以只有这一个monitorexit。
    26: aload_2
    27: athrow                           //
  Exception table:
     from    to  target type
         7    26    23   any

```

当前线程进入到monitorenter指令后，线程将会持有Monitor对象，退出monitorenter指令后，线程将会释放Monitor对象。

#### synchronized对方法的同步

```
public class MyTest2 {

    public synchronized void method(){
        System.out.println("hello world");
    }

}
```
字节码：
```
public synchronized void method();
    descriptor: ()V
    flags: ACC_PUBLIC, ACC_SYNCHRONIZED
    Code:
      stack=2, locals=1, args_size=1
         0: getstatic     #2                  // Field java/lang/System.out:Ljava/io/PrintStream;
         3: ldc           #3                  // String hello world
         5: invokevirtual #4                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
         8: return
      LineNumberTable:
        line 13: 0
        line 14: 8
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0       9     0  this   Lcom/twodragonlake/concurrency3/MyTest2;

```

当synchronized修饰方法的时候看不到监视器的指令，但是怎么分辨是同步的呢？其实是通过方法的标示：
flags: ACC_PUBLIC, ACC_SYNCHRONIZED
ACC_SYNCHRONIZED标示是一个同步的方法。
对于synchronized关键字修饰方法来说，并没有监视器的进入和退出指令，而是出现了一个ACC_SYNCHRONIZED标志。
jvm使用了ACC_SYNCHRONIZED访问标志来区分一个方法是否为同步方法。
如果有，那么执行线程将会先持有方法所在对象的monitor对象，然后再去执行方法体；在该方法执行期间，
其他的任何线程均无法获取到这个Monitor对象，当线程执行完该方法后，它会释放掉这个Monitor对象。


#### synchronized修饰静态方法
编写代码：
```
public class MyTest3 {

    public static  synchronized  void  method(){
        System.out.println("hello world");
    }

}

```
字节码：

```
public static synchronized void method();
  descriptor: ()V
  flags: ACC_PUBLIC, ACC_STATIC, ACC_SYNCHRONIZED
  Code:
    stack=2, locals=0, args_size=0
       0: getstatic     #2                  // Field java/lang/System.out:Ljava/io/PrintStream;
       3: ldc           #3                  // String hello world
       5: invokevirtual #4                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
       8: return
    LineNumberTable:
      line 13: 0
      line 14: 8

```

访问标记：ACC_PUBLIC, ACC_STATIC, ACC_SYNCHRONIZED 相比非静态方法多了一个标志 ACC_STATIC。
即，方法 的字节码标志存在ACC_STATIC和ACC_SYNCHRONIZED的时候就是一个静态同步方法。

JVM中的同步是基于进入与退出监视器对象（管程对象）来实现的，每个对象实例都会有一个Monitor对象，Monitor对象和Java对象一同创建并销毁，Monitor对象是由C++来实现的。

当多个线程同时访问同一段同步代码时，这些线程会被放到一个EntryList集合中，处于阻塞状态的线程都会被放到该列表当中，接下来，当前线程获取到对象的Monitor时，Monitor是依赖于底层操作系统的mutex lock来实现互斥的，线程获取mutex成功，则会持有该mutex，这时其他线程无法再获取到该mutex。

如果线程调用了wait方法，那么该线程就会释放掉所持有的的mutex，并且该线程会进入到wait集合（等待集合）中，，等待下一次被其他线程调用notify/notifyall唤醒，如果当前线程顺利执行完毕方法，那么它也会释放掉所有持有mutex。

总结一下：同步锁在这种实现方式当中，因为Monitor是依赖于底层的操作系统实现，这样就存在用户态与内核态之间的切换，，所以会增加性能开销。
通过对象互斥锁的概念保证共享数据操作的完整性，每个对象都对应于一个可称为【互斥锁】的标记，这个标记用于保证在任何时刻，只能有一个线程访问该对象。


那些处于EntryList与waitSet中的线程均处于阻塞状态，阻塞操作是由操作系统来完成的，在inux下是通过pthread_mutex_local函数实现的。
线程被阻塞后便会进入到内核调度状态，这会导致系统用户态与内核态之间来回切换，严重影响锁的性能。


解决上述问题的办法便是自旋。其原理：当发生对Monitor的挣用时，若Owner能够在很短的时间内释放掉锁，则那些正在挣用的线程就可以稍微等待下，【即所谓的自旋】，在Owner线程释放锁之后，挣用线程可能会立刻获取到锁，从而避免了系统阻塞。不过，当Owner运行时间超过了临界值后，挣用线程自旋一段时间后依然无法获取到锁，这时挣用线程则会停止自旋从而到阻塞状态，所以总体的思想是：先自旋，不成功再进行阻塞，尽量降低阻塞的可能性，这对那些执行时间很短的代码块来说就有极大性能提升，显然，自旋在多处理器（多核心）上才有意义。
阻塞要进入到内核态，如果线程唤醒又会从内核态转到用户态，所以要尽量避免阻塞。


互斥锁的属性：
1. PTHREAD_MUTEX_TIMED_NP: 这是缺省值，也就是普通锁，当一个线程加锁以后，，其余请求锁的线程将会形成一个等待队列，并且在解锁后按照优先级获取到锁。这种策略可以确保资源分配的公平性。
2. PTHREAD_MUTEX_RECURSIVE_NP:  嵌套锁。允许一个线程对同一个锁成功获取多次，并通过unlock解锁。如果是不同线程请求，则在加锁线程解锁时重新进行竞争。
3. PTHREAD_MUTEX_ERRORCHECK_NP: 检错锁，如果一个线程请求同一个锁，则返回EDEADLK,否则与PTHREAD_MUTEX_TIMED_NP类型的动作相同，这样就保证了当不允许多次加锁时不会出现最简单情况下的死锁。
4. PTHREAD_MUTEX_ADAPTIVE_NP: 适应锁，动作最为简单的锁类型，仅仅等待解锁后重新竞争。



### ObjectMonitor openjdk 解读
synchronized关键字是通过monitor管理线程的同步，那么这个monitor在openjdk里边有哪些组成，干了一些什么事情？
其实在c++的层面monitor对应的c++类就是ObjectMonitor，它的头文件源码如下：
http://hg.openjdk.java.net/jdk8u/jdk8u/hotspot/file/bfac16f18d92/src/share/vm/runtime/objectMonitor.hpp

看一下初始化方法：

```
  // initialize the monitor, exception the semaphore, all other fields
  // are simple integers or pointers
  ObjectMonitor() {
    _header       = NULL;
    _count        = 0;
    _waiters      = 0,
    _recursions   = 0;     记录可重入锁重入的次数
    _object       = NULL;  
    _owner        = NULL;  当前锁的拥有者线程
    _WaitSet      = NULL;  线程调用了wait方法，就会进入这个队列
    _WaitSetLock  = 0 ;    简单的一个自旋锁【先自旋，自旋拿不到锁再进行内核态转换】
    _Responsible  = NULL ;
    _succ         = NULL ;
    _cxq          = NULL ; 最近的一个等待线程，也是一个ObjectMonitor的线程代理
    FreeNext      = NULL ;
    _EntryList    = NULL ; 等待进入monitor的线程都在_EntryList集合里边
    _SpinFreq     = 0 ;
    _SpinClock    = 0 ;
    OwnerIsThread = 0 ;
    _previous_owner_tid = 0;
  }
```

看一下它的处理架构：
![monitor.png](monitor.png)
waitSet采用链表的结构存储等待的线程的好处是，只要拿到一个线程就能访问其他的线程，在有些情况下可能针对于优先级唤醒有非常好的帮助。

### wait方法的实现
java的Object的wait方法，在objectMonitor.cpp里边，源码位置：
http://hg.openjdk.java.net/jdk8u/jdk8u/hotspot/file/bfac16f18d92/src/share/vm/runtime/objectMonitor.cpp
wait方法的开始是从1463---1690，定位到1508行：
![wait.png](wait.png)
ObjectWaiter node(Self);构建了一个ObjectWaiter的节点，然后调用 AddWaiter (&node) ;将其加入到waitset里边。
AddWaiter:
```
waitSet里边是一个双向链表，这里边都是在修改指针，将当前节点加入到链表。
inline void ObjectMonitor::AddWaiter(ObjectWaiter* node) {
  assert(node != NULL, "should not dequeue NULL node");
  assert(node->_prev == NULL, "node already in list");
  assert(node->_next == NULL, "node already in list");
  // put node at end of queue (circular doubly linked list)
  if (_WaitSet == NULL) {
    _WaitSet = node;
    node->_prev = node;
    node->_next = node;
  } else {
    ObjectWaiter* head = _WaitSet ;
    ObjectWaiter* tail = head->_prev;
    assert(tail->_next == head, "invariant check");
    tail->_next = node;
    head->_prev = node;
    node->_next = head;
    node->_prev = tail;
  }
}
```
wait方法里边的 exit (true, Self); 指的是线程进入waitSet之后就退出了monitor，释放对象的锁。


### notify方法
notify在从1698行开始。
![notify1.png](notify1.png)
看一下DequeueWaiter方法：
```
唤醒waitSet里边的第一个线程
inline ObjectWaiter* ObjectMonitor::DequeueWaiter() {
  // dequeue the very first waiter
  ObjectWaiter* waiter = _WaitSet;
  if (waiter) {
    DequeueSpecificWaiter(waiter);
  }
  return waiter;
}
```

在notify调用完DequeueWaiter拿到第一个线程之后，下边有一系列逻辑：
```
if (Policy != 4) {

}
if (Policy == 0) {  
}

if (Policy == 1) {
}
if (Policy == 2) {
}

if (Policy == 3) {
}

if (Policy < 4) {
}
```
Policy代表的是调度策略类型，不同的调度策略唤醒的线程会大不相同。
唤醒的线程会进入到EntryList,并且从waitSet移除：
举个例子：
```
if (Policy == 1) {      // append to EntryList
    if (List == NULL) {
        iterator->_next = iterator->_prev = NULL ;
        _EntryList = iterator ;
    } else {
       // CONSIDER:  finding the tail currently requires a linear-time walk of
       // the EntryList.  We can make tail access constant-time by converting to
       // a CDLL instead of using our current DLL.
       ObjectWaiter * Tail ;
       for (Tail = List ; Tail->_next != NULL ; Tail = Tail->_next) ;
       assert (Tail != NULL && Tail->_next == NULL, "invariant") ;
       Tail->_next = iterator ;
       iterator->_prev = Tail ;
       iterator->_next = NULL ;
   }
}
```


### 锁升级与偏向锁深入解析
在jdk1.5之前，，我们若想实现线程同步，只能通过synchronized关键字这一种方式达成，底层，java也是通过synchronized关键字来做到数据的原子性维护的；synchronized关键字是jvm实现的一种内置锁，从底层角度来说，这种锁的获取与释放都是由jvm帮助我们隐式实现的。

从jdk1.5开始，并发包引入了Lock锁，Lock这种同步锁是基于java来实现的，因此锁的获取与释放都是通过java代码来实现与控制的。

然后synchronized是基于底层操作系统的Mutex Lock来实现的，每次对锁的获取与释放动作都会带来用户态与内核态之间的切换，这种切换会极大地增加系统负担；在并发量较高时，也就是说锁的竞争比较激烈时，synchronized锁在性能上的表现就非常差。

从JDK1.6开始，synchronized锁的实现发生了很大的变化，JVM引入了相应的优化手段来提升synchronized锁的性能，这种提升涉及到偏向锁，轻量级锁及重量级锁等，从而减少锁的竞争锁带来的用户态与内核态之间的切换；这种锁的优化实际上是通过java对象头中的一些标志位来去实现的；对于锁的访问与改变，实际上都与对象头息息相关。

从JDK1.6开始，对象实例在堆当中划分为三个组成部分：对象头，实例数据与对齐填充。
对象头主要也是由三块内容构成：
1. Mark Word
2. 指向类的指针
3. 数组长度

其中Mark Word（它记录了对象，锁及垃圾回收相关的信息，在6位的jvm中，器长度也是64bit）的信息包括了如下组成部分：
1. 无锁标记
2. 偏向锁标记
3. 轻量级锁标记
4. 重量级锁标记
5. GC标记

对于synchronized锁来说，锁的升级主要是通过Mark Word中的锁标记位与是否偏向锁标志位来达成的，synchronized关键字所对应的锁都是先从偏向锁开始，随着锁竞争的不断升级，逐步演化至轻量级锁，最后则变成了重量级锁。

无锁 -> 偏向锁 -> 轻量级锁 -> 重量级锁

#### 偏向锁：
针对于一个线程来说的，它的主要作用是优化同一个线程多次获取一个锁的情况；如果一个synchronized方法被一个线程访问，那么这个方法所在的对象就会在其Mark Word中的将偏向锁进行标记，同时还会有一个字段来存储该线程的ID；当这个线程再次访问同一个synchronized方法时，他会检查这个对象的Mark Word的偏向锁标记以及是否指向了气线程id，如果是的话，那么该线程就无需进入管程(Monitor)，而是直接进入到该方法体中。

如果是另外一个线程访问synchronized方法，那么实际情况会如何呢？

偏向锁会被取消掉，升级为轻量级锁。

#### 轻量级锁：
若第一个线程已经获取到了当前对象的锁，这时第二个线程又开始尝试争抢该对象的锁，由于该对象的锁已经被第一个线程获取到，因此它是偏向锁，而第二个线程在争抢时，会发现该对象头中的Mark Word已经是偏向锁，但是里边存储的线程id并不是自己的（是第一个线程），那么它会进行CAS（Compare and Swap），从而获取到锁，这里边存在两种情况：
1. 获取锁成功：那么它会直接将Mark Word中的线程id由第一个线程变成自己（偏向锁标记为保持不变），这样改对象依然会保存锁的状态。
2. 获取锁失败：则表示这时可能会有多个线程同时尝试争抢该对象的锁，那么这时偏向锁就会进行升级，升级为轻量级锁。

#### 自旋锁：
若自旋失败（依然无法获取锁），那么锁就会转化为重量级锁，在这种情况下，无法获取到锁的线程都会进入到Monitor（即内核态）
自旋最大的一个特点就是避免了线程从用户态进入到内核态。

#### 重量级锁：
线程最终从用户态进入到内核态。


### 编译器对于锁的优化措施
#### 锁消除：
程序1：
```
public class MyTest4 {
    private Object object = new Object();
    public void method(){
       synchronized (object){
           System.out.println("hello world");
       }
    }
}

```

程序2：
```
public class MyTest4 {
    public void method(){
        Object object = new Object();
       synchronized (object){
           System.out.println("hello world");
       }
    }
}

```
程序2将锁对象object作为局部变量放在方法体里边，这样就意味着每个线程都有一个自己的锁，并不会像程序1那样在成员变量object上发生锁的竞争，观察程序2的字节码还是会有synchronized的相关字节码，但是在实际运行的时候，jit编译器会进行优化，会把程序2的synchronized关键字去掉。

JIT编译器（Just In Time编译器）可以在动态编辑同步代码时，使用一种叫做逃逸分析的技术，来通过该项技术判别程序中所使用的锁对象是否只被一个线程所使用，而没有散布到其他线程当中；如果情况就是这样的话，那么JIT编译器在编译这个同步代码时就不会生成synchronized
关键字所标示的锁的申请与释放机器码，从而消除了锁的使用流程。

#### 锁粗化：
```
public class MyTest5 {
    private Object object = new Object();
    public void method(){
        synchronized (object){
            System.out.println("hello world");
        }
        synchronized (object){
            System.out.println("welcome");
        }
        synchronized (object){
            System.out.println("person");
        }
    }
}
```

反编译结果：

javap  -c com.twodragonlake.concurrency3.MyTest5
```
public void method();
    Code:
       0: aload_0
       1: getfield      #3                  // Field object:Ljava/lang/Object;
       4: dup
       5: astore_1
       6: monitorenter                      【第一个synchronized的monitorenter】
       7: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
      10: ldc           #5                  // String hello world
      12: invokevirtual #6                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
      15: aload_1
      16: monitorexit                       【第一个synchronized的monitorexit】
      17: goto          25
      20: astore_2
      21: aload_1
      22: monitorexit                       【第一个synchronized的第二个monitorenter，异常情况释放锁用】
      23: aload_2
      24: athrow
      25: aload_0
      26: getfield      #3                  // Field object:Ljava/lang/Object;
      29: dup
      30: astore_1
      31: monitorenter                      【第二个synchronized的monitorenter】
      32: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
      35: ldc           #7                  // String welcome
      37: invokevirtual #6                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
      40: aload_1
      41: monitorexit                       【第二个synchronized的monitorexit】
      42: goto          50
      45: astore_3
      46: aload_1
      47: monitorexit                      【第二个synchronized的第二个monitorenter，异常情况释放锁用】
      48: aload_3
      49: athrow
      50: aload_0
      51: getfield      #3                  // Field object:Ljava/lang/Object;
      54: dup
      55: astore_1
      56: monitorenter                      【第三个synchronized的monitorenter】
      57: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
      60: ldc           #8                  // String person
      62: invokevirtual #6                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
      65: aload_1
      66: monitorexit                       【第三个synchronized的monitorexit】
      67: goto          77
      70: astore        4
      72: aload_1
      73: monitorexit                       【第三个synchronized的第二个monitorenter，异常情况释放锁用】
      74: aload         4
      76: athrow
      77: return
```

JIT编译器在执行动态编译时，若发现前后相邻的synchronized块使用的是同一个锁对象，那么它就会把这几个synchronized块给合并为一个较大的同步块，这样做的好处在于线程执行这些代码时，就无需频繁申请与释放锁了，从而达到申请与释放锁一次，就可以执行全部的同步代码块，从而提升了性能。
