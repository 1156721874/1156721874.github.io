---
title: concurrency(14)CompletionService
date: 2020-06-30 13:36:00
tags: [CompletionService]
categories: concurrency
---

### 需求
我们在向线程池提交任务的时候，提交的顺序是ABCD，提交之后任务执行完毕的时间都是不确定的，比如执行完毕的顺序是CBAD，然后实际开发中有这样的需求是，只要得到第一个任务的执行结果，其他任务的执行结果就不考虑了，试想，如果没有jdk的实现的api的话，我们也可以操作，增加一个队列，让任务执行完毕之后，将任务的执行结果放入到队列的头部，第二执行完毕的任务的执行结果放在结果队列的第二个位置，以此类推，队列头部的就是第一个任务执行的结果。

### CompletionService的实现
A service that decouples the production of new asynchronous tasks from the consumption of the results of completed tasks.
Producers submit tasks for execution. Consumers take completed tasks and process their results in the order they complete.
A CompletionService can for example be used to manage asynchronous I/O, in which tasks that perform reads are submitted in one part of a program or system, and then acted upon in a different part of the program when the reads complete, possibly in a different order than they were requested.
Typically, a CompletionService relies on a separate Executor to actually execute the tasks, in which case the CompletionService only manages an internal completion queue. The ExecutorCompletionService class provides an implementation of this approach.
将异步任务的生产和任务结果的完成解耦。
生产者提交对任务的执行，消费者按照任务的执行完毕的时间顺序对结果进行处理。
CompletionService 可以用于管理异步的io，读取的任务会作为系统或者程序的一部分进行提交，当读取完成的时候可以在程序的不同部分去执行，他们的执行顺序和请求顺序是不一样的。
典型的情况，一个CompletionService依赖独立的线程池去执行任务。这种情况，CompletionService仅仅管理一个内部的任务完成队列，ExecutorCompletionService类提供了一个这种放是的实现。

java.util.concurrent.CompletionService
java.util.concurrent.CompletionService#submit(java.util.concurrent.Callable<V>)
java.util.concurrent.CompletionService#submit(java.lang.Runnable, V)
java.util.concurrent.CompletionService#take 从完成队列得到并且移除一个队头的数据，如果不存在就一直等待
java.util.concurrent.CompletionService#poll() 和take类似，不同的是poll如果元素不存在就会返回空。
java.util.concurrent.CompletionService#poll(long, java.util.concurrent.TimeUnit)  如果元素为空，会等待一段指定的时间

#### ExecutorCompletionService
ExecutorCompletionService在已有线程池基础上加了一个任务完成队列completionQueue。
```
public class ExecutorCompletionService<V> implements CompletionService<V> {
    private final Executor executor;
    private final AbstractExecutorService aes;
    private final BlockingQueue<Future<V>> completionQueue;
    ...
  }
```
使用ExecutorCompletionService前需要向构造一个线程池,ExecutorCompletionService提交的任务最终提交给线程池:

#### 实例
```
public class MyTest4 {
    public static void main(String[] args) throws InterruptedException, ExecutionException {
        ExecutorService executorService = new ThreadPoolExecutor(4,
                10, 10, TimeUnit.SECONDS,
                new LinkedBlockingDeque<>(20), new ThreadPoolExecutor.AbortPolicy());
        CompletionService completionService = new ExecutorCompletionService(executorService);
        IntStream.range(0, 10).forEach(i -> {
            completionService.submit(() -> {
                Thread.sleep((long) (Math.random() * 1000));
                System.out.println(Thread.currentThread().getName());
                return i * i;
            });
        });
        System.out.println("==========================================");
        for (int i = 0; i < 10; ++i) {
            System.out.println(completionService.take().get());
        }
        executorService.shutdown();
    }
}
```
pool-1-thread-1
0
pool-1-thread-2
1
pool-1-thread-3
4
pool-1-thread-4
9
pool-1-thread-1
16
pool-1-thread-3
36
pool-1-thread-1
64
pool-1-thread-2
25
pool-1-thread-4
49
pool-1-thread-3
81

可以看到任务的提交顺序和结果的获取顺序是不一样的。
