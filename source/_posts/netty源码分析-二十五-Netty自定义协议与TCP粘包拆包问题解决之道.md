---
title: netty源码分析(二十五)Netty自定义协议与TCP粘包拆包问题解决之道
date: 2018-10-04 15:33:47
tags: 自定义协议 tcp粘包拆包问题解决
categories: netty
---

上一节说了TCP的粘包和拆包，用一个实例的方式做了说明，那么在netty里面是怎么解决粘包和拆包问题呢，这就需要编解码器，我们写一个简单的自动以协议的demo，说明一下编解码器在解决tcp粘包和拆包的解决方式。
先罗列一下服务端的代码：
<!-- more -->
MyServer负责服务端的启动：

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
MyServerInitializer 负责加入编解码器和handler，包括我们自己定义的编解码器（MyPersonDecoder、MyPersonEncoder）：

```
public class MyServerInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
       ChannelPipeline channelPipeline =  ch.pipeline();
        channelPipeline.addLast(new MyPersonDecoder());
        channelPipeline.addLast(new MyPersonEncoder());
        channelPipeline.addLast(new MyServerHandler());
    }
}
```

MyServerHandler，接受客户端发来的信息并打印调用次数，之后向客户端写入一个uuid：

```
public class MyServerHandler extends SimpleChannelInboundHandler<PersonProtocal> {
    private int count;
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, PersonProtocal msg) throws Exception {
        System.out.println("服务端接受到的数据：");
        System.out.println("数据长度:"+msg.getLength());
        System.out.println("数据内容："+ new String(msg.getContent(), Charset.forName("utf-8")) );
        System.out.println("服务端接收到的消息数量:"+(++count));

        String responseMessage = UUID.randomUUID().toString();
        int responseLength = responseMessage.getBytes(Charset.forName("utf-8")).length;
        byte[] responseContent = responseMessage.getBytes(Charset.forName("utf-8"));
        PersonProtocal personProtocal = new PersonProtocal();
        personProtocal.setLength(responseLength);
        personProtocal.setContent(responseContent);
        ctx.writeAndFlush(personProtocal);

    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}

```

解码器，将字节数组解码成我们自定义的协议PersonProtocal类型：

```
public class MyPersonDecoder extends ReplayingDecoder<Void> {
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        System.out.println("MyPersonDecoder decode invoked ");
        int length = in.readInt();
        byte[] content = new byte[length];
        in.readBytes(content);

        PersonProtocal personProtocal = new PersonProtocal();
        personProtocal.setLength(length);
        personProtocal.setContent(content);

        out.add(personProtocal);
    }
}

```

PersonProtocal 自定义的协议的封装，其实很简单，只有消息的长度和消息内容，先读取消息长度，再读取消息内容：

```
public class PersonProtocal {
    private int length;

    private byte[] content;

    public int getLength() {
        return length;
    }

    public void setLength(int length) {
        this.length = length;
    }

    public byte[] getContent() {
        return content;
    }

    public void setContent(byte[] content) {
        this.content = content;
    }

}
```

解码器MyPersonDecoder ，我们继承了ReplayingDecoder无需关注粘包问题，将字节转换为协议实体（PersonProtocal）：

```
public class MyPersonDecoder extends ReplayingDecoder<Void> {
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        System.out.println("MyPersonDecoder decode invoked ");
        int length = in.readInt();
        byte[] content = new byte[length];
        in.readBytes(content);

        PersonProtocal personProtocal = new PersonProtocal();
        personProtocal.setLength(length);
        personProtocal.setContent(content);

        out.add(personProtocal);
    }
}

```

编码器MyPersonEncoder实现很简单，这是将数据（PersonProtocal）写入到网络：

```

public class MyPersonEncoder extends MessageToByteEncoder<PersonProtocal> {

    @Override
    protected void encode(ChannelHandlerContext ctx, PersonProtocal msg, ByteBuf out) throws Exception {
        System.out.println("MyPersonEncoder encode invoked");
        out.writeInt(msg.getLength());
        out.writeBytes(msg.getContent());
    }
}
```

最后是客户端的程序MyClientHandler，启动的时候向服务端发送十条消息，再者接受服务端回执的uuid：

```
public class MyClientHandler extends SimpleChannelInboundHandler<PersonProtocal> {

    private int count;

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        for(int i=0;i<10;i++){
            String messaage = "sent from client";
            int length = messaage.getBytes(Charset.forName("utf-8")).length;
            byte[] content = messaage.getBytes(Charset.forName("utf-8"));
            PersonProtocal personProtocal = new PersonProtocal();
            personProtocal.setLength(length);
            personProtocal.setContent(content);
            ctx.writeAndFlush(personProtocal);
        }
    }

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, PersonProtocal msg) throws Exception {
        int length = msg.getLength();
        byte[] content = msg.getContent();
        System.out.println("客户端接收到的消息");
        System.out.println("长度:"+length);
        System.out.println("消息内容:"+new String(content,Charset.forName("utf-8")));
        System.out.println("客户端接收到的消息数量:"+(++this.count));
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

客户端启动程序Myclient：

```
public class Myclient {
    public static void main(String[] args) throws InterruptedException {
        EventLoopGroup eventLoopGroup = new NioEventLoopGroup();
        try {
            Bootstrap bootstrap = new Bootstrap();
            bootstrap.group(eventLoopGroup).channel(NioSocketChannel.class).handler(new ChannelInitializer<SocketChannel>() {

                @Override
                protected void initChannel(SocketChannel ch) throws Exception {
                    ChannelPipeline channelPipeline =  ch.pipeline();
                    channelPipeline.addLast(new MyPersonDecoder());
                    channelPipeline.addLast(new MyPersonEncoder());
                    channelPipeline.addLast(new MyClientHandler());
                }
            });
            ChannelFuture channelFuture = bootstrap.connect("localhost", 8899).sync();
            channelFuture.channel().writeAndFlush("hello");
            channelFuture.channel().closeFuture().sync();
        } finally {
            eventLoopGroup.shutdownGracefully();
        }
    }
}

```
整个流程：
客户端启动之后，向服务端发送了十条“sent from client”客户端经过编码器MyPersonEncoder发送出去， 然后服务端接收到之后先经过解码器MyPersonDecoder，解码成PersonProtocal实体，然后打印消息内容，服务端每接收到一条“sent from client”，紧接着向客户端发送一个uuid（讲过编码器MyPersonEncoder），之后客户端收到uuid，经过解码器MyPersonDecoder转换成PersonProtocal实体。
服务端打印结果：

```
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:1
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:2
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:3
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:4
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:5
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:6
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:7
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:8
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:9
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
服务端接受到的数据：
数据长度:16
数据内容：sent from client
服务端接收到的消息数量:10
MyPersonEncoder encode invoked
```
客户端打印结果：

```
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonEncoder encode invoked
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:aeb03767-5b48-4c1b-ae08-2c643fa511f1
客户端接收到的消息数量:1
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:22a19d24-3a53-4954-af51-6d8a47a31412
客户端接收到的消息数量:2
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:0bb4cbff-8725-4aa1-b431-81d185639dd0
客户端接收到的消息数量:3
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:4770c9ec-8868-4253-a6be-632105bc677c
客户端接收到的消息数量:4
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:07562dc9-bde7-42bf-91b5-a964d320a4ab
客户端接收到的消息数量:5
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:08955003-5487-47a4-92c0-3fd6d636abbd
客户端接收到的消息数量:6
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:4e35d4d9-5780-46df-a78a-8bc0bf293e03
客户端接收到的消息数量:7
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:051d7e80-8e1c-4b0a-979e-9ab390c9d139
客户端接收到的消息数量:8
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:a220680e-852f-4525-9ec4-06f7912dcabe
客户端接收到的消息数量:9
MyPersonDecoder decode invoked
客户端接收到的消息
长度:36
消息内容:64bf6571-e246-4f4e-89f5-afe609ccc4ed
客户端接收到的消息数量:10

```
