---
title: netty源码分析(十二)Channel与ChannelHandler及ChannelHandlerContext之间的关系分析
date: 2018-10-04 14:38:13
tags: channel ChannelHandler ChannelHandlerContext
categories: netty
---

还是之前的init代码入口，上一节我们介绍了ChannelOption和AttributeKey，本次我们说下Channel与ChannelHandler及ChannelHandlerContext之间的关系分析。
```
<!-- more -->
void init(Channel channel) throws Exception {
        final Map<ChannelOption<?>, Object> options = options0();
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
先从ChannelInitializer，我们看下它的doc：

```

/**
 * A special {@link ChannelInboundHandler} which offers an easy way to initialize a {@link Channel} once it was
 * registered to its {@link EventLoop}.
 * 一个特殊的ChannelInboundHandler，提供了简单的方式来初始化Channel，通过注册到EventLoop里边来实现的。
 * Implementations are most often used in the context of {@link Bootstrap#handler(ChannelHandler)} ,
 * {@link ServerBootstrap#handler(ChannelHandler)} and {@link ServerBootstrap#childHandler(ChannelHandler)} to
 * setup the {@link ChannelPipeline} of a {@link Channel}.
 * 具体实现经常使用在Bootstrap#handler(ChannelHandler)、ServerBootstrap#handler(ChannelHandler)、
 * ServerBootstrap#childHandler(ChannelHandler)等来初始化Channel的ChannelPipeline
 * <pre>
 *  使用举例：
 * public class MyChannelInitializer extends {@link ChannelInitializer} {
 *     public void initChannel({@link Channel} channel) {
 *         channel.pipeline().addLast("myHandler", new MyHandler());
 *     }
 * }
 *
 * {@link ServerBootstrap} bootstrap = ...;
 * ...
 * bootstrap.childHandler(new MyChannelInitializer());
 * ...
 * </pre>
 * Be aware that this class is marked as {@link Sharable} and so the implementation must be safe to be re-used.
 *注意这个类是标记为Sharable的，所以在实现的时候必须是线程安全的。
 * @param <C>   A sub-type of {@link Channel}
 */
@Sharable
public abstract class ChannelInitializer<C extends Channel> extends ChannelInboundHandlerAdapter {

}
```
程序调用p.addLast(new ChannelInitializer<Channel>() ......这样的方式把ChannelInitializer放到ChannelPipeline当中，那么ChannelPipeline.addLast()的逻辑是怎样的呢？

```
    /**
     * Inserts {@link ChannelHandler}s at the last position of this pipeline.
     * 在pipeline的最后一个位置插入一个ChannelHandler
     * @param handlers  the handlers to insert last
     */
    ChannelPipeline addLast(ChannelHandler... handlers);
```
查看ChannelPipeline 的实现类DefaultChannelPipeline：
```
public class DefaultChannelPipeline implements ChannelPipeline {
...略
    @Override
    public final ChannelPipeline addLast(ChannelHandler... handlers) {
        return addLast(null, handlers);
    }
    ...略
```
调用了addLast(null, handlers),第一个参数为null：

```
即executor为null
    public final ChannelPipeline addLast(EventExecutorGroup executor, ChannelHandler... handlers) {
        if (handlers == null) {
            throw new NullPointerException("handlers");
        }
//循环遍历，调用addLast(executor, null, h)方法，第二个参数也为null
        for (ChannelHandler h: handlers) {
            if (h == null) {
                break;
            }
            addLast(executor, null, h);
        }

        return this;
    }
```
进入最终的方法，其中group为null，name为null：
```
    public final ChannelPipeline addLast(EventExecutorGroup group, String name, ChannelHandler handler) {
        final AbstractChannelHandlerContext newCtx;//首先声明一个AbstractChannelHandlerContext
        synchronized (this) {
            checkMultiplicity(handler);
            newCtx = newContext(group, filterName(name, handler), handler);
            addLast0(newCtx);

            // If the registered is false it means that the channel was not registered on an eventloop yet.
            // In this case we add the context to the pipeline and add a task that will call
            // ChannelHandler.handlerAdded(...) once the channel is registered.
            if (!registered) {
                newCtx.setAddPending();
                callHandlerCallbackLater(newCtx, true);
                return this;
            }

            EventExecutor executor = newCtx.executor();
            if (!executor.inEventLoop()) {
                newCtx.setAddPending();
                executor.execute(new Runnable() {
                    @Override
                    public void run() {
                        callHandlerAdded0(newCtx);
                    }
                });
                return this;
            }
        }
        callHandlerAdded0(newCtx);
        return this;
    }
```
上文提到AbstractChannelHandlerContext ，那么看下AbstractChannelHandlerContext 的doc是怎么一个东西：
```
abstract class AbstractChannelHandlerContext extends DefaultAttributeMap
        implements ChannelHandlerContext, ResourceLeakHint {
```
进入他的接口ChannelHandlerContext：

```

/**
 * Enables a {@link ChannelHandler} to interact with its {@link ChannelPipeline}
 * and other handlers. Among other things a handler can notify the next {@link ChannelHandler} in the
 * {@link ChannelPipeline} as well as modify the {@link ChannelPipeline} it belongs to dynamically.
 * 使ChannelHandler和它的ChannelPipeline以及其他的处理器之间进行交互，可以通知ChannelPipeline里的下一个ChannelHandler，
 * 以及动态的修改它属的ChannelPipeline
 * <h3>Notify</h3>
 *  通知
 * You can notify the closest handler in the same {@link ChannelPipeline} by calling one of the various methods
 * provided here.
 *你可以通过调用各种方法来通知ChannelPipeline里边最近的一个handler
 * Please refer to {@link ChannelPipeline} to understand how an event flows.
 * 请参考ChannelPipeline来理解事件的过程。
 * <h3>Modifying a pipeline</h3>
 * 修改一个pipeline
 * You can get the {@link ChannelPipeline} your handler belongs to by calling
 * {@link #pipeline()}.  A non-trivial application could insert, remove, or
 * replace handlers in the pipeline dynamically at runtime.
 *你可以调用所属处理器的pipeline()方法得到ChannelPipeline，一个应用可以在pipeline 里边动态的插入，删除或者替换处理器。
 * <h3>Retrieving for later use</h3>
 *  获取为了以后使用
 * You can keep the {@link ChannelHandlerContext} for later use, such as
 * triggering an event outside the handler methods, even from a different thread.
 * 你可以持有ChannelHandlerContext为了后续使用，比如在handler 方法之外触发一个事件，甚至是不同的线程。
 * <pre>
 * public class MyHandler extends {@link ChannelDuplexHandler} {
 *
 *     <b>private {@link ChannelHandlerContext} ctx;</b>
 *
 *     public void beforeAdd({@link ChannelHandlerContext} ctx) {
 *         <b>this.ctx = ctx;</b>//提前获得ChannelHandlerContext
 *     }
 *
 *     public void login(String username, password) {
 *         ctx.write(new LoginMessage(username, password));//之后的业务逻辑再去使用
 *     }
 *     ...
 * }
 * </pre>
 *
 * <h3>Storing stateful information</h3>
 *  存储状态信息
 * {@link #attr(AttributeKey)} allow you to
 * store and access stateful information that is related with a handler and its
 * context.  Please refer to {@link ChannelHandler} to learn various recommended
 * ways to manage stateful information.
 * AttributeKey允许你存储和它有关联的handler 以及它的上下文的状态信息，可以参考ChannelHandler学习不同的方式来管理状态信息
 * <h3>A handler can have more than one context</h3>
 *  一个handler 可以有多个上下文
 * Please note that a {@link ChannelHandler} instance can be added to more than
 * one {@link ChannelPipeline}.  It means a single {@link ChannelHandler}
 * instance can have more than one {@link ChannelHandlerContext} and therefore
 * the single instance can be invoked with different
 * {@link ChannelHandlerContext}s if it is added to one or more
 * {@link ChannelPipeline}s more than once.
 * 注意，一个ChannelHandler可以被添加多次在一个ChannelPipeline里边，意味着一个单独的ChannelHandler实例可以有多个
 * ChannelHandlerContext以及因此一个单独的实例可以被多个ChannelHandlerContext多次调用，如果ChannelHandler实例被添加了多次。
 * <p>
 * For example, the following handler will have as many independent {@link AttributeKey}s
 * as how many times it is added to pipelines, regardless if it is added to the
 * same pipeline multiple times or added to different pipelines multiple times:
 * <pre>
 * public class FactorialHandler extends {@link ChannelInboundHandlerAdapter} {
 *
 *   private final {@link AttributeKey}&lt;{@link Integer}&gt; counter = {@link AttributeKey}.valueOf("counter");
 *
 *   // This handler will receive a sequence of increasing integers starting
 *   // from 1.
 *   {@code @Override}
 *   public void channelRead({@link ChannelHandlerContext} ctx, Object msg) {
 *     Integer a = ctx.attr(counter).get();
 *
 *     if (a == null) {
 *       a = 1;
 *     }
 *
 *     attr.set(a * (Integer) msg);
 *   }
 * }
 *
 * // Different context objects are given to "f1", "f2", "f3", and "f4" even if
 * // they refer to the same handler instance.  Because the FactorialHandler
 * // stores its state in a context object (using an {@link AttributeKey}), the factorial is
 * // calculated correctly 4 times once the two pipelines (p1 and p2) are active.
 * 给出"f1", "f2", "f3", and "f4"不同的上下文对象，但是他们来自同一个实例，因为FactorialHandler存储了他们的状态在上下文对象里边
 * （使用AttributeKey），当处于活动状态的factorial ，factorial 被计算了四次在2个pipelines （p1 和 p2）中。
 * FactorialHandler fh = new FactorialHandler();
 *
 * {@link ChannelPipeline} p1 = {@link Channels}.pipeline();
 * p1.addLast("f1", fh);
 * p1.addLast("f2", fh);
 *
 * {@link ChannelPipeline} p2 = {@link Channels}.pipeline();
 * p2.addLast("f3", fh);
 * p2.addLast("f4", fh);
 * </pre>
 *
 * <h3>Additional resources worth reading</h3>
 * <p>
 * Please refer to the {@link ChannelHandler}, and
 * {@link ChannelPipeline} to find out more about inbound and outbound operations,
 * what fundamental differences they have, how they flow in a  pipeline,  and how to handle
 * the operation in your application.
 * 请参考ChannelHandler和ChannelPipeline来找出更多的关于出栈和入栈的操作、他们之间最基本的不同、怎样在pipeline流动，怎么使用在应用当中
 */
public interface ChannelHandlerContext extends AttributeMap, ChannelInboundInvoker, ChannelOutboundInvoker {
```
