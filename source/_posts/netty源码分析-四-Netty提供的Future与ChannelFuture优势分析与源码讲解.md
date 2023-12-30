---
title: netty源码分析(四)Netty提供的Future与ChannelFuture优势分析与源码讲解
date: 2018-10-04 14:20:15
tags: Future ChannelFuture
categories: netty
---

上一节我们讲到netty启动服务类AbstractBootstrap的doBind的方法：

<!-- more -->
```
    private ChannelFuture doBind(final SocketAddress localAddress) {
        final ChannelFuture regFuture = initAndRegister();
        ...略
    }    
```
这里边有一个重要的类ChannelFuture ：
![这里写图片描述](2018/10/04/netty源码分析-四-Netty提供的Future与ChannelFuture优势分析与源码讲解/20170916155223422.png)

```
最红他们的接口会来到jdk的Future接口，Future代表了一个异步处理的结果。
/**
 * A {@code Future} represents the result of an asynchronous
 * computation.  Methods are provided to check if the computation is
 * complete, to wait for its completion, and to retrieve the result of
 * the computation.  The result can only be retrieved using method
 * {@code get} when the computation has completed, blocking if
 * necessary until it is ready.  Cancellation is performed by the
 * {@code cancel} method.  Additional methods are provided to
 * determine if the task completed normally or was cancelled. Once a
 * computation has completed, the computation cannot be cancelled.
 * If you would like to use a {@code Future} for the sake
 * of cancellability but not provide a usable result, you can
 * declare types of the form {@code Future<?>} and
 * return {@code null} as a result of the underlying task.
 译：
一个Future代表一个一步计算的结果，它提供了一些方法检查是否计算完毕，比如等待计算完毕，获取计算结果的方法。
当计算完毕之后只能通过get方法获取结果，或者一直阻塞等待计算的完成。取消操作通过cancle方法来取消，
另外还提供了检测是正常的完成还是被取消的方法，当一个计算完成后，不能进行取消操作。如果你想用Future实现取消，
但是却没有一个可用的结果，你可以声明很多Future的类型，然后返回一个null的结果给当前任务。

 * <p>
 * <b>Sample Usage</b> (Note that the following classes are all
 * made-up.)
 * <pre> {@code
 * interface ArchiveSearcher { String search(String target); }
 * class App {
 *   ExecutorService executor = ...//线程池
 *   ArchiveSearcher searcher = ...//搜索接口
 *   void showSearch(final String target)
 *       throws InterruptedException {
 *     Future<String> future
 *       = executor.submit(new Callable<String>() {//创建一个Callable给线程池，Callable是有返回结果的。
 *         public String call() {
 *             return searcher.search(target);
 *         }});
 *     displayOtherThings(); // do other things while searching  中间可以做其他的事情，submit不会阻塞。
 *     try {
 *       displayText(future.get()); // use future  使用future的get拿到线程的处理结果，此处是阻塞的方式。
 *     } catch (ExecutionException ex) { cleanup(); return; }
 *   }
 * }}</pre>
 *
 * The {@link FutureTask} class is an implementation of {@code Future} that
 * implements {@code Runnable}, and so may be executed by an {@code Executor}.
 * FutureTask是Future的实现类，并且实现了Runnable接口，因此可以被Executor执行。
 * For example, the above construction with {@code submit} could be replaced by:
 * 之前的方式可以被下边的FutureTask的方式替换。
 *  <pre> {@code
 * FutureTask<String> future =
 *   new FutureTask<String>(new Callable<String>() {
 *     public String call() {
 *       return searcher.search(target);
 *   }});
 * executor.execute(future);}</pre>
 *
 * <p>Memory consistency effects: Actions taken by the asynchronous computation
 * <a href="package-summary.html#MemoryVisibility"> <i>happen-before</i></a>
 * actions following the corresponding {@code Future.get()} in another thread.
 * 内存一致性影响：异步计算的动作的完成，发生在Future.get()之前。
 * @see FutureTask
 * @see Executor
 * @since 1.5
 * @author Doug Lea
 * @param <V> The result type returned by this Future's {@code get} method
 */
 public interface Future<V> {
	 boolean cancel(boolean mayInterruptIfRunning);
	 boolean isCancelled();
	 boolean isDone();
	 V get() throws InterruptedException, ExecutionException;
	 V get(long timeout, TimeUnit unit) throws InterruptedException, ExecutionException, TimeoutException;
     V get(long timeout, TimeUnit unit) throws InterruptedException, ExecutionException, TimeoutException;}
```
io.netty.util.concurrent.Future对java.util.concurrent.Future进行了扩展：

```
public interface Future<V> extends java.util.concurrent.Future<V> {
    boolean isSuccess();//是否计算成功
    boolean isCancellable();//可以被取消
    Throwable cause();//原因
    Future<V> addListener(GenericFutureListener<? extends Future<? super V>> listener);//添加一个监听器
    Future<V> addListeners(GenericFutureListener<? extends Future<? super V>>... listeners);//添加多个监听器
    Future<V> removeListener(GenericFutureListener<? extends Future<? super V>> listener);//移除一个监听器
    Future<V> removeListeners(GenericFutureListener<? extends Future<? super V>>... listeners);//移除多个监听器
    Future<V> sync() throws InterruptedException;//等待结果返回
    Future<V> syncUninterruptibly();//等待结果返回，不能被中断
    Future<V> await() throws InterruptedException;//等待结果返回
    Future<V> awaitUninterruptibly();//等待结果返回，不能被中断
    boolean await(long timeout, TimeUnit unit) throws InterruptedException;
    boolean await(long timeoutMillis) throws InterruptedException;
    boolean awaitUninterruptibly(long timeout, TimeUnit unit);
    boolean awaitUninterruptibly(long timeoutMillis);
    V getNow();//立刻返回，没有计算完毕，返回null，需要配合isDone()方法判定是不是已经完成，因为runnable没有返回结果，
    //而callable有返回结果
    boolean cancel(boolean mayInterruptIfRunning);  //取消                                                          
}
```

提到一个监听器GenericFutureListener的封装，一碰到XXXlistener，都会用到监听器模式：

```
/**
 * Listens to the result of a {@link Future}.  The result of the asynchronous operation is notified once this listener
 * is added by calling {@link Future#addListener(GenericFutureListener)}.
 * 监听Future的结果，当一个监听器被注册后，结果的异步操作会被注册的监听器监听。
 */
public interface GenericFutureListener<F extends Future<?>> extends EventListener {

    /**
     * Invoked when the operation associated with the {@link Future} has been completed.
     *
     * 和Future的完成计算相关的事件，次方法会被调用。
     */
    void operationComplete(F future) throws Exception;
}
```
监听器对Future的扩展起到了很灵活的作用，当某个计算完毕，会触发相应的时间，得到Future的结果，因为jdk的get方法我们知道什么时候去掉，调早了需要等待，调晚了浪费了一段时间，还有isDone里边有2种情况，无法区分到底是正常的io完毕返回的true还是被取消之后返回的true，所有到了netty的Future里边加了一个isSuccess()方法，只有正常的io处理结束isSuccess()才返回true。

接下来我们会走一下ChannelFuture的源码的doc：

```

/**
 * The result of an asynchronous {@link Channel} I/O operation.
 * Channel的异步io操作的结果。
 * <p>
 * All I/O operations in Netty are asynchronous.  It means any I/O calls will
 * return immediately with no guarantee that the requested I/O operation has
 * been completed at the end of the call.  Instead, you will be returned with
 * a {@link ChannelFuture} instance which gives you the information about the
 * result or status of the I/O operation.
 * netty中所有的i/o都是异步的，意味着很多i/o操作被调用过后会立刻返回，并且不能保证i/o请求操作被调用后计算已经完毕，
 * 替代它的是返回一个当前i/o操作状态和结果信息的ChannelFuture实例。
 * <p>
 * A {@link ChannelFuture} is either <em>uncompleted</em> or <em>completed</em>.
 * When an I/O operation begins, a new future object is created.  The new future
 * is uncompleted initially - it is neither succeeded, failed, nor cancelled
 * because the I/O operation is not finished yet.  If the I/O operation is
 * finished either successfully, with failure, or by cancellation, the future is
 * marked as completed with more specific information, such as the cause of the
 * failure.  Please note that even failure and cancellation belong to the
 * completed state.
 * 一个ChannelFuture要么是完成的，要么是未完成的。当一个i/o操作开始的时候，会创建一个future 对象，future 初始化的时候是为完成的状态，
 * 既不是是成功的，或者失败的，也不是取消的，因为i/o操作还没有完成，如果一个i/o不管是成功，还是失败，或者被取消，future 会被标记一些特殊
 * 的信息，比如失败的原因，请注意即使是失败和取消也属于完成状态。
 * <pre>
 *                                      +---------------------------+
 *                                      | Completed successfully    |
 *                                      +---------------------------+
 *                                 +---->      isDone() = true      |
 * +--------------------------+    |    |   isSuccess() = true      |
 * |        Uncompleted       |    |    +===========================+
 * +--------------------------+    |    | Completed with failure    |
 * |      isDone() = false    |    |    +---------------------------+
 * |   isSuccess() = false    |----+---->      isDone() = true      |
 * | isCancelled() = false    |    |    |       cause() = non-null  |
 * |       cause() = null     |    |    +===========================+
 * +--------------------------+    |    | Completed by cancellation |
 *                                 |    +---------------------------+
 *                                 +---->      isDone() = true      |
 *                                      | isCancelled() = true      |
 *                                      +---------------------------+
 * </pre>
 *
 * Various methods are provided to let you check if the I/O operation has been
 * completed, wait for the completion, and retrieve the result of the I/O
 * operation. It also allows you to add {@link ChannelFutureListener}s so you
 * can get notified when the I/O operation is completed.
 * ChannelFuture提供了很多方法让你检查i/o操作是否完成、等待完成、获取i/o操作的结果，他也允许你添加ChannelFutureListener
 * 因此可以在i/o操作完成的时候被通知。
 * <h3>Prefer {@link #addListener(GenericFutureListener)} to {@link #await()}</h3>
 * 建议使用addListener(GenericFutureListener)，而不使用await()
 * It is recommended to prefer {@link #addListener(GenericFutureListener)} to
 * {@link #await()} wherever possible to get notified when an I/O operation is
 * done and to do any follow-up tasks.
 * 推荐优先使用addListener(GenericFutureListener)，不是await()在可能的情况下，这样就能在i/o操作完成的时候收到通知，并且可以去做
 * 后续的任务处理。
 * <p>
 * {@link #addListener(GenericFutureListener)} is non-blocking.  It simply adds
 * the specified {@link ChannelFutureListener} to the {@link ChannelFuture}, and
 * I/O thread will notify the listeners when the I/O operation associated with
 * the future is done.  {@link ChannelFutureListener} yields the best
 * performance and resource utilization because it does not block at all, but
 * it could be tricky to implement a sequential logic if you are not used to
 * event-driven programming.
 * addListener(GenericFutureListener)本身是非阻塞的，他会添加一个指定的ChannelFutureListener到ChannelFuture
 * 并且i/o线程在完成对应的操作将会通知监听器，ChannelFutureListener也会提供最好的性能和资源利用率，因为他永远不会阻塞，但是如果
 * 不是基于事件编程，他可能在顺序逻辑存在棘手的问题。
 * <p>
 * By contrast, {@link #await()} is a blocking operation.  Once called, the
 * caller thread blocks until the operation is done.  It is easier to implement
 * a sequential logic with {@link #await()}, but the caller thread blocks
 * unnecessarily until the I/O operation is done and there's relatively
 * expensive cost of inter-thread notification.  Moreover, there's a chance of
 * dead lock in a particular circumstance, which is described below.
 *相反的，await()是一个阻塞的操作，一旦被调用，调用者线程在操作完成之前是阻塞的，实现顺序的逻辑比较容易，但是他让调用者线程等待是没有必要
 * 的，会造成资源的消耗，更多可能性会造成死锁，接下来会介绍。
 * <h3>Do not call {@link #await()} inside {@link ChannelHandler}</h3>
 * 不要再ChannelHandler里边调用await()方法
 * <p>
 * The event handler methods in {@link ChannelHandler} are usually called by
 * an I/O thread.  If {@link #await()} is called by an event handler
 * method, which is called by the I/O thread, the I/O operation it is waiting
 * for might never complete because {@link #await()} can block the I/O
 * operation it is waiting for, which is a dead lock.
 * ChannelHandler里边的时间处理器通常会被i/o线程调用，如果await()被一个时间处理方法调用，并且是一个i/o线程，那么这个i/o操作将永远不会
 * 完成，因为await()是会阻塞i/o操作，这是一个死锁。
 * <pre>
 * // BAD - NEVER DO THIS 不推荐的使用方式
 * {@code @Override}
 * public void channelRead({@link ChannelHandlerContext} ctx, Object msg) {
 *     {@link ChannelFuture} future = ctx.channel().close();
 *     future.awaitUninterruptibly();//不要使用await的 方式
 *     // Perform post-closure operation
 *     // ...
 * }
 *
 * // GOOD
 * {@code @Override} //推荐使用的方式
 * public void channelRead({@link ChannelHandlerContext} ctx, Object msg) {
 *     {@link ChannelFuture} future = ctx.channel().close();
 *     future.addListener(new {@link ChannelFutureListener}() {//使用时间的方式
 *         public void operationComplete({@link ChannelFuture} future) {
 *             // Perform post-closure operation
 *             // ...
 *         }
 *     });
 * }
 * </pre>
 * <p>
 * In spite of the disadvantages mentioned above, there are certainly the cases
 * where it is more convenient to call {@link #await()}. In such a case, please
 * make sure you do not call {@link #await()} in an I/O thread.  Otherwise,
 * {@link BlockingOperationException} will be raised to prevent a dead lock.
 * 尽管出现了上面提到的这些缺陷，但是在某些情况下更方便，在这种情况下，请确保不要再i/o线程里边调用await()方法，
 * 否则会出现BlockingOperationException异常，导致死锁。
 * <h3>Do not confuse I/O timeout and await timeout</h3>
 *不要将i/o超时和等待超时混淆。
 * The timeout value you specify with {@link #await(long)},
 * {@link #await(long, TimeUnit)}, {@link #awaitUninterruptibly(long)}, or
 * {@link #awaitUninterruptibly(long, TimeUnit)} are not related with I/O
 * timeout at all.  If an I/O operation times out, the future will be marked as
 * 'completed with failure,' as depicted in the diagram above.  For example,
 * connect timeout should be configured via a transport-specific option:
 * 使用await(long)、await(long, TimeUnit)、awaitUninterruptibly(long)、awaitUninterruptibly(long, TimeUnit)设置的超时时间
 * 和i/o超时没有任何关系，如果一个i/o操作超时，future 将被标记为失败的完成状态，比如连接超时通过一些选项来配置：
 * <pre>
 * // BAD - NEVER DO THIS //不推荐的方式
 * {@link Bootstrap} b = ...;
 * {@link ChannelFuture} f = b.connect(...);
 * f.awaitUninterruptibly(10, TimeUnit.SECONDS);//不真正确的等待超时
 * if (f.isCancelled()) {
 *     // Connection attempt cancelled by user
 * } else if (!f.isSuccess()) {
 *     // You might get a NullPointerException here because the future//不能确保future 的完成。
 *     // might not be completed yet.
 *     f.cause().printStackTrace();
 * } else {
 *     // Connection established successfully
 * }
 *
 * // GOOD//推荐的方式
 * {@link Bootstrap} b = ...;
 * // Configure the connect timeout option.
 * <b>b.option({@link ChannelOption}.CONNECT_TIMEOUT_MILLIS, 10000);</b>//配置连接超时
 * {@link ChannelFuture} f = b.connect(...);
 * f.awaitUninterruptibly();
 *
 * // Now we are sure the future is completed.//确保future 一定是完成了。
 * assert f.isDone();
 *
 * if (f.isCancelled()) {
 *     // Connection attempt cancelled by user
 * } else if (!f.isSuccess()) {
 *     f.cause().printStackTrace();
 * } else {
 *     // Connection established successfully
 * }
 * </pre>
 */
public interface ChannelFuture extends Future<Void> {

    /**
     * Returns a channel where the I/O operation associated with this
     * future takes place.
	 * 返回和当前future 相关联的i/o操作的channel
     */
    Channel channel();
    ChannelFuture addListener(GenericFutureListener<? extends Future<? super Void>> listener);
    ChannelFuture addListeners(GenericFutureListener<? extends Future<? super Void>>... listeners);
    ChannelFuture removeListener(GenericFutureListener<? extends Future<? super Void>> listener);
    ChannelFuture removeListeners(GenericFutureListener<? extends Future<? super Void>>... listeners);
    ChannelFuture sync() throws InterruptedException;
    ChannelFuture syncUninterruptibly();
    ChannelFuture await() throws InterruptedException;
    ChannelFuture awaitUninterruptibly();
}
```
下一接介绍initAndRegister( )方法。
