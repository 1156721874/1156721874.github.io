---
title: jvm原理（48）强引用-软引用-弱引用-虚引用-ThreadLocal
date: 2020-03-08 20:14:13
tags: [强引用、软引用、弱引用、虚引用]
categories: jvm
---
### 强引用
- 我们日常开发中所遇到的绝大多数引用均是强引用
- 如果对象拥有强引用，就表示它是可达的，那么垃圾收集器就不会将其回收。
<!-- more -->
- 如果将某个强引用显式置位null，就表示该引用不再指向对象，若该对象没有其他引用指向它，那么在适当时机就会被垃圾收集器回收。

- 参考ArrayList类的源代码
```
/**
 * Removes all of the elements from this list.  The list will
 * be empty after this call returns.
 */
public void clear() {
    modCount++;

    // clear to let GC do its work
    for (int i = 0; i < size; i++)
        elementData[i] = null;//显式将引用置为null

    size = 0;
}
```

### 其他三种类型的引用
- 软引用(soft Reference)
- 弱引用(waek reference)
- 虚引用(phantom reference)
- Reference 抽象类是这些引用的父类
- 具体参见Reference类的JavaDoc文档
- ReferenceQueue

#### Reference

java.lang.ref public abstract class Reference<T>
extends Object
Abstract base class for reference objects. This class defines the operations common to all reference objects. Because reference objects are implemented in close cooperation with the garbage collector, this class may not be subclassed directly.
Reference是引用对象的父类，这个类定义了一些适用于所有引用对象的操作，因为引用对象他的实现和垃圾收集器是紧密相关的，所以这个类是不可以被子类化的。
他的构造器：
```
Reference(T referent) {
    this(referent, null);
}

Reference(T referent, ReferenceQueue<? super T> queue) {
    this.referent = referent;
    this.queue = (queue == null) ? ReferenceQueue.NULL : queue;
}
```
Reference的构造器不是public的，子类无法去super调用，而SoftReference、WeakReference、PhantomReference都是和Reference
同一个包下边，我们自己定义的类是无法去继承Reference的。

```
public abstract class Reference<T> {

    /* A Reference instance is in one of four possible internal states:
     *
     *     Active: Subject to special treatment by the garbage collector.  Some
     *     time after the collector detects that the reachability of the
     *     referent has changed to the appropriate state, it changes the
     *     instance's state to either Pending or Inactive, depending upon
     *     whether or not the instance was registered with a queue when it was
     *     created.  In the former case it also adds the instance to the
     *     pending-Reference list.  Newly-created instances are Active.
     *
     *     Pending: An element of the pending-Reference list, waiting to be
     *     enqueued by the Reference-handler thread.  Unregistered instances
     *     are never in this state.
     *
     *     Enqueued: An element of the queue with which the instance was
     *     registered when it was created.  When an instance is removed from
     *     its ReferenceQueue, it is made Inactive.  Unregistered instances are
     *     never in this state.
     *
     *     Inactive: Nothing more to do.  Once an instance becomes Inactive its
     *     state will never change again.
     *
     * The state is encoded in the queue and next fields as follows:
     *
     *     Active: queue = ReferenceQueue with which instance is registered, or
     *     ReferenceQueue.NULL if it was not registered with a queue; next =
     *     null.
     *
     *     Pending: queue = ReferenceQueue with which instance is registered;
     *     next = this
     *
     *     Enqueued: queue = ReferenceQueue.ENQUEUED; next = Following instance
     *     in queue, or this if at end of list.
     *
     *     Inactive: queue = ReferenceQueue.NULL; next = this.
     *
     * With this scheme the collector need only examine the next field in order
     * to determine whether a Reference instance requires special treatment: If
     * the next field is null then the instance is active; if it is non-null,
     * then the collector should treat the instance normally.
     *
     * To ensure that a concurrent collector can discover active Reference
     * objects without interfering with application threads that may apply
     * the enqueue() method to those objects, collectors should link
     * discovered objects through the discovered field. The discovered
     * field is also used for linking Reference objects in the pending list.
     */

    private T referent;         /* Treated specially by GC */

    volatile ReferenceQueue<? super T> queue;

    /* When active:   NULL 还没有入队
     *     pending:   this 表示也还没有入队，只是指向自己
     *    Enqueued:   next reference in queue (or this if last) 入队，next指向是队列的下一个元素
     *    Inactive:   this 他自己
     */
    @SuppressWarnings("rawtypes")
    Reference next;

    /* When active:   next element in a discovered reference list maintained by GC (or this if last)
     *     pending:   next element in the pending list (or null if last)
     *   otherwise:   NULL
     */
    transient private Reference<T> discovered;  /* used by VM */


    /* Object used to synchronize with the garbage collector.  The collector
     * must acquire this lock at the beginning of each collection cycle.  It is
     * therefore critical that any code holding this lock complete as quickly
     * as possible, allocate no new objects, and avoid calling user code.
     */
    static private class Lock { }
    private static Lock lock = new Lock();


    /* List of References waiting to be enqueued.  The collector adds
     * References to this list, while the Reference-handler thread removes
     * them.  This list is protected by the above lock object. The
     * list uses the discovered field to link its elements.
     */
    private static Reference<Object> pending = null;

    /* High-priority thread to enqueue pending References
     */
    private static class ReferenceHandler extends Thread {

        private static void ensureClassInitialized(Class<?> clazz) {
            try {
                Class.forName(clazz.getName(), true, clazz.getClassLoader());
            } catch (ClassNotFoundException e) {
                throw (Error) new NoClassDefFoundError(e.getMessage()).initCause(e);
            }
        }

        static {
            // pre-load and initialize InterruptedException and Cleaner classes
            // so that we don't get into trouble later in the run loop if there's
            // memory shortage while loading/initializing them lazily.
            ensureClassInitialized(InterruptedException.class);
            ensureClassInitialized(Cleaner.class);
        }

        ReferenceHandler(ThreadGroup g, String name) {
            super(g, name);
        }

        public void run() {
            while (true) {
                tryHandlePending(true);
            }
        }
    }

    /**
     * Try handle pending {@link Reference} if there is one.<p>
     * Return {@code true} as a hint that there might be another
     * {@link Reference} pending or {@code false} when there are no more pending
     * {@link Reference}s at the moment and the program can do some other
     * useful work instead of looping.
     *
     * @param waitForNotify if {@code true} and there was no pending
     *                      {@link Reference}, wait until notified from VM
     *                      or interrupted; if {@code false}, return immediately
     *                      when there is no pending {@link Reference}.
     * @return {@code true} if there was a {@link Reference} pending and it
     *         was processed, or we waited for notification and either got it
     *         or thread was interrupted before being notified;
     *         {@code false} otherwise.
     */
    static boolean tryHandlePending(boolean waitForNotify) {
        Reference<Object> r;
        Cleaner c;
        try {
            synchronized (lock) {
                if (pending != null) {
                    r = pending;
                    // 'instanceof' might throw OutOfMemoryError sometimes
                    // so do this before un-linking 'r' from the 'pending' chain...
                    c = r instanceof Cleaner ? (Cleaner) r : null;
                    // unlink 'r' from 'pending' chain
                    pending = r.discovered;
                    r.discovered = null;
                } else {
                    // The waiting on the lock may cause an OutOfMemoryError
                    // because it may try to allocate exception objects.
                    if (waitForNotify) {
                        lock.wait();
                    }
                    // retry if waited
                    return waitForNotify;
                }
            }
        } catch (OutOfMemoryError x) {
            // Give other threads CPU time so they hopefully drop some live references
            // and GC reclaims some space.
            // Also prevent CPU intensive spinning in case 'r instanceof Cleaner' above
            // persistently throws OOME for some time...
            Thread.yield();
            // retry
            return true;
        } catch (InterruptedException x) {
            // retry
            return true;
        }

        // Fast path for cleaners
        if (c != null) {
            c.clean();
            return true;
        }

        ReferenceQueue<? super Object> q = r.queue;
        if (q != ReferenceQueue.NULL) q.enqueue(r);
        return true;
    }

    static {
        ThreadGroup tg = Thread.currentThread().getThreadGroup();
        for (ThreadGroup tgn = tg;
             tgn != null;
             tg = tgn, tgn = tg.getParent());
        Thread handler = new ReferenceHandler(tg, "Reference Handler");
        /* If there were a special system-only priority greater than
         * MAX_PRIORITY, it would be used here
         */
        handler.setPriority(Thread.MAX_PRIORITY);
        handler.setDaemon(true);
        handler.start();

        // provide access in SharedSecrets
        SharedSecrets.setJavaLangRefAccess(new JavaLangRefAccess() {
            @Override
            public boolean tryHandlePendingReference() {
                return tryHandlePending(false);
            }
        });
    }

    /* -- Referent accessor and setters -- */

    /**
     * Returns this reference object's referent.  If this reference object has
     * been cleared, either by the program or by the garbage collector, then
     * this method returns <code>null</code>.
     *
     * @return   The object to which this reference refers, or
     *           <code>null</code> if this reference object has been cleared
     */
    public T get() {
        return this.referent;
    }

    /**
     * Clears this reference object.  Invoking this method will not cause this
     * object to be enqueued.
     *
     * <p> This method is invoked only by Java code; when the garbage collector
     * clears references it does so directly, without invoking this method.
     */
     调用这个方法并不会将对象入队。
     当垃圾收集器清理的时候它会直接清理，而不会调用这个方法。
    public void clear() {
        this.referent = null;
    }


    /* -- Queue operations -- */

    /**
     * Tells whether or not this reference object has been enqueued, either by
     * the program or by the garbage collector.  If this reference object was
     * not registered with a queue when it was created, then this method will
     * always return <code>false</code>.
     *
     * @return   <code>true</code> if and only if this reference object has
     *           been enqueued
     */
    public boolean isEnqueued() {
        return (this.queue == ReferenceQueue.ENQUEUED);
    }

    /**
     * Adds this reference object to the queue with which it is registered,
     * if any.
     *
     * <p> This method is invoked only by Java code; when the garbage collector
     * enqueues references it does so directly, without invoking this method.
     *
     * @return   <code>true</code> if this reference object was successfully
     *           enqueued; <code>false</code> if it was already enqueued or if
     *           it was not registered with a queue when it was created
     */
    public boolean enqueue() {
        return this.queue.enqueue(this);
    }


    /* -- Constructors -- */

    Reference(T referent) {
        this(referent, null);
    }

    Reference(T referent, ReferenceQueue<? super T> queue) {
        this.referent = referent;
        this.queue = (queue == null) ? ReferenceQueue.NULL : queue;
    }

}
```
ReferenceQueue java doc：
Reference queues, to which registered reference objects are appended by the garbage collector after the appropriate reachability changes are detected.
引用队列，当垃圾收集器检测到引用对象的可达性发生变化后，会把引用对象放到引用队列当中。

一个引用实例可以是如下四种内部状态的其中之一：
- 活跃状态
    他会被垃圾收集器进行一种特殊的对待 当垃圾收集器检测到被引用的对象的可达性达到一种恰当的状态的一段时间之后，就会改变实例的状态，要么变成pending或者inactive，这个取决于这个实例在注册的时候是否被注册到一个队列上面。在前者这种状态下（pending）实例会被添加到pending引用列表当中， 而新创建的总是活动状态。
- 挂起状态
    引用队列里边的一个元素，等待引用处理线程将其入队，未注册的实例永远不会有这种状态。
- 入队状态
    当一个实例创建的时候被注册了，那么实例将会作为队列的一个元素，当一个实例从他的引用队列中移除时，它会变成inactive状态，未注册的实例永远不会处于这种状态。
- 不活跃状态
    没什么对它可做的，一个实例处于inactive，他的状态永远不会发生变化。

 引用的状态在队列里边会被编码，next 成员变量是如下的逻辑：
    Active: quene = ReferenceQueue 他里边的实例是已经注册，或者ReferenceQueue.NULL 它没有被注册到引用队列里边去，next = null
    pending：quene = ReferenceQueue，next = this
    enquene：quene = ReferenceQueue.ENQUEUED;next = 队列中的下一个元素，或者是this，前提是位于列表的最末端.
    inactive:queue = ReferenceQueue.NULL;next = this.

    在这种模式下，垃圾收集器就可以通过next成员变量判断引用实例是否需要特殊对待，如果next实例是null，那么实例就是活动状态，如果不是null，那么收集器就以正常的实例对待它。

    为了确保并发收集器能够探测到活动的引用对象，而不需要介入线程，应用可以使用enqueue()方法对待这些对象，收集器应该将发现的对象通过discovered变量连接起来，discovered变量也是用于在pending列表当中连接引用对象。

    观察构造器：
    ```
    Reference(T referent, ReferenceQueue<? super T> queue) {
        this.referent = referent;
        this.queue = (queue == null) ? ReferenceQueue.NULL : queue;
    }
    ```
    引用新创建的时候，是活动状态，Reference的queue = ReferenceQueue.NULL(如果没有传递引用队列的情况)，ReferenceQueue.NULL是什么？
    ```
    public class ReferenceQueue<T> {
      private static class Null<S> extends ReferenceQueue<S> {
      boolean enqueue(Reference<? extends S> r) {
              return false;
          }
        }

      static ReferenceQueue<Object> NULL = new Null<>();
      static ReferenceQueue<Object> ENQUEUED = new Null<>();
    }
    ```
    ReferenceQueue.NULL是ReferenceQueue里边的一个私有子类对象，他的enqueue()总是返回false。next并没有被复制，因此next是null。




#### SoftReference
首先编写一个实例：
```
public class MyTest1 {
    public static void main(String[] args) {
        Date date=  new Date();
        SoftReference<Date> softReference = new SoftReference(date);
        Date date1 = softReference.get();
        //这里一定要判空，因为不一定什么时刻内存不够了，软引用就会被清理掉。
        if(null != date1){
            System.out.println("hello");
        }else{
            System.out.println("world");
        }
        System.out.println("=========");
        softReference.clear();
        Date date2 = softReference.get();
        System.out.println(date2);
    }
}
```
运行结果：
hello
=========
null

那么接下来看一下SoftReference的文档：
Soft reference objects, which are cleared at the discretion of the garbage collector in response to memory demand. Soft references are most often used to implement memory-sensitive caches.
Suppose that the garbage collector determines at a certain point in time that an object is softly reachable. At that time it may choose to clear atomically all soft references to that object and all soft references to any other softly-reachable objects from which that object is reachable through a chain of strong references. At the same time or at some later time it will enqueue those newly-cleared soft references that are registered with reference queues.
All soft references to softly-reachable objects are guaranteed to have been cleared before the virtual machine throws an OutOfMemoryError. Otherwise no constraints are placed upon the time at which a soft reference will be cleared or the order in which a set of such references to different objects will be cleared. Virtual machine implementations are, however, encouraged to bias against clearing recently-created or recently-used soft references.
Direct instances of this class may be used to implement simple caches; this class or derived subclasses may also be used in larger data structures to implement more sophisticated caches. As long as the referent of a soft reference is strongly reachable, that is, is actually in use, the soft reference will not be cleared. Thus a sophisticated cache can, for example, prevent its most recently used entries from being discarded by keeping strong referents to those entries, leaving the remaining entries to be discarded at the discretion of the garbage collector.
软引用对象 当垃圾收集器去响应一些内存需求的时候软引用会被清理掉，软引用经常用于实现内存敏感的缓存。

假如垃圾收集器检测到在某个时间点软引用是可达的（一个对象只有软引用指向它），他可以选择原子性的清理对象的所有的软引用，以及对于任何其他从这对象开始的，通过软引用链条可达的对象也会别清理，在这个时候或者这之后的某个时间，他会将新创建的被清理掉过的软引用入队列，这个队列是创建的时候注册的。

所有软引用以及通过软引用链条可达的对象 可以确保在jvm抛出OOM错误之前被清理掉。

这个类的直接事例就是实现简单的缓存，或者它延伸的子类可以用于在比较大的数据结构当中实现更为复杂的缓存，只要软引用里边的reference在实际使用当中是强可达的，那么软引用本身就不会被清理掉。 这样我们就可以设计一种复杂的缓存，可以避免最近被使用的实体被清除，通过对这些实体保持强引用就可以实现。

##### ReferenceQueue
ReferenceQueue引用队列的设计目的是在于让我们能够知道或者是识别出垃圾收集器所执行的动作.
```
public class MyTests2 {
    public static void main(String[] args) {
        Date date=  new Date();
        ReferenceQueue<Date> referenceQueue = new ReferenceQueue<>();
        SoftReference<Date> softReference = new SoftReference(date,referenceQueue);

        System.out.println(softReference.get());

    }
}
```
输出
Tue Mar 10 21:10:09 CST 2020

时间可以正常得到，证明date并没有被回收，因为内存还没到紧急的时刻，还没到OOM之前的时刻，我们修改程序：
```
public class MyTests2 {
    public static void main(String[] args) {
        Date date=  new Date();
        ReferenceQueue<Date> referenceQueue = new ReferenceQueue<>();
        SoftReference<Date> softReference = new SoftReference(date,referenceQueue);
        date = null;
        System.gc();
        System.out.println(softReference.get());

    }
}
```
输出：
Wed Mar 11 20:21:18 CST 2020

虽然我们将强引用去掉，但是软引用里边的referent还是没有被回收，因为没到内存吃紧的时候。只有在内存吃紧的时候，软引用才会被执行回收。

#### WeakReference
Weak reference objects, which do not prevent their referents from being made finalizable, finalized, and then reclaimed. Weak references are most often used to implement canonicalizing mappings.
Suppose that the garbage collector determines at a certain point in time that an object is weakly reachable. At that time it will atomically clear all weak references to that object and all weak references to any other weakly-reachable objects from which that object is reachable through a chain of strong and soft references. At the same time it will declare all of the formerly weakly-reachable objects to be finalizable. At the same time or at some later time it will enqueue those newly-cleared weak references that are registered with reference queues.

弱引用对象，它不会阻止它里边的reference被回收掉，他经常用于映射。
假设垃圾收集器在某个时间点认为一个对象是弱引用可达的，这个时候会原子性的清除弱引用和弱引用可达的其他对象，她会声明之前的弱引用是可以回收的，同时或者过一段时间后这些新的被清理掉的引用背会入队到创建的时候注册的队列里边。

实例：
```
public class MyTests3 {
    public static void main(String[] args) {
        Date date = new Date();
        WeakReference<Date> weakReference = new WeakReference<>(date);
        System.out.println(weakReference.get());
    }
}
```
输出：
Tue Mar 10 21:10:09 CST 2020

如果一个对象指向它的引用最强的引用是弱引用并且是弱引用可达的，那么这个对象会在下一次垃圾收集周期当中被回收。
如果是软引用可能还会存活几个收集周期。

但是这个要和内存的使用情况来分析，比如如下的使用，并不一定会被回收：
```
public class MyTests3 {
    public static void main(String[] args) throws InterruptedException {
        Date date = new Date();
        WeakReference<Date> weakReference = new WeakReference<>(date);
        System.gc();
        Thread.sleep(5000);
        System.out.println(weakReference.get());
    }
}
```
输出：
Tue Mar 10 21:28:16 CST 2020

为什么没有被回收，原因其实是Date date = new Date();这个地方存在一个强引用，如果我们修改下：
```
public class MyTests3 {
    public static void main(String[] args) throws InterruptedException {
        Date date = new Date();
        WeakReference<Date> weakReference = new WeakReference<>(date);
        date = null;
        System.gc();
        Thread.sleep(5000);
        System.out.println(weakReference.get());
    }
}
```
输出：
null


#### PhantomReference
Phantom reference objects, which are enqueued after the collector determines that their referents may otherwise be reclaimed. Phantom references are most often used for scheduling pre-mortem(在真正的清除之前) cleanup actions in a more flexible way than is possible with the Java finalization mechanism.
If the garbage collector determines at a certain point in time that the referent of a phantom reference is phantom reachable, then at that time or at some later time it will enqueue the reference.
In order to ensure that a reclaimable object remains so, the referent of a phantom reference may not be retrieved: The get method of a phantom reference always returns null.
Unlike soft and weak references, phantom references are not automatically cleared by the garbage collector as they are enqueued. An object that is reachable via phantom references will remain so until all such references are cleared or themselves become unreachable.
虚引用引用的对象，当垃圾收集器确定它们的引用可以被回收的情况下，会被入队,虚引用经常用于调度这种清除的动作，这个要比java的finalization的方式更加灵活，即在对象在被真正清理之前执行一些特殊的逻辑。
在垃圾收集器再确定的时间点可以确定虚引用包装对象里边的referent是虚引用可达的，在这个时刻或者之后的某个时刻，就会将这个引用执行入队操作。
为了确保一个可回收的对象遵守这样的规则，phantom reference 里边的referent就应该不应该被获取到，因此phantom reference 的get方法总是返回null。
试想，如果get方法能够被获取到，那么在外部我们可以使用强引用关联上这个referent，那么对象就不可能被回收掉，对象无法回收掉，就无法实现上面描述的规则，无法得到通知。
和弱引用软引用不用的是，对象入队的时候，虚引用的对象并不会被垃圾收集器自动清理掉，一个对象如果是虚引用可达的，它会依然保留，直到所有这样的引用都被清理掉或者它们自身都不可达的，才会被清理掉，虚引用的主要作用是虚引用的对象在被垃圾回收的时候，我们会收到一个通知。

```
public class PhantomReference<T> extends Reference<T> {

  //get方法直接返回null
  public T get() {
         return null;
  }
 //构造方法让使用者必须传递一个引用队列。
  public PhantomReference(T referent, ReferenceQueue<? super T> q) {
      super(referent, q);
  }

}
```

实例：
```
public class MyTests4 {
    public static void main(String[] args) {
        Date date = new Date();
        PhantomReference<Date> phantomReference = new PhantomReference(date, new ReferenceQueue<>());
        System.out.println(phantomReference.get());
    }
}
```
输出：
null

##### 问题
- 为什么PhantomReference的get方法直接返回null?
- 为什么PhantomReference的构造器只有接受2个参数(referent与queue)的这一种形式，而没有只接收referent这唯一参数的构造器?

当我们将一个对象封装到PhantomReference中时，这就意味着我们永远也无法再访问到这个对象了，因为PhantomReference的get方法永远会返回null；PhantomReference的主要作用并不在于可以让我们获取到其中封装的referent，而是在于当垃圾收集器回收其referent时，这个PhantomReference会被放置到与其关联的队列中，并且得到相应的通知，这就是PhantomReference存在的唯一目的。

### ThreadLocal
This class provides thread-local variables. These variables differ from their normal counterparts in that each thread that accesses one (via its get or set method) has its own, independently initialized copy of the variable. ThreadLocal instances are typically private static fields in classes that wish to associate state with a thread (e.g., a user ID or Transaction ID).
For example, the class below generates unique identifiers local to each thread. A thread's id is assigned the first time it invokes ThreadId.get() and remains unchanged on subsequent calls.
   import java.util.concurrent.atomic.AtomicInteger;

   public class ThreadId {
       // Atomic integer containing the next thread ID to be assigned
       private static final AtomicInteger nextId = new AtomicInteger(0);

       // Thread local variable containing each thread's ID
       private static final ThreadLocal<Integer> threadId =
           new ThreadLocal<Integer>() {
               @Override protected Integer initialValue() {
                   return nextId.getAndIncrement();
           }
       };

       // Returns the current thread's unique ID, assigning it if necessary
       public static int get() {
           return threadId.get();
       }
   }

Each thread holds an implicit reference to its copy of a thread-local variable as long as the thread is alive and the ThreadLocal instance is accessible; after a thread goes away, all of its copies of thread-local instances are subject to garbage collection (unless other references to these copies exist).

这个类提供一个 thread-local变量，不同的线程得到的这个值是不一样的。通过set和get方法设置和读取 thread-local变量，每个线程都有一个它自己的对这个变量的副本，ThreadLocal通常被定义成 private static 的成员变量。
下边这个实例会生成一个标识符，这个标识符归属一个线程，线程的id是首次调用get方法的时候初始化一个值，并且以后的流程中不会被修改

每个线程都有持有一个thread-local副本的隐式引用，只要这个线程是存活的并且ThreadLocal是可以被访问，当一个线程消亡了，所有的thread-local的实例的副本都会被垃圾回收掉，除非有其他引用关联到这个副本。

重要方法-get：
```
/**
   * Returns the value in the current thread's copy of this
   * thread-local variable.  If the variable has no value for the
   * current thread, it is first initialized to the value returned
   * by an invocation of the {@link #initialValue} method.
   *
   * @return the current thread's value of this thread-local
   */
  public T get() {
      Thread t = Thread.currentThread();
      ThreadLocalMap map = getMap(t);
      if (map != null) {
          ThreadLocalMap.Entry e = map.getEntry(this);
          if (e != null) {
              @SuppressWarnings("unchecked")
              T result = (T)e.value;
              return result;
          }
      }
      return setInitialValue();
  }

  /**
   * Sets the current thread's copy of this thread-local variable
   * to the specified value.  Most subclasses will have no need to
   * override this method, relying solely on the {@link #initialValue}
   * method to set the values of thread-locals.
   *
   * @param value the value to be stored in the current thread's copy of
   *        this thread-local.
   */
  public void set(T value) {
      Thread t = Thread.currentThread();
      ThreadLocalMap map = getMap(t);
      if (map != null)
          map.set(this, value);
      else
          createMap(t, value);
  }
```
get()方法：
获取到当前线程的thread-local副本的值，如果这个线程的变量的值不存在，那么initialValue()方法初始化的值会被返回。
set方法首先得到当前线程，然后调用getMap方法，那么getMap方法做了什么？
```
/**
 * Get the map associated with a ThreadLocal. Overridden in
 * InheritableThreadLocal.
 *
 * @param  t the current thread
 * @return the map
 */
 获取到ThreadLocal关联的map对象
ThreadLocalMap getMap(Thread t) {
    return t.threadLocals;
}
```

得到Thread的threadLocals,进入到Thread类：
```
/* ThreadLocal values pertaining to this thread. This map is maintained
 * by the ThreadLocal class. */
 属于当前线程的ThreadLocal的值，这个map被ThreadLocal维护
ThreadLocal.ThreadLocalMap threadLocals = null;
```
ThreadLocalMap是ThreadLocal的一个内部类。
回到ThreadLocal的set方法，得到map之后做了一个判断，map!=null,那么紧接着将value设置到map里边去，key是ThreadLocal，value就是set方法的参数value。
如果map是空的，那么就是执行  createMap(t, value)方法：
```
void createMap(Thread t, T firstValue) {
    t.threadLocals = new ThreadLocalMap(this, firstValue);
}
```
直接创建一个ThreadLocalMap对象赋值给了Thread的成员变量threadLocals，构造器参数是ThreadLocal和将要设置的value。

get方法里边也是首先得到当前线程，通过当前线程得到ThreadLocalMap，如果map不是空的，就从ThreadLocalMap里边get一个Entry，
getEntry的key是ThreadLocal，那么ThreadLocalMap.Entry是什么？
ThreadLocalMap.Entry是ThreadLocalMap内部静态类，看定义：
```
static class Entry extends WeakReference<ThreadLocal<?>>
```
Entry继承了WeakReference。
我们设置的value存储在ThreadLocalMap.Entry里边，得到ThreadLocalMap.Entry之后，得到里边的value。然后get方法返回。

#### 实例
```
public class MyTest5 {
    public static void main(String[] args) {
        ThreadLocal<String> threadLocal = new ThreadLocal<>();
        threadLocal.set("hello");
        threadLocal.set("world");
        System.out.println(threadLocal.get());
    }
}
```
输出：
world

#### 详解
![ThreadLocal.png](ThreadLocal.png)

Entry为什么是WeakReference,是因为当线程执行完run方法之后，就会处于消亡的状态，也不会指向ThreadLocal对象，那么这个时候应该被回收，否则就会出现内存泄露。
