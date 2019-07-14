---
title: netty源码分析(十五)Channel注册流程深度解读
date: 2018-10-04 14:44:55
tags: channel注册
categories: netty
---

前边的介绍是netty对一些组件初始化的过程，接下来是第二部分，注册，还是之前的initAndRegister方法：

```
    final ChannelFuture initAndRegister() {
        Channel channel = null;
...略
            channel = channelFactory.newChannel();
            init(channel);
 ...略
        ChannelFuture regFuture = config().group().register(channel);//注册逻辑
        ...略
        return regFuture;
    }
```
config方法从字面意思来看就是得到一个配置，具体的是什么配置呢：

```
public class ServerBootstrap extends AbstractBootstrap<ServerBootstrap, ServerChannel> {
...略
    private final ServerBootstrapConfig config = new ServerBootstrapConfig(this);
    ...略
    public final ServerBootstrapConfig config() {
        return config;
    }
    ...略
}
```
config方法返回的是一个ServerBootstrapConfig ,他有ServerBootstrap的引用,因此ServerBootstrapConfig 可以得到ServerBootstrap的一些属性：

```
    public EventLoopGroup childGroup() {
        return bootstrap.childGroup();
    }

    /**
     * Returns the configured {@link ChannelHandler} be used for the child channels or {@code null}
     * if non is configured yet.
     */
    public ChannelHandler childHandler() {
        return bootstrap.childHandler();
    }

    /**
     * Returns a copy of the configured options which will be used for the child channels.
     */
    public Map<ChannelOption<?>, Object> childOptions() {
        return bootstrap.childOptions();
    }

    /**
     * Returns a copy of the configured attributes which will be used for the child channels.
     */
    public Map<AttributeKey<?>, Object> childAttrs() {
        return bootstrap.childAttrs();
    }
```
对应的ServerBootstrap的就是：

```
    private final Map<ChannelOption<?>, Object> childOptions = new LinkedHashMap<ChannelOption<?>, Object>();
    private final Map<AttributeKey<?>, Object> childAttrs = new LinkedHashMap<AttributeKey<?>, Object>();
    private volatile EventLoopGroup childGroup;
    private volatile ChannelHandler childHandler;
```
回到initAndRegister方法：

```
 ChannelFuture regFuture = config().group().register(channel);
```
config()方法返回的是ServerBootstrapConfig ，接着调用他的group(),实际上调用的是他的父类AbstractBootstrapConfig的group()方法：
```
public abstract class AbstractBootstrapConfig<B extends AbstractBootstrap<B, C>, C extends Channel> {
...略
    protected final B bootstrap;//B的实际类型是ServerBootstrap
    public final EventLoopGroup group() {
        return bootstrap.group();
    }
    ...略
    }
```
bootstrap.group():

```
public abstract class AbstractBootstrap<B extends AbstractBootstrap<B, C>, C extends Channel> implements Cloneable {
...略
    volatile EventLoopGroup group;//事件循环组，实际上是NioEventLoopGroup
    ...略
    public final EventLoopGroup group() {
        return group;
    }
    ...略
    }
```
接下来是register方法，我们在此处打一个断点：
```
 ChannelFuture regFuture = config().group().register(channel);
```
但是我们看到的register是在MultithreadEventLoopGroup里边：
![这里写图片描述](20171104122652131.png)

这个比较让人困惑，其实很简单：
![这里写图片描述](20171104122817431.png)
即 NioEventLoopGroup的父类是MultithreadEventLoopGroup，register是父类的方法，所以我们才进入MultithreadEventLoopGroup里边。
```
    public ChannelFuture register(Channel channel) {
        return next().register(channel);
    }
```
接下来进入真正的注册过程。
