---
title: netty源码分析(二十二)Netty编解码器剖析与入站出站处理器详解
date: 2018-10-04 15:14:32
tags: 编解码器 出栈处理器 入栈处理器
categories: netty
---

Netty处理器重要概念：
1、Netty的处理器可以分为两类：入栈处理器和出栈处理器。
<!-- more -->
2、入栈处理器的顶层是ChannelInboundHandler，出栈处理器的顶层是ChannelOutboundHandler。
3、数据处理时常用的各种编解码器本质上都是处理器。
4、编解码器：无论我们是向网络中写入数据是什么类型（int、char、String、二进制等），数据在网络中传递时，其都是以字节流的形式出现的；将数据由原本的形式转换为字节流的操作称为编码（encode），将数据由字节转换为它原本的格式或是其他格式的操作称为解码（decode），编码统一称为codec。
5、编码：本质上是一种出栈处理器；因此，编码一定是一种ChannelOutboundHandler。
6、解码：本质上是一种入栈处理器，因此。解码一定是一种ChannelInboundHandler。
7、在Netty中，编码器通常以XXXEncoder命名；解码器通常以XXXDecoder命名。

netty下边有很多编解码器的实现：
![这里写图片描述](20171210132017305.png)

实际开发的过程中我们可以去使用它们，我们要讲的不是去使用它们，现在以一个例子来说明编解码的一些内幕：
netty提供了一个字节到消息的转换器(ByteToMessageDecoder)：
![这里写图片描述](20171210135608726.png)  
接下来我们使用ByteToMessageDecoder自己实现一个解码器：

```

public class MyByteToLongDecoder extends ByteToMessageDecoder {
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        System.out.println("decode invoked");
        System.out.println(in.readableBytes());
        if(in.readableBytes()>=8){
                out.add(in.readLong());
        }
    }
}

```

然后需要一个将Long类型的数据转换为byte的书装换器：
使用MessageToByteEncoder：
服务端：

```
/**
 * Created by Administrator on 2017/5/20.
 * 服务器和客户端互发程序
 */
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
服务端初始化：

```
public class MyServerInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipline = ch.pipeline();
        pipline.addLast(new MyByteToLongDecoder());
        pipline.addLast(new MyLongToByteEncoder());
        pipline.addLast(new MyServerHandler());
    }
}
```
服务端handler：

```
public class MyServerHandler extends SimpleChannelInboundHandler<Long> {
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, Long msg) throws Exception {
        System.out.println(ctx.channel().remoteAddress()+" --> "+msg);
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```
客户端：

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
客户端的initializer：

```
public class MyClientIniatializer extends ChannelInitializer<SocketChannel> {

    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipline = ch.pipeline();

        pipline.addLast(new MyByteToLongDecoder());
        pipline.addLast(new MyLongToByteEncoder());
        pipline.addLast(new MyClientHandler());
    }
}

```
客户端handler：

```
public class MyClientHandler extends SimpleChannelInboundHandler<Long> {
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, Long msg) throws Exception {
        System.out.println(ctx.channel().remoteAddress());
        System.out.println("client output "+msg);
    }

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        ctx.writeAndFlush(123456L);//一定要加L，否则会作为int类型处理，最终导致消息发送不出去。
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        super.exceptionCaught(ctx, cause);
        ctx.close();
    }
}
```

字节到Long类型的解码器（解析网络传过来的数据）：
```
public class MyByteToLongDecoder extends ByteToMessageDecoder {
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        System.out.println("decode invoked");
        System.out.println(in.readableBytes());
        if(in.readableBytes()>=8){
                out.add(in.readLong());
        }
    }
}
```

Long类型转换为字节（发送到网络之前的转换）：

```
public class MyLongToByteEncoder extends MessageToByteEncoder<Long> {
    @Override
    protected void encode(ChannelHandlerContext ctx, Long msg, ByteBuf out) throws Exception {
        System.out.println("encode invoked");
        System.out.println(msg);
        out.writeLong(msg);
    }
}
```
运行服务端，之后运行客户端，打印输出：
server端输出：
```
decode invoked
8
/127.0.0.1:4679 --> 123456

```
client输出：

```
encode invoked
123456
```
至于为什么是这样一个过程：
首先客户端启动之后，调用MyLongToByteEncoder的encode方法打印“encode invoked”和发送的数据“123456”。
服务段接受到之后调用MyByteToLongDecoder的decode打印“decode invoked”和数据长度“8”，之后是调用MyClientHandler的channelRead0打印“/127.0.0.1:4679 --> 123456”

接下来我们修改MyClientHandler如下：

```
public class MyClientHandler extends SimpleChannelInboundHandler<Long> {
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, Long msg) throws Exception {
        System.out.println(ctx.channel().remoteAddress());
        System.out.println("client output "+msg);
    }

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        // ctx.writeAndFlush(123456L);
    /*
        都可以发送
        ctx.writeAndFlush(1L);
        ctx.writeAndFlush(2L);
        ctx.writeAndFlush(3L);
        ctx.writeAndFlush(4L);*/

        ctx.writeAndFlush(Unpooled.copiedBuffer("helloworld", Charset.forName("utf-8")));
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        super.exceptionCaught(ctx, cause);
        ctx.close();
    }
}
```
ctx.writeAndFlush(Unpooled.copiedBuffer("helloworld", Charset.forName("utf-8")));
这行代码，即发送一个Buffer，我们查看控制台打印的数据：
server端的打印：

```
decode invoked
10
/127.0.0.1:6394 --> 7522537965574647666
decode invoked
2
```
客户端没有任何输出，因为我们的客户端使用的是ByteBuff，而客户端的编码器是Long类型的，所以编码器没有执行，直接把数据丢给了Socket传输到了网络，所以服务端会收到数据，我们发送的数据是“helloworld”由于是utf-8，所以一个英文字符是一个字节，一共是10个字节，我们解码器只有在大于8个字节的时候才会对其进行解码然后给到下一个处理器，所以10个字节前8个通过了解码器，去了下一个handler，而剩下的2个没有通过解码器，服务端打印的“/127.0.0.1:6394 --> 7522537965574647666”后边的那串数字是8个字节的数据。

  关于netty编解码器的重要结论：
  1、无论是编码器还是解码器，其接受的消息类型必须要与待处理的参数类型一致，否则该编码器或解码器并不会执行。
  2、在解码器进行数据解码时，一定要记得判断缓冲（ByteBuf）中的数据是否 足够，否则将会产生一些问题。
  例如上边的例子判断是否是8个长度（因为long是占用8个字节的数据类型）：


```
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        System.out.println("decode invoked");
        System.out.println(in.readableBytes());
        if(in.readableBytes()>=8){
                out.add(in.readLong());
        }
    }
```
