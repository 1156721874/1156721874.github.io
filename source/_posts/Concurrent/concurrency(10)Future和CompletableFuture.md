---
title: concurrency(10)Future和CompletableFuture
date: 2020-05-05 16:13:45
tags: [Future CompletableFuture]
categories: concurrency
---

### Future

<!-- more -->
A Future represents the result of an asynchronous computation. Methods are provided to check if the computation is complete, to wait for its completion, and to retrieve the result of the computation. The result can only be retrieved using method get when the computation has completed, blocking if necessary until it is ready. Cancellation is performed by the cancel method. Additional methods are provided to determine if the task completed normally or was cancelled. Once a computation has completed, the computation cannot be cancelled. If you would like to use a Future for the sake of cancellability but not provide a usable result, you can declare types of the form Future<?> and return null as a result of the underlying task.
Sample Usage (Note that the following classes are all made-up.)

<!-- more -->

```java
interface ArchiveSearcher { String search(String target); }
class App {
 ExecutorService executor = ...
 ArchiveSearcher searcher = ...
 void showSearch(final String target)
     throws InterruptedException {
   Future<String> future
     = executor.submit(new Callable<String>() {
       public String call() {
           return searcher.search(target);
       }});
   displayOtherThings(); // do other things while searching
   try {
     displayText(future.get()); // use future
   } catch (ExecutionException ex) { cleanup(); return; }
 }
}
```

The FutureTask class is an implementation of Future that implements Runnable, and so may be executed by an Executor. For example, the above construction with submit could be replaced by:

```java
FutureTask<String> future = new FutureTask<String>(new Callable<String>() {
   public String call() {
       return searcher.search(target);
}});
```
executor.execute(future);
Memory consistency effects: Actions taken by the asynchronous computation happen-before actions following the corresponding Future.get() in another thread.
代表一个异步计算的结果，提供的方法用来检查计算是否完成，等待计算完成，以及返回计算的结果，当计算完毕的时候只能通过get方法返回，如果没有计算完成那么get方法将会一直阻塞，cancel用来取消操作，此外提供了其他的方法用来检查是正常完成还是取消完成，如果一个 计算已经完成了，那么这个计算不能再进行取消操作，如果一个计算只是为了取消，而不想得到计算结果，你可以声明为Future<?>，那么底层执行任务就会返回一个null的计算结果。

```java
//取消
 boolean cancel(boolean mayInterruptIfRunning);
 //是否被取消
 boolean isCancelled();
 //是否完成
 boolean isDone();
 //返回异步任务的计算结果，
 //Waits if necessary for the computation to complete, and then retrieves its result.
 //如果任务计算完成，直接返回结果，否则，get会阻塞等待计算完成，然后返回结果
 V get() throws InterruptedException, ExecutionException;
 //返回异步任务的执行结果，带超时参数，如果超时，那么抛出TimeoutException异常
 V get(long timeout, TimeUnit unit)  throws InterruptedException, ExecutionException, TimeoutException;
```

### FutureTask

#### 正常的使用

```java
public class MyTest1 {
    public static void main(String[] args) {
        Callable<Integer> callable =  () -> {
            System.out.println("pre execute");
            int randomNumber = new Random().nextInt(500);
            System.out.println("post execute");
            return randomNumber;
        };

        FutureTask<Integer> futureTask = new FutureTask<>(callable);
        new Thread(futureTask).start();
        System.out.println("thread has started");
        try {
            System.out.println(futureTask.get());
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
    }
}
```
输出：
thread has started
pre execute
post execute
282

#### get方法阻塞一段时间

```java
public class MyTest1 {
    public static void main(String[] args) {
        Callable<Integer> callable =  () -> {
            System.out.println("pre execute");
            Thread.sleep(5000);
            int randomNumber = new Random().nextInt(500);
            System.out.println("post execute");
            return randomNumber;
        };

        FutureTask<Integer> futureTask = new FutureTask<>(callable);
        new Thread(futureTask).start();
        System.out.println("thread has started");
        try {
            Thread.sleep(2000);
            System.out.println(futureTask.get());
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
    }
}
```

输出：
thread has started
pre execute
post execute
218
实际运行的时候会在get方法阻塞等待一段时间

#### get等待超时

```java
public class MyTest1 {
    public static void main(String[] args) {
        Callable<Integer> callable =  () -> {
            System.out.println("pre execute");
            Thread.sleep(5000);
            int randomNumber = new Random().nextInt(500);
            System.out.println("post execute");
            return randomNumber;
        };

        FutureTask<Integer> futureTask = new FutureTask<>(callable);
        new Thread(futureTask).start();
        System.out.println("thread has started");
        try {
            Thread.sleep(2000);
            System.out.println(futureTask.get(1, TimeUnit.MILLISECONDS));
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
    }
}
```

输出：
thread has started
pre execute
java.util.concurrent.TimeoutException
	at java.util.concurrent.FutureTask.get(FutureTask.java:205)
	at com.twodragonlake.concurrency7.MyTest1.main(MyTest1.java:21)
post execute

即超时会抛出异常

### CompletableFuture

Future的不足就是get方法会阻塞。CompletableFuture解决了这个问题。

```java
//实现了Future，所以具备Future的功能和特点，CompletionStage是说明：
//A stage of a possibly asynchronous computation, that performs an action or computes a value when another //////////CompletionStage completes.
// 异步计算的一个阶段，当一个阶段完成时，代表一个动作或者一个计算的值
public class CompletableFuture<T> implements Future<T>, CompletionStage<T> {

}
```
CompletableFuture doc：
A Future that may be explicitly completed (setting its value and status), and may be used as a CompletionStage, supporting dependent functions and actions that trigger upon its completion.
When two or more threads attempt to complete, completeExceptionally, or cancel a CompletableFuture, only one of them succeeds.
一个可以被显式设置为完成的Future, 除了是一个Future以外，可以被当做一个CompletionStage去使用，依赖函数和动作的完成触发。
当有2个或以上的线程去完成，完成异常，取消CompletableFuture的时候，只有一个会成功。

#### 实例1：

```java
public class MyTest2 {
    public static void main(String[] args) {
        String result = CompletableFuture.supplyAsync(()->"hello" )
                .thenApplyAsync((x) -> x + "world").join();
        System.out.println(result);
    }
}
```
输出：
helloworld

#### 实例2：

supplyAsync需要返回执行结果，runAsync不需要返回结果。

```java
CompletableFuture.supplyAsync(() -> "hello")
        .thenAccept(value -> System.out.println("welcome" + value));
```
输出： welcomehello
thenAccept不返回结果，直接把结果处理掉

#### 实例3

```java
String result2 = CompletableFuture.supplyAsync(() ->{
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            return "hello";
        }).thenCombine(CompletableFuture.supplyAsync(() ->{
            try {
                Thread.sleep(2000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            return "world";
        }),(s1,s2) -> s1+" "+s2).join();
        System.out.println(result2);
```
输出：
hello world

thenCombine是对两个 CompletableFuture.supplyAsync执行结果的合并，CompletableFuture.supplyAsync都是异步的，他们之间可以并行执行。

#### 实例4

```java
  CompletableFuture<Void> completableFuture = CompletableFuture.runAsync(() -> {
      try {
          TimeUnit.MILLISECONDS.sleep(2000);
      } catch (InterruptedException e) {
          e.printStackTrace();
      }
      System.out.println("task finish");
  });

  completableFuture.whenComplete((s1,s2) ->{
      System.out.println("执行完成");
  });
  System.out.println("主线程执行完毕");
  TimeUnit.MILLISECONDS.sleep(7000);
```
输出：
主线程执行完
task finish
执行完成

completableFuture.whenComplete不会阻塞，会继续往下执行，这个解决了Future的get方法阻塞弊病。
