---
title: netty源码分析(二)Netty对Executor的实现机制源码分析
date: 2018-10-04 14:16:12
tags: Executor 实现机制
categories: netty
---

上一节说到NioEventLoopGroup 的初始化，到了他的父类MultithreadEventExecutorGroup的构造器：

```
    protected MultithreadEventExecutorGroup(int nThreads, Executor executor,
                                            EventExecutorChooserFactory chooserFactory, Object... args) {
...略
        if (executor == null) {
            executor = new ThreadPerTaskExecutor(newDefaultThreadFactory());
        }
...略
```
MultithreadEventExecutorGroup.newDefaultThreadFactory():
```
    protected ThreadFactory newDefaultThreadFactory() {
        return new DefaultThreadFactory(getClass());
    }
```
DefaultThreadFactory默认线程工厂类，继承了ThreadFactory
next(DefaultThreadFactory类):

```
    public DefaultThreadFactory(Class<?> poolType) {
        this(poolType, false, Thread.NORM_PRIORITY);//参数poolType为newDefaultThreadFactory的class，false表示线程不是后台线
        //程，Thread.NORM_PRIORITY，是正常的线程的优先级(三个优先级：MIN_PRIORITY = 1;NORM_PRIORITY = 5;MAX_PRIORITY = 10;)。
    }
```
next:

```
    public DefaultThreadFactory(Class<?> poolType, boolean daemon, int priority) {
        this(toPoolName(poolType), daemon, priority);
    }
```
toPoolName(poolType)的功能：比如我们给定当前newDefaultThreadFactory的poolType为io.netty.util.concurrent.newDefaultThreadFactory,那么经过toPoolName（）方法返回为newDefaultThreadFactory。
next：
加入了线程组参数。
```
    public DefaultThreadFactory(String poolName, boolean daemon, int priority) {
        this(poolName, daemon, priority, System.getSecurityManager() == null ?
                Thread.currentThread().getThreadGroup() : System.getSecurityManager().getThreadGroup());
    }
```
接着走：

```
    public DefaultThreadFactory(String poolName, boolean daemon, int priority, ThreadGroup threadGroup) {
        if (poolName == null) {
            throw new NullPointerException("poolName");
        }
        if (priority < Thread.MIN_PRIORITY || priority > Thread.MAX_PRIORITY) {
            throw new IllegalArgumentException(
                    "priority: " + priority + " (expected: Thread.MIN_PRIORITY <= priority <= Thread.MAX_PRIORITY)");
        }

        prefix = poolName + '-' + poolId.incrementAndGet() + '-';
        //poolId:private static final AtomicInteger poolId = new AtomicInteger();保证线程安全。
        this.daemon = daemon;//是否后台线程
        this.priority = priority;//优先级
        this.threadGroup = threadGroup;//线程组
    }
```
到现在只是指定了线程的一些属性的设置，返回到MultithreadEventExecutorGroup：
 executor = new ThreadPerTaskExecutor(newDefaultThreadFactory());

newDefaultThreadFactory继承了ThreadFactory:

```
将一个Runnable 做成一个Thread ，并且可以指定线程的name、daemon status ThreadGroup
public interface ThreadFactory {

    /**
     * Constructs a new {@code Thread}.  Implementations may also initialize
     * priority, name, daemon status, {@code ThreadGroup}, etc.
     *
     * @param r a runnable to be executed by new thread instance
     * @return constructed thread, or {@code null} if the request to
     *         create a thread is rejected
     *
     */
    Thread newThread(Runnable r);
}
```
我们创建完DefaultThreadFactory之后给了ThreadPerTaskExecutor:

```
ThreadPerTaskExecutor 使用了命令模式，execute执行的是命令。ThreadPerTaskExecutor的构造方法只是把DefaultThreadFactory传递进来。public final class ThreadPerTaskExecutor implements Executor {
    private final ThreadFactory threadFactory;

    public ThreadPerTaskExecutor(ThreadFactory threadFactory) {
        if (threadFactory == null) {
            throw new NullPointerException("threadFactory");
        }
        this.threadFactory = threadFactory;
    }

    @Override
    public void execute(Runnable command) {
        threadFactory.newThread(command).start();//ThreadFactory 执行命令，稍后我们到DefaultThreadFactory里边看看newThread
        //方法
    }
}
```
DefaultThreadFactory的newThread：
```
    @Override
    public Thread newThread(Runnable r) {
        Thread t = newThread(new DefaultRunnableDecorator(r), prefix + nextId.incrementAndGet());
        //将参数r包装为一个DefaultRunnableDecorator(实现了Runnable)
        try {
            if (t.isDaemon() != daemon) {
                t.setDaemon(daemon);
            }

            if (t.getPriority() != priority) {
                t.setPriority(priority);
            }
        } catch (Exception ignored) {
            // Doesn't matter even if failed to set.
        }
        return t;//返回Thread
    }
```
切到DefaultRunnableDecorator:

```
    private static final class DefaultRunnableDecorator implements Runnable {

        private final Runnable r;

        DefaultRunnableDecorator(Runnable r) {
            this.r = r;
        }

        @Override
        public void run() {
            try {
                r.run();//注意！！！！直接调用的命令的run方法，并没有创建线程，也就是说
                //threadFactory.newThread(command).start()只有一个线程。
            } finally {
                FastThreadLocal.removeAll();
            }
        }
    }
```
这种调用方式和jdk内置的Executor（ThreadPerTaskExecutor implements Executor）如出一撤,DefaultRunnableDecorator 的run（通过Thread的start调用）直接调用了Runnable 的run方法，我们去看一些Executor的文档：

```
/**
 * An object that executes submitted {@link Runnable} tasks. This
 * interface provides a way of decoupling task submission from the
 * mechanics of how each task will be run, including details of thread
 * use, scheduling, etc.  An {@code Executor} is normally used
 * instead of explicitly creating threads. For example, rather than
 * invoking {@code new Thread(new(RunnableTask())).start()} for each
 * of a set of tasks, you might use:
 *大体意思是将任务（线程）的提交和线程的细节解耦，例如new Thread(new(RunnableTask())).start()这种方式被得到替换。
 * <pre>使用方式
 * Executor executor = <em>anExecutor</em>;
 * executor.execute(new RunnableTask1());
 * executor.execute(new RunnableTask2());
 * ...
 * </pre>
 *
 * However, the {@code Executor} interface does not strictly
 * require that execution be asynchronous. In the simplest case, an
 * executor can run the submitted task immediately in the caller's
 * thread:
 *当然Executor不会严格的要求执行是异步的，因为在有些情况会被调用线程直接执行任务的run方法。
 *  <pre> {@code
 * class DirectExecutor implements Executor {
 *   public void execute(Runnable r) {
 *     r.run();
 *   }
 * }}</pre>
 *
 * More typically, tasks are executed in some thread other
 * than the caller's thread.  The executor below spawns a new thread
 * for each task.
 *典型的方式是将任务依附在Thread上执行，是一个线程。
 *  <pre> {@code
 * class ThreadPerTaskExecutor implements Executor {
 *   public void execute(Runnable r) {
 *     new Thread(r).start();
 *   }
 * }}</pre>
 *
 * Many {@code Executor} implementations impose some sort of
 * limitation on how and when tasks are scheduled.  The executor below
 * serializes the submission of tasks to a second executor,
 * illustrating a composite executor.
 *有的时候任务会被串行的被多个tasks  执行，A->B->C->D，是一个流水的过程。
 *  <pre> {@code
 * class SerialExecutor implements Executor {
 *   final Queue<Runnable> tasks = new ArrayDeque<Runnable>();
 *   final Executor executor;
 *   Runnable active;
 *
 *   SerialExecutor(Executor executor) {
 *     this.executor = executor;
 *   }
 *
 *   public synchronized void execute(final Runnable r) {
 *     tasks.offer(new Runnable() {
 *       public void run() {
 *         try {
 *           r.run();
 *         } finally {
 *           scheduleNext();//转到下一个task执行。
 *         }
 *       }
 *     });
 *     if (active == null) {
 *       scheduleNext();
 *     }
 *   }
 *
 *   protected synchronized void scheduleNext() {
 *     if ((active = tasks.poll()) != null) {
 *       executor.execute(active);
 *     }
 *   }
 * }}</pre>
 *
 * The {@code Executor} implementations provided in this package
 * implement {@link ExecutorService}, which is a more extensive
 * interface.  The {@link ThreadPoolExecutor} class provides an
 * extensible thread pool implementation. The {@link Executors} class
 * provides convenient factory methods for these Executors.
 *
 * <p>Memory consistency effects: Actions in a thread prior to
 * submitting a {@code Runnable} object to an {@code Executor}
 * <a href="package-summary.html#MemoryVisibility"><i>happen-before</i></a>
 * its execution begins, perhaps in another thread.
 *
 * @since 1.5
 * @author Doug Lea
 */
```
