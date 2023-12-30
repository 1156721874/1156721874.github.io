---
title: netty源码分析(三)Netty服务端ServerBootstrap的初始化与反射在其中的应用分析
date: 2018-10-04 14:17:46
tags: ServerBootstrap reflect机制
categories: netty
---

上一节说到EventLoopGroup只是对bossGroup和workerGroup的一些初始化，包括线程数量，执行器（命令模式），我们的服务端接下来使用ServerBootstrap对bossGroup和workerGroup进行了包装，整个过程是一个方法链的调用过程，每个方法返回调用者本身：
![这里写图片描述](2018/10/04/netty源码分析-三-Netty服务端ServerBootstrap的初始化与反射在其中的应用分析/20170916120817979.png)
<!-- more -->
然后进行了启动，先看一下ServerBootstrap的结构：

```
 //{@link Bootstrap} sub-class which allows easy bootstrap of {@link ServerChannel}
 //Bootstrap的子类型，用来启动ServerChannel，父类是AbstractBootstrap，父类的泛型是它的子类类型ServerBootstrap和
 //要启动的ServerChannel类型。
public class ServerBootstrap extends AbstractBootstrap<ServerBootstrap, ServerChannel> {
	...略
    private volatile EventLoopGroup childGroup;//即之前创建的workerGroup，实际处理数据的EventLoopGroup。
    ...略
    public ServerBootstrap() { } //构造器非常简化。
	...略

    /**
     * Set the {@link EventLoopGroup} for the parent (acceptor) and the child (client). These
     * {@link EventLoopGroup}'s are used to handle all the events and IO for {@link ServerChannel} and
     * {@link Channel}'s.
     * parentGroup放在父类AbstractBootstrap里边，即acceptor，childGroup放在当前类里边，即client
     * EventLoopGroup的作用就是处理所有的ServerChannel和Channel的io事件。
     */
    public ServerBootstrap group(EventLoopGroup parentGroup, EventLoopGroup childGroup) {
        super.group(parentGroup);//调父类的构造器，将parentGroup放在父类
        if (childGroup == null) {
            throw new NullPointerException("childGroup");
        }
        if (this.childGroup != null) {
            throw new IllegalStateException("childGroup set already");
        }
        this.childGroup = childGroup;//childGroup放在子类里边
        return this;
    }
```
我们切换到父类AbstractBootstrap：

```
//泛型B是AbstractBootstrap的子类类型，当前是ServerBootstrap，C是通道类型，当前是NioServerSocketChannel（后续会提到）
public abstract class AbstractBootstrap<B extends AbstractBootstrap<B, C>, C extends Channel> implements Cloneable {
    ...略
        private volatile ChannelFactory<? extends C> channelFactory;//Channel类型的C会被反射成实体，放在ChannelFactory
        //里边，后边会说。
 /**
     * The {@link EventLoopGroup} which is used to handle all the events for the to-be-created
     * {@link Channel}
     */
    @SuppressWarnings("unchecked")
    public B group(EventLoopGroup group) {
        if (group == null) {
            throw new NullPointerException("group");
        }
        if (this.group != null) {
            throw new IllegalStateException("group set already");
        }
        this.group = group;
        return (B) this;//返回子类型ServerBootstrap。
    }
        ...略
```
接下来会调用serverBootstrap.group(bossGroup,workerGroup).channel(NioServerSocketChannel.class)，channel方法，channel位于父类AbstractBootstrap里边：

```
    /**
     * The {@link Class} which is used to create {@link Channel} instances from.
     * You either use this or {@link #channelFactory(io.netty.channel.ChannelFactory)} if your
     * {@link Channel} implementation has no no-args constructor.
     * channelClass即我们的参数NioServerSocketChannel.class，new ReflectiveChannelFactory<C>(channelClass)使用反射生成了
     * NioServerSocketChannel的实例（无参构造器），
     */
    public B channel(Class<? extends C> channelClass) {
        if (channelClass == null) {
            throw new NullPointerException("channelClass");
        }
        return channelFactory(new ReflectiveChannelFactory<C>(channelClass));
    }
```
这里用到了ReflectiveChannelFactory，这里牵扯了三个factory和他们之间的关系，如图：
![这里写图片描述](2018/10/04/netty源码分析-三-Netty服务端ServerBootstrap的初始化与反射在其中的应用分析/20170916110106930.png)

这个图我们只要了解一下即可，接下来 return channelFactory(new ReflectiveChannelFactory<C>(channelClass));，进入channelFactory方法：

```
//入参：channelFactory类型io.netty.channel.ChannelFactory
    public B channelFactory(io.netty.channel.ChannelFactory<? extends C> channelFactory) {
        return channelFactory((ChannelFactory<C>) channelFactory);
    }
```
继续走：
```
//入参：channelFactory类型io.netty.bootstrap.ChannelFactory
    public B channelFactory(ChannelFactory<? extends C> channelFactory) {
        if (channelFactory == null) {
            throw new NullPointerException("channelFactory");
        }
        if (this.channelFactory != null) {
            throw new IllegalStateException("channelFactory set already");
        }

        this.channelFactory = channelFactory;
         //即AbstractBootstrap的成员变量channelFactory被赋值，实际上是一个ReflectiveChannelFactory。
         //private volatile ChannelFactory<? extends C> channelFactory;

        return (B) this;//返回子类型ServerBootstrap 为了链式方法调用
    }
```

接下是serverBootstrap.group(bossGroup,workerGroup).channel(NioServerSocketChannel.class).childHandler(new MyServerInitializer());，childHandler方法：

```
    /**
     * Set the {@link ChannelHandler} which is used to serve the request for the {@link Channel}'s.
     * childHandler是为了服务客户端的request请求。
     */
    public ServerBootstrap childHandler(ChannelHandler childHandler) {
        if (childHandler == null) {
            throw new NullPointerException("childHandler");
        }
        this.childHandler = childHandler;//只是简单的赋值
        return this;
    }
```
到目前为止：
bossGroup 位于父类AbstractBootstrap，workerGroup位于ServerBootstrap ，NioServerSocketChannel位于AbstractBootstrap
ChannelHandler位于ServerBootstrap ，这写操作都是数据的准备，为了后边的启动：
```
ChannelFuture channelFuture = serverBootstrap.bind(8899).sync();
```

bind方法：

```
    /**
     * Create a new {@link Channel} and bind it.
     * 创建一个新的channel绑定到ServerBootstrap 上
     */
    public ChannelFuture bind(int inetPort) {
        return bind(new InetSocketAddress(inetPort));
    }
```

方法最终调用dobind：
这个方法是启动服务的比较重要的一个实现
```
 private ChannelFuture doBind(final SocketAddress localAddress) {
        final ChannelFuture regFuture = initAndRegister();
        final Channel channel = regFuture.channel();
        if (regFuture.cause() != null) {
            return regFuture;
        }

        if (regFuture.isDone()) {
            // At this point we know that the registration was complete and successful.
            ChannelPromise promise = channel.newPromise();
            doBind0(regFuture, channel, localAddress, promise);
            return promise;
        } else {
            // Registration future is almost always fulfilled already, but just in case it's not.
            final PendingRegistrationPromise promise = new PendingRegistrationPromise(channel);
            regFuture.addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture future) throws Exception {
                    Throwable cause = future.cause();
                    if (cause != null) {
                        // Registration on the EventLoop failed so fail the ChannelPromise directly to not cause an
                        // IllegalStateException once we try to access the EventLoop of the Channel.
                        promise.setFailure(cause);
                    } else {
                        // Registration was successful, so set the correct executor to use.
                        // See https://github.com/netty/netty/issues/2586
                        promise.registered();

                        doBind0(regFuture, channel, localAddress, promise);
                    }
                }
            });
            return promise;
        }
    }
```
下一节我们从initAndRegister方法开始讲解。
