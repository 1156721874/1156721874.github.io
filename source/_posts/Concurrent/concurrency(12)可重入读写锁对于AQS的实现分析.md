---
title: concurrency(12)可重入读写锁对于AQS的实现分析
date: 2020-05-10 17:37:00
tags: [AQS 可重入读写锁 ReentrantReadWriteLock]
categories: concurrency
---

### ReentrantReadWriteLock
实例:
```
public class MyTest2 {
    private ReadWriteLock lock = new ReentrantReadWriteLock();
    public void method(){
        try{
            lock.readLock().lock();
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.println("method");
        }finally {
            lock.readLock().unlock();
        }
    }

    public static void main(String[] args) {
        MyTest2 myTest2 = new MyTest2();
        IntStream.range(0,10).forEach(i -> new Thread(myTest2::method).start());
    }
}

```
输出：
method
method
method
method
method
method
method
method
method
method

如果将  lock.readLock().lock();换成 lock.writeLock().lock();再去运行，就会看出读锁和写锁的区别,
readLock打印输出结果的速度很快，因为读锁不需要阻塞是共享的，writeLock打印结果的结果很慢，有输出的时间顺序，因为写锁是互斥的，需要挨个执行。

#### ReentrantReadWriteLock分析
ReentrantReadWriteLock岁state的使用是划分了2部分去使用，state的高16位表示的是读锁，低1位表示的是写锁。
ReentrantReadWriteLock的构造器:
```
public ReentrantReadWriteLock() {
        this(false);
}
public ReentrantReadWriteLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
    readerLock = new ReadLock(this);
    writerLock = new WriteLock(this);
}
```
ReentrantReadWriteLock默认使用的还是公平锁。
##### ReadLock的lock
```
public void lock() {
    sync.acquireShared(1);//共享锁
}
```
acquireShared调用的是AQS的acquireShared实现：
```
//Acquires in shared mode, ignoring interrupts.  共享模式下去获取
public final void acquireShared(int arg) {
    if (tryAcquireShared(arg) < 0)
        doAcquireShared(arg);
}
```
tryAcquireShared的实现是子类(Sync)的实现：
```
protected final int tryAcquireShared(int unused) {
    /*
     * Walkthrough:
     * 1. If write lock held by another thread, fail.//写锁存在，直接失败
     * 2. Otherwise, this thread is eligible for
     *    lock wrt state, so ask if it should block
     *    because of queue policy. If not, try
     *    to grant by CASing state and updating count.
     *    Note that step does not check for reentrant
     *    acquires, which is postponed to full version
     *    to avoid having to check hold count in
     *    the more typical non-reentrant case.
     *    
     * 3. If step 2 fails either because thread
     *    apparently not eligible or CAS fails or count
     *    saturated, chain to version with full retry loop.
     */
    Thread current = Thread.currentThread();
    int c = getState();
    //映射第一步：1. If write lock held by another thread, fail.
    if (exclusiveCount(c) != 0 &&//返回低16位记录的数量，写锁的数量不等于0
        getExclusiveOwnerThread() != current) // 排它锁的持有者不是当前线程，直接失败
        return -1;
    int r = sharedCount(c);//程序走到这，意味着没有写锁，读取高16位
    if (!readerShouldBlock() && // 判断阻塞队列前边是否有线程，公平锁和非公平锁的实现会不一样
        r < MAX_COUNT && //不管是读锁还是写锁，锁的数量是有限制的。
        compareAndSetState(c, c + SHARED_UNIT)) {//CAS操作，增加数量
        if (r == 0) {//之前没有读锁
            firstReader = current;//当前线程是第一个获取读锁的线程
            firstReaderHoldCount = 1;//读锁的数量
        } else if (firstReader == current) { //当前线程就是firstReader
            firstReaderHoldCount++; //持有数量+1
        } else {
            HoldCounter rh = cachedHoldCounter;
            if (rh == null || rh.tid != getThreadId(current))
                cachedHoldCounter = rh = readHolds.get();
            else if (rh.count == 0)
                readHolds.set(rh);
            rh.count++;
        }
        return 1;
    }
    //CAS的补救措施的一些操作
    return fullTryAcquireShared(current);
}
```

#####  WriteLock的lock
WriteLock的lock的lock实现：
```
public void lock() {
      sync.acquire(1);
}
```
AQS的实现:
```
//Acquires in exclusive mode, ignoring interrupts.   排他模式下使用
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```
tryAcquire在子类ReentrantReadWriteLock.Sync实现的：
```
protected final boolean tryAcquire(int acquires) {
    /*
     * Walkthrough:
     * 1. If read count nonzero or write count nonzero
     *    and owner is a different thread, fail.
     * 读的线程数量非0，写的线程数量非0，直接失败，因为写锁是互斥的
     * 2. If count would saturate, fail. (This can only
     *    happen if count is already nonzero.)
     * 3. Otherwise, this thread is eligible for lock if
     *    it is either a reentrant acquire or
     *    queue policy allows it. If so, update state
     *    and set owner.
     */
    Thread current = Thread.currentThread();
    int c = getState();
    int w = exclusiveCount(c);//写锁的数量
    if (c != 0) {//排它锁被线程持有
        // (Note: if c != 0 and w == 0 then shared count != 0)
        if (w == 0 || current != getExclusiveOwnerThread())//持有线程是其他线程，不是自己
            return false; //直接返回false
        if (w + exclusiveCount(acquires) > MAX_COUNT) //写锁数量超过锁的数量最大值
            throw new Error("Maximum lock count exceeded"); //直接异常
        // Reentrant acquire
        setState(c + acquires); // 可重入的获取（已经有线程持有锁，并且持有锁的线程就是自己，那么就是重入性的获取锁）
        return true;
    }
    //
    if (writerShouldBlock() || // 是否需要阻塞(排队)，公平锁和非公平锁的实现是不一样的
        !compareAndSetState(c, c + acquires))//CAS失败，意味着存在一个竞争的获取写锁的线程
        return false;
    setExclusiveOwnerThread(current);//获取排它锁成功，设置锁的持有者是当前线程
    return true;
}
```

##### ReentrantReadWriteLock的操作逻辑
读锁：
1. 在获取读锁时，会尝试判断当前对象是否拥有了写锁，如果已经拥有，则直接失败。
2. 如果没有写锁，，就表示当前对象没有排它锁，则当前线程会尝试给对象加锁。
3. 如果当前线程已经持有了该对象的锁，那么直接将读锁数量+1.

写锁：
1. 在获取写锁时，会尝试判断当前对象是否拥有了锁（读锁和写锁），如果已经拥有并且持有的线程并非当前线程，直接失败。
2. 如果当前对象没有被加锁，，那么写锁就会为了当前对象上锁，并且将写锁的个数+1.
3. 将当前对象的排它锁线程持有者设为自己。
