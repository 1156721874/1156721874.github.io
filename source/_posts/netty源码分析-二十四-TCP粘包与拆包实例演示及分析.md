---
title: netty源码分析(二十四)TCP粘包与拆包实例演示及分析
date: 2018-10-04 15:32:26
tags: tcp  粘包 拆包
categories: netty
---

关于粘包与拆包的概念这里不再熬术，下面举一个粘包的例子：
客户端启动的时候向服务端写入了10条消息，然后服务端接收到消息之后，回写客户端一条UUID，客户端打印服务端发过来的UUID
<!-- more -->
MyServer：

```
public class MyServer {

    public static void main(String[] args) throws InterruptedException {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        try{
            ServerBootstrap serverBootstrap = new ServerBootstrap();
            serverBootstrap.group(bossGroup,workerGroup).channel(NioServerSocketChannel.class)
                    .childHandler(new MyServerInitializer());
            ChannelFuture channelFuture = serverBootstrap.bind(8899).sync();
            channelFuture.channel().closeFuture().sync();
        }finally{
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}

```
MyClientIniatializer：

```
public class MyClientIniatializer extends ChannelInitializer<SocketChannel> {

    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipline = ch.pipeline();

        pipline.addLast(new MyClientHandler());
    }
}
```
MyServerHandler：

```
public class MyServerHandler extends SimpleChannelInboundHandler<ByteBuf> {
    private int  count ;
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, ByteBuf msg) throws Exception {
        byte[] buffer = new byte[msg.readableBytes()] ;
        msg.readBytes(buffer);//注意buffer的长度必须和msg.readableBytes()一样，否则报错，这是netty规定的
        String message = new String(buffer, Charset.forName("utf-8"));
        System.out.println("服务端接收到的消息："+message);
        System.out.println("服务端接收到的消息数量："+(++this.count));

        ByteBuf responseMessage = Unpooled.copiedBuffer(UUID.randomUUID().toString(),Charset.forName("utf-8"));
        ctx.writeAndFlush(responseMessage);
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

Myclient：

```
public class Myclient {
    public static void main(String[] args) throws InterruptedException {
        EventLoopGroup eventLoopGroup = new NioEventLoopGroup();
        try {
            Bootstrap bootstrap = new Bootstrap();
            bootstrap.group(eventLoopGroup).channel(NioSocketChannel.class).handler(new MyClientIniatializer());
            ChannelFuture channelFuture = bootstrap.connect("localhost", 8899).sync();
            channelFuture.channel().writeAndFlush("hello");
            channelFuture.channel().closeFuture().sync();
        } finally {
            eventLoopGroup.shutdownGracefully();
        }
    }
}

```
MyClientIniatializer：

```
public class MyClientIniatializer extends ChannelInitializer<SocketChannel> {

    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipline = ch.pipeline();

        pipline.addLast(new MyClientHandler());
    }
}
```

MyClientHandler：

```
public class MyClientHandler extends SimpleChannelInboundHandler<ByteBuf> {
    private int count;
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, ByteBuf msg) throws Exception {
        byte[] buffer = new byte[msg.readableBytes()];
        msg.readBytes(buffer);

        String message = new String(buffer,Charset.forName("utf-8"));
        System.out.println("客户端接收到的消息内容："+message);
        System.out.println("客户端接收到的消息数量："+(++this.count));

    }

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        for(int i = 0;i <10;i++){
            ByteBuf buffer  = Unpooled.copiedBuffer("sent from client",Charset.forName("utf-8"));
            ctx.writeAndFlush(buffer);
        }
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        super.exceptionCaught(ctx, cause);
        ctx.close();
    }
}
```

服务端打印结果：

```
服务端接收到的消息：sent from clientsent from clientsent from clientsent from clientsent from clientsent from clientsent from clientsent from clientsent from clientsent from client
服务端接收到的消息数量：1
```

客户端打印结果：

```
客户端接收到的消息内容：8c260c09-8a9d-4491-9bf7-ff5c5c8f790c
客户端接收到的消息数量：1
```
很多人认为客户端应该收到10条UUID才对，但是这里协议进行了粘包，将客户端的10条消息作为一条消息发给我服务端，才导致服务端只打印了一天消息（10条客户端消息的集合）而且只接受了一次，因此服务端打印的接收数量是1。

此时我们把客户端关闭，然后重新连接服务端，我们重复2次这个过程。
服务端打印结果：

```
服务端接收到的消息：sent from clientsent from clientsent from clientsent from clientsent from clientsent from clientsent from clientsent from clientsent from clientsent from client
服务端接收到的消息数量：1
服务端接收到的消息：sent from client
服务端接收到的消息数量：1
服务端接收到的消息：sent from client
服务端接收到的消息数量：2
服务端接收到的消息：sent from clientsent from clientsent from client
服务端接收到的消息数量：3
服务端接收到的消息：sent from clientsent from client
服务端接收到的消息数量：4
服务端接收到的消息：sent from clientsent from clientsent from client
服务端接收到的消息数量：5
服务端接收到的消息：sent from client
服务端接收到的消息数量：1
服务端接收到的消息：sent from client
服务端接收到的消息数量：2
服务端接收到的消息：sent from clientsent from clientsent from clientsent from client
服务端接收到的消息数量：3
服务端接收到的消息：sent from clientsent from client
服务端接收到的消息数量：4
服务端接收到的消息：sent from clientsent from client
服务端接收到的消息数量：5
```
疑问是为什么MyServerHandler里边的count会重新从1开始？
其实这里的MyServerInitializer每当有一个客户端连接上来的时候都会新建一个MyServerHandler，也就会初始化MyServerHandler的count，因此出现这样的结果。
这样的现象是tcp协议的一部分，我们在使用netty的时候可以通过编解码器来解决tcp粘包和拆包的问题。
