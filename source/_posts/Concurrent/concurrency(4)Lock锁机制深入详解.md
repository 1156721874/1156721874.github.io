---
title: concurrency(4)Lock锁机制深入详解
date: 2019-12-08 12:58:45
tags: [concurrency Lock]
categories: concurrency
---

### Lock接口
Lock implementations provide more extensive locking operations than can be obtained using synchronized methods and statements. They allow more flexible structuring, may have quite different properties, and may support multiple associated Condition objects.
A lock is a tool for controlling access to a shared resource by multiple threads. Commonly, a lock provides exclusive access to a shared resource: only one thread at a time can acquire the lock and all access to the shared resource requires that the lock be acquired first. However, some locks may allow concurrent access to a shared resource, such as the read lock of a ReadWriteLock.
The use of synchronized methods or statements provides access to the implicit monitor lock associated with every object, but forces all lock acquisition and release to occur in a block-structured way: when multiple locks are acquired they must be released in the opposite order, and all locks must be released in the same lexical scope in which they were acquired.
While the scoping mechanism for synchronized methods and statements makes it much easier to program with monitor locks, and helps avoid many common programming errors involving locks, there are occasions where you need to work with locks in a more flexible way. For example, some algorithms for traversing concurrently accessed data structures require the use of "hand-over-hand" or "chain locking": you acquire the lock of node A, then node B, then release A and acquire C, then release B and acquire D and so on. Implementations of the Lock interface enable the use of such techniques by allowing a lock to be acquired and released in different scopes, and allowing multiple locks to be acquired and released in any order.
With this increased flexibility comes additional responsibility. The absence of block-structured locking removes the automatic release of locks that occurs with synchronized methods and statements. In most cases, the following idiom should be used:

 Lock l = ...;
 l.lock();
 try {
   // access the resource protected by this lock
 } finally {
   l.unlock();
 }
When locking and unlocking occur in different scopes, care must be taken to ensure that all code that is executed while the lock is held is protected by try-finally or try-catch to ensure that the lock is released when necessary.
Lock implementations provide additional functionality over the use of synchronized methods and statements by providing a non-blocking attempt to acquire a lock (tryLock()), an attempt to acquire the lock that can be interrupted (lockInterruptibly, and an attempt to acquire the lock that can timeout (tryLock(long, TimeUnit)).
A Lock class can also provide behavior and semantics that is quite different from that of the implicit monitor lock, such as guaranteed ordering, non-reentrant usage, or deadlock detection. If an implementation provides such specialized semantics then the implementation must document those semantics.
Note that Lock instances are just normal objects and can themselves be used as the target in a synchronized statement. Acquiring the monitor lock of a Lock instance has no specified relationship with invoking any of the lock methods of that instance. It is recommended that to avoid confusion you never use Lock instances in this way, except within their own implementation.
Except where noted, passing a null value for any parameter will result in a NullPointerException being thrown.
Memory Synchronization
All Lock implementations must enforce the same memory synchronization semantics as provided by the built-in monitor lock, as described in The Java Language Specification (17.4 Memory Model) :
A successful lock operation has the same memory synchronization effects as a successful Lock action.
A successful unlock operation has the same memory synchronization effects as a successful Unlock action.
Unsuccessful locking and unlocking operations, and reentrant locking/unlocking operations, do not require any memory synchronization effects.
Implementation Considerations
The three forms of lock acquisition (interruptible, non-interruptible, and timed) may differ in their performance characteristics, ordering guarantees, or other implementation qualities. Further, the ability to interrupt the ongoing acquisition of a lock may not be available in a given Lock class. Consequently, an implementation is not required to define exactly the same guarantees or semantics for all three forms of lock acquisition, nor is it required to support interruption of an ongoing lock acquisition. An implementation is required to clearly document the semantics and guarantees provided by each of the locking methods. It must also obey the interruption semantics as defined in this interface, to the extent that interruption of lock acquisition is supported: which is either totally, or only on method entry.
As interruption generally implies cancellation, and checks for interruption are often infrequent, an implementation can favor responding to an interrupt over normal method return. This is true even if it can be shown that the interrupt occurred after another action may have unblocked the thread. An implementation should document this behavior.

lock的实现和synchronized的方法或者代码块来说提供了更多的锁获取的扩展操作，允许更为灵活的结构化，也可能有一些十分不同的属性，并且支持更多相关联Condation对象。

锁是一个用于控制多个线程访问共享资源的工具，通常，一个锁会对共享资源提供排他控制访问，在一个时刻只有一个线程获取锁，所有获取共享资源的线程首先要获取锁，当然，有些锁允许共享资源的并发访问，比如读写锁。

synchronized的方法和语句的使用，是隐式的对每个对象关联的monitor 锁的访问控制，但是它强制所有锁的获取和释放发生在一个块结构的上方式，当有多个线程访问的时候，他们必须要以相反的顺序进行释放，并且是在他们相同获取锁的作用域进行。

虽然synchronized这种作用域上的获取和释放monitor的方式变得更加简单，并且会避免许多一些通常情况下的编码错误，但是也有一些情况需要比较灵活的方式操作锁，比如，一些算法用于并发遍历访问数据结构，他们需要使用手把手或者链式获取锁，你获取lockA，然后获取lockB，然后释放A，然后获取C，然后释放B，然后获取D等等，实现lock接口，让这种方式成为可能，这种锁的技术允许在不同的作用域获取和释放锁，并且允许多个锁同时获取和释放锁。

借助这种更加灵活性，带来更多的职责，我们不需要synchronized块结构的形式进行锁的自动释放，在大多数情况，典型的使用形式如下：
```
Lock l = ...;
l.lock();
try {
  // access the resource protected by this lock
} finally {
  l.unlock();
}
```
当锁的获取和释放在不同的作用域，我们必须要非常小心的使用，当锁被获取后，在执行的代码要在try catch里边，，在finally里边进行释放。

lock的实现相比synchronized会提供一些额外的功能，提供了非阻塞的方式获取锁，trylock，并且提供了可以被中断的获取锁的方式，也提供了超时敏感的获取锁的方式。
Lock接口的对象提供了一些和monitor不同的行为和语义，比如确保顺序性，死锁检测，可重入，如果提供了这些语义那么实现要以文档的形式呈现出来。
lock仅仅是一个普通的对象而已，也可以用作synchronized的目标，获取锁实例的监视器锁和调用lock的lock方式之间没有任何关联关系，推荐的做法是避免这种混淆，永远不要用这种方式去使用lock实例，除了他么自己底层实现当中。

除了这些我们应该注意，在所有参数当中解析到一个null值就会抛出一个npe异常。

#### 内存同步
所有的锁的实现必须强制的保持内存同步语义，这一点和monitor是一致的。这一点在[java语言规范的内存模型](https://docs.oracle.com/javase/specs/jls/se7/html/jls-17.html#jls-17.4)有定义。
- 一个成功的lock操作，拥有相同的内存同步操作，相同的lock动作的效果。
- 一个成功的unlock操作，拥有相同的内存同步操作，相同的unlock动作的效果。

不成功的锁定和解锁，以及可重入的解锁和解锁，他们不要求任何内存的同步的效果。

#### 实现上的考量
lock获取的三种形式（可中断，不可中断的，基于时间的）在性能、保证有序性、以及其他的点上会有所不同，更进一步来说，这种可以中断获取锁的过程的能力可能不在lock类当中，因此，这个实现并不要求精确的定义前边三种lock特性的这种保证和语义，也不要求锁的获取的过程就去中断，这个实现被要求被清晰的记录语义和保证是在每个每个lock方法上面，它必须在接口上获取中断的语义，以支持获取锁的中断，仅仅是在方法层面去支持。

由于中断往往意味着取消，所以检查中断就不是一个频繁的操作，一个实现要响应中断，而不是等待方法的返回，这也是真的，中断可能发生在另一个动作上，可能需要解锁这个线程，一个实现需要记录这一点。

#### lock接口的方法
  - lock
    阻塞获取
  - unlock
    阻塞释放锁
  - lockInterruptibly
    如果没有被中断就去获取；
    如果锁可用，那么立刻返回；
    如果当前锁不可用，当前线程无法进行调度，进入睡眠状态，知道如下2件事情发生就会醒来：
      - lock被当前线程获取到了；
      - 其他线程中断了当前这个线程，而且锁获取的过程是可以被中断的；
      如果当前线程拥有自己的中断的状态，或者它在获取的时候被支持中断，那么当前线程的状态被清除，并且抛出中断异常。
  - newCondition
    返回一个新的condition实例，绑定到lock实例上的condition。
    在condition之前，lock必须被线程持有，condition的await被调用会释放锁。
  - tryLock
    调用的时候，当锁是自由的他才会获取到锁；
    如果锁不是可用的，那么方法会返回立刻返回false，锁可用的时候会立刻返回true，典型的使用方式：
    ```
      Lock lock = ...;
      if (lock.tryLock()) {
       try {
         // manipulate protected state
       } finally {
         lock.unlock();
       }
      } else {
       // perform alternative actions
      }
    ```
    如果锁获取了，可以确保被释放，如果没有获取到锁，也没有必要去释放锁；
  - tryLock(times)
    在给定的等待 时间之内，如果锁是可用的，线程没有被中断那么获取锁，获取成功返回true，如果没有获取到，线程会进入等待，直到如下三种情况出现才会醒来：
      - 线程获取到了锁；
      - 其他的线程中断了当前的线程，并且中断是支持的；
      - 等待的时间超时；
    如果锁被获取，那么返回true。
    如果当前线程满足：
      - 当前线程设置了中断状态；
      - 获取的过程被中断了，并且支持中断；
    那么抛出中断异常，中断位被清除。
    如果等待的时候超时，返回false，如果时间没有超时，时间小于等于0， 那么就等于没有任何等待。
