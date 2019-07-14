---
title: netty源码分析(十六)Channel选择器工厂与轮询算法及注册底层实现
date: 2018-10-04 14:47:19
tags: Channel注册 轮询算法
categories: netty
---

上一节说到注册的入口，即
MultithreadEventLoopGroup:

```
    public ChannelFuture register(Channel channel) {
        return next().register(channel);
    }
```
注册channel第一步调用了next()方法，next()是MultithreadEventLoopGroup里边的:

```
    public EventLoop next() {
        return (EventLoop) super.next();
    }
```
到了父类MultithreadEventExecutorGroup：

```
    public EventExecutor next() {
        return chooser.next();
    }
```
这里出现了一个chooser：

```
private final EventExecutorChooserFactory.EventExecutorChooser chooser;
```
看一下他的结构,EventExecutorChooserFactory是一个工厂，生产各种Executor,，用EventExecutorChooserFactory的实现类DefaultEventExecutorChooserFactory看一下：

```
/**
 * Default implementation which uses simple round-robin to choose next {@link EventExecutor}.
 * 默认使用round-robin算法选择下一个实例的EventExecutor实现
 * round-robin：主要用在负载均衡方向，比如有5台机器，第一次分请求到了第一台机器，第二次到了第二台机器，第三次请求到了第三台请求，以此类推一直到第五台机器，然后第六次又到了第一台机器，这样一个轮流的调用，处理负载，这里的Executor数组也是使用这种方式，保证数组里边的EventExecutor被均衡调用。
 */
public final class DefaultEventExecutorChooserFactory implements EventExecutorChooserFactory {
    public EventExecutorChooser newChooser(EventExecutor[] executors) {
        if (isPowerOfTwo(executors.length)) {
            return new PowerOfTwoEventExecutorChooser(executors);
        } else {
            return new GenericEventExecutorChooser(executors);
        }
    }
```
从这里可以看到netty对性能的压榨，当有2的指数个executor的时候使用PowerOfTwoEventExecutorChooser性能会比非指数个的GenericEventExecutorChooser性能高一点,PowerOfTwoEventExecutorChooser和GenericEventExecutorChooser都是DefaultEventExecutorChooserFactory 的静态内部类，都有next()方法返回一个EventExecutor。以上是对chooser的创建的一个分析,
回到MultithreadEventExecutorGroup看一下对chooser的赋值：

```
//伪代码
public abstract class MultithreadEventExecutorGroup extends AbstractEventExecutorGroup {
    private final EventExecutor[] children;
    protected MultithreadEventExecutorGroup(int nThreads, Executor executor,
                                            EventExecutorChooserFactory chooserFactory, Object... args) {
       children = new EventExecutor[nThreads];
         for (int i = 0; i < nThreads; i ++) {
            children[i] = newChild(executor, args);
         }   
        chooser = chooserFactory.newChooser(children);  
    }
}
```
children的来源是newChild()方法：

```
    /**
     * Create a new EventExecutor which will later then accessible via the {@link #next()}  method. This method will be
     * called for each thread that will serve this {@link MultithreadEventExecutorGroup}.
     *
     创建一个EventExecutor ，稍后可以调用next()方法，这个next()方法被每个线程调用，这些线程 是服务MultithreadEventExecutorGroup的
     */
    protected abstract EventExecutor newChild(Executor executor, Object... args) throws Exception;
```
这个是EventExecutor 的创建，接下来我们看一下register方法，我们打了一个断点：
![这里写图片描述](20171105130718472.png)
之后debug进入register方法，我们进入的是SingleThreadEventLoop:
![这里写图片描述](20171105130647892.png)

```
/**
 * Abstract base class for {@link EventLoop}s that execute all its submitted tasks in a single thread.
 * EventLoop的基础抽象类，所有提交的任务都会在一个线程里边执行。
 *
 */
public abstract class SingleThreadEventLoop extends SingleThreadEventExecutor implements EventLoop {
...略
    public ChannelFuture register(Channel channel) {
        return register(new DefaultChannelPromise(channel, this));
    }
    ...略
}
```

DefaultChannelPromise是ChannelFuture的具体实现，	其持有Channel 和当前的EventLoop。

```
    public DefaultChannelPromise(Channel channel, EventExecutor executor) {
        super(executor);
        this.channel = channel;
    }
```
父类->
```
public class DefaultPromise<V> extends AbstractFuture<V> implements Promise<V> {
    public DefaultPromise(EventExecutor executor) {
        this.executor = checkNotNull(executor, "executor");
    }
}
```
  最后我们来到register方法：
```
public abstract class SingleThreadEventLoop extends SingleThreadEventExecutor implements EventLoop
    public ChannelFuture register(final ChannelPromise promise) {
        ObjectUtil.checkNotNull(promise, "promise");
        promise.channel().unsafe().register(this, promise);
        return promise;
    }
}
```
这个方法是注册逻辑的真正的入口了，出现了unsafe对象，下一节介绍。
