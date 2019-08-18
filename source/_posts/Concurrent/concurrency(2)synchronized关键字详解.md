---
title: concurrency(2)synchronized关键字详解
date: 2019-08-11 14:05:45
tags: [Object 并发]
categories: concurrency
---

### 变量在多线程之间的影响
编写程序：
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
