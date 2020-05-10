---
title: concurrency(11)AQS-可重入锁
date: 2020-05-10 15:07:00
tags: [AQS 可重入锁]
categories: concurrency
---

### AQS(AbstractQueuedSynchronizer)
AQS和synchronized关键字C++的实现原理相似度是80%左右。
#### AbstractQueuedSynchronizer主要成员
![aqs1.png](aqs1.png)
- public class ConditionObject implements Condition, java.io.Serializable
  一个AQS可以有多个Condition对象，也就意味着有多个等待队列
- static final class Node
  Node是对阻塞线程的封装，Node内部有一个Thread的引用。
- private volatile int state; 同步状态,在不同的场景有不同的含义，精妙所在

#### 关键方法
1. protected boolean tryAcquire(int arg)
Attempts to acquire in exclusive mode
排它锁的获取。
2.  protected boolean tryRelease(int arg)
Attempts to set the state to reflect a release in exclusive mode.
排它锁的释放。
3. protected int tryAcquireShared(int arg)
Attempts to acquire in shared mode.
共享模式获取锁。
4. protected boolean tryReleaseShared(int arg)
Attempts to set the state to reflect a release in shared mode.
在共享模式下释放锁。
5. protected boolean isHeldExclusively()
排它锁的情况返回true，共享锁的情况返回false。



### ReentrantLock
当前线程获取到了锁还可以再次获取锁。
#### 例子：
```
public class MyTest1 {
    private Lock lock = new ReentrantLock();

    public void menthod(){
        try {
            lock.lock();
        }catch (Exception e){
            e.printStackTrace();
        }finally {
            lock.unlock();
        }
    }

    public static void main(String[] args) {
        MyTest1 myTest1 = new MyTest1();
        IntStream.range(0,10).forEach(x ->{
            new Thread(() ->{
                myTest1.menthod();
            }).start();
        });
    }
}
```
#### 锁的主要实现是内部的Syn：
```
abstract static class Sync extends AbstractQueuedSynchronizer {
  private static final long serialVersionUID = -5179523762034025860L;

  /**
   * Performs {@link Lock#lock}. The main reason for subclassing
   * is to allow fast path for nonfair version.
   */
  abstract void lock();

  /**
   * Performs non-fair tryLock.  tryAcquire is implemented in
   * subclasses, but both need nonfair try for trylock method.
   */
  final boolean nonfairTryAcquire(int acquires) {
      final Thread current = Thread.currentThread();
      int c = getState();
      if (c == 0) {
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

  protected final boolean tryRelease(int releases) {
      int c = getState() - releases;
      if (Thread.currentThread() != getExclusiveOwnerThread())
          throw new IllegalMonitorStateException();
      boolean free = false;
      if (c == 0) {
          free = true;
          setExclusiveOwnerThread(null);
      }
      setState(c);
      return free;
  }

  protected final boolean isHeldExclusively() {
      // While we must in general read state before owner,
      // we don't need to do so to check if current thread is owner
      return getExclusiveOwnerThread() == Thread.currentThread();
  }

  final ConditionObject newCondition() {
      return new ConditionObject();
  }

  // Methods relayed from outer class

  final Thread getOwner() {
      return getState() == 0 ? null : getExclusiveOwnerThread();
  }

  final int getHoldCount() {
      return isHeldExclusively() ? getState() : 0;
  }

  final boolean isLocked() {
      return getState() != 0;
  }

  /**
   * Reconstitutes the instance from a stream (that is, deserializes it).
   */
  private void readObject(java.io.ObjectInputStream s)
      throws java.io.IOException, ClassNotFoundException {
      s.defaultReadObject();
      setState(0); // reset to unlocked state
  }
}
```
ReentrantLock.Sync为什么没有 **tryAcquire** 和 **tryRelease** 呢，因为ReentrantLock支持公平锁和非公平锁的实现，在重载的构造方法上就能看出：
```
public ReentrantLock() {
    sync = new NonfairSync();
}

/**
 * Creates an instance of {@code ReentrantLock} with the
 * given fairness policy.
 *
 * @param fair {@code true} if this lock should use a fair ordering policy
 */
public ReentrantLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
}

```
如果是公平的那么就老老实实的等待队列前边的线程执行完毕，如果是非公平的就需要插队。

#### 公平锁的实现,ReentrantLock.FairSync:
```
static final class FairSync extends Sync {
    private static final long serialVersionUID = -3000897897090466540L;

    final void lock() {
        acquire(1);
    }

    /**
     * Fair version of tryAcquire.  Don't grant access unless
     * recursive call or no waiters or is first.
     */
    protected final boolean tryAcquire(int acquires) {
        final Thread current = Thread.currentThread();
        int c = getState();//持有锁的线程个数
        if (c == 0) {//没有线程获取到锁
          //判断当前线程在队列里边，它前边是否有线程正在执行，排队，保证锁的获取是公平的
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
}
```
ReentrantLock.FairSync继承了ReentrantLock.Sync.

#### 非公平锁的实现ReentrantLock.NonfairSync:
```
static final class NonfairSync extends Sync {
    private static final long serialVersionUID = 7316153563782823691L;

    /**
     * Performs lock.  Try immediate barge, backing up to normal
     * acquire on failure.
     */
    final void lock() {
      //不排队直接CAS替换操作。
        if (compareAndSetState(0, 1))
            setExclusiveOwnerThread(Thread.currentThread());
        else
            acquire(1);
    }

    protected final boolean tryAcquire(int acquires) {
      //调用父类的nonfairTryAcquire获取。
        return nonfairTryAcquire(acquires);
    }
}
```
ReentrantLock.NonfairSync同样实现了ReentrantLock.Sync。

#### ReentrantLock.lock调用流程
ReentrantLock.lock:
```
public void lock() {
    sync.lock();
}
```
sync分为NonfairSync和FairSync的实现。
Sync:
  FairSync
  NonfairSync
##### FairSync的lock实现:
```
final void lock() {
    acquire(1);
}
```
acquire(1)调用的是AQS的实现：
```
//Acquires in exclusive mode, ignoring interrupts.  排他模式获取锁
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg)) 如果获取不到锁，那么就放到等待队列等待
        selfInterrupt();
}
```
tryAcquire的实现类是FairSync，进入到公平锁的获取实现逻辑:
```
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();//持有锁的线程个数
    if (c == 0) {//没有线程获取到锁
        if (!hasQueuedPredecessors() && //判断当前线程在队列里边，它前边是否有线程正在执行，排队，保证锁的获取是公平的
            compareAndSetState(0, acquires)) {//CAS成功，把0改成1成功，意味着获取锁成功
            setExclusiveOwnerThread(current);//设置排它锁，表示当前线程正在执行
            return true;
        }
    }
    //当前线程是否是排他线程的拥有者
    else if (current == getExclusiveOwnerThread()) {
      //加和，比如由1变成2
        int nextc = c + acquires;
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        //重新CAS设置
        setState(nextc);
        return true;
    }
    return false;
}
```
hasQueuedPredecessors判断当前线程在队列里边，它前边是否有线程
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
##### NonfairSync的lock实现:
```
final void lock() {
    //不排队直接CAS替换操作。CAS替换
    if (compareAndSetState(0, 1))
    //设置排他
        setExclusiveOwnerThread(Thread.currentThread());
    else
        acquire(1);
}

protected final boolean tryAcquire(int acquires) {
  //调用父类的nonfairTryAcquire获取。
    return nonfairTryAcquire(acquires);
}
```
Syn的nonfairTryAcquire：
```
final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {//没有线程持有锁
      //非公平锁的获取，直接CAS替换，不会判断等待队列有没有线程。
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

#### Node的状态值
Node里边有几个成员变量是Node的状态值:
static final Node SHARED = new Node(); //共享锁
static final Node EXCLUSIVE = null;//排它锁
static final int CANCELLED =  1;//被取消掉
static final int SIGNAL    = -1;//
static final int CONDITION = -2;
static final int PROPAGATE = -3;//

#### 阻塞线程唤醒
ReentrantLock.unlock触发锁的释放，看一下unlock的实现：
public void unlock() {
    sync.release(1);
}
sync分为NonfairSync和FairSync的实现。
Sync:
  FairSync
  NonfairSync

sync调用了AQS的release：
```
//Releases in exclusive mode.  排他模式释放锁
public final boolean release(int arg) {
  //释放成功(没有任何线程持有锁)
    if (tryRelease(arg)) {
        Node h = head;
        //等待队列的头结点
        if (h != null && h.waitStatus != 0)
        //唤醒当前线程后边的线程
            unparkSuccessor(h);
        return true;
    }
    return false;
}
```
unparkSuccessor的实现：
```
//Wakes up node's successor, if one exists.
//如果当前线程的后继存在，那么唤醒后继线程
private void unparkSuccessor(Node node) {
    /*
     * If status is negative (i.e., possibly needing signal) try
     * to clear in anticipation of signalling.  It is OK if this
     * fails or if status is changed by waiting thread.
     */
    int ws = node.waitStatus;
    if (ws < 0)
        compareAndSetWaitStatus(node, ws, 0);

    /*
     * Thread to unpark is held in successor, which is normally
     * just the next node.  But if cancelled or apparently null,
     * traverse backwards from tail to find the actual
     * non-cancelled successor.
     */
    Node s = node.next;
    if (s == null || s.waitStatus > 0) {
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    if (s != null)
        //执行唤醒
        LockSupport.unpark(s.thread);
}
```
LockSupport.unpark实现：
```
//os.linux.vm.oslinux.cpp=>parker.unpark
public static void unpark(Thread thread) {
    if (thread != null)
        UNSAFE.unpark(thread);//negative方法
}
```

tryRelease会使用 FairSync父类Syn的重写的tryRelease方法
##### FairSync的unlock实现:
```
protected final boolean tryRelease(int releases) {
    int c = getState() - releases;//状态减一，比如由2变成1
    if (Thread.currentThread() != getExclusiveOwnerThread())//A线程获取到了锁，必须是由A释放锁
        throw new IllegalMonitorStateException();
    boolean free = false;
    if (c == 0) {//当前没有线程持有锁
        free = true;//锁是自由的状态
        setExclusiveOwnerThread(null);//排它锁持有者设置为空
    }
    setState(c);//CAS设置state
    return free;//为false，是重入状态，true是自由状态
}
```

#### ReentrantLock的执行逻辑
1. 尝试获取对象的锁，，如果获取不到（意味着已经有其他线程持有了锁，并且尚未释放锁），那么它就会进入到AQS的阻塞队列当中。
2. 如果获取到，那么根据锁是不公平锁还是非公平锁进行不同的处理
  2.1 如果是公平的，那么线程会直接放置到AQS阻塞队列的末尾
  2.2 如果是非公平锁，那么线程会首先尝试进行CAS计算，如果成功，则直接获取到锁。
    如果失败，则与公平锁的处理方式一致，被放到阻塞队列末尾。
3. 当锁释放时（调用了unlock方法），那么底层会调用release方法对state成员变量值进行减一操作，如果减一后，state值不为0，那么release操作就执行完毕；如果减一操作后，state值为0，则调用LockSupport的unpark方法唤醒该线程后的等待队列中的第一个后继线程(pthread mutex_unlock)，将其唤醒，使之能够获取到对象的锁(release时，对于公平锁与非公平锁的处理逻辑是一致的)；之所以调用release方法后state值可能不为0，原因在于ReentrantLock是可重入锁，表示线程可以多次调用lock方法，导致每调用一次，state值都会加一。

在于ReentrantLock来说，所谓的上锁，本质上就是对AQS中的state成员变量的操作，对该成员变量+1，表示上锁，对该成员变量-1，表示释放锁。

###
