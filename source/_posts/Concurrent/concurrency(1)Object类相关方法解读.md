---
title: concurrency(1)Object类相关方法解读
date: 2019-08-11 14:05:45
tags: [Object 并发]
categories: concurrency
---

### Object类的并发相关方法

-Object
  - clone
  - equals(Object)
  - finalize
  - getClass
  - hashCode
  - notify            *
  - notifyAll         *
  - registerNatives
  - toString
  - wait              *
  - wait(long)        *
  - wait(long,int)    *

#### wait()方法

####   public final native void wait(long timeout) throws InterruptedException;

Causes the current thread to wait until another thread invokes the notify() method or the notifyAll() method for this object. In other words, this method behaves exactly as if it simply performs the call wait(0).
The current thread must own this object's monitor. The thread releases ownership of this monitor and waits until another thread notifies threads waiting on this object's monitor to wake up either through a call to the notify method or the notifyAll method. The thread then waits until it can re-obtain ownership of the monitor and resumes execution.
As in the one argument version, interrupts and spurious wakeups are possible, and this method should always be used in a loop:
           synchronized (obj) {
               while (<condition does not hold>)
                   obj.wait();
               ... // Perform action appropriate to condition
           }

This method should only be called by a thread that is the owner of this object's monitor. See the notify method for a description of the ways in which a thread can become the owner of a monitor.

Throws:
IllegalMonitorStateException – if the current thread is not the owner of the object's monitor.
InterruptedException – if any thread interrupted the current thread before or while the current thread was waiting for a notification. The interrupted status of the current thread is cleared when this exception is thrown.
See Also:
notify(), notifyAll()


wait()方法会让当前线程等待，直到其他线程调用了Object的notify()或者notifyAll()方法。
换句话说，这个方法和执行wait(0)的效果是一样的。

当前线程必须要拥有对象(Object对象)的监视器(锁)，当调用了wait()方法的时候会释放锁的拥有权，然后进入等待，直到拥有这把锁的其他线程调用了这个对象的锁的notify或者notifyAll方法才会被唤醒，线程进入等待，直到可以重新获取锁的拥有权，并且回复执行。
对于单参数的版本来说，中断和虚假的唤醒是可能发生的，这个方法会用于一个循环当中：
synchronized (obj) {
    while (<condition does not hold>)
        obj.wait();
    ... // Perform action appropriate to condition
}
wait放只能被拥有当前对象锁的线程去执行，请参看notify方法的描述一个线程怎么获取到一把锁。

##### 验证wait方法必须获取锁
编写代码：
```
public class MyTest1 {
    public static void main(String[] args) throws InterruptedException {
        Object object = new Object();
        object.wait();
    }
}
```
抛出异常：
Exception in thread "main" java.lang.IllegalMonitorStateException
	at java.lang.Object.wait(Native Method)
	at java.lang.Object.wait(Object.java:502)
	at com.twodragonlake.concurrency1.MyTest1.main(MyTest1.java:13)

如果我们先获取锁：
```
public static void main(String[] args) throws InterruptedException {
    Object object = new Object();
    synchronized (object){
        object.wait();
    }
}
```
这样不会出现异常。


#### Object.wait()和Thread.sleep()的区别
Thread的sleep()的doc：
Causes the currently executing thread to sleep (temporarily cease execution) for the specified number of milliseconds, subject to the precision and accuracy of system timers and schedulers. The thread does not lose ownership of any monitors.

让当前线程睡眠用户指定的毫秒数，当前线程不会丢失锁的拥有权。

而Object的wait方法调用之后会释放锁。

#### 通过字节码观察
反编译测试类MyTest1
javap -c  com.twodragonlake.concurrency1.MyTest1

找到main方法的反编译部分：
```
public static void main(java.lang.String[]) throws java.lang.InterruptedException;
  Code:
     0: new           #2                  // class java/lang/Object
     3: dup
     4: invokespecial #1                  // Method java/lang/Object."<init>":()V
     7: astore_1
     8: aload_1
     9: dup
    10: astore_2
    11: monitorenter                     //synchronized开始的时候，获取监视器
    12: aload_1
    13: invokevirtual #3                  // Method java/lang/Object.wait:()V
    16: aload_2
    17: monitorexit
    18: goto          26
    21: astore_3
    22: aload_2
    23: monitorexit                      //监视器的退出。
    24: aload_3
    25: athrow
    26: return
  Exception table:
     from    to  target type
        12    18    21   any
        21    24    21   any
}
```

#### public final void wait(long timeout) throws InterruptedException
doc：

Causes the current thread to wait until either another thread invokes the notify() method or the notifyAll() method for this object, or a specified amount of time has elapsed.
The current thread must own this object's monitor.
This method causes the current thread (call it T) to place itself in the wait set for this object and then to relinquish(放弃) any and all synchronization claims on this object. Thread T becomes disabled for thread scheduling purposes and lies dormant until one of four things happens:
Some other thread invokes the notify method for this object and thread T happens to be arbitrarily chosen as the thread to be awakened(唤醒).
Some other thread invokes the notifyAll method for this object.
Some other thread interrupts thread T.
The specified amount of real time has elapsed, more or less. If timeout is zero, however, then real time is not taken into consideration and the thread simply waits until notified.
The thread T is then removed from the wait set for this object and re-enabled for thread scheduling. It then competes in the usual manner with other threads for the right to synchronize on the object; once it has gained control of the object, all its synchronization claims on the object are restored to the status quo ante - that is, to the situation as of the time that the wait method was invoked. Thread T then returns from the invocation of the wait method. Thus, on return from the wait method, the synchronization state of the object and of thread T is exactly as it was when the wait method was invoked.
A thread can also wake up without being notified, interrupted, or timing out, a so-called spurious wakeup. While this will rarely occur in practice, applications must guard against it by testing for the condition that should have caused the thread to be awakened, and continuing to wait if the condition is not satisfied. In other words, waits should always occur in loops, like this one:
           synchronized (obj) {
               while (<condition does not hold>)
                   obj.wait(timeout);
               ... // Perform action appropriate to condition
           }

(For more information on this topic, see Section 3.2.3 in Doug Lea's "Concurrent Programming in Java (Second Edition)" (Addison-Wesley, 2000), or Item 50 in Joshua Bloch's "Effective Java Programming Language Guide" (Addison-Wesley, 2001).
If the current thread is interrupted by any thread before or while it is waiting, then an InterruptedException is thrown. This exception is not thrown until the lock status of this object has been restored as described above.
Note that the wait method, as it places the current thread into the wait set for this object, unlocks only this object; any other objects on which the current thread may be synchronized remain locked while the thread waits.
This method should only be called by a thread that is the owner of this object's monitor. See the notify method for a description of the ways in which a thread can become the owner of a monitor.

此方法会导致当前线程等待，直到其他线程调用object对象的notify或者notifyall方法，或者时间超时。
当前线程必须拥有obect对象的锁。
这个方法会导致当前线程将它自己放在一个object对象的等待集合当中，放弃对这个对象的同步声明，即放弃锁，这个线程无法进行线程调度，会进入休眠等待，直到下面的四件事情发生：
 - 其他线程调用了这个对象的notify方法，当前线程碰巧被选中成为被唤醒的线程。
 - 其他的额线程调用了对象的notifyall方法
 - 其他线程中断了当前线程。
 - 指定的时间超时，不过呢，如果timeout的值是0，实际上时间是不会考虑的，会一直等待。

如果发生以上四件事情，当前线程就会从当前对象的等待队列移除，然后又可以进行线程的调度，会按照通常的方式和其他的线程进行竞争，竞争这个对象的同步控制权， 一旦获取了对象的控制权，所有对这个对象的同步声明都会恢复，恢复到wait方法曾经被调用的时候的状态。线程就会从wait方法调用当中返回， 这个时候对象和线程的状态和被调用wait方法的时候的状态是一模一样的。
 一个线程被唤醒也可以不通过notify，中断，或者超时，即一个虚假的唤醒，虽然在实际当中很少出现，但是应用也要做一些规避措施来避免线程被不正当的唤醒，即，wait应该总是发生在循环当中，就像如下：
 ```
 synchronized (obj) {
     while (<condition does not hold>)
         obj.wait(timeout);
     ... // Perform action appropriate to condition
 }
 ```
(更多的信息参考Doug Lea'sjava并发编程第二章节，或者Joshua Bloch's的高效java 语言指南的50章节)

如果当前线程在等待之前和等待过程之中被其他线程中断了，InterruptedException就会被抛出，异常会在对象的锁的状态已经恢复到之前描述的样子才会抛出，而不是立马抛出。

这个wait方法会把当前的线程放到对象的等待集合当中，只会解锁这个对象，这个线程等待的其他锁所在的对象不会受到影响。

这个方法应该被获取到对象锁的线程被调用，参考notify方法的介绍，了解对象怎么获取对象的锁。

#### public final void wait(long timeout, int nanos)
nanos的范围是 0-999999.
会调用【public final void wait(long timeout) throws InterruptedException】

### notify()方法
doc：
Wakes up a single thread that is waiting on this object's monitor. If any threads are waiting on this object, one of them is chosen to be awakened. The choice is arbitrary and occurs at the discretion of the implementation. A thread waits on an object's monitor by calling one of the wait methods.
The awakened thread will not be able to proceed until the current thread relinquishes the lock on this object. The awakened thread will compete in the usual manner with any other threads that might be actively competing to synchronize on this object; for example, the awakened thread enjoys no reliable privilege or disadvantage in being the next thread to lock this object.
This method should only be called by a thread that is the owner of this object's monitor. A thread becomes the owner of the object's monitor in one of three ways:
By executing a synchronized instance method of that object.
By executing the body of a synchronized statement that synchronizes on the object.
For objects of type Class, by executing a synchronized static method of that class.
Only one thread at a time can own an object's monitor.

唤醒等待在对象锁上的一个线程。
如果有多个等在在对象锁上，选择一个被唤醒。选择的随意性和慎重行根据不同的实现而不同。一个线程会通过调用对象的wait去等待。
被唤醒的线程是无法被执行的，除非它获取了正在执行的线程放弃的对象锁。被唤醒的线程会按照通常的方式和其他的线程进行竞争， 竞争对这个对象的同步权（谁拿到了锁 ，谁就有控制权），比如一个没有权限的或者没有缺陷的线程都有可能成为获取锁的线程。

这个方法只能被获取了对象锁的线程所调用，一个线程获取锁的方式有如下三种方式：
- 执行对象的synchronized的方法获取锁。
- 执行对象当中synchronized代码块获取锁。
- 对于class类型的对象，调用class的静态的synchronized方法获取锁。

在某一时刻只有一个线程才持有对象的锁。
