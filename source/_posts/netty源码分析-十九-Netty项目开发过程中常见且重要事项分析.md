---
title: netty源码分析(十九)Netty项目开发过程中常见且重要事项分析
date: 2018-10-04 14:55:18
tags: netty实践问题
categories: netty
---

一、服务端在回写数据到客户端的时候可以有一下2中方式：
![这里写图片描述](20171118104445662.png)
在Netty中有22种发送消息的方式，可以直接写到Channel中，也可以写到与ChannelHandler所关联的那个ChannelHandlerContext中，对于前一种方式来说，消息会从ChannelPipeline的末尾开始流动，对于后一种方式来说，消息将从ChannelPipleline中的下一个ChannelG、Handler开始流动。
图示：
![这里写图片描述](20171118105821855.png)
二、nio和oio通用的线程模型。
1、ChannelHandlerContext与ChannelHandler之间的关联绑定关系是永远都不会发生改变的，因此对其进行缓存是没有任何问题的。
2、对于与Channel的同名方法来说，channelHandlerContext的方法将会产生更短的事件流，所以我们应该在可能的情况下利用这个特性来提升应用性能。
Netty中不光支持了Java中NIO模型，同时也提供了对OIO模型的支持。（New IO vs Old IO）。
首先，在Netty中，切换OIO和NIO两种模式是非常方便的，只需要初始化不同的Channel工程即可。

```
Netty中不光支持了Java中NIO模型，同时也提供了对OIO模型的支持。（New IO vs Old IO）。
首先，在Netty中，切换OIO和NIO两种模式是非常方便的，只需要初始化不同的Channel工程即可。
```

```
Netty中不光支持了Java中NIO模型，同时也提供了对OIO模型的支持。（New IO vs Old IO）。
首先，在Netty中，切换OIO和NIO两种模式是非常方便的，只需要初始化不同的Channel工程即可。
```
NIO时候异步的，调用完毕之后会立刻返回，那么OIO是怎么做到适应这个Netty建立的模型的呢？
答案是通过设置OIO的超时时间：

```
try{
	oio synchronous operation (setTimeOut(xxxx))
}catch(SocketTimeOutException ex){
	捕捉异常
	捕捉到异常之后会进行记录下次时间还会去执行这个oio操作
}
```

这就是Netty框架为我们做的贡献。
图示：
![这里写图片描述](20171118114535305.png)
左图是nio的情况，一个线程（EventLoop）可以处理多个Channel连接，右图是OIO，每个EventLoop只能处理一个Channel连接。

三、客户端A连接服务端B然后服务端B把消息转发给C，那么B的模型是什么样子的呢？
![这里写图片描述](20171118120501393.png)
这个时候要在B上写一个Netty的客户端用来连接C，但是我们可以共用B的EventLoopGroup：
伪代码：
```
public void channelActive(ChannelHandlerContext ctx){
	BootStrap bootstrap = .....
	bootstrap.channel(NioSocketChannel.class).handler(
			bootstrap.group(ctx.channeleventLoop());
			bootstrap.connect();
	);
}
```
