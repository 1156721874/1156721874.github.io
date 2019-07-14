---
title: netty源码分析(十)ChannelPipeline创建时机与高级拦截过滤器模式的运用
date: 2018-10-04 14:34:29
tags: ChannelPipeline 拦截过滤器
categories: netty
---

ChannelPipeline的创建时机：
我们从服务端的入口main程序开始：
1、
```
ChannelFuture channelFuture = serverBootstrap.bind(8899).sync();
```
2、
AbstractBootstrap:
```
    public ChannelFuture bind(SocketAddress localAddress) {
        validate();
        if (localAddress == null) {
            throw new NullPointerException("localAddress");
        }
        return doBind(localAddress);
    }
```
3、AbstractBootstrap
```
....略
    private ChannelFuture doBind(final SocketAddress localAddress) {
        final ChannelFuture regFuture = initAndRegister();
        final Channel channel = regFuture.channel();
....略
```

4、AbstractBootstrap
```
....略
    final ChannelFuture initAndRegister() {
        Channel channel = null;
        try {
            channel = channelFactory.newChannel();//前边章节说过这个channel 是NioServerSocketChannel通过反射new出来的
            init(channel);//init方法内部会直接调用ChannelPipeline p = channel.pipeline();，即NioServerSocketChannel
            //实例化的时候构建了ChannelPipeline
                        ....略
```
5、进入NioServerSocketChannel的构造器
```
  public NioServerSocketChannel() {
        this(newSocket(DEFAULT_SELECTOR_PROVIDER));
    }
```
6、NioServerSocketChannel重载构造器
```
    /**
     * Create a new instance using the given {@link ServerSocketChannel}.
     */
    public NioServerSocketChannel(ServerSocketChannel channel) {
        super(null, channel, SelectionKey.OP_ACCEPT);
        config = new NioServerSocketChannelConfig(this, javaChannel().socket());
    }
```
7、进入super 类 AbstractNioMessageChannel的构造器
```
   protected AbstractNioMessageChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
        super(parent, ch, readInterestOp);
    }
```
8、进入super类AbstractNioChannel的构造器
```
    protected AbstractNioChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
        super(parent);
        this.ch = ch;
        this.readInterestOp = readInterestOp;
        try {
            ch.configureBlocking(false);
        } catch (IOException e) {
            try {
                ch.close();
            } catch (IOException e2) {
                if (logger.isWarnEnabled()) {
                    logger.warn(
                            "Failed to close a partially initialized socket.", e2);
                }
            }

            throw new ChannelException("Failed to enter non-blocking mode.", e);
        }
    }
```
9、进入super类AbstractChannel的构造器：
```
    protected AbstractChannel(Channel parent) {
        this.parent = parent;
        id = newId();
        unsafe = newUnsafe();
        pipeline = newChannelPipeline();//ChannelPipeline被实例化
    }
```

10、进入newChannelPipeline的方法：

```
    protected DefaultChannelPipeline newChannelPipeline() {
        return new DefaultChannelPipeline(this);//返回的是一个DefaultChannelPipeline，并且DefaultChannelPipeline持有
        //AbstractChannel的引用，即Channel的引用
    }
```
11、进入DefaultChannelPipeline的构造器：

```
public class DefaultChannelPipeline implements ChannelPipeline {
...略
    final AbstractChannelHandlerContext head;
    final AbstractChannelHandlerContext tail;
    private final Channel channel;//ChannelPipeline 持有Channel的引用
...略
    protected DefaultChannelPipeline(Channel channel) {
        this.channel = ObjectUtil.checkNotNull(channel, "channel");//给DefaultChannelPipeline的Channel引用赋值。
        succeededFuture = new SucceededChannelFuture(channel, null);
        voidPromise =  new VoidChannelPromise(channel, true);

        tail = new TailContext(this);//构造尾结点
        head = new HeadContext(this);//构造头结点
        //组成链表
        head.next = tail;
        tail.prev = head;
    }
...略
}
```
可以看到Channel所有的ChannelPipeline组成了一个链表的形式，回想我们之前分析的ServerBootstrap类的启动初始化过程的init方法：

```
 void init(Channel channel) throws Exception {
	 ChannelPipeline p = channel.pipeline();
	 p.addLast(new ChannelInitializer<Channel>() {
            @Override
            public void initChannel(final Channel ch) throws Exception {
                final ChannelPipeline pipeline = ch.pipeline();
                ChannelHandler handler = config.handler();
                if (handler != null) {
                    pipeline.addLast(handler);
                }

                ch.eventLoop().execute(new Runnable() {
                    @Override
                    public void run() {
                        pipeline.addLast(new ServerBootstrapAcceptor(
                                ch, currentChildGroup, currentChildHandler, currentChildOptions, currentChildAttrs));
                    }
                });
            }
        });
```
当拿到ChannelPipeline 之后，紧接着会在链表上添加一个ChannelInitializer，以及我们开发者自己写的Initializer，都是在链表上执行add方法，加入到链表里边：
```
public class MyServerInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipline = ch.pipeline();
        pipline.addLast(new LengthFieldBasedFrameDecoder(Integer.MAX_VALUE,0,4,0,4));
        pipline.addLast(new LengthFieldPrepender(4));
        pipline.addLast(new StringDecoder(CharsetUtil.UTF_8));
        pipline.addLast(new StringEncoder(CharsetUtil.UTF_8));
        pipline.addLast(new MyServerHandler());
    }
}
```
那么我们有必要看一下ChannelPipeline的doc：

```
/**
 * A list of {@link ChannelHandler}s which handles or intercepts inbound events and outbound operations of a
 * {@link Channel}.  {@link ChannelPipeline} implements an advanced form of the
 * <a href="http://www.oracle.com/technetwork/java/interceptingfilter-142169.html">Intercepting Filter</a> pattern
 * to give a user full control over how an event is handled and how the {@link ChannelHandler}s in a pipeline
 * interact with each other.
ChannelPipeline是一个处理或者拦截Channel的出栈事件或者入栈操作的ChannelHandler列表，
ChannelPipeline实现了一种高效的拦截过滤器模式的形式来让用户完全控制一个事件怎样处理
和pipeline的ChannelHandler怎样和其他ChannelHandler交互。
 * <h3>Creation of a pipeline</h3>
 * Each channel has its own pipeline and it is created automatically when a new channel is created.
 * 每一个channel 都有自己的pipeline，就是在channel 创建的时候自动创建一个pipeline
 * <h3>How an event flows in a pipeline</h3>
 * 一个事件是怎样在pipeline流动的。
 * The following diagram describes how I/O events are processed by {@link ChannelHandler}s in a {@link ChannelPipeline}
 * typically. An I/O event is handled by either a {@link ChannelInboundHandler} or a {@link ChannelOutboundHandler}
 * and be forwarded to its closest handler by calling the event propagation methods defined in
 * {@link ChannelHandlerContext}, such as {@link ChannelHandlerContext#fireChannelRead(Object)} and
 * {@link ChannelHandlerContext#write(Object)}.
 * 下面的图描述了一个I/O事件一般是怎样在ChannelPipeline里的ChannelHandler处理的，
 * 一个I/O事件要么被ChannelInboundHandler处理，要么
 * 里边的事件传播方法转发给最近的一个处理器，比如ChannelHandlerContext#fireChannelRead(Object)
 * 和ChannelHandlerContext#write(Object)。
 * <pre>
 *                                                 I/O Request
 *                                            via {@link Channel} or
 *                                        {@link ChannelHandlerContext}
 *                                                      |
 *  +---------------------------------------------------+---------------+
 *  |                           ChannelPipeline         |               |
 *  |                                                  \|/              |
 *  |    +---------------------+            +-----------+----------+    |
 *  |    | Inbound Handler  N  |            | Outbound Handler  1  |    |
 *  |    +----------+----------+            +-----------+----------+    |
 *  |              /|\                                  |               |
 *  |               |                                  \|/              |
 *  |    +----------+----------+            +-----------+----------+    |
 *  |    | Inbound Handler N-1 |            | Outbound Handler  2  |    |
 *  |    +----------+----------+            +-----------+----------+    |
 *  |              /|\                                  .               |
 *  |               .                                   .               |
 *  | ChannelHandlerContext.fireIN_EVT() ChannelHandlerContext.OUT_EVT()|
 *  |        [ method call]                       [method call]         |
 *  |               .                                   .               |
 *  |               .                                  \|/              |
 *  |    +----------+----------+            +-----------+----------+    |
 *  |    | Inbound Handler  2  |            | Outbound Handler M-1 |    |
 *  |    +----------+----------+            +-----------+----------+    |
 *  |              /|\                                  |               |
 *  |               |                                  \|/              |
 *  |    +----------+----------+            +-----------+----------+    |
 *  |    | Inbound Handler  1  |            | Outbound Handler  M  |    |
 *  |    +----------+----------+            +-----------+----------+    |
 *  |              /|\                                  |               |
 *  +---------------+-----------------------------------+---------------+
 *                  |                                  \|/
 *  +---------------+-----------------------------------+---------------+
 *  |               |                                   |               |
 *  |       [ Socket.read() ]                    [ Socket.write() ]     |
 *  |                                                                   |
 *  |  Netty Internal I/O Threads (Transport Implementation)            |
 *  +-------------------------------------------------------------------+
 * </pre>
通过上图可以看到入栈的和出栈的处理器互不干扰。
 * An inbound event is handled by the inbound handlers in the bottom-up direction as shown on the left side of the
 * diagram.  An inbound handler usually handles the inbound data generated by the I/O thread on the bottom of the
 * diagram.  The inbound data is often read from a remote peer via the actual input operation such as
 * {@link SocketChannel#read(ByteBuffer)}.  If an inbound event goes beyond the top inbound handler, it is discarded
 * silently, or logged if it needs your attention.
 * 在左图，一个入栈事件是从下到上的顺序被绑定的处理器处理的，一个入栈处理器通常处理从I/O线程生成的数据，
 * 这些入栈数据一般是从远程实际的操作
 *  它将会被悄无声息的丢弃，或者需要的话使用日志
 * 记录下来。
 * * <p>
 * An outbound event is handled by the outbound handler in the top-down direction as shown on the right side of the
 * diagram.  An outbound handler usually generates or transforms the outbound traffic such as write requests.
 * If an outbound event goes beyond the bottom outbound handler, it is handled by an I/O thread associated with the
 * {@link Channel}. The I/O thread often performs the actual output operation such as
 * {@link SocketChannel#write(ByteBuffer)}.
 * <p>
 * 右图，一个出栈事件会被出栈处理器处理，一个出栈处理器生成或者传输出栈数据，比如写请求，
 * 如果一个出栈事件超出最底层的处理器，那么他将会被I/O
 * 线程处理，与其关联的SocketChannel#write(ByteBuffer)操作。
  * For example, let us assume that we created the following pipeline:
  * 加入我们假设创建了如下的pipeline
 * <pre>
 * {@link ChannelPipeline} p = ...;
 * p.addLast("1", new InboundHandlerA());//入栈处理器
 * p.addLast("2", new InboundHandlerB());//入栈处理器
 * p.addLast("3", new OutboundHandlerA());//出栈处理器
 * p.addLast("4", new OutboundHandlerB());//出栈处理器
 * p.addLast("5", new InboundOutboundHandlerX());//既是入栈又是出栈处理器
 * </pre>

  * In the example above, the class whose name starts with {@code Inbound} means it is an inbound handler.
 * The class whose name starts with {@code Outbound} means it is a outbound handler.
 * 在前边提到的例子中，以Inbound开头的都是入栈处理器，以Outbound开头的都是出栈处理器。
 * <p>
 * In the given example configuration, the handler evaluation order is 1, 2, 3, 4, 5 when an event goes inbound.
 * When an event goes outbound, the order is 5, 4, 3, 2, 1.  On top of this principle, {@link ChannelPipeline} skips
 * the evaluation of certain handlers to shorten the stack depth:
根据上边的原理，ChannelPipeline会忽略掉某些处理器来减
 * 栈的深度。
 * <ul>
 * <li>3 and 4 don't implement {@link ChannelInboundHandler}, and therefore the actual evaluation order of an inbound
 *     event will be: 1, 2, and 5.</li>
 * 3和4没有实现ChannelInboundHandler，因此实际的入栈顺序是1, 2, 5
 * <li>1 and 2 don't implement {@link ChannelOutboundHandler}, and therefore the actual evaluation order of a
 *     outbound event will be: 5, 4, and 3.</li>
 * 1和2没有实现ChannelOutboundHandler，因此出栈顺序是 5, 4, 3
 * <li>If 5 implements both {@link ChannelInboundHandler} and {@link ChannelOutboundHandler}, the evaluation order of
 *     an inbound and a outbound event could be 125 and 543 respectively.</li>
 * 5实现了ChannelInboundHandler和ChannelOutboundHandler，出栈和入栈都包含5。只是一个在结尾，一个在开头。
 * </ul>
 * <h3>Forwarding an event to the next handler</h3>
 * 将事件转发给下一个处理器。
 * As you might noticed in the diagram shows, a handler has to invoke the event propagation methods in
 * {@link ChannelHandlerContext} to forward an event to its next handler.  Those methods include:
 * 你可能在图中可以看到，一个处理器调用ChannelHandlerContext的事件传播方法转发给下一个处理器，这些方法包括：
 * <ul>
 * <li>Inbound event propagation methods:
 *    入栈事件传播方法
 *     <ul>
 *     <li>{@link ChannelHandlerContext#fireChannelRegistered()}</li>
 *     <li>{@link ChannelHandlerContext#fireChannelActive()}</li>
 *     <li>{@link ChannelHandlerContext#fireChannelRead(Object)}</li>
 *     <li>{@link ChannelHandlerContext#fireChannelReadComplete()}</li>
 *     <li>{@link ChannelHandlerContext#fireExceptionCaught(Throwable)}</li>
 *     <li>{@link ChannelHandlerContext#fireUserEventTriggered(Object)}</li>
 *     <li>{@link ChannelHandlerContext#fireChannelWritabilityChanged()}</li>
 *     <li>{@link ChannelHandlerContext#fireChannelInactive()}</li>
 *     <li>{@link ChannelHandlerContext#fireChannelUnregistered()}</li>
 *     </ul>
 * </li>
 * <li>Outbound event propagation methods:
 * 出栈事件传播方法
 *     <ul>
 *     <li>{@link ChannelHandlerContext#bind(SocketAddress, ChannelPromise)}</li>
 *     <li>{@link ChannelHandlerContext#connect(SocketAddress, SocketAddress, ChannelPromise)}</li>
 *     <li>{@link ChannelHandlerContext#write(Object, ChannelPromise)}</li>
 *     <li>{@link ChannelHandlerContext#flush()}</li>
 *     <li>{@link ChannelHandlerContext#read()}</li>
 *     <li>{@link ChannelHandlerContext#disconnect(ChannelPromise)}</li>
 *     <li>{@link ChannelHandlerContext#close(ChannelPromise)}</li>
 *     <li>{@link ChannelHandlerContext#deregister(ChannelPromise)}</li>
 *     </ul>
 * </li>
 * </ul>
 *
 * and the following example shows how the event propagation is usually done:
 *下面的实例展示了事件传播是怎么做的
 * <pre>
 * public class MyInboundHandler extends {@link ChannelInboundHandlerAdapter} {
 *     {@code @Override}
 *     public void channelActive({@link ChannelHandlerContext} ctx) {
 *         System.out.println("Connected!");
 *         ctx.fireChannelActive();//传播下一个
 *     }
 * }
 *
 * public class MyOutboundHandler extends {@link ChannelOutboundHandlerAdapter} {
 *     {@code @Override}
 *     public void close({@link ChannelHandlerContext} ctx, {@link ChannelPromise} promise) {
 *         System.out.println("Closing ..");
 *         ctx.close(promise);//关闭
 *     }
 * }
 * </pre>
 *
 * <h3>Building a pipeline</h3>
 * 创建pipeline
 * <p>
 * A user is supposed to have one or more {@link ChannelHandler}s in a pipeline to receive I/O events (e.g. read) and
 * to request I/O operations (e.g. write and close).  For example, a typical server will have the following handlers
 * in each channel's pipeline, but your mileage may vary depending on the complexity and characteristics of the
 * protocol and business logic:
 *一个用户可以支持在pipeline 中有一个或者多个ChannelHandler来接受I/O 事件，
 比如读操作，或者请求I/O操作，比如写后者关闭，比如，一个典型
 的服务的每个channel下的pipeline有下面的处理器，但是会因为复杂度和协议的特性或者业务逻辑而有一些不同：
 * <ol>
 * <li>Protocol Decoder - translates binary data (e.g. {@link ByteBuf}) into a Java object.</li>
 * 协议解码器 - 将二级制转换为一个Java对象，比如ByteBuf，
 * <li>Protocol Encoder - translates a Java object into binary data.</li>
 * 协议解码器，将一个Java对象转换为一个二进制数据
 * <li>Business Logic Handler - performs the actual business logic (e.g. database access).</li>
 * 业务逻辑处理器 - 实现实际的业务逻辑.
 * </ol>
 *
 * and it could be represented as shown in the following example:
 *这些会通过如下的业务逻辑来体现。
 * <pre>
 * static final {@link EventExecutorGroup} group = new {@link DefaultEventExecutorGroup}(16);
 * ...
 *
 * {@link ChannelPipeline} pipeline = ch.pipeline();
 *
 * pipeline.addLast("decoder", new MyProtocolDecoder());
 * pipeline.addLast("encoder", new MyProtocolEncoder());
 *
 * // Tell the pipeline to run MyBusinessLogicHandler's event handler methods
 * // in a different thread than an I/O thread so that the I/O thread is not blocked by
 * // a time-consuming task.
 * // If your business logic is fully asynchronous or finished very quickly, you don't
 * // need to specify a group.
 * 告诉pipeline 在另外一个I/O 线程里边执行MyBusinessLogicHandler的事件处理器的方法，
 * 这样就不会阻塞实时消费任务。
 * 如果你得业务逻辑是同步的或者完成速度非常快，就不需要指定这个group。
 * pipeline.addLast(group, "handler", new MyBusinessLogicHandler());
 * 这种方式是netty指定的标准方式，另外一种方式是在MyBusinessLogicHandler里边创建线程池也是可以的。
 *  * </pre>
 *
 * <h3>Thread safety</h3>
 * 线程安全性
 * <p>
 * A {@link ChannelHandler} can be added or removed at any time because a {@link ChannelPipeline} is thread safe.
 * For example, you can insert an encryption handler when sensitive information is about to be exchanged,
 * after the exchange.
 * ChannelHandler可以随时添加和删除，因为ChannelPipeline是线程安全的，比如，
 * 当敏感的数据被交换的时候你可以插入一个加密的处理器，
 * 当交换完毕再删除掉。
 */
```
