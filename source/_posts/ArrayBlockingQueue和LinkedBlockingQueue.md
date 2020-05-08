---
title: ArrayBlockingQueue和LinkedBlockingQueue
date: 2018-10-04 10:12:50
tags: [ArrayBlockQueue, ArrayBlockQueue]
categories: Thread
---
ArrayBlockQueue和ArrayBlockQueue属于Java.util.current包下的两个封装的线程安全的队列，主要讨论线程安全和阻塞操作的实现
他们之间的关系如下：
![这里写图片描述](20161029145814547.png)
<!-- more -->
[复制图片地址，在新的浏览器器页面查看大图]
**ArrayBlockingQueue:**
线程安全和阻塞操作在入队列和取出队列元素都会涉及，先从线程安全进入：
注意：ArrayBlockQueue只有一把锁：

```
    /** Main lock guarding all access */
    final ReentrantLock lock;
    /** Condition for waiting takes */
    private final Condition notEmpty;
    /** Condition for waiting puts */
    private final Condition notFull;
```
锁的初始化：

```
    public ArrayBlockingQueue(int capacity, boolean fair) {
        if (capacity <= 0)
            throw new IllegalArgumentException();
        this.items = new Object[capacity];
        lock = new ReentrantLock(fair);
        notEmpty = lock.newCondition();//用于取走队列元素
        notFull =  lock.newCondition();//用于元素插入队列
    }
```

take方法：

```
    /**
     * Inserts the specified element at the tail of this queue if it is
     * possible to do so immediately without exceeding the queue's capacity,
     * returning {@code true} upon success and {@code false} if this queue
     * is full.  This method is generally preferable to method {@link #add},
     * which can fail to insert an element only by throwing an exception.
     *
     * @throws NullPointerException if the specified element is null
     */
    public boolean offer(E e) {
        checkNotNull(e);
        final ReentrantLock lock = this.lock;
        //获取锁，使用可重入锁的同步器，cvs操作，非公平锁
        lock.lock();
        try {
            if (count == items.length)
                return false;
            else {
                insert(e);
                return true;
            }
        } finally {
            //释放锁
            lock.unlock();
        }
    }
```
poll方法：

```
    public E poll() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return (count == 0) ? null : extract();
        } finally {
            lock.unlock();
        }
    }
```

再看阻塞：
Condition拥有类似的操作：await/signal。Condition和一个Lock相关，由Lock的newCondition来创建。只有当前线程获取了这把锁，才能调用Condition的await方法来等待通知，否则会抛出异常。

下面来看看put方法就会明白如何使用一个Condition了
put操作
```
    /**
     * Inserts the specified element at the tail of this queue, waiting
     * for space to become available if the queue is full.
     *
     * @throws InterruptedException {@inheritDoc}
     * @throws NullPointerException {@inheritDoc}
     */
    public void put(E e) throws InterruptedException {
        checkNotNull(e);
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        try {
            while (count == items.length)
                notFull.await();
            insert(e);
        } finally {
            lock.unlock();
        }
    }
```
take操作：
```
    public E take() throws InterruptedException {
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        try {
            while (count == 0)
                notEmpty.await();
            return extract();
        } finally {
            lock.unlock();
        }
    }
```

实现阻塞的关键就是就是这个notFull的Condition，当队列已满，await方法会阻塞当前线程，并且释放Lock，等待其他线程调用notFull的signal来唤醒这个阻塞的线程。那么这个操作必然会在拿走元素的操作中出现，这样一旦有元素被拿走，阻塞的线程就会被唤醒。

这里有个问题，发出signal的线程肯定拥有这把锁的，因此await方法所在的线程肯定是拿不到这把锁的，await方法不能立刻返回，需要尝试获取锁直到拥有了锁才可以从await方法中返回。

这就是阻塞的实现原理，也是所谓的线程同步。

**LinkedBlockingQueue**
LinkedBlockingQueue使用一个链表来实现，会有一个head和tail分别指向队列的开始和队列的结尾。因此LinkedBlockingQueue会有两把锁，分别控制这两个元素，这样在添加元素和拿走元素的时候就不会有锁的冲突，因此取走元素操作的是head，而添加元素操作的是tail。

offer方法和poll方法：

```
    /**
     * Inserts the specified element at the tail of this queue if it is
     * possible to do so immediately without exceeding the queue's capacity,
     * returning {@code true} upon success and {@code false} if this queue
     * is full.
     * When using a capacity-restricted queue, this method is generally
     * preferable to method {@link BlockingQueue#add add}, which can fail to
     * insert an element only by throwing an exception.
     *
     * @throws NullPointerException if the specified element is null
     */
    public boolean offer(E e) {
        if (e == null) throw new NullPointerException();
        final AtomicInteger count = this.count;
        if (count.get() == capacity)
            return false;
        int c = -1;
        Node<E> node = new Node(e);
        final ReentrantLock putLock = this.putLock;
        putLock.lock();
        try {
            if (count.get() < capacity) {
                enqueue(node);
                c = count.getAndIncrement();
                if (c + 1 < capacity)
                    notFull.signal();
            }
        } finally {
            putLock.unlock();
        }
        if (c == 0)
            signalNotEmpty();
        return c >= 0;
    }
```
可以看到offer方法在添加元素时候仅仅涉及到putLock，但是还是会需要takeLock，看看signalNotEmpty代码就知道。而poll方法拿走元素的时候涉及到takeLock，也是会需要putLock。参见signalNotFull()。关于signalNotEmpty会在后面讲阻塞的时候讲到。

```
    public E poll() {
        final AtomicInteger count = this.count;
        if (count.get() == 0)
            return null;
        E x = null;
        int c = -1;
        final ReentrantLock takeLock = this.takeLock;
        takeLock.lock();
        try {
            if (count.get() > 0) {
                x = dequeue();
                c = count.getAndDecrement();
                if (c > 1)
                    notEmpty.signal();
            }
        } finally {
            takeLock.unlock();
        }
        if (c == capacity)
            signalNotFull();
        return x;
    }
```
这里顺便说说队列长度的count，因为有两把锁存在，所以如果还是像ArrayBlockingQueue一样使用基本类型的count的话会同时用到两把锁，这样就会很复杂，因此直接使用原子数据类型AtomicInteger来操作count。

LinkedQueue的阻塞
一个BlockingQueue会有两个Condition：notFull和notEmpty，LinkedBlockingQueue会有两把锁，因此这两个Condition肯定是由这两个锁分别创建的，takeLock创建notEmpty，putLock创建notFull。

```
    /** Lock held by take, poll, etc */
    private final ReentrantLock takeLock = new ReentrantLock();

    /** Wait queue for waiting takes */
    private final Condition notEmpty = takeLock.newCondition();

    /** Lock held by put, offer, etc */
    private final ReentrantLock putLock = new ReentrantLock();

    /** Wait queue for waiting puts */
    private final Condition notFull = putLock.newCondition();
```

put方法：

```
    /**
     * Inserts the specified element at the tail of this queue, waiting if
     * necessary for space to become available.
     *
     * @throws InterruptedException {@inheritDoc}
     * @throws NullPointerException {@inheritDoc}
     */
    public void put(E e) throws InterruptedException {
        if (e == null) throw new NullPointerException();
        // Note: convention in all put/take/etc is to preset local var
        // holding count negative to indicate failure unless set.
        int c = -1;
        Node<E> node = new Node(e);
        final ReentrantLock putLock = this.putLock;
        final AtomicInteger count = this.count;
        putLock.lockInterruptibly();
        try {
            /*
             * Note that count is used in wait guard even though it is
             * not protected by lock. This works because count can
             * only decrease at this point (all other puts are shut
             * out by lock), and we (or some other waiting put) are
             * signalled if it ever changes from capacity. Similarly
             * for all other uses of count in other wait guards.
             */
            while (count.get() == capacity) {
                notFull.await();
            }
            enqueue(node);
            c = count.getAndIncrement();
            if (c + 1 < capacity)
                notFull.signal();
        } finally {
            putLock.unlock();
        }
        if (c == 0)
            signalNotEmpty();
    }
```
其实大体逻辑和ArrayBlockingQueue差不多，也会需要通知notEmpty条件，因为notEmpty条件属于takeLock，而调用signal方法需要获取Lock，因此put方法也是用到了另外一个锁：takeLock。这里有一点会不同，按照道理来说put方法是不需要通知notFull条件的，是由由拿走元素的操作来通知的，但是notFull条件属于putLock，而拿走元素时，是用了takeLock，因此这里put方法在拥有putLock的情况通知notFull条件，会让其他添加元素的方法避免过长时间的等待。同理对于take方法来说也通知notEmpty条件。

take 方法：

```
    public E take() throws InterruptedException {
        E x;
        int c = -1;
        final AtomicInteger count = this.count;
        final ReentrantLock takeLock = this.takeLock;
        takeLock.lockInterruptibly();
        try {
            while (count.get() == 0) {
                notEmpty.await();
            }
            x = dequeue();
            c = count.getAndDecrement();
            if (c > 1)
                notEmpty.signal();
        } finally {
            takeLock.unlock();
        }
        if (c == capacity)
            signalNotFull();
        return x;
    }

```
remove和contains方法，因为需要操作整个链表，因此需要同时拥有两个锁才能操作。
