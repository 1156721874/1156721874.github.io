---
title: netty源码分析(一)EventLoopGroup
date: 2018-10-04 14:12:37
tags: nio socket netty源码分析
categories: netty
---

首先我们使用netty建立一个服务端和客户端，功能是相互之间发消息，[代码](https://github.com/1156721874/netty_lecture/tree/master/src/main/java/com/ceaser/netty/secondexample)
我们把服务端的主要代码贴出来：
<!-- more -->

```
package com.ceaser.netty.secondexample;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.nio.NioServerSocketChannel;

/**
 * Created by Administrator on 2017/5/20.
 * 服务器和客户端互发程序
 */
public class MyServer {

    public static void main(String[] args) throws InterruptedException {
        EventLoopGroup bossGroup = new NioEventLoopGroup();//第一步建立bossGroup 接受数据然后转发给workerGroup ，是一个死循环
        EventLoopGroup workerGroup = new NioEventLoopGroup();//第二部 workerGroup 完成实际数据的处理，也是一个死循环
        try{
            ServerBootstrap serverBootstrap = new ServerBootstrap();//第三步。启动bossGroup和workerGroup
            serverBootstrap.group(bossGroup,workerGroup).channel(NioServerSocketChannel.class).
            handler(new LoggingHandler(LogLevel.WARN))
            .childHandler(new MyServerInitializer());
            ChannelFuture channelFuture = serverBootstrap.bind(8899).sync();//第四部，指定服务端的端口。
            channelFuture.channel().closeFuture().sync();
        }finally{
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}
```
我们从EventLoopGroup 入手，看一下EventLoopGroup 的结构：

```

/**
 * Special {@link EventExecutorGroup} which allows registering {@link Channel}s that get
 * processed for later selection during the event loop.
 *EventLoopGroup 首先是一个接口，继承了EventExecutorGroup ，主要的功能是在时间循环对Channel的注册，
 */
public interface EventLoopGroup extends EventExecutorGroup {
    /**
     * Return the next {@link EventLoop} to use
     * 一个EventLoopGroup 有多个EventLoop ，地方法得到下一个EventLoop
     */
    @Override
    EventLoop next();

    /**
     * Register a {@link Channel} with this {@link EventLoop}. The returned {@link ChannelFuture}
     * will get notified once the registration was complete.
     * 将参数channel 注册到EventLoop当中，然后注册完毕之后会异步的ChannelFuture 返回到ChannelFuture 当中。
     */
    ChannelFuture register(Channel channel);

    /**
     * Register a {@link Channel} with this {@link EventLoop} using a {@link ChannelFuture}. The passed
     * {@link ChannelFuture} will get notified once the registration was complete and also will get returned.
     * 也是讲channel注册到EventLoop当中，当时我们发现 参数是ChannelPromise 类型的，不是Channel 类型的，那只有一种可能，
     * ChannelPromise 里边包含Channel 的引用，后续会展开讲解。
     */
    ChannelFuture register(ChannelPromise promise);

    /**
     * Register a {@link Channel} with this {@link EventLoop}. The passed {@link ChannelFuture}
     * will get notified once the registration was complete and also will get returned.
     *
     * @deprecated Use {@link #register(ChannelPromise)} instead.
     * 废弃的注册，在 ChannelFuture register(ChannelPromise promise);方法当中ChannelPromise 已经包含了Channel 的引用，那么这个
     * 方法把Channel 也作为参数，是一种功能上的重复，因此被Deprecated，不推荐使用。
     */
    @Deprecated
    ChannelFuture register(Channel channel, ChannelPromise promise);
}
```
注册返回结果ChannelFuture:

```
//ChannelFuture 的父类Future继承了java.util.concurrent.Future,是对结果的一些判断或者监听的操作。
public interface ChannelFuture extends Future<Void> {
    Channel channel();
    @Override
    ChannelFuture addListener(GenericFutureListener<? extends Future<? super Void>> listener);
    @Override
    ChannelFuture addListeners(GenericFutureListener<? extends Future<? super Void>>... listeners);
    @Override
    ChannelFuture removeListener(GenericFutureListener<? extends Future<? super Void>> listener);
    @Override
    ChannelFuture removeListeners(GenericFutureListener<? extends Future<? super Void>>... listeners);
    @Override
    ChannelFuture sync() throws InterruptedException;
    @Override
    ChannelFuture syncUninterruptibly();
    @Override
    ChannelFuture await() throws InterruptedException;
    @Override
    ChannelFuture awaitUninterruptibly();
    boolean isVoid();
}
```

ChannelPromise 是怎么注册Channel 的呢，因为它内部有Channel 的引用
```
public interface ChannelPromise extends ChannelFuture, Promise<Void> {

    @Override
    Channel channel();
    ...略
    ...
    }
```
找一个ChannelPromise 的实现类：

```
public class DefaultChannelPromise extends DefaultPromise<Void> implements ChannelPromise, FlushCheckpoint {

    private final Channel channel;内部的Channel引用。
    private long checkpoint;
    ...
    ...略
 }    
```

接着EventLoopGroup 继承接口EventExecutorGroup：

```
/**
 * The {@link EventExecutorGroup} is responsible for providing the {@link EventExecutor}'s to use
 * via its {@link #next()} method. Besides this, it is also responsible for handling their
 * life-cycle and allows shutting them down in a global fashion.
 *
 */
public interface EventExecutorGroup extends ScheduledExecutorService, Iterable<EventExecutor> {
...
...中间方法略
...
    /**
     * Returns one of the {@link EventExecutor}s managed by this {@link EventExecutorGroup}.
     * EventExecutorGroup内部管理了EventExecutor 。
     */
    EventExecutor next();

```

透过EventLoopGroup 和EventExecutorGroup我们知道他们都有自己的EventLoop和EventExecutor
回到：EventLoopGroup bossGroup = new NioEventLoopGroup();这行代码，NioEventLoopGroup()可以传递参数比如new NioEventLoopGroup(1)；代表有一个线程接受连接。
进入NioEventLoopGroup(Int nThreads）的构造器：

```
    public NioEventLoopGroup(int nThreads) {
        this(nThreads, (Executor) null);//第二个参数传null
    }
```
继续走：

```
    public NioEventLoopGroup(int nThreads, Executor executor) {
        this(nThreads, executor, SelectorProvider.provider());//加入SelectorProvider,调SelectorProvider 的静态方法得到一个
        //SelectorProvider
    }
```
next:

```
    public NioEventLoopGroup(
            int nThreads, Executor executor, final SelectorProvider selectorProvider) {
        this(nThreads, executor, selectorProvider, DefaultSelectStrategyFactory.INSTANCE);
        //DefaultSelectStrategyFactory.INSTANCE返回一个DefaultSelectStrategyFactory实例。
    }
```
next：

```
    public NioEventLoopGroup(int nThreads, Executor executor, final SelectorProvider selectorProvider,
                             final SelectStrategyFactory selectStrategyFactory) {
        super(nThreads, executor, selectorProvider, selectStrategyFactory, RejectedExecutionHandlers.reject());
        //RejectedExecutionHandlers提供了拒绝策略
    }
```
next调父类MultithreadEventLoopGroup的构造器：

```
    protected MultithreadEventLoopGroup(int nThreads, Executor executor, Object... args) {
        super(nThreads == 0 ? DEFAULT_EVENT_LOOP_THREADS : nThreads, executor, args);
    }
```
DEFAULT_EVENT_LOOP_THREADS 初始化是在系统加载的时候：

```

    static {
        DEFAULT_EVENT_LOOP_THREADS = Math.max(1, SystemPropertyUtil.getInt(
                "io.netty.eventLoopThreads", NettyRuntime.availableProcessors() * 2));
//如果配置了io.netty.eventLoopThreads会取io.netty.eventLoopThreads的值，否则就去系统cpu的核数*2，注意，现在的cpu都有超频技术
        if (logger.isDebugEnabled()) {
            logger.debug("-Dio.netty.eventLoopThreads: {}", DEFAULT_EVENT_LOOP_THREADS);
        }
    }
```
我们可以测试一下：

```
public class Test {
    public static void main(String[] args) {
        int result = Math.max(1, SystemPropertyUtil.getInt(
                "io.netty.eventLoopThreads", NettyRuntime.availableProcessors() * 2));
        System.out.println(result);
    }
}
```
以为我的机器是8核的：
![这里写图片描述](20170910175123805.png)
运行结果是16。
接着往下走调用MultithreadEventLoopGroup的父类MultithreadEventExecutorGroup的构造器：

```
    protected MultithreadEventExecutorGroup(int nThreads, Executor executor, Object... args) {
        this(nThreads, executor, DefaultEventExecutorChooserFactory.INSTANCE, args);
    }
```

最后来到最终初始化的地方MultithreadEventExecutorGroup的：

```
public abstract class MultithreadEventExecutorGroup extends AbstractEventExecutorGroup {

    private final EventExecutor[] children;
	....
	....略
	....
    protected MultithreadEventExecutorGroup(int nThreads, Executor executor,
                                            EventExecutorChooserFactory chooserFactory, Object... args) {
        if (nThreads <= 0) {
            throw new IllegalArgumentException(String.format("nThreads: %d (expected: > 0)", nThreads));
        }

        if (executor == null) {
            executor = new ThreadPerTaskExecutor(newDefaultThreadFactory());
        }

        children = new EventExecutor[nThreads];
		//循环对MultithreadEventExecutorGroup的数组EventExecutor初始化，根据指定的线程数量。
        for (int i = 0; i < nThreads; i ++) {
            boolean success = false;
            try {
                children[i] = newChild(executor, args);
                success = true;
            } catch (Exception e) {
                // TODO: Think about if this is a good exception type
                throw new IllegalStateException("failed to create a child event loop", e);
            } finally {
                if (!success) {
                    for (int j = 0; j < i; j ++) {
                        children[j].shutdownGracefully();
                    }

                    for (int j = 0; j < i; j ++) {
                        EventExecutor e = children[j];
                        try {
                            while (!e.isTerminated()) {
                                e.awaitTermination(Integer.MAX_VALUE, TimeUnit.SECONDS);
                            }
                        } catch (InterruptedException interrupted) {
                            // Let the caller handle the interruption.
                            Thread.currentThread().interrupt();
                            break;
                        }
                    }
                }
            }
        }

        chooser = chooserFactory.newChooser(children);

        final FutureListener<Object> terminationListener = new FutureListener<Object>() {
            @Override
            public void operationComplete(Future<Object> future) throws Exception {
                if (terminatedChildren.incrementAndGet() == children.length) {
                    terminationFuture.setSuccess(null);
                }
            }
        };

        for (EventExecutor e: children) {
            e.terminationFuture().addListener(terminationListener);
        }

        Set<EventExecutor> childrenSet = new LinkedHashSet<EventExecutor>(children.length);
        Collections.addAll(childrenSet, children);
        readonlyChildren = Collections.unmodifiableSet(childrenSet);
    }
```
由此完成初始化。
本节先到这儿~~
