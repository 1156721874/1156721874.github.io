---
title: netty源码分析(五)Netty服务器地址绑定底层源码分析
date: 2018-10-04 14:22:27
tags: netty服务器地址绑定
categories: netty
---

AbstractBootstrapd的initAndRegister方法，完成 初始化和注册：

<!-- more -->
```
 final ChannelFuture initAndRegister() {
        Channel channel = null;
        try {
            channel = channelFactory.newChannel();//channelFactory是ReflectiveChannelFactory，ReflectiveChannelFactory
            //内部的成员变量是NioServerSocketChannel.class，调用newChannel()即通过反射得到一个NioServerSocketChannel实体对象
            //调用无参构造器。在接下来的NioServerSocketChannel介绍你会知道这句代码做了哪些事情，透剧一下：
            //设置ServerSocketChannel的兴趣事件（初始状态都是SelectionKey.OP_ACCEPT）、ChannelId（唯一的一个编码）、
            //设置ServerSocketChannel为非阻塞、初始化了ServerSocketChannel的pipline。

            init(channel);//进入init方法。
        } catch (Throwable t) {
            if (channel != null) {
                // channel can be null if newChannel crashed (eg SocketException("too many open files"))
                channel.unsafe().closeForcibly();
            }
            // as the Channel is not registered yet we need to force the usage of the GlobalEventExecutor
            return new DefaultChannelPromise(channel, GlobalEventExecutor.INSTANCE).setFailure(t);
        }

        ChannelFuture regFuture = config().group().register(channel);
        if (regFuture.cause() != null) {
            if (channel.isRegistered()) {
                channel.close();
            } else {
                channel.unsafe().closeForcibly();
            }
        }

        // If we are here and the promise is not failed, it's one of the following cases:
        // 1) If we attempted registration from the event loop, the registration has been completed at this point.
        //    i.e. It's safe to attempt bind() or connect() now because the channel has been registered.
        // 2) If we attempted registration from the other thread, the registration request has been successfully
        //    added to the event loop's task queue for later execution.
        //    i.e. It's safe to attempt bind() or connect() now:
        //         because bind() or connect() will be executed *after* the scheduled registration task is executed
        //         because register(), bind(), and connect() are all bound to the same thread.

        return regFuture;
    }
```

紧接着我们进入init方法，init方法是父类AbstractBootstrap的方法，我们到子类ServerBootstrap里边查看：

```
 void init(Channel channel) throws Exception {
        final Map<ChannelOption<?>, Object> options = options0();//ServerBootstrap设置的option集合，是一个LinkedHashMap
        synchronized (options) {
            setChannelOptions(channel, options, logger);//将options 集合放到channel（NioServerSocketChannel）里边
        }

        final Map<AttributeKey<?>, Object> attrs = attrs0();//ServerBootstrap设置的属性，也是一个LinkedHashMap
        synchronized (attrs) {
            for (Entry<AttributeKey<?>, Object> e: attrs.entrySet()) {
                @SuppressWarnings("unchecked")
                AttributeKey<Object> key = (AttributeKey<Object>) e.getKey();
                channel.attr(key).set(e.getValue());//设置到channel里边。
            }
        }

        ChannelPipeline p = channel.pipeline();//获取channel的对应的管道。

        final EventLoopGroup currentChildGroup = childGroup;//MyServer实例程序中的workerGroup
        final ChannelHandler currentChildHandler = childHandler;//MyServer实例程序中的MyServerInitializer
        final Entry<ChannelOption<?>, Object>[] currentChildOptions;
        final Entry<AttributeKey<?>, Object>[] currentChildAttrs;
        synchronized (childOptions) {
            currentChildOptions = childOptions.entrySet().toArray(newOptionArray(childOptions.size()));
        }
        synchronized (childAttrs) {
            currentChildAttrs = childAttrs.entrySet().toArray(newAttrArray(childAttrs.size()));
        }

        p.addLast(new ChannelInitializer<Channel>() {
        //ChannelInitializer
            /**
            This method will be called once the {@link Channel} was registered. After the method returns this instance
            will be removed from the {@link ChannelPipeline} of the {@link Channel}.
            当Channel被注册的时候当前方法会被调用，当方法返回的时候当前Channel的实例会被删除从ChannelPipeline当中。
            */
            public void initChannel(final Channel ch) throws Exception {
                final ChannelPipeline pipeline = ch.pipeline();
                ChannelHandler handler = config.handler();//MyServer实例程序中的LoggingHandler
                //LoggingHandler详见MyServer实例程序 http://blog.csdn.net/wzq6578702/article/details/77923602
                if (handler != null) {
                    pipeline.addLast(handler);//如果ServerBootstrap的handler被设置过，把设置的Handler放到管道当中。
                    //详见MyServer实例程序 http://blog.csdn.net/wzq6578702/article/details/77923602
                }

                ch.eventLoop().execute(new Runnable() {//ch.eventLoop()得到是一个类似于线程池的东西
                    @Override
                    public void run() {
                        pipeline.addLast(new ServerBootstrapAcceptor(
                                ch, currentChildGroup, currentChildHandler, currentChildOptions, currentChildAttrs));
                    }
                });
            }
        });
    }
```
另外还有一个重要的点，initAndRegister的channel 实例化：channel = channelFactory.newChannel();是对NioServerSocketChannel
调用无参数的构造器通过反射实例化出来的，我们进入到NioServerSocketChannel无参构造器：

```
public class NioServerSocketChannel extends AbstractNioMessageChannel
                             implements io.netty.channel.socket.ServerSocketChannel {
      private static final SelectorProvider DEFAULT_SELECTOR_PROVIDER = SelectorProvider.provider();
          private static ServerSocketChannel newSocket(SelectorProvider provider) {
        try {
            /**
             *  Use the {@link SelectorProvider} to open {@link SocketChannel} and so remove condition in
             *  {@link SelectorProvider#provider()} which is called by each ServerSocketChannel.open() otherwise.
             *
             *  See <a href="https://github.com/netty/netty/issues/2308">#2308</a>.
             */
            return provider.openServerSocketChannel();
        } catch (IOException e) {
            throw new ChannelException(
                    "Failed to open a server socket.", e);
        }
    }             
//SelectorProvider是jdk提供的一个提供Channel的提供者,java.nio.channels.DatagramChannel、java.nio.channels.Pipe
// java.nio.channels.Selector、java.nio.channels.ServerSocketChannel等Channel都是通过SelectorProvider.provider()
//打开一个通道，但是SelectorProvider.provider()是同步的（有synchronized）,netty为了适应在高并发的其工况下，这样的同步会造成性能
//的损失，因此将SelectorProvider.provider()获得的SelectorProvider做成一个名字是DEFAULT_SELECTOR_PROVIDER 的常量，获得通道的时候
//直接使用[ return provider.openServerSocketChannel();]类似这样的用法返回Channel，不会有同步加锁操作，提高了并发，有兴趣的可以看下
//https://github.com/netty/netty/issues/2308 说明，为什么netty这样写。

    /**
     * Create a new instance
     * 无参构造器，主要获取ServerSocketChannel
     */
    public NioServerSocketChannel() {
        this(newSocket(DEFAULT_SELECTOR_PROVIDER));
    }              

    /**
     * Create a new instance using the given {@link ServerSocketChannel}.
     * 设置ServerSocketChannel的兴趣事件（初始状态都是SelectionKey.OP_ACCEPT）、ChannelId（唯一的一个编码）、
     * 设置ServerSocketChannel为非阻塞、初始化了ServerSocketChannel的pipline。
     *
     * config 对ServerSocketChannelConfig进行了赋值。
     */
    public NioServerSocketChannel(ServerSocketChannel channel) {
        super(null, channel, SelectionKey.OP_ACCEPT);
        config = new NioServerSocketChannelConfig(this, javaChannel().socket());
    }

}                     
```
