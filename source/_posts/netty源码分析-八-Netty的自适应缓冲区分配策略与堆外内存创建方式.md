---
title: netty源码分析(八)Netty的自适应缓冲区分配策略与堆外内存创建方式
date: 2018-10-04 14:29:18
tags: 自适应缓冲区分配策略 堆外内存创建
categories: netty
---

我们总结一下netty的模式：
![这里写图片描述](20170923212403693.png)

bossGroup将得到的selectedKyes中的socketchannel接收到，然后封装成NioServerSocketChannel,NioServerSocketChannel注册到workerGroup里边，最后客户端直接和workerGroup 里边的NioServerSocketChannel通信交换信息，即bossGroup负责派发，workerGroup 负责真正数据的处理。

我们在处理实际的业务数据的时候，一般是在handler里边的方法去实现业务逻辑:
channelRead0这个方法肯定是被netty框架回调=被执行，但是我们的业务逻辑如果复杂，整个channelRead0需要执行很长时间，虽然netty性能很高，但是过长时间的业务处理使得整体速度变慢，对于这种情况，我们需要建立一个业务的线程组放在channelRead0里边，做成异步的处理，处理完毕用 channel写回到客户端处理结果。
```
public class MyServerHandler extends SimpleChannelInboundHandler<String> {
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, String msg) throws Exception {
        System.out.println(ctx.channel().remoteAddress()+" --> "+msg);
        ctx.channel().writeAndFlush("from server : "+ UUID.randomUUID());
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```
然后下一个知识点是关于缓冲区的申请是怎么回事、
回到NioServerSocketChannel:

```
 /**
     * Create a new instance
     * 默认构造器
     */
    public NioServerSocketChannel() {
        this(newSocket(DEFAULT_SELECTOR_PROVIDER));
    }

    /**
     * Create a new instance using the given {@link ServerSocketChannel}.
     * 默认构造器调用带ServerSocketChannel参数的构造器
     */
    public NioServerSocketChannel(ServerSocketChannel channel) {
        super(null, channel, SelectionKey.OP_ACCEPT);//这一部分之前我们讲解过，不做介绍。
        config = new NioServerSocketChannelConfig(this, javaChannel().socket());
        //javaChannel()  是ServerSocketChannel，javaChannel().socket()就是一个ServerSocketChannel得到的ServerSocket。
    }

    @Override
    //获取无参构造器设置的ServerSocketChannel
    protected ServerSocketChannel javaChannel() {
        return (ServerSocketChannel) super.javaChannel();
    }

	//紧接着进入NioServerSocketChannelConfig的构造器，NioServerSocketChannelConfig是NioServerSocketChannel的内部类。
    private final class NioServerSocketChannelConfig extends DefaultServerSocketChannelConfig {
        private NioServerSocketChannelConfig(NioServerSocketChannel channel, ServerSocket javaSocket) {
            super(channel, javaSocket);//调用DefaultServerSocketChannelConfig的构造器
        }

        @Override
        protected void autoReadCleared() {
            clearReadPending();
        }
    }

```

进入DefaultServerSocketChannelConfig的构造器：

```
public class DefaultServerSocketChannelConfig extends DefaultChannelConfig
                                              implements ServerSocketChannelConfig{
    ....略
    public DefaultServerSocketChannelConfig(ServerSocketChannel channel, ServerSocket javaSocket) {
        super(channel);//进入DefaultChannelConfig的构造器
        if (javaSocket == null) {
            throw new NullPointerException("javaSocket");
        }
        this.javaSocket = javaSocket;
    }
     ....略
}
```
DefaultChannelConfig构造器：

```
    public DefaultChannelConfig(Channel channel) {
        this(channel, new AdaptiveRecvByteBufAllocator());//Channel是NioServerSocketChannel
    }
```
这里见到一个新的类AdaptiveRecvByteBufAllocator，适配的字节缓冲器，进去看看：

```
/**
 * The {@link RecvByteBufAllocator} that automatically increases and
 * decreases the predicted buffer size on feed back.
 * <p>RecvByteBufAllocator是一个对buffer的大小根据反馈自动自动增长或者减少的这么一个类。
 * It gradually increases the expected number of readable bytes if the previous
 * read fully filled the allocated buffer.  It gradually decreases the expected
 * number of readable bytes if the read operation was not able to fill a certain
 * amount of the allocated buffer two times consecutively.  Otherwise, it keeps
 * returning the same prediction.
 * 如果前一次的缓冲区的申请大小满了，那么本次会自动增加容量，同样的道理如果上2次没有填满，那么本次的容量会减少。
 * */
public class AdaptiveRecvByteBufAllocator extends DefaultMaxMessagesRecvByteBufAllocator {

    static final int DEFAULT_MINIMUM = 64;
    static final int DEFAULT_INITIAL = 1024;
    static final int DEFAULT_MAXIMUM = 65536;

    private static final int INDEX_INCREMENT = 4;
    private static final int INDEX_DECREMENT = 1;

    private static final int[] SIZE_TABLE;

    //静态代码块的作用是对SIZE_TABLE数组填写1~38的坐标的值是16，32，48....一直到65536
    //自动减少或者增加的幅度就是来自于这个数组。具体逻辑在HandleImpl对的record方法。
    static {
        List<Integer> sizeTable = new ArrayList<Integer>();
        for (int i = 16; i < 512; i += 16) {
            sizeTable.add(i);//1~16的设置是16到（512-16）
        }

        for (int i = 512; i > 0; i <<= 1) {
            sizeTable.add(i);//从512到65536
        }

        SIZE_TABLE = new int[sizeTable.size()];
        for (int i = 0; i < SIZE_TABLE.length; i ++) {
            SIZE_TABLE[i] = sizeTable.get(i);//填写到SIZE_TABLE数组
        }
    }

    /**
     * Creates a new predictor with the default parameters.  With the default
     * parameters, the expected buffer size starts from {@code 1024}, does not
     * go down below {@code 64}, and does not go up above {@code 65536}.
     */
    public AdaptiveRecvByteBufAllocator() {
        this(DEFAULT_MINIMUM, DEFAULT_INITIAL, DEFAULT_MAXIMUM);//默认是是DEFAULT_MINIMUM（也是最小值，即64）
        //初始大小DEFAULT_INITIAL（即1024），最大值是DEFAULT_MAXIMUM（即65536）
    }
.....略。。。
    private final class HandleImpl extends MaxMessageHandle {
        private final int minIndex;
        private final int maxIndex;
        private int index;
        private int nextReceiveBufferSize;
        private boolean decreaseNow;

        public HandleImpl(int minIndex, int maxIndex, int initial) {
            this.minIndex = minIndex;
            this.maxIndex = maxIndex;

            index = getSizeTableIndex(initial);
            nextReceiveBufferSize = SIZE_TABLE[index];
        }

        @Override
        //得到预测值
        public int guess() {
            return nextReceiveBufferSize;
        }

       //计算预测值
        private void record(int actualReadBytes) {
            if (actualReadBytes <= SIZE_TABLE[Math.max(0, index - INDEX_DECREMENT - 1)]) {
                if (decreaseNow) {
                    index = Math.max(index - INDEX_DECREMENT, minIndex);
                    nextReceiveBufferSize = SIZE_TABLE[index];
                    decreaseNow = false;
                } else {
                    decreaseNow = true;
                }
            } else if (actualReadBytes >= nextReceiveBufferSize) {
                index = Math.min(index + INDEX_INCREMENT, maxIndex);
                nextReceiveBufferSize = SIZE_TABLE[index];
                decreaseNow = false;
            }
        }

        @Override
        public void readComplete() {
            record(totalBytesRead());
        }
    }
  ....略...
```

我们进入HandleImpl 的父类MaxMessageHandle 之中，里边有一个申请缓冲区的重要方法：

```
        @Override
        public ByteBuf allocate(ByteBufAllocator alloc) {
            return alloc.ioBuffer(guess());//guess()方法得到预测值，用来设置当前缓冲区的大小
        }
```
alloc.ioBuffer(）有很多实现方法，我们拿AbstractByteBufAllocator举例。
进入AbstractByteBufAllocator：

```
     /**
     PlatformDependent.hasUnsafe()会根据是否存在io.netty.noUnsafe配置返回boolean,如果是android系统返回false。
     */
    public ByteBuf ioBuffer(int initialCapacity) {
        if (PlatformDependent.hasUnsafe()) {
            return directBuffer(initialCapacity);
        }
        return heapBuffer(initialCapacity);
    }
```
看一下directBuffer（）方法：
```
    public ByteBuf directBuffer(int initialCapacity) {
        return directBuffer(initialCapacity, DEFAULT_MAX_CAPACITY);
    }
```
继续钻：

```
    @Override
    public ByteBuf directBuffer(int initialCapacity, int maxCapacity) {
        if (initialCapacity == 0 && maxCapacity == 0) {
            return emptyBuf;
        }
        validate(initialCapacity, maxCapacity);
        return newDirectBuffer(initialCapacity, maxCapacity);
    }
```
由于中间调用链比较长，不在列举，最后我们会找到我们熟悉的nio的API：

```
    protected ByteBuffer allocateDirect(int initialCapacity) {
        return ByteBuffer.allocateDirect(initialCapacity);
    }
```
即netty最终是用nio的ByteBuffer申请的直接内存。
同样的道理，堆内内存的申请也是如此：
heapBuffer(initialCapacity)方法最终的调用是这样：

```
    byte[] allocateArray(int initialCapacity) {
        return new byte[initialCapacity];
    }
```
由于是堆内内存直接是返回一个数组。
