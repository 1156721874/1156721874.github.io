---
title: concurrency(13)ThreadPool
date: 2020-06-26 13:21:00
tags: [ThreadPool ForkJoinPool]
categories: concurrency
---


### Executor

An object that executes submitted Runnable tasks. This interface provides a way of decoupling task submission from the mechanics of how each task will be run, including details of thread use, scheduling, etc. An Executor is normally used instead of explicitly creating threads. For example, rather than invoking new Thread(new(RunnableTask())).start() for each of a set of tasks, you might use:
<!-- more -->
Executor是一个可运行提交任务的对象，这个接口提供了一种将任务的提交和每个任务的运行机制解耦的方式，包括线程的具体使用，调度等，一个Executor一般用于替代手动创建线程的方式，可以使用如下的方式：
   Executor executor = anExecutor;
   executor.execute(new RunnableTask1());
   executor.execute(new RunnableTask2());
   ...

However, the Executor interface does not strictly require that execution be asynchronous. In the simplest case, an executor can run the submitted task immediately in the caller's thread:

 class DirectExecutor implements Executor {
   public void execute(Runnable r) {
     r.run();
   }
 }
More typically, tasks are executed in some thread other than the caller's thread. The executor below spawns a new thread for each task.

 class ThreadPerTaskExecutor implements Executor {
   public void execute(Runnable r) {
     new Thread(r).start();
   }
 }
Many Executor implementations impose some sort of limitation on how and when tasks are scheduled. The executor below serializes the submission of tasks to a second executor, illustrating a composite executor.

 class SerialExecutor implements Executor {
   final Queue<Runnable> tasks = new ArrayDeque<Runnable>();
   final Executor executor;
   Runnable active;

   SerialExecutor(Executor executor) {
     this.executor = executor;
   }

   public synchronized void execute(final Runnable r) {
     tasks.offer(new Runnable() {
       public void run() {
         try {
           r.run();
         } finally {
           scheduleNext();
         }
       }
     });
     if (active == null) {
       scheduleNext();
     }
   }

   protected synchronized void scheduleNext() {
     if ((active = tasks.poll()) != null) {
       executor.execute(active);
     }
   }
 }
The Executor implementations provided in this package implement ExecutorService, which is a more extensive interface. The ThreadPoolExecutor class provides an extensible thread pool implementation. The Executors class provides convenient factory methods for these Executors.
Memory consistency effects: Actions in a thread prior to submitting a Runnable object to an Executor happen-before its execution begins, perhaps in another thread


Executor包含的方法：
  execute

#### ExecutorService
An Executor that provides methods to manage termination and methods that can produce a Future for tracking progress of one or more asynchronous tasks.
一个Executor的实现，提供了一些管理终止任务和返回一个用来追踪处理过程或者更多异步任务future的方法。
An ExecutorService can be shut down, which will cause it to reject new tasks. Two different methods are provided for shutting down an ExecutorService. The shutdown method will allow previously submitted tasks to execute before terminating, while the shutdownNow method prevents waiting tasks from starting and attempts to stop currently executing tasks. Upon termination, an executor has no tasks actively executing, no tasks awaiting execution, and no new tasks can be submitted. An unused ExecutorService should be shut down to allow reclamation of its resources.
Method submit extends base method Executor.execute(Runnable) by creating and returning a Future that can be used to cancel execution and/or wait for completion. Methods invokeAny and invokeAll perform the most commonly useful forms of bulk execution, executing a collection of tasks and then waiting for at least one, or all, to complete. (Class ExecutorCompletionService can be used to write customized variants of these methods.)
一个ExecutorService是可以被关闭的，这样的话拒绝一些新的任务，提供了shutdow和shutdownnow方法。
The Executors class provides factory methods for the executor services provided in this package

java.util.concurrent.ExecutorService
java.util.concurrent.ExecutorService#shutdown
java.util.concurrent.ExecutorService#shutdownNow
java.util.concurrent.ExecutorService#isShutdown
java.util.concurrent.ExecutorService#isTerminated
java.util.concurrent.ExecutorService#awaitTermination
java.util.concurrent.ExecutorService#submit(java.util.concurrent.Callable<T>)
java.util.concurrent.ExecutorService#submit(java.lang.Runnable, T)
java.util.concurrent.ExecutorService#submit(java.lang.Runnable)
java.util.concurrent.ExecutorService#invokeAll(java.util.Collection<? extends java.util.concurrent.Callable<T>>)
java.util.concurrent.ExecutorService#invokeAll(java.util.Collection<? extends java.util.concurrent.Callable<T>>, long, java.util.concurrent.TimeUnit)
java.util.concurrent.ExecutorService#invokeAny(java.util.Collection<? extends java.util.concurrent.Callable<T>>)
java.util.concurrent.ExecutorService#invokeAny(java.util.Collection<? extends java.util.concurrent.Callable<T>>, long, java.util.concurrent.TimeUnit)

#### ThreadPoolExecutor
具体是线程池实现是由ThreadPoolExecutor实现，ThreadPoolExecutor是间接的实现了ExecutorService，ThreadPoolExecutor继承了AbstractExecutorService，AbstractExecutorService实现了ExecutorService。
AbstractExecutorService的实现方法：
java.util.concurrent.AbstractExecutorService
java.util.concurrent.AbstractExecutorService#newTaskFor(java.lang.Runnable, T)
java.util.concurrent.AbstractExecutorService#newTaskFor(java.util.concurrent.Callable<T>)
java.util.concurrent.AbstractExecutorService#submit(java.lang.Runnable)
java.util.concurrent.AbstractExecutorService#submit(java.lang.Runnable, T)
java.util.concurrent.AbstractExecutorService#submit(java.util.concurrent.Callable<T>)
java.util.concurrent.AbstractExecutorService#doInvokeAny
java.util.concurrent.AbstractExecutorService#invokeAny(java.util.Collection<? extends java.util.concurrent.Callable<T>>)
java.util.concurrent.AbstractExecutorService#invokeAny(java.util.Collection<? extends java.util.concurrent.Callable<T>>, long, java.util.concurrent.TimeUnit)
java.util.concurrent.AbstractExecutorService#invokeAll(java.util.Collection<? extends java.util.concurrent.Callable<T>>)
java.util.concurrent.AbstractExecutorService#invokeAll(java.util.Collection<? extends java.util.concurrent.Callable<T>>, long, java.util.concurrent.TimeUnit)

AbstractExecutorService是线程池实现的基础，提供了一些默认的实现。

##### 线程池需要管理的数据
- 线程池本身的状态
- 执行的线程的状态
```
// ctl存储了【线程池的状态】以及【线程池里边线程的数量】
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));
// 减去的3位是存储的是线程池的状态剩下的是管理的线程的数量：COUNT_BITS = 32-3=29
private static final int COUNT_BITS = Integer.SIZE - 3;
private static final int CAPACITY   = (1 << COUNT_BITS) - 1;

// runState is stored in the high-order bits
private static final int RUNNING    = -1 << COUNT_BITS;
private static final int SHUTDOWN   =  0 << COUNT_BITS;
private static final int STOP       =  1 << COUNT_BITS;
private static final int TIDYING    =  2 << COUNT_BITS;
private static final int TERMINATED =  3 << COUNT_BITS;
```
线程池里边的worker线程实现了AQS：
```
private final class Worker extends AbstractQueuedSynchronizer  implements Runnable
{
  ...
}
```
#### 线程池的创建
##### ThreadPoolExecutor的构造器
```
/**
 * Creates a new {@code ThreadPoolExecutor} with the given initial
 * parameters.
 *
 * @param corePoolSize the number of threads to keep in the pool, even
 *        if they are idle, unless {@code allowCoreThreadTimeOut} is set
 * @param maximumPoolSize the maximum number of threads to allow in the
 *        pool
 * @param keepAliveTime when the number of threads is greater than
 *        the core, this is the maximum time that excess idle threads
 *        will wait for new tasks before terminating.
 * @param unit the time unit for the {@code keepAliveTime} argument
 * @param workQueue the queue to use for holding tasks before they are
 *        executed.  This queue will hold only the {@code Runnable}
 *        tasks submitted by the {@code execute} method.
 * @param threadFactory the factory to use when the executor
 *        creates a new thread
 * @param handler the handler to use when execution is blocked
 *        because the thread bounds and queue capacities are reached
 * @throws IllegalArgumentException if one of the following holds:<br>
 *         {@code corePoolSize < 0}<br>
 *         {@code keepAliveTime < 0}<br>
 *         {@code maximumPoolSize <= 0}<br>
 *         {@code maximumPoolSize < corePoolSize}
 * @throws NullPointerException if {@code workQueue}
 *         or {@code threadFactory} or {@code handler} is null
 */
public ThreadPoolExecutor(
    int corePoolSize,  //核心的线程数量，即使没有任务执行也不会关闭
    int maximumPoolSize, 最大的线程数量
    long keepAliveTime, //线程等待新任务到来的时间超过keepAliveTime就会回收掉
    TimeUnit unit, //时间单位
    BlockingQueue<Runnable> workQueue, //缓存提交的任务的队列
    ThreadFactory threadFactory, //线程工厂
    RejectedExecutionHandler handler // 拒绝策略
                          ) {
    if (corePoolSize < 0 ||
        maximumPoolSize <= 0 ||
        maximumPoolSize < corePoolSize ||
        keepAliveTime < 0)
        throw new IllegalArgumentException();
    if (workQueue == null || threadFactory == null || handler == null)
        throw new NullPointerException();
    this.corePoolSize = corePoolSize;
    this.maximumPoolSize = maximumPoolSize;
    this.workQueue = workQueue;
    this.keepAliveTime = unit.toNanos(keepAliveTime);
    this.threadFactory = threadFactory;
    this.handler = handler;
}
```
int corePoolSize：
  核心的线程数量，即使没有任务执行也不会关闭。
int maximumPoolSize：
  线程池当中维护的最大的线程数量
long keepAliveTime：
  线程等待新任务到来的时间超过keepAliveTime就会被回收掉，回收的底线是corePoolSize。
TimeUnit unit：
  keepAliveTime的时间单位
BlockingQueue<Runnable> workQueue：
  缓存提交的任务的队列
ThreadFactory threadFactory：
  线程工厂，推荐使用Executors#defaultThreadFactory。
  ```
  static class DefaultThreadFactory implements ThreadFactory {
    //poolNumber是静态的，原因是系统中所有的线程池都是共享这个AtomicInteger，这样就不会出现名称相同的线程池
    private static final AtomicInteger poolNumber = new AtomicInteger(1);
    private final ThreadGroup group;
    private final AtomicInteger threadNumber = new AtomicInteger(1);
    private final String namePrefix;

    DefaultThreadFactory() {
        SecurityManager s = System.getSecurityManager();
        group = (s != null) ? s.getThreadGroup() : Thread.currentThread().getThreadGroup();
        namePrefix = "pool-" + poolNumber.getAndIncrement() + "-thread-";
    }

    public Thread newThread(Runnable r) {
        Thread t = new Thread(group, r,
                              namePrefix + threadNumber.getAndIncrement(),
                              0);
        if (t.isDaemon())
            t.setDaemon(false);//非守护线程，即为用户线程，main执行完之后，不会退出
        if (t.getPriority() != Thread.NORM_PRIORITY)
            t.setPriority(Thread.NORM_PRIORITY);
        return t;
    }
  }
  ```
RejectedExecutionHandler handler：
  拒绝策略，当达到队列上限或者再也不能创建现线程的时候被调用。
  - AbortPolicy 直接抛出运行期异常，一直抛给执行execute的调用者，rejectedExecution抛出RejectedExecutionException
  - CallerRunsPolicy
    调用者线程去执行
    ```
    public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
      if (!e.isShutdown()) {
          r.run();
      }
    }
    ```
  - DiscardOldestPolicy
    将最老的一个未被处理的任务丢弃，然后让线程池执行当前的任务
    ```
    public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
        if (!e.isShutdown()) {
            //将最老的一个拿出来，不做处理，丢弃
            e.getQueue().poll();
            //执行当前的任务
            e.execute(r);
        }
    }
    ```
  - DiscardPolicy 直接丢弃，也不会抛出任何异常，rejectedExecution是空实现

##### Executors工厂
java.util.concurrent.Executors
java.util.concurrent.Executors#newFixedThreadPool(int)
java.util.concurrent.Executors#newWorkStealingPool(int)
java.util.concurrent.Executors#newWorkStealingPool()
java.util.concurrent.Executors#newFixedThreadPool(int, java.util.concurrent.ThreadFactory)
java.util.concurrent.Executors#newSingleThreadExecutor()
java.util.concurrent.Executors#newSingleThreadExecutor(java.util.concurrent.ThreadFactory)
java.util.concurrent.Executors#newCachedThreadPool()
java.util.concurrent.Executors#newCachedThreadPool(java.util.concurrent.ThreadFactory)
java.util.concurrent.Executors#newSingleThreadScheduledExecutor()
java.util.concurrent.Executors#newSingleThreadScheduledExecutor(java.util.concurrent.ThreadFactory)
java.util.concurrent.Executors#newScheduledThreadPool(int)
java.util.concurrent.Executors#newScheduledThreadPool(int, java.util.concurrent.ThreadFactory)
java.util.concurrent.Executors#unconfigurableExecutorService
java.util.concurrent.Executors#unconfigurableScheduledExecutorService
java.util.concurrent.Executors#defaultThreadFactory
java.util.concurrent.Executors#privilegedThreadFactory
java.util.concurrent.Executors#callable(java.lang.Runnable, T)
java.util.concurrent.Executors#callable(java.lang.Runnable)
java.util.concurrent.Executors#callable(java.security.PrivilegedAction<?>)
java.util.concurrent.Executors#callable(java.security.PrivilegedExceptionAction<?>)
java.util.concurrent.Executors#privilegedCallable
java.util.concurrent.Executors#privilegedCallableUsingCurrentClassLoader
```
public class MyTest1 {
    public static void main(String[] args) {
        ExecutorService executorService = Executors.newFixedThreadPool(3);
        executorService.submit(() ->{
            IntStream.range(0,50).forEach(i -> {
                System.out.println(Thread.currentThread().getName());
            });
        });
    }
}
```
打印的线程名称都是同一个名称，以为只提交了一个任务，会使用其中一个线程去执行。
代码运行之后，jvm线程并不会退出，那是因为线程池创建的线程都是用户线程，而非守护线程，我们只有显式的调用线程池的shutdow之类的方法停止线程池。
Executors.newFixedThreadPool(3):创建只有三个线程的线程池，永远不会增加减少
Executors.newSingleThreadExecutor():创建只有1个线程的线程池，永远不会增加减少
Executors.newCachedThreadPool(): 带缓冲的线程池，它里边的线程的数量会根据提交的任务的多少来动态创建线程。

提交多个任务：
```
public class MyTest1 {
    public static void main(String[] args) {
        ExecutorService executorService = Executors.newFixedThreadPool(3);
        IntStream.range(0,10).forEach(i ->{
            executorService.submit(() ->{
                IntStream.range(0,50).forEach(j -> {
                    System.out.println(Thread.currentThread().getName());
                });
            });  
        });
    }
}
```
打印结果会出现3个线程的名称，因为提交了多个任务，会有线程的复用。
如果使用的是newSingleThreadExecutor()，那么打印结果只会出现一个线程的名称，所有的任务都是由这一个线程去执行。
如果使用newCachedThreadPool()，打印结果会出现很多线程的名称。

#### newCachedThreadPool()
```
public static ExecutorService newCachedThreadPool() {
    //最小线程数量是0，最大线程数量是Integer的最大值，AbortPolicy拒绝策略
    return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                  60L, TimeUnit.SECONDS,
                                  new SynchronousQueue<Runnable>());
}
```
SynchronousQueue即同步的队列，插入操作必须等待移除操作的完成才能进行，返回来也是，里边只有一个元素。
由于核心线程数是0，因此回往SynchronousQueue添加任务，但是SynchronousQueue是同步的必须立刻执行，
因此新提交过来的任务会不断的创建线程去执行。
#### Executors.newSingleThreadExecutor()
```
public static ExecutorService newSingleThreadExecutor() {
  //最小和最大线程数量被限制成了1个，AbortPolicy拒绝策略，无界队列
    return new FinalizableDelegatedExecutorService
        (new ThreadPoolExecutor(1, 1,
                                0L, TimeUnit.MILLISECONDS,
                                new LinkedBlockingQueue<Runnable>()));
}
```

#### Executors.newFixedThreadPool(n)
```
nThreads限制了最小和最大线程数量，AbortPolicy拒绝策略，无界队列
public static ExecutorService newFixedThreadPool(int nThreads) {
    return new ThreadPoolExecutor(nThreads, nThreads,
                                  0L, TimeUnit.MILLISECONDS,
                                  new LinkedBlockingQueue<Runnable>());
}
```
工厂方法底层都是调用的ThreadPoolExecutor的构造器。实际使用线程池不推荐使用工厂的方式，因为：
- 这些工厂创建的线程池拒绝策略都是抛出异常
- newSingleThreadExecutor、newFixedThreadPool中的任务缓冲队列都是无界的，很容易出现oom异常。

#### 偏向锁
在线程池当中，尽量把偏向锁关闭

#### 自定义ThreadPoolExecutor参数
```
public class MyTest2 {
    public static void main(String[] args) {
        ExecutorService executorService = new ThreadPoolExecutor(3,5,
                0,
                TimeUnit.SECONDS,new LinkedBlockingDeque<>(3),
                new ThreadPoolExecutor.CallerRunsPolicy()
                );
        int number = 9;
        IntStream.range(0,number).forEach(i ->{
            executorService.submit(() ->{
                try {
                    Thread.sleep(100);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                IntStream.range(0,1).forEach(j -> {
                    System.out.println(Thread.currentThread().getName());
                });
            });
        });
    }
}

```
number小于等于3的时候，日志最多打印三个线程在执行任务。
number大于3小于等于6的时候，日志最多打印三个线程在执行任务。
number大于6小于等于8的时候，日志最多打印8个线程在执行任务。
number大于8的时候最多会出现8个线程在执行任务，并且可能会出现拒绝执行任务的异常。
如果拒绝策略使用DiscardPolicy，那么程序不会抛出异常，但是会有一些任务被静默丢弃。
如实拒绝策略使用DiscardOldestPolicy，那么程序也不会抛出异常，但是会将阻塞队列里边的最老的任务丢弃，然后执行当前任务。
如果拒绝策略使用CallerRunsPolicy，那么打印结果里边会出现一个main的线程名称，即，使用调用者的线程去执行任务:
```
pool-1-thread-3
pool-1-thread-4
pool-1-thread-1
pool-1-thread-5
pool-1-thread-2
main
pool-1-thread-3
pool-1-thread-4
pool-1-thread-1
```

#### 线程池任务创建与执行任务的核心逻辑
ThreadPoolExecutor的submit有三种实现方式：
 - <T> Future<T> submit(Callable<T> task); //Future是线程run方法真正的返回值.
 - <T> Future<T> submit(Runnable task, T result); // Future.get()返回的是参数result.
 - Future<?> submit(Runnable task); //Future.get()返回为null.

submit方法会调用execute方法去执行任务。
对于线程池来说，其提供了execute与submit两种方式来向线程池提交任务。
总体来说，submit方法是可以提供execute方法的，因为它既可以接收callable任务，也可以接收Runnable任务。

关于线程池的总体的执行策略：
1. 如果线程池中正在执行的线程数 < corePoolSize，那么线程池就会优先选择创建新的线程而非将提交的任务加到阻塞队列中。
2. 如果线程池中正在执行的线程数数 >= corePoolSize，那么线程池就会优先选择对提交的任务进行阻塞排队而非创建新的线程。
3. 如果提交的任务无法加入到阻塞队列当中，那么线程池就会创建新的线程；如果创建的线程数超过了maximumPoolSize，那么拒绝策略就会起作用。

执行submit过程:
```
public Future<?> submit(Runnable task) {
    if (task == null) throw new NullPointerException();
    RunnableFuture<Void> ftask = newTaskFor(task, null);
    execute(ftask);
    return ftask;
}
protected <T> RunnableFuture<T> newTaskFor(Runnable runnable, T value) {
    return new FutureTask<T>(runnable, value);
}
```
FutureTask的构造器：
```
public FutureTask(Runnable runnable, V result) {
    this.callable = Executors.callable(runnable, result);
    this.state = NEW;       // ensure visibility of callable
}
```
 Executors.callable(runnable, result)逻辑是对callable创建的封装:
 ```
 public static <T> Callable<T> callable(Runnable task, T result) {
     if (task == null)
         throw new NullPointerException();
     return new RunnableAdapter<T>(task, result);
 }
 ```
RunnableAdapter实际上是一个Callable，call方法是实际任务的执行:
 ```
 static final class RunnableAdapter<T> implements Callable<T> {
     final Runnable task;
     final T result;
     RunnableAdapter(Runnable task, T result) {
         this.task = task;
         this.result = result;
     }
     public T call() {
         task.run();
         // 等待任务执行完毕(task.run()),然后直接返回result
         return result;
     }
 }
 ```
 其他的重载的submit方法执行逻辑都是一样的，不管是runnbale或者callable都会转换为callable，只不过参数是Callable的时候不需要RunnableAdapter。
newTaskFor返回的是RunnableFuture，RunnableFuture的实现类FutureTask封装了执行和返回的结构的一个集合体:
```
public class FutureTask<V> implements RunnableFuture<V> {
  java.util.concurrent.FutureTask#FutureTask(java.util.concurrent.Callable<V>)
  java.util.concurrent.FutureTask#FutureTask(java.lang.Runnable, V)
  java.util.concurrent.FutureTask#report
  java.util.concurrent.FutureTask#isCancelled
  java.util.concurrent.FutureTask#isDone
  java.util.concurrent.FutureTask#cancel
  java.util.concurrent.FutureTask#get()
  java.util.concurrent.FutureTask#get(long, java.util.concurrent.TimeUnit)
  java.util.concurrent.FutureTask#done
  java.util.concurrent.FutureTask#set
  java.util.concurrent.FutureTask#setException
  java.util.concurrent.FutureTask#run
  java.util.concurrent.FutureTask#runAndReset
  java.util.concurrent.FutureTask#handlePossibleCancellationInterrupt
  java.util.concurrent.FutureTask#finishCompletion
  java.util.concurrent.FutureTask#awaitDone
  java.util.concurrent.FutureTask#removeWaiter
}
```
RunnableFuture是一个可取消的异步的计算，提供了Future的基础的实现，提供了开始、取消、查询、获取运算结构的方法，运算结果只有运算完成之后才能获取，如果运算还没有完成，那么get方法是阻塞，任务一旦计算完成就不能重新开始或者取消，除非计算的时候调用了runAndReset方法。

##### 关于线程池任务的提交
1. 两种提交方式:submit与execute
2. submit有三种方式，无论是哪种方式，最终都是将传递将来的任务转换为一个callable对象进行处理
3. 当callable对象构造完毕后，最终都会调用Executor提供接口中声明的execute方法进行统一的处理

execute()方法是主要的逻辑，它的实现【java.util.concurrent.ThreadPoolExecutor.execute()】。

介绍【java.util.concurrent.ThreadPoolExecutor.execute()】之前先了解下ThreadPoolExecutor的一些成员变量。
- 对于线程池来说，有2个状态需要维护：
  - 线程池本身的状态
  - 线程池所运行着的线程的数量

```
// ctl是一个原子整型变量，表示了线程池本身的状态、线程池所运行着的线程的数量
// 高三位表示【 线程池本身的状态】，低29位表示【线程池所运行着的线程的数量】
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));
private static final int COUNT_BITS = Integer.SIZE - 3;
private static final int CAPACITY   = (1 << COUNT_BITS) - 1;

// runState is stored in the high-order bits
// 线程池一共有5种状态
private static final int RUNNING    = -1 << COUNT_BITS;
private static final int SHUTDOWN   =  0 << COUNT_BITS;
private static final int STOP       =  1 << COUNT_BITS;
private static final int TIDYING    =  2 << COUNT_BITS;
private static final int TERMINATED =  3 << COUNT_BITS;

// Packing and unpacking ctl
// runStateOf是线程池的状态
private static int runStateOf(int c)     { return c & ~CAPACITY; }
// workerCountOf是当前线程池工作线程的数量
private static int workerCountOf(int c)  { return c & CAPACITY; }
// ctlOf重新计算ctl的值
private static int ctlOf(int rs, int wc) { return rs | wc; }
```

线程池的状态:
1. RUNNING: 线程池可以接受新的任务提交，并且还可以正常处理阻塞队列。
2. SHUTDOWN: 不再接收新的任务提交，不过线程池还可以继续处理阻塞队列中的任务。
3. STOP：不再接收新的任务，同时还会丢弃阻塞队列中的既有任务，它还会中断正在处理中的任务。SHUTDOWNNOW会将状态置位stop状态。
4. TIDYING：所有的任务都执行完毕后（同时也涵盖了阻塞队列中的任务），当前线程池的活动的线程数量降为0，将会调用terminated方法。
5. TERMINATED：线程池的终止状态，当terminated方法执行完毕后，线程池将会处于该状态之下。

线程池的状态切换:
RUNNING -> SHUTDOWN: 当调用了线程池的SHUTDOWN方法，或者finalize方法被隐式调用后(该方法内部会调用shutdown方法)
```
public void shutdown() {
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        checkShutdownAccess();
        advanceRunState(SHUTDOWN);
        interruptIdleWorkers();
        onShutdown(); // hook for ScheduledThreadPoolExecutor
    } finally {
        mainLock.unlock();
    }
    tryTerminate();
}

protected void finalize() {
    shutdown();
}
```

RUNNING/SHUTDOWN -> STOP: 当调用了线程池的shutdownNow方法时。
```
public List<Runnable> shutdownNow() {
    List<Runnable> tasks;
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        checkShutdownAccess();
        advanceRunState(STOP);
        interruptWorkers();
        tasks = drainQueue();
    } finally {
        mainLock.unlock();
    }
    tryTerminate();
    return tasks;
}
```
SHUTDOWN -> TIDYING: 在线程池与阻塞队列均变成空时。

STOP -> TIDYING: 在线程池变成空时。

TIDYING -> TERMINATED: 在terminated方法被执行完毕时。

ThreadPoolExecutor.execute()执行逻辑：
```
/**
   * Executes the given task sometime in the future.  The task
   * may execute in a new thread or in an existing pooled thread.
   * 在将来某个时刻执行给定的任务，任务可能在一个新的线程里边被执行，也可能在已有的线程里边被执行
   * If the task cannot be submitted for execution, either because this
   * executor has been shutdown or because its capacity has been reached,
   * the task is handled by the current {@code RejectedExecutionHandler}.
   * 如果任务无法被提交执行，原因可能是executor已经被关闭，或者阻塞队列容量已经满了，
   * 那么任务就会交给RejectedExecutionHandler处理。
   * @param command the task to execute
   * @throws RejectedExecutionException at discretion of
   *         {@code RejectedExecutionHandler}, if the task
   *         cannot be accepted for execution
   * @throws NullPointerException if {@code command} is null
   */
  public void execute(Runnable command) {
      if (command == null)
          throw new NullPointerException();
      /*
       * Proceed in 3 steps:
       *
       * 1. If fewer than corePoolSize threads are running, try to
       * start a new thread with the given command as its first
       * task.  The call to addWorker atomically checks runState and
       * workerCount, and so prevents false alarms that would add
       * threads when it shouldn't, by returning false.
       * 如果线程池运行的线程数如果少于corePoolSize，线程池会尝试创建新的线程，
       * 并且用新的线程去执行给定的任务，对于addWorker会使用原子的方式去调用。
       * 2. If a task can be successfully queued, then we still need
       * to double-check whether we should have added a thread
       * (because existing ones died since last checking) or that
       * the pool shut down since entry into this method. So we
       * recheck state and if necessary roll back the enqueuing if
       * stopped, or start a new thread if there are none.
       * 如果一个任务能够被成功的添加到任务队列中，会尝试双重检查是否已经添加了一个新的线程，
       * 或者线程池被关闭了等，如果不行就会回
       * 滚带入队之前的状态；
       * 3. If we cannot queue task, then we try to add a new
       * thread.  If it fails, we know we are shut down or saturated
       * and so reject the task.
       * 如果不能进行入队操作，那么就会创建新的线程。如果失败，执行拒绝策略
       */
      int c = ctl.get();
      // workerCountOf返回线程池存活的线程的数量，如果小于corePoolSize核心线程数量
      if (workerCountOf(c) < corePoolSize) {
          //创建一个新的线程去执行当前任务
          if (addWorker(command, true))
              //执行成功直接返回
              return;
          //因为线程池可能会把其他线程使用，所以在此获取ctl的值
          c = ctl.get();
      }
      // 线程的线程数大于等于corePoolSize，并且线程池正在运行isRunning=true,
      // 并且任务入队成功：workQueue.offer(command)  = true
      if (isRunning(c) && workQueue.offer(command)) {
        // 重新获取ctl检查
          int recheck = ctl.get();
          //线程池已经关闭并且可以将刚才入队的【workQueue.offer(command)】删除掉成功
          //(回滚操作)
          if (! isRunning(recheck) && remove(command))
              // 执行拒绝策略
              reject(command);
          // 线程池正在运行，线程池可用线程数等于0
          else if (workerCountOf(recheck) == 0)
              // 创建新的线程去执行当前任务
              addWorker(null, false);
      }
      // 线程池被关闭，并且创建新的线程失败
      else if (!addWorker(command, false))
          // 拒绝策略
          reject(command);
  }
```

addWorker方法：
```
/**
 * Checks if a new worker can be added with respect to current
 * pool state and the given bound (either core or maximum). If so,
 * the worker count is adjusted accordingly, and, if possible, a
 * new worker is created and started, running firstTask as its
 * first task. This method returns false if the pool is stopped or
 * eligible to shut down. It also returns false if the thread
 * factory fails to create a thread when asked.  If the thread
 * creation fails, either due to the thread factory returning
 * null, or due to an exception (typically OutOfMemoryError in
 * Thread.start()), we roll back cleanly.
 * 检查一个新的word而是否能够添加进来，并且还会考虑当前线程池的状态以及边界
 * （核心线程数和最大线程数），如果能够添加成功，那么wordercount就会被调整，新的worker
 * 会被创建和启动，参数firstTask作为worder的第一个任务，如果线程池被停止了那么这个方法返回false，
 * 如果线程工厂无法创建一个新的线程也会返回false，如果线程创建失败，可能是由于线程工厂创建失败，或者
 * 由于一些异常导致，比如线程启动的时候出现OutOfMemoryError，这个时候程序就会进行回滚清理操作
 * @param firstTask the task the new thread should run first (or
 * null if none). Workers are created with an initial first task
 * (in method execute()) to bypass queuing when there are fewer
 * than corePoolSize threads (in which case we always start one),
 * or when the queue is full (in which case we must bypass queue).
 * Initially idle threads are usually created via
 * prestartCoreThread or to replace other dying workers.
 * 新创建的线程应该被执行的任务，worker会被创建出来，并且会有第一个任务(参数firstTask)
 * 当总的线程数小于corePoolSize，会跳过加入阻塞队列的逻辑，会直接执行这个任务，如果阻塞
 * 队列满了，也会绕过队列的加入逻辑，
 * @param core if true use corePoolSize as bound, else
 * maximumPoolSize. (A boolean indicator is used here rather than a
 * value to ensure reads of fresh values after checking other pool
 * state). 如果是true，使用corePoolSize作为边界，如果是false使用maximumPoolSize作为
 * 边界，这个参数决定了线程是怎么创建，任务怎么往阻塞队列里边插入等等逻辑。
 * @return true if successful
 */
private boolean addWorker(Runnable firstTask, boolean core) {
    //标签
    retry:
    //外层死循环
    for (;;) {
      //得到状态
        int c = ctl.get();
        //线程池运行状态
        int rs = runStateOf(c);

        // Check if queue empty only if necessary.
        //条件A： 线程池状态是SHUTDOWN、STOP、TIDYING、TERMINATED
        //条件B： 【线程池状态是SHUTDOWN 并且参数firstTask是空，并且任务阻塞不是空的】取反
        if (rs >= SHUTDOWN &&
            ! (rs == SHUTDOWN &&
               firstTask == null &&
               ! workQueue.isEmpty()))
               //创建失败
            return false;
        // 内存死循环
        for (;;) {
            // 当前线程池的线程数量
            int wc = workerCountOf(c);
            // 线程数量大于等于线程数最大能表示的上限数量，或者大于等于上限，返回false，创建失败
            if (wc >= CAPACITY ||
                wc >= (core ? corePoolSize : maximumPoolSize))
                // 创建失败
                return false;
            //增加线程池线程数量+1成功，退出到外层循环，程序往下走
            if (compareAndIncrementWorkerCount(c))
                break retry;
            // 获取线程池ctl
            c = ctl.get();  // Re-read ctl
            // 线程池状态发生了变化
            if (runStateOf(c) != rs)
                // 外层循环执行，重新执行addWorker方法
                continue retry;
            //CAS失败，即，增加线程池线程数量CAS失败，内层循环执行一遍
            // else CAS failed due to workerCount change; retry inner loop
        }
    }
    // 工作线程是否启动
    boolean workerStarted = false;
    // 工作线程是否添加
    boolean workerAdded = false;
    Worker w = null;
    try {
        // Worker继承了AQS,代表了工作线程
        w = new Worker(firstTask);
        //得到线程对象
        final Thread t = w.thread;
        // 线程工厂创建线程失败
        if (t != null) {
            // 获取到重入锁(排它锁)
            final ReentrantLock mainLock = this.mainLock;
            //加锁
            mainLock.lock();
            try {
                // Recheck while holding lock.
                // Back out on ThreadFactory failure or if
                // shut down before lock acquired.
                // 再次检查线程池状态
                int rs = runStateOf(ctl.get());
                // 线程池状态是RUNNING，或者（线程池状态是SHUTDOWN 并且参数firstTask是空）
                if (rs < SHUTDOWN ||
                    (rs == SHUTDOWN && firstTask == null)) {
                    //再次判断线程工厂创建的线程是可以启动的，如果不可用，直接抛出异常
                    if (t.isAlive()) // precheck that t is startable
                        throw new IllegalThreadStateException();
                    //将新创建的线程添加到HashSet里边
                    workers.add(w);
                    //得到工作线程的数量
                    int s = workers.size();
                    //工作线程的数量大于largestPoolSize
                    if (s > largestPoolSize)
                        //记录曾经最大的线程池的数量
                        largestPoolSize = s;
                    // 标记新创建的线程添加成功
                    workerAdded = true;
                }
            } finally {
              //解锁
                mainLock.unlock();
            }
            //如果工作线程添加成功
            if (workerAdded) {
                //启动工作线程
                t.start();
                //标记工作线程已经启动成功
                workerStarted = true;
            }
        }
    } finally {
      // 如果工作线程没有启动成功
        if (! workerStarted)
            //将线程从工作线程集合里边移除。相当于回滚
            addWorkerFailed(w);
    }
    return workerStarted;
}
private void addWorkerFailed(Worker w) {
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        if (w != null)
            workers.remove(w);
        //工作线程数量CAS减1
        decrementWorkerCount();
        //尝试终止线程池
        tryTerminate();
    } finally {
        mainLock.unlock();
    }
}
```
Worker的构造器以及worker的主流程：
Worker继承了AbstractQueuedSynchronizer
```
private final class Worker extends AbstractQueuedSynchronizer implements Runnable
{
  ....
  Worker(Runnable firstTask) {
      //执行线程之前，线程不能被中断，其实是设置了AQS的state，中断的情况就是项城市的shutdown，
      // stop之类的方法，这类方法在执行的时候会判断state是否大约等于0，小于0的-1不会被中断
      setState(-1); // inhibit interrupts until runWorker
      this.firstTask = firstTask;
      this.thread = getThreadFactory().newThread(this);
  }
  public void run() {
      runWorker(this);
  }
}
```
注意， getThreadFactory().newThread(this)传递的是this，也就是worker，当执行thread.start()的时候就会执行worker的run方法。
ThreadPoolExecutor当中的实现：
```
  /**
 * Main worker run loop.  Repeatedly gets tasks from queue and
 * executes them, while coping with a number of issues:
 * 主要的worker循环，重复不断的从阻塞队列里边获取和执行任务。
 * 1. We may start out with an initial task, in which case we
 * don't need to get the first one. Otherwise, as long as pool is
 * running, we get tasks from getTask. If it returns null then the
 * worker exits due to changed pool state or configuration
 * parameters.  Other exits result from exception throws in
 * external code, in which case completedAbruptly holds, which
 * usually leads processWorkerExit to replace this thread.
 *
 * 2. Before running any task, the lock is acquired to prevent
 * other pool interrupts while the task is executing, and then we
 * ensure that unless pool is stopping, this thread does not have
 * its interrupt set.
 *
 * 3. Each task run is preceded by a call to beforeExecute, which
 * might throw an exception, in which case we cause thread to die
 * (breaking loop with completedAbruptly true) without processing
 * the task.
 *
 * 4. Assuming beforeExecute completes normally, we run the task,
 * gathering any of its thrown exceptions to send to afterExecute.
 * We separately handle RuntimeException, Error (both of which the
 * specs guarantee that we trap) and arbitrary Throwables.
 * Because we cannot rethrow Throwables within Runnable.run, we
 * wrap them within Errors on the way out (to the thread's
 * UncaughtExceptionHandler).  Any thrown exception also
 * conservatively causes thread to die.
 *
 * 5. After task.run completes, we call afterExecute, which may
 * also throw an exception, which will also cause thread to
 * die. According to JLS Sec 14.20, this exception is the one that
 * will be in effect even if task.run throws.
 *
 * The net effect of the exception mechanics is that afterExecute
 * and the thread's UncaughtExceptionHandler have as accurate
 * information as we can provide about any problems encountered by
 * user code.
 *
 * @param w the worker
 */
final void runWorker(Worker w) {
    //获取到当前线程对象
    Thread wt = Thread.currentThread();
    // worker创建后，第一个任务
    Runnable task = w.firstTask;
    // 任务已经已经暂存，防止下次再次传递进来，造成错乱
    w.firstTask = null;
    // aqs的解锁，将aqs的state设置为0，即，设置线程可以被中断（线程可以被shutdown），实现在Worker的tryRelease
    // 方法里边对state设置为0
    w.unlock(); // allow interrupts
    //完成标记
    boolean completedAbruptly = true;
    try {
        //初始任务不是空，优先执行第一个任务，否则再去阻塞队列拉取任务执行。
        while (task != null || (task = getTask()) != null) {
            // 加锁处理，将aqs的state由0设置为1
            w.lock();
            // If pool is stopping, ensure thread is interrupted;
            // if not, ensure thread is not interrupted.  This
            // requires a recheck in second case to deal with
            // shutdownNow race while clearing interrupt
            // 如果线程池停止了，要确保线程是中断的，
            // 如果线程池不是停止状态，要确保线程没有被中断
            // 这里二次确认shutdownnow导致的停止
            if ((runStateAtLeast(ctl.get(), STOP) ||
                 (Thread.interrupted() &&
                  runStateAtLeast(ctl.get(), STOP))) &&
                !wt.isInterrupted())
                wt.interrupt();
            try {
                // 在执行任务之前的一些预先的逻辑，默认空实现，用于继承ThreadPoolExecutor的子类去实现
                beforeExecute(wt, task);
                Throwable thrown = null;
                try {
                    //真正执行任务
                    task.run();
                } catch (RuntimeException x) {
                    thrown = x; throw x;
                } catch (Error x) {
                    thrown = x; throw x;
                } catch (Throwable x) {
                    thrown = x; throw new Error(x);
                } finally {
                    //真正的任务执行之后的逻辑，默认空实现，用于继承ThreadPoolExecutor的子类去实现
                    afterExecute(task, thrown);
                }
            } finally {
                // 执行完毕置空，help GC
                task = null;
                //woker成功执行完毕的任务数量，是woker的一个计数器
                w.completedTasks++;
                //解锁
                w.unlock();
            }
        }
        completedAbruptly = false;
    } finally {
        // 处理worker的退出
        processWorkerExit(w, completedAbruptly);
    }
  }

  private void processWorkerExit(Worker w, boolean completedAbruptly) {
    // 如果woker处理任务完毕，那么将线程池线程数量减一
    if (completedAbruptly) // If abrupt, then workerCount wasn't adjusted
        decrementWorkerCount();
    // 得到排它锁
    final ReentrantLock mainLock = this.mainLock;
    //加锁
    mainLock.lock();
    try {
        // 线程池完成的总的任务数
        completedTaskCount += w.completedTasks;
        //线程从集合当中删除
        workers.remove(w);
    } finally {
      //解锁
        mainLock.unlock();
    }
    //尝试终止
    tryTerminate();
    //再次获取线程池状态
    int c = ctl.get();
    //状态是running或者shutdown状态，之后判断是否要创建新的线程去完成一些工作
    if (runStateLessThan(c, STOP)) {
        if (!completedAbruptly) {
            int min = allowCoreThreadTimeOut ? 0 : corePoolSize;
            if (min == 0 && ! workQueue.isEmpty())
                min = 1;
            if (workerCountOf(c) >= min)
                return; // replacement not needed
        }
        addWorker(null, false);
    }
  }
```

##### 关于线程池的关闭
```
将已经积存的任务执行完毕，不接受新的任务，重复执行这个方法没有任何副作用
public void shutdown() {
    // 获取线程池的排它锁
    final ReentrantLock mainLock = this.mainLock;
    //加锁
    mainLock.lock();
    try {
        //权限检查，是否当前线程可以进行一些操作
        checkShutdownAccess();
        //将线程池状态设置为shutdown状态
        advanceRunState(SHUTDOWN);
        // 中断空闲的worker线程
        interruptIdleWorkers();
        //回调函数，默认空实现
        onShutdown(); // hook for ScheduledThreadPoolExecutor
    } finally {
        mainLock.unlock();
    }

    tryTerminate();
}

//无限循环cas设置状态，runStateAtLeast意思是检查运行中的状态至少是targetState这个状态
private void advanceRunState(int targetState) {
    for (;;) {
        int c = ctl.get();
        if (runStateAtLeast(c, targetState) ||
            ctl.compareAndSet(c, ctlOf(targetState, workerCountOf(c))))
            break;
    }
}

private void interruptIdleWorkers() {
    interruptIdleWorkers(false);
}

private void interruptIdleWorkers(boolean onlyOne) {
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        for (Worker w : workers) {
            Thread t = w.thread;
            //工作线程没有被中断，并且能获取锁（woker执行run的时候是加锁的，这里能得到锁的都是空闲线程）
            if (!t.isInterrupted() && w.tryLock()) {
                try {
                   //执行中断
                    t.interrupt();
                } catch (SecurityException ignore) {
                } finally {
                    //解锁
                    w.unlock();
                }
            }
            if (onlyOne)
                break;
        }
    } finally {
        mainLock.unlock();
    }
}

final void tryTerminate() {
    for (;;) {
        // 对不能Terminate的线程池状态执行程序返回
        int c = ctl.get();
        if (isRunning(c) ||
            runStateAtLeast(c, TIDYING) ||
            (runStateOf(c) == SHUTDOWN && ! workQueue.isEmpty()))
            return;
        if (workerCountOf(c) != 0) { // Eligible to terminate
            interruptIdleWorkers(ONLY_ONE);
            return;
        }

        final ReentrantLock mainLock = this.mainLock;
        mainLock.lock();
        try {
            //当前是TIDYING状态才能置为terminate
            if (ctl.compareAndSet(c, ctlOf(TIDYING, 0))) {
                try {
                    terminated();
                } finally {
                    ctl.set(ctlOf(TERMINATED, 0));
                    // private final Condition termination = mainLock.newCondition();
                    // 尝试阻塞在调用终止线程池方法的线程，将他们唤醒，其中有一个方法是awaitTermination
                    // awaitTermination阻塞在termination上
                    termination.signalAll();
                }
                return;
            }
        } finally {
            mainLock.unlock();
        }
        // else retry on failed CAS
    }
  }

  //
  public List<Runnable> shutdownNow() {
    List<Runnable> tasks;
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        checkShutdownAccess();
        //状态置位stop
        advanceRunState(STOP);
        //中断所有线程，无论是否在执行
        interruptWorkers();
        //将阻塞队列里边的任务清空，丢弃，返回
        tasks = drainQueue();
    } finally {
        mainLock.unlock();
    }
    //
    tryTerminate();
    return tasks;
}

private void interruptWorkers() {
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
      //不区分是否空闲，直接循环工作线程集合，全部中断
        for (Worker w : workers)
            w.interruptIfStarted();
    } finally {
        mainLock.unlock();
    }
}

Blocks until all tasks have completed execution after a shutdown request, or the timeout occurs, or the current thread is interrupted, whichever happens first.
//当调用了shutdown请求后，阻塞等待所有的任务完成，或者超时发生返回，或者当前线程被中断返回
public boolean awaitTermination(long timeout, TimeUnit unit) throws InterruptedException {
    long nanos = unit.toNanos(timeout);
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        for (;;) {
            if (runStateAtLeast(ctl.get(), TERMINATED))
                return true;
            if (nanos <= 0)
                return false;
            //tryTerminate方法里边 termination.signalAll()会唤醒这里的wait
            nanos = termination.awaitNanos(nanos);
        }
    } finally {
        mainLock.unlock();
    }
}
```

##### 等待任务完成
ThreadPoolExecutor的submit方法通过newTaskFor方法返回一个FutureTask对象，提交任务到线程池之后调用FutureTask的get方法阻塞得到返回值，等待任务的完成，那么怎样才算是任务完成呢，其实state状态取值标志了任务是否完成。
```

/**
 * The run state of this task, initially NEW.  The run state
 * transitions to a terminal state only in methods set,
 * setException, and cancel.  During completion, state may take on
 * transient values of COMPLETING (while outcome is being set) or
 * INTERRUPTING (only while interrupting the runner to satisfy a
 * cancel(true)). Transitions from these intermediate to final
 * states use cheaper ordered/lazy writes because values are unique
 * and cannot be further modified.
 *
 * Possible state transitions:
 * NEW -> COMPLETING -> NORMAL
 * NEW -> COMPLETING -> EXCEPTIONAL
 * NEW -> CANCELLED
 * NEW -> INTERRUPTING -> INTERRUPTED
 */
private volatile int state;
private static final int NEW          = 0;
private static final int COMPLETING   = 1;
private static final int NORMAL       = 2;
private static final int EXCEPTIONAL  = 3;
private static final int CANCELLED    = 4;
private static final int INTERRUPTING = 5;
private static final int INTERRUPTED  = 6;

//FutureTask创建的时候state是NEW
public FutureTask(Runnable runnable, V result) {
    this.callable = Executors.callable(runnable, result);
    this.state = NEW;       // ensure visibility of callable
}
public V get() throws InterruptedException, ExecutionException {
    int s = state;
    //状态是NEW、COMPLETING执行等待
    if (s <= COMPLETING)
        s = awaitDone(false, 0L);
    //report返回任务执行的结果
    return report(s);
}

//run方法是对任务执行过程外层抽象逻辑的封装
public void run() {
  //状态校验
    if (state != NEW ||
        !UNSAFE.compareAndSwapObject(this, runnerOffset,
                                     null, Thread.currentThread()))
        return;
    try {
        Callable<V> c = callable;
        if (c != null && state == NEW) {
            V result;
            boolean ran;
            try {
                //任务执行
                result = c.call();
                ran = true;
            } catch (Throwable ex) {
                result = null;
                ran = false;
                //设置state为任务执行失败
                setException(ex);
            }
            if (ran)
            //设置状态为完成
                set(result);
        }
    } finally {
        // runner must be non-null until state is settled to
        // prevent concurrent calls to run()
        runner = null;
        // state must be re-read after nulling runner to prevent
        // leaked interrupts
        int s = state;
        if (s >= INTERRUPTING)
            handlePossibleCancellationInterrupt(s);
    }
}
```

**当我们把一个任务扔到了线程池当中，我们可以通过get方法获取任务的执行结果，倘若我们的线程池满了，会回调拒绝策略，而恰好我们拒绝策略是DiscardPolicy无声丢弃或者DiscardOldestPolicy，DiscardPolicy的rejectedExecution方法是一个空实现，被丢弃的任务(FutureTask)的默认状态是NEW，此时我们调用get方法等待任务返回结果，后果就是get方法永远也不会返回！**

因此建议使用带有超时时间的get方法。

#### forkjoin框架
ForkJoinPool的主要使用场景比如：
一批任务，有的任务很快执行完毕，有的任务会执行的很慢，这样导致了普通的线程池存在部分线程很忙，部分线程很闲，出现了分配不均衡的现象。
ForkJoinPool也是间接实现了ExecutorService
```
public class ForkJoinPool extends AbstractExecutorService {

}
```
forkjoin会对一个大任务进行不断的拆解，拆解的过程就是fork的过程，直到fork的粒度足够小，然后对这些小任务进行执行，最后将执行完毕的小人物的结果进行合并，即，join的过程，最后会合并成一个结果，这个结果就是大任务的结果：
![fork-join.png](fork-join.png)

##### 任务窃取
![fork-join-task-steal.png](fork-join-task-steal.png)

线程池每个线程都有一个任务队列，但是实际情况当中，有些任务比较简单，有些任务比较复杂，他们各自的执行时间长短不同，当一个线程执行完他自己的队列里边的任务的时候，会从其他线程的队列里边窃取任务执行，这里的队列都是双向的队列，两端都可以pop一个任务，当然这个要保证是线程安全的。

#### 源码介绍
ForkJoinPool构造器：
```
private ForkJoinPool(int parallelism,
                     ForkJoinWorkerThreadFactory factory,
                     UncaughtExceptionHandler handler,
                     int mode,
                     String workerNamePrefix) {
    this.workerNamePrefix = workerNamePrefix; //线程名字前缀
    this.factory = factory; //类似于线程池里边的线程工厂
    this.ueh = handler;
    this.config = (parallelism & SMASK) | mode;
    long np = (long)(-parallelism); // offset ctl counts
    this.ctl = ((np << AC_SHIFT) & AC_MASK) | ((np << TC_SHIFT) & TC_MASK);
}
```
ForkJoinWorkerThreadFactory创建的时候，会创建一个队列:
```
protected ForkJoinWorkerThread(ForkJoinPool pool) {
    // Use a placeholder until a useful name can be set in registerWorker
    super("aForkJoinWorkerThread");
    this.pool = pool;
    this.workQueue = pool.registerWorker(this);
}
```
这个队列就是线程对应的任务队列。

#####  ForkJoinTask
ForkJoinTask是forkjoinpool执行的任务的抽象。
```
public abstract class ForkJoinTask<V> implements Future<V>, Serializable {

}
```

RecursiveAction和RecursiveTask都实现了ForkJoinTask，RecursiveAction的compute没有返回值，RecursiveTask的compute方法是有返回值的。
在使用ForkJoinPool的时候，任务抽象的时候，如果任务有返回值，那么就是用RecursiveTask，否则使用RecursiveAction。

##### 实例
```
public class MyTest3 {
    public static void main(String[] args) {
        ForkJoinPool forkJoinPool = new ForkJoinPool();
        MyTask myTask = new MyTask(1,100);
        int  result = forkJoinPool.invoke(myTask);
        System.out.println(result);
        forkJoinPool.shutdown();
    }
}

class MyTask extends RecursiveTask<Integer>{

    private int limit = 4;
    private int firstIndex;
    private int lastIndex ;
    MyTask(int firstIndex,int lastIndex){
        this.firstIndex = firstIndex;
        this.lastIndex = lastIndex;
    }

    @Override
    protected Integer compute() {
        int gap = this.lastIndex - this.firstIndex;
        boolean flag = gap <= this.limit;
        int result = 0;
        if(flag){
            System.out.println(Thread.currentThread().getName());
            for(int i=this.firstIndex;i<=this.lastIndex;++i){
                result +=i;
            }
        }else {
            int middleIndex = (this.firstIndex + this.lastIndex)/2;
            MyTask leftTask = new MyTask(this.firstIndex,middleIndex);
            MyTask rightTask = new MyTask(middleIndex + 1,this.lastIndex);
            invokeAll(leftTask, rightTask);
            result = leftTask.join() + rightTask.join();
        }
        return result;
    }
}
```
打印结果:
ForkJoinPool-1-worker-1
ForkJoinPool-1-worker-1
ForkJoinPool-1-worker-1
ForkJoinPool-1-worker-4
ForkJoinPool-1-worker-3
ForkJoinPool-1-worker-3
ForkJoinPool-1-worker-1
ForkJoinPool-1-worker-7
ForkJoinPool-1-worker-7
ForkJoinPool-1-worker-3
ForkJoinPool-1-worker-3
ForkJoinPool-1-worker-2
ForkJoinPool-1-worker-2
ForkJoinPool-1-worker-5
ForkJoinPool-1-worker-5
ForkJoinPool-1-worker-4
ForkJoinPool-1-worker-4
ForkJoinPool-1-worker-4
ForkJoinPool-1-worker-5
ForkJoinPool-1-worker-2
ForkJoinPool-1-worker-2
ForkJoinPool-1-worker-3
ForkJoinPool-1-worker-3
ForkJoinPool-1-worker-7
ForkJoinPool-1-worker-0
ForkJoinPool-1-worker-0
ForkJoinPool-1-worker-6
ForkJoinPool-1-worker-1
ForkJoinPool-1-worker-0
ForkJoinPool-1-worker-3
ForkJoinPool-1-worker-2
ForkJoinPool-1-worker-4
5050
