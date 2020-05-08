---
title: concurrency(6)Condition详解
date: 2020-01-04 14:00:45
tags: [Condition Lock]
categories: concurrency
---

### Condition
Lock接口里边有一个方法【Condition newCondition();】，返回的是一个Condition实例；
<!-- more -->
看一下Condition的doc：
Returns a new Condition instance that is bound to this Lock instance.
Before waiting on the condition the lock must be held by the current thread. A call to Condition.await() will atomically release the lock before waiting and re-acquire the lock before the wait returns.
返回一个绑定到当前锁实例的一个Condition。
在等待Condition之前当前线程必须要获取到Condition绑定的锁实例。
调用Condition.await()方法的时候将会自动释放锁，在等待重新获取锁和wait方法之前。

传统上，我们可以通过synchronized关键字+wait + notify/notifyall来实现多个线程之间的协调与通信，整个 过程都是由jvm来帮助实现的，开发者无需（也是无法）了解底层实现细节。
从jdk1.5开始，并发包提供了lock，Condation(wait与notify/signalAll)来实现多个线程之间协调与通信，整个过程都是由开发者来控制的 而且相比于传统方式，更加灵活，功能也更加强。

Thread.sleep与await（或是Object的wait方法）的本质区别：sleep方法本质上不会释放锁，而await会释放锁，并且在signal之后，还需要重新获取到锁才能继续执行（该行为与Object的wait方法完全一致）


#### doc说明
Condition factors out the Object monitor methods (wait, notify and notifyAll) into distinct objects to give the effect of having multiple wait-sets per object, by combining them with the use of arbitrary Lock implementations. Where a Lock replaces the use of synchronized methods and statements, a Condition replaces the use of the Object monitor methods.
Conditions (also known as condition queues or condition variables) provide a means for one thread to suspend execution (to "wait") until notified by another thread that some state condition may now be true. Because access to this shared state information occurs in different threads, it must be protected, so a lock of some form is associated with the condition. The key property that waiting for a condition provides is that it atomically releases the associated lock and suspends the current thread, just like Object.wait.
A Condition instance is intrinsically bound to a lock. To obtain a Condition instance for a particular Lock instance use its newCondition() method.
As an example, suppose we have a bounded buffer which supports put and take methods. If a take is attempted on an empty buffer, then the thread will block until an item becomes available; if a put is attempted on a full buffer, then the thread will block until a space becomes available. We would like to keep waiting put threads and take threads in separate wait-sets so that we can use the optimization of only notifying a single thread at a time when items or spaces become available in the buffer. This can be achieved using two Condition instances.
   class BoundedBuffer {
     final Lock lock = new ReentrantLock();
     final Condition notFull  = lock.newCondition();
     final Condition notEmpty = lock.newCondition();

     final Object[] items = new Object[100];
     int putptr, takeptr, count;

     public void put(Object x) throws InterruptedException {
       lock.lock();
       try {
         while (count == items.length)
           notFull.await();
         items[putptr] = x;
         if (++putptr == items.length) putptr = 0;
         ++count;
         notEmpty.signal();
       } finally {
         lock.unlock();
       }
     }

     public Object take() throws InterruptedException {
       lock.lock();
       try {
         while (count == 0)
           notEmpty.await();
         Object x = items[takeptr];
         if (++takeptr == items.length) takeptr = 0;
         --count;
         notFull.signal();
         return x;
       } finally {
         lock.unlock();
       }
     }
   }

(The java.util.concurrent.ArrayBlockingQueue class provides this functionality, so there is no reason to implement this sample usage class.)
A Condition implementation can provide behavior and semantics that is different from that of the Object monitor methods, such as guaranteed ordering for notifications, or not requiring a lock to be held when performing notifications. If an implementation provides such specialized semantics then the implementation must document those semantics.
Note that Condition instances are just normal objects and can themselves be used as the target in a synchronized statement, and can have their own monitor wait and notification methods invoked. Acquiring the monitor lock of a Condition instance, or using its monitor methods, has no specified relationship with acquiring the Lock associated with that Condition or the use of its waiting and signalling methods. It is recommended that to avoid confusion you never use Condition instances in this way, except perhaps within their own implementation.
Except where noted, passing a null value for any parameter will result in a NullPointerException being thrown.
Implementation Considerations
When waiting upon a Condition, a "spurious wakeup" is permitted to occur, in general, as a concession to the underlying platform semantics. This has little practical impact on most application programs as a Condition should always be waited upon in a loop, testing the state predicate that is being waited for. An implementation is free to remove the possibility of spurious wakeups but it is recommended that applications programmers always assume that they can occur and so always wait in a loop.
The three forms of condition waiting (interruptible, non-interruptible, and timed) may differ in their ease of implementation on some platforms and in their performance characteristics. In particular, it may be difficult to provide these features and maintain specific semantics such as ordering guarantees. Further, the ability to interrupt the actual suspension of the thread may not always be feasible to implement on all platforms.
Consequently, an implementation is not required to define exactly the same guarantees or semantics for all three forms of waiting, nor is it required to support interruption of the actual suspension of the thread.
An implementation is required to clearly document the semantics and guarantees provided by each of the waiting methods, and when an implementation does support interruption of thread suspension then it must obey the interruption semantics as defined in this interface.
As interruption generally implies cancellation, and checks for interruption are often infrequent, an implementation can favor responding to an interrupt over normal method return. This is true even if it can be shown that the interrupt occurred after another action that may have unblocked the thread. An implementation should document this behavior.

Condition相当于把Object的监控器方法(wait,notify和notifyall)插入到各种不同的对象当中，达到让每一个对象拥有多个等待集合的效果，通过任意的一个锁的实现组合起来，其中会用lock替代synchronized语句和代码块，Condition会替代Object的monitor方法的使用。

Condition又叫做条件队列或者条件变量，Condition提供了一种方式可以让线程挂起（等待），直到被另一个线程发现共享变量信息为true把它唤醒为止，由于共享变量的信息可以在不同的线程里边可见，因此它必须要受到保护，这样就一定要lock和Condition绑定起来。等待这个条件的属性，会自动的释放关联的锁，挂起当前的线程，就像Object的wait方法一样。

一个Condition实例天然的绑定到lock上，我们使用newCondition()获取一个特定的lock实例对应的Condition实例。
举例，假设有一个有界的缓冲区，有take和put方法，如果take的时候是一个空的buffer直到有元素可取，那么当前线程阻塞，如果put一个满的buffer的时候，当前线程阻塞直到有空闲位置可塞，这样可以保持put和take线程等待在2个不同的等待集合里边。
```
class BoundedBuffer {
     final Lock lock = new ReentrantLock();
     final Condition notFull  = lock.newCondition();
     final Condition notEmpty = lock.newCondition();

     final Object[] items = new Object[100];
     int putptr, takeptr, count;

     public void put(Object x) throws InterruptedException {
       lock.lock();
       try {
         while (count == items.length)
           notFull.await();
         items[putptr] = x;
         if (++putptr == items.length) putptr = 0;
         ++count;
         notEmpty.signal();
       } finally {
         lock.unlock();
       }
     }

     public Object take() throws InterruptedException {
       lock.lock();
       try {
         while (count == 0)
           notEmpty.await();
         Object x = items[takeptr];
         if (++takeptr == items.length) takeptr = 0;
         --count;
         notFull.signal();
         return x;
       } finally {
         lock.unlock();
       }
     }
   }
```
java.util.concurrent.ArrayBlockingQueue已经实现了上述的功能，因此没有必要再实现相同的class。
Condition提供的行为或者语义和Object的monitor可以是不一样的，比如通知的确定性的排序，或者执行通知的时候不要求持有锁，如果实现实现了这样的语义，那么不需要在文档里边指明。

Condition仅仅是普通的对象，他们自己也可以作为synchronized的目标，可以有他们自己的wait和notify方法，获取Condition实例的监视器锁或者使用监视器方法和获取Condition绑定的锁以及使用Condition的waiting和signalling方法没有任何关联。推荐避免使用Condition的实例的监视器相关方式，除非是在他们自己的实现当中。

除非有说明，Condition的任何null的参数都会抛出NullPointerException 异常。

##### 实现上的考量
在等待条件发生的时候，一种假的唤醒是允许发生的，通常作为一种所属平台的语义，这对大多数的应用程序不会产生实际的影响，Condition通常会在一个while循环当中去等待，测试等待的条件是否被满足。
三种条件的等待(可中断，不可中断，超时)在一些平台的实现是不一样的，我们很难实现这些语义的。
每一个实现要在文档中说明它所实现的语气。
略。


### Condition.await()
Causes the current thread to wait until it is signalled or interrupted.
The lock associated with this Condition is atomically released and the current thread becomes disabled for thread scheduling purposes and lies dormant until one of four things happens:
Some other thread invokes the signal method for this Condition and the current thread happens to be chosen as the thread to be awakened; or
Some other thread invokes the signalAll method for this Condition; or
Some other thread interrupts the current thread, and interruption of thread suspension is supported; or
A "spurious wakeup" occurs.
In all cases, before this method can return the current thread must re-acquire the lock associated with this condition. When the thread returns it is guaranteed to hold this lock.
If the current thread:
has its interrupted status set on entry to this method; or
is interrupted while waiting and interruption of thread suspension is supported,
then InterruptedException is thrown and the current thread's interrupted status is cleared. It is not specified, in the first case, whether or not the test for interruption occurs before the lock is released.
Implementation Considerations
The current thread is assumed to hold the lock associated with this Condition when this method is called. It is up to the implementation to determine if this is the case and if not, how to respond. Typically, an exception will be thrown (such as IllegalMonitorStateException) and the implementation must document that fact.
An implementation can favor responding to an interrupt over normal method return in response to a signal. In that case the implementation must ensure that the signal is redirected to another waiting thread, if there is one.
让当前线程挂起，直到被唤醒或者被中断。
和当前Condition关联到的锁自动释放，当前的线程无法得到调度，进入休眠状态，直到如下四个条件发生：
- 其他线程调用了当前Condition的signal方法，并且当前线程被选中被唤醒。
- 其他线程调用了Condition的signalAll；
- 其他的线程中断了当前线程，并且线程中断和挂起是被支持的；
- 假唤醒发生；

在所有的情况当中，在方法返回之前，当前线程必须要重新获取到Condition关联的锁，当线程返回的时候，确保线程持有锁。

如果当前线程满足：
- 当前线程在进入这个方法之前设置了中断状态，或者
- 在等待的时候被中断，并且中断和挂起是被支持的。
InterruptedException异常将会抛出，当前线程的中断状态将会被清除。

### Condition.awaitUninterruptibly()
等待，不可中断
Causes the current thread to wait until it is signalled.
The lock associated with this condition is atomically released and the current thread becomes disabled for thread scheduling purposes and lies dormant until one of three things happens:
Some other thread invokes the signal method for this Condition and the current thread happens to be chosen as the thread to be awakened; or
Some other thread invokes the signalAll method for this Condition; or
A "spurious wakeup" occurs.
In all cases, before this method can return the current thread must re-acquire the lock associated with this condition. When the thread returns it is guaranteed to hold this lock.
If the current thread's interrupted status is set when it enters this method, or it is interrupted while waiting, it will continue to wait until signalled. When it finally returns from this method its interrupted status will still be set.
让当前线程挂起，直到被唤醒
和当前Condition关联到的锁自动释放，当前的线程无法得到调度，进入休眠状态，直到如下四个条件发生：
- 其他线程调用了当前Condition的signal方法，并且当前线程被选中被唤醒。
- 其他线程调用了Condition的signalAll；
- 假唤醒发生；

在所有的情况当中，在方法返回之前，当前线程必须要重新获取到Condition关联的锁，当线程返回的时候，确保线程持有锁。

### long Condition.awaitNanos(long nanosTimeout)
等待纳秒时间
让当前线程挂起，直到被唤醒或者被中断，或者指定的时间已经过去了。
返回结果的long值的意义：比我我们的nanosTimeout是500，但是我们等了300就返回了，那么返回的long是200，就是剩余的时间。
如果返回值是小于等于0，就是超时了，在给定的时间并没有返回，可以重新去等待。
为了减少误差参数使用了纳秒，减少误差。

### boolean await(long time, TimeUnit unit)

### boolean awaitUntil(Date deadline)
指定在未来的一个时间作为超时的判定

### void signal()
Wakes up one waiting thread.
If any threads are waiting on this condition then one is selected for waking up. That thread must then re-acquire the lock before returning from await.
唤醒一个等待的线程。

如果有多个线程在condition等待，那么就选择一个去唤醒，被唤醒的线程在从wait方法返回之前必须要重新获取到锁。

### void signalAll()
Wakes up all waiting threads.
If any threads are waiting on this condition then they are all woken up. Each thread must re-acquire the lock before it can return from await.

唤醒所有的等待线程，每个线程在从wait方法返回之前必须重新获取到锁。

注意被唤醒和继续执行是不一样的，有10个线程同时等待在一个Condition上，第11个线程调用了Condition的signalAll方法，那么另外的等待的10个线程只有一个拿到锁，并且继续执行，剩余的9个都在轮询获取锁的过程之中，并没有得到执行。

### 通过Condition实现线程间通信实例剖析
```
public class MyTest2 {
    public static void main(String[] args) {
        BoundedContainer boundedContainer = new BoundedContainer();
        IntStream.range(0,10).forEach(i -> new Thread(() -> {
            try {
                boundedContainer.put("hello"+i);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start());

        IntStream.range(0,10).forEach(i -> new Thread(() -> {
            try {
                boundedContainer.take();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start());
    }
}

class BoundedContainer {

    private String[] elements = new String[10];

    private Lock lock = new ReentrantLock();

    private Condition notEmptyCondition = lock.newCondition();

    private Condition notFullCondition = lock.newCondition();

    private int elementCount;//elements数组中已有元素数量

    private int putIndex;

    private int takeIndex;


    public void put(String element) throws InterruptedException {
        lock.lock();
        try{
            while (elementCount == elements.length){
                notFullCondition.await();
            }
            elements[putIndex] = element;
            if(++putIndex == elements.length){
                putIndex = 0;
            }
            ++elementCount;
            System.out.println("put method :" + Arrays.toString(elements));
            notEmptyCondition.signal();
        }finally {
            lock.unlock();
        }
    }

    public String take() throws InterruptedException {
        lock.lock();
        String element;
        try{
            while (elementCount == 0){
                notEmptyCondition.await();
            }
            element = elements[takeIndex];
            elements[takeIndex] = null;
            if(++takeIndex == elements.length){
                takeIndex = 0;
            }
            --elementCount;
            System.out.println("take method :" + Arrays.toString(elements));
            notFullCondition.signal();
            return element;
        }finally {
            lock.unlock();
        }
    }

}
```

输出：
```
put method :[hello0, null, null, null, null, null, null, null, null, null]
put method :[hello0, hello7, null, null, null, null, null, null, null, null]
put method :[hello0, hello7, hello8, null, null, null, null, null, null, null]
put method :[hello0, hello7, hello8, hello1, null, null, null, null, null, null]
put method :[hello0, hello7, hello8, hello1, hello2, null, null, null, null, null]
put method :[hello0, hello7, hello8, hello1, hello2, hello3, null, null, null, null]
put method :[hello0, hello7, hello8, hello1, hello2, hello3, hello4, null, null, null]
put method :[hello0, hello7, hello8, hello1, hello2, hello3, hello4, hello6, null, null]
put method :[hello0, hello7, hello8, hello1, hello2, hello3, hello4, hello6, hello5, null]
put method :[hello0, hello7, hello8, hello1, hello2, hello3, hello4, hello6, hello5, hello9]
take method :[null, hello7, hello8, hello1, hello2, hello3, hello4, hello6, hello5, hello9]
take method :[null, null, hello8, hello1, hello2, hello3, hello4, hello6, hello5, hello9]
take method :[null, null, null, hello1, hello2, hello3, hello4, hello6, hello5, hello9]
take method :[null, null, null, null, hello2, hello3, hello4, hello6, hello5, hello9]
take method :[null, null, null, null, null, hello3, hello4, hello6, hello5, hello9]
take method :[null, null, null, null, null, null, hello4, hello6, hello5, hello9]
take method :[null, null, null, null, null, null, null, hello6, hello5, hello9]
take method :[null, null, null, null, null, null, null, null, hello5, hello9]
take method :[null, null, null, null, null, null, null, null, null, hello9]
take method :[null, null, null, null, null, null, null, null, null, null]
```

修改main方法执行顺序：
```
BoundedContainer boundedContainer = new BoundedContainer();
IntStream.range(0,10).forEach(i -> new Thread(() -> {
    try {
        boundedContainer.take();
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
}).start());
IntStream.range(0,10).forEach(i -> new Thread(() -> {
    try {
        boundedContainer.put("hello"+i);
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
}).start());
```

执行结果：
```
put method :[hello0, null, null, null, null, null, null, null, null, null]
put method :[hello0, hello1, null, null, null, null, null, null, null, null]
put method :[hello0, hello1, hello2, null, null, null, null, null, null, null]
put method :[hello0, hello1, hello2, hello3, null, null, null, null, null, null]
put method :[hello0, hello1, hello2, hello3, hello4, null, null, null, null, null]
put method :[hello0, hello1, hello2, hello3, hello4, hello6, null, null, null, null]
put method :[hello0, hello1, hello2, hello3, hello4, hello6, hello5, null, null, null]
put method :[hello0, hello1, hello2, hello3, hello4, hello6, hello5, hello7, null, null]
take method :[null, hello1, hello2, hello3, hello4, hello6, hello5, hello7, null, null]
put method :[null, hello1, hello2, hello3, hello4, hello6, hello5, hello7, hello8, null]
take method :[null, null, hello2, hello3, hello4, hello6, hello5, hello7, hello8, null]
put method :[null, null, hello2, hello3, hello4, hello6, hello5, hello7, hello8, hello9]
take method :[null, null, null, hello3, hello4, hello6, hello5, hello7, hello8, hello9]
take method :[null, null, null, null, hello4, hello6, hello5, hello7, hello8, hello9]
take method :[null, null, null, null, null, hello6, hello5, hello7, hello8, hello9]
take method :[null, null, null, null, null, null, hello5, hello7, hello8, hello9]
take method :[null, null, null, null, null, null, null, hello7, hello8, hello9]
take method :[null, null, null, null, null, null, null, null, hello8, hello9]
take method :[null, null, null, null, null, null, null, null, null, hello9]
take method :[null, null, null, null, null, null, null, null, null, null]
```
由于先执行的take线程，但是没有元素会一直wait，直到put线程生成元素之后，take线程才会得到执行，但是和take线程争夺所资源的还有put线程。

如果线程数量大于数组的长度10，也会在put方法的while方法上等待，直到可以put为止。

如果put线程数量小于take线程数量，那么程序不会结束，因为take线程会阻塞在while循环上面，直到有数据可以取出，但是put线程都已经完毕了，不会有元素添加，那么take线程会一直阻塞下去。
