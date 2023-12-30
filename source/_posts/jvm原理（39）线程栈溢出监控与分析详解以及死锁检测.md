---
title: jvm原理（39）线程栈溢出监控与分析详解以及死锁检测
date: 2019-04-21 19:47:58
tags: [死锁, jconsole, jvisualvm]
categories: jvm
---

### java.lang.StackOverflowError

<!-- more -->
编写程序：
```
//配置jvm参数：-Xss160k
public class MyTest2 {

    private int length;

    public int getLength() {
        return length;
    }

    public void test(){
        this.length++;
        test();
    }

    public static void main(String[] args) {
        MyTest2 myTest2 = new MyTest2();
        try {
            myTest2.test();
        }catch (Throwable throwable){
            System.out.println(myTest2.getLength());
            throwable.printStackTrace();
        }
    }

}

```
结果：
```
1743
java.lang.StackOverflowError
	at com.twodragonlake.jvm.memory.MyTest2.test(MyTest2.java:35)
```
即到了1743次递归的时候出现了错误。

现在我们使用jvisualvm体现下线程的堆栈日志：
为了延迟出现StackOverflowError我们在test方法里边加了线程延迟：
```
public void test() throws InterruptedException {
    this.length++;
    Thread.sleep(300);
    test();
}
```
然后打开jvisualvm：
![jstack1](2019/04/21/jvm原理（39）线程栈溢出监控与分析详解以及死锁检测/jstack1.png)
可以看到很多线程。其中就有main线程。
![jstack1](jstack2.png)
线程dump之后会出现当前所有线程的日志。

### jconsole
我们在运行MyTest2的时候，使用jconsole命令可以打开jconsole的界面：
我们连接MyTest2
![jconsole](2019/04/21/jvm原理（39）线程栈溢出监控与分析详解以及死锁检测/jconsole1.png)
在线程tab里边点开main线程，右边出现的等待次数就是Thread.sleep(300);的次数，每次刷新都会变化的。
![jconsole](2019/04/21/jvm原理（39）线程栈溢出监控与分析详解以及死锁检测/jconsole2.png)
实际工作中我们可以使用jvisualvm和jconsole配合使用。
下边有一个按钮是“检测死锁”，我们点了一下提示没有检测到死锁。这个功能在做底层开发的时候会使用到。

### 死锁检测
编写一个产生死锁的程序：
```
public class DeadLock {
    private static Object lock1 = new Object();
    private static  Object lock2 = new Object();

    public static void main(String[] args) {
        Thread thread1 = new Thread(new Runnable() {
            @Override
            public void run() {
                synchronized (lock1){
                    System.out.println("get lock1");
                    synchronized (lock2){
                        System.out.println("get lock2");
                    }
                }
            }
        });
        Thread thread2 = new Thread(new Runnable() {
            @Override
            public void run() {
                synchronized (lock2){
                    System.out.println("get lock2");
                    synchronized (lock1){
                        System.out.println("get lock1");
                    }
                }
            }
        });

        thread1.start();
        thread2.start();
    }
}
```
打开jconsole，执行“检测死锁”这个时候我们检测到了死锁的结果。
![deadlock](2019/04/21/jvm原理（39）线程栈溢出监控与分析详解以及死锁检测/deadlock1.png)
![deadlock](2019/04/21/jvm原理（39）线程栈溢出监控与分析详解以及死锁检测/deadlock2.png)

Thread-0持有锁java.lang.Object@59307d92， 状态是BLOCK，证明是在java.lang.Object@3818ced5上阻塞。但是java.lang.Object@3818ced5的拥有者是Thread-1。
Thread-1持有锁java.lang.Object@3818ced5， 状态是BLOCK，证明是在java.lang.Object@59307d92上阻塞，但是java.lang.Object@59307d92的拥有者是Thread-0。
这就是死锁。

另外我们没有看到main线程的影子，其实执行完 thread1.start(); thread2.start();之后面线程就退出了，如果想让main出现可以在thread1.start(); thread2.start();加一句：
 Thread.sleep(40000);main就会出现，如图：
![deadlock](2019/04/21/jvm原理（39）线程栈溢出监控与分析详解以及死锁检测/deadlock3.png)  

现在我们jvisualvm检测一下：
![deadlock](2019/04/21/jvm原理（39）线程栈溢出监控与分析详解以及死锁检测/deadlock4.png)  
之后打开dump的日志，在日志底部会打印：
```
Found one Java-level deadlock:
=============================
"thread2":
  waiting to lock monitor 0x000000001c6b3608 (object 0x000000076b327330, a java.lang.Object),
  which is held by "thread1"
"thread1":
  waiting to lock monitor 0x000000001e7c9f78 (object 0x000000076b327340, a java.lang.Object),
  which is held by "thread2"

Java stack information for the threads listed above:
===================================================
"thread2":
	at com.twodragonlake.jvm.memory.DeadLock$2.run(DeadLock.java:48)
	- waiting to lock <0x000000076b327330> (a java.lang.Object)
	- locked <0x000000076b327340> (a java.lang.Object)
	at java.lang.Thread.run(Thread.java:745)
"thread1":
	at com.twodragonlake.jvm.memory.DeadLock$1.run(DeadLock.java:37)
	- waiting to lock <0x000000076b327340> (a java.lang.Object)
	- locked <0x000000076b327330> (a java.lang.Object)
	at java.lang.Thread.run(Thread.java:745)

Found 1 deadlock.
```
