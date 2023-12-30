---
title: netty源码分析(十一)Netty常量池实现及ChannelOption与Attribute作用分析
date: 2018-10-04 14:36:33
tags: netty常量池 ChannelOption Attribute
categories: netty
---

ServerBootstrap的init方法是服务初始的关键逻辑：

<!-- more -->
```
    void init(Channel channel) throws Exception {
        final Map<ChannelOption<?>, Object> options = options0();//是一个linkedHashMap
        synchronized (options) {
            setChannelOptions(channel, options, logger);
        }

        final Map<AttributeKey<?>, Object> attrs = attrs0();
        synchronized (attrs) {
            for (Entry<AttributeKey<?>, Object> e: attrs.entrySet()) {
                @SuppressWarnings("unchecked")
                AttributeKey<Object> key = (AttributeKey<Object>) e.getKey();
                channel.attr(key).set(e.getValue());
            }
        }

        ChannelPipeline p = channel.pipeline();

        final EventLoopGroup currentChildGroup = childGroup;
        final ChannelHandler currentChildHandler = childHandler;
        final Entry<ChannelOption<?>, Object>[] currentChildOptions;
        final Entry<AttributeKey<?>, Object>[] currentChildAttrs;
        synchronized (childOptions) {
            currentChildOptions = childOptions.entrySet().toArray(newOptionArray(childOptions.size()));
        }
        synchronized (childAttrs) {
            currentChildAttrs = childAttrs.entrySet().toArray(newAttrArray(childAttrs.size()));
        }

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
    }
```
这里边有2个重要的类：ChannelOption和AttributeKey。
ChannelOption：
![这里写图片描述](2018/10/04/netty源码分析-十一-Netty常量池实现及ChannelOption与Attribute作用分析/20171028105501784.png)

```
ChannelOption的doc说明
/**
 * A {@link ChannelOption} allows to configure a {@link ChannelConfig} in a type-safe
 * way. Which {@link ChannelOption} is supported depends on the actual implementation
 * of {@link ChannelConfig} and may depend on the nature of the transport it belongs
 * to.
 *
 * @param <T>   the type of the value which is valid for the {@link ChannelOption}
 */
 ChannelOption是一种以一种安全的方式配置ChannelConfig，ChannelOption支持的类型个依赖于ChannelConfig的实际类型
 和他所属的传输层的本质。
 T 类型是ChannelOption的值得类型
public class ChannelOption<T> extends AbstractConstant<ChannelOption<T>> {
    private static final ConstantPool<ChannelOption<Object>> pool = new ConstantPool<ChannelOption<Object>>() {
        protected ChannelOption<Object> newConstant(int id, String name) {
            return new ChannelOption<Object>(id, name);
        }
    };
    ...略
```
ChannelOption的主要作用是用来存在TCP之类的传输层的一些协议的参数，比如：

```
   public static final ChannelOption<Boolean> SO_BROADCAST = valueOf("SO_BROADCAST");
    public static final ChannelOption<Boolean> SO_KEEPALIVE = valueOf("SO_KEEPALIVE");
    public static final ChannelOption<Integer> SO_SNDBUF = valueOf("SO_SNDBUF");
    public static final ChannelOption<Integer> SO_RCVBUF = valueOf("SO_RCVBUF");
    public static final ChannelOption<Boolean> SO_REUSEADDR = valueOf("SO_REUSEADDR");
    public static final ChannelOption<Integer> SO_LINGER = valueOf("SO_LINGER");
    public static final ChannelOption<Integer> SO_BACKLOG = valueOf("SO_BACKLOG");
    public static final ChannelOption<Integer> SO_TIMEOUT = valueOf("SO_TIMEOUT");
```
紧接着我们进入AbstractConstant：

```
public abstract class AbstractConstant<T extends AbstractConstant<T>> implements Constant<T> {}
```
AbstractConstant实现了Constant接口:

```
/**
 * A singleton which is safe to compare via the {@code ==} operator. Created and managed by {@link ConstantPool}.
 * 是单例的并且是可以用过“==”安全比较的。使用ConstantPool创建和管理
 */
public interface Constant<T extends Constant<T>> extends Comparable<T> {

    /**
     * Returns the unique number assigned to this {@link Constant}.
     * 返回唯一的编码
     */
    int id();

    /**
     * Returns the name of this {@link Constant}.
     * 返回一个名称
     */
    String name();
}
```
ConstantPool是什么:

```
/**
 * A pool of {@link Constant}s.
 *一个Constant的常量池
 * @param <T> the type of the constant
 * T是constant类型
 */
public abstract class ConstantPool<T extends Constant<T>> {

    private final ConcurrentMap<String, T> constants = PlatformDependent.newConcurrentHashMap();
    //返回Java.util里边的ConcurrentHashMap
    private final AtomicInteger nextId = new AtomicInteger(1);
    ....略
    /**
     * Get existing constant by name or creates new one if not exists. Threadsafe
     * 通过name得到一个已近存在的constant ，没有的话直接创建，线程安全的
     * @param name the name of the {@link Constant}
     * 常量的名字
     */
    private T getOrCreate(String name) {
        T constant = constants.get(name);//根据名字从ConcurrentHashMap里边获取
        if (constant == null) {//不存在
            final T tempConstant = newConstant(nextId(), name);//构建一个，id是随机出来的
            constant = constants.putIfAbsent(name, tempConstant);//放入ConcurrentHashMap里边
            if (constant == null) {//考虑多线程的时候，二次判空处理
                return tempConstant;
            }
        }

        return constant;
    }
    public final int nextId() {
        return nextId.getAndIncrement();
    }
        ....略
```

回到ChannelOption,ChannelOption不存储值，只存储值得类型.
回到init方法，我们进入setChannelOptions里边：

```
    static void setChannelOptions(Channel channel, Map<ChannelOption<?>, Object> options, InternalLogger logger) {
        for (Map.Entry<ChannelOption<?>, Object> e: options.entrySet()) {
            setChannelOption(channel, e.getKey(), e.getValue(), logger);
        }
    }
```
setChannelOption：
```
    private static void setChannelOption(
            Channel channel, ChannelOption<?> option, Object value, InternalLogger logger) {
        try {
            if (!channel.config().setOption((ChannelOption<Object>) option, value)) {//将ChannelOption作为key，value
            //作为value塞到config里边
                logger.warn("Unknown channel option '{}' for channel '{}'", option, channel);
            }
        } catch (Throwable t) {
            logger.warn(
                    "Failed to set channel option '{}' with value '{}' for channel '{}'", option, value, channel, t);
        }
    }
```
这是在ChannelOption上层我们看到的设置过程，那么在ChannelOption里边是怎么一些细节呢?
以ChannelOption里边的任意一个参数为入口
```
    public static final ChannelOption<Boolean> AUTO_CLOSE = valueOf("AUTO_CLOSE");
```

```
    public static <T> ChannelOption<T> valueOf(String name) {
        return (ChannelOption<T>) pool.valueOf(name);
    }
```
进入ConstantPool

```

    /**
     * Returns the {@link Constant} which is assigned to the specified {@code name}.
     * If there's no such {@link Constant}, a new one will be created and returned.
     * Once created, the subsequent calls with the same {@code name} will always return the previously created one
     * (i.e. singleton.)
     *
     * @param name the name of the {@link Constant}
     */
    public T valueOf(String name) {
        checkNotNullAndNotEmpty(name);
        return getOrCreate(name);
    }
```
进入ConstantPool的getOrCreate
```
    /**
     * Get existing constant by name or creates new one if not exists. Threadsafe
     *
     * @param name the name of the {@link Constant}
     */
    private T getOrCreate(String name) {
        T constant = constants.get(name);
        if (constant == null) {
            final T tempConstant = newConstant(nextId(), name);
            constant = constants.putIfAbsent(name, tempConstant);
            if (constant == null) {
                return tempConstant;
            }
        }

        return constant;
    }
```
这个就是我们刚才看到的那个方法，为什么ChannelOption是线程安全的，原因就在于此,并且ChannelOption不存储值，只是存储值得类型。
在服务端我们用的时候可以这样设置ChannelOption：

```
serverBootstrap.group(bossGroup,workerGroup).channel(NioServerSocketChannel.class).handler(new LoggingHandler(LogLevel.WARN)).option(option,value)
```
ChannelOption是用来配置ChannelConfig的，那么看一下ChannelConfig：

```
/**
 * A set of configuration properties of a {@link Channel}.
 * 一个Channel配置属性的集合
 * <p>
 * Please down-cast to more specific configuration type such as
 * {@link SocketChannelConfig} or use {@link #setOptions(Map)} to set the
 * transport-specific properties:
 * 通过向下类型转换比如SocketChannelConfig或者使用setOptions(Map)设置特殊传输属性
 * <pre>
 * {@link Channel} ch = ...;
 * {@link SocketChannelConfig} cfg = <strong>({@link SocketChannelConfig}) ch.getConfig();</strong>
 * cfg.setTcpNoDelay(false);
 * </pre>
 *
 * <h3>Option map</h3>
 *
 * An option map property is a dynamic write-only property which allows
 * the configuration of a {@link Channel} without down-casting its associated
 * {@link ChannelConfig}.  To update an option map, please call {@link #setOptions(Map)}.
 * 使用map将所有的属性进行设置，它们的key可以是如下的一些参数，value是向下类型装换的类。
 * <p>
 * All {@link ChannelConfig} has the following options:
 *
 * <table border="1" cellspacing="0" cellpadding="6">
 * <tr>
 * <th>Name</th><th>Associated setter method</th>
 * </tr><tr>
 * <td>{@link ChannelOption#CONNECT_TIMEOUT_MILLIS}</td><td>{@link #setConnectTimeoutMillis(int)}</td>
 * </tr><tr>
 * <td>{@link ChannelOption#WRITE_SPIN_COUNT}</td><td>{@link #setWriteSpinCount(int)}</td>
 * </tr><tr>
 * <td>{@link ChannelOption#WRITE_BUFFER_WATER_MARK}</td><td>{@link #setWriteBufferWaterMark(WriteBufferWaterMark)}</td>
 * </tr><tr>
 * <td>{@link ChannelOption#ALLOCATOR}</td><td>{@link #setAllocator(ByteBufAllocator)}</td>
 * </tr><tr>
 * <td>{@link ChannelOption#AUTO_READ}</td><td>{@link #setAutoRead(boolean)}</td>
 * </tr>
 * </table>
 * <p>
 * More options are available in the sub-types of {@link ChannelConfig}.  For
 * example, you can configure the parameters which are specific to a TCP/IP
 * socket as explained in {@link SocketChannelConfig}.
 * 更多的参数设置可以在ChannelConfig子类类型里边设置，比如你可以在SocketChannelConfig里边指定TCP/IP的一些设置
 */
```
对于ChannelConfig来说他是对Channel一个整个配置的信息。

再来看一下AttributeKey：
![这里写图片描述](2018/10/04/netty源码分析-十一-Netty常量池实现及ChannelOption与Attribute作用分析/20171028115151418.png)
可以看到它和ChannelOption的上层结构是一样的。

```
/**
 * Key which can be used to access {@link Attribute} out of the {@link AttributeMap}. Be aware that it is not be
 * possible to have multiple keys with the same name.
 * 一个在AttributeMap外部访问Attribute的key，不会出现2个相同的key
 * @param <T>   the type of the {@link Attribute} which can be accessed via this {@link AttributeKey}.
 * T类型是一个Attribute类型，可以通过AttributeKey访问
 */
@SuppressWarnings("UnusedDeclaration") // 'T' is used only at compile time
public final class AttributeKey<T> extends AbstractConstant<AttributeKey<T>> {

    private static final ConstantPool<AttributeKey<Object>> pool = new ConstantPool<AttributeKey<Object>>() {
        @Override
        protected AttributeKey<Object> newConstant(int id, String name) {
            return new AttributeKey<Object>(id, name);
        }
    };
```
可以看到AttributeKey类的结构和ChannelOption是一样的，都有一个ConstantPool。
 和AttributeKey相关的一个组件Attribute，Attribute是什么呢？


```
/**
 * An attribute which allows to store a value reference. It may be updated atomically and so is thread-safe.
 *用来存放值得引用，可以进行原子操作，并且是线程安全的。
 * @param <T>   the type of the value it holds.
 * T是Attribute持有的值得类型
 */
public interface Attribute<T> {
```
AttributeKey作为AttributeMap的key，Attribute作为AttributeMap的value：

```
/**
 * Holds {@link Attribute}s which can be accessed via {@link AttributeKey}.
 *通过AttributeKey访问Attribute
 * Implementations must be Thread-safe.
 * 实现类必须是线程安全的
 */
public interface AttributeMap {
    /**
     * Get the {@link Attribute} for the given {@link AttributeKey}. This method will never return null, but may return
     * an {@link Attribute} which does not have a value set yet.
     */
    <T> Attribute<T> attr(AttributeKey<T> key);

    /**
     * Returns {@code} true if and only if the given {@link Attribute} exists in this {@link AttributeMap}.
     */
    <T> boolean hasAttr(AttributeKey<T> key);
}
```
AttributeMap 、 Attribute 、 AttributeKey 分别对应Map、value、Key，netty对他们进行了一次封装。
