---
title: netty源码分析(十三)Netty核心四大组件关系与构建方式深度解读
date: 2018-10-04 14:39:50
tags: netty四大核心组件
categories: netty
---

上一节主要看了一下ChannelHandlerContext，中间我们走到DefaultChannelPipeline的addLast方法，这一节我们从addLast方法切入：
其中group为null，name为null
<!-- more -->
```
public class DefaultChannelPipeline implements ChannelPipeline {
...略
    /**
	* Set to {@code true} once the {@link AbstractChannel} is registered.Once set to {@code true} the value will
	*  never  change.
	* 当AbstractChannel注册的时候被设置为true，设置之后以后就不会被改变。
    */
    private boolean registered;
   ...略
   public final ChannelPipeline addLast(EventExecutorGroup group, String name, ChannelHandler handler) {
        final AbstractChannelHandlerContext newCtx;
        synchronized (this) {
            checkMultiplicity(handler);//判断是否已经添加过。
            newCtx = newContext(group, filterName(name, handler), handler);//重要方法，创建有一个context
            addLast0(newCtx);//最后添加到Pipeline的handlers集合里边的对象，准确的说不是handler，而是context。
            // If the registered is false it means that the channel was not registered on an eventloop yet.
            // In this case we add the context to the pipeline and add a task that will call
            // ChannelHandler.handlerAdded(...) once the channel is registered.
            //如果registered是false，意味着channel没有在事件循环组中注册过，
            //这种情况下我们将context添加到pipeline 当中，并且添加一个回调任务，当channel 被注册的时候，回调任务会执行
            //ChannelHandler.handlerAdded(...)方法。
            if (!registered) {
                newCtx.setAddPending();//将当前context挂起。
                callHandlerCallbackLater(newCtx, true);//建议一个线程任务稍后执行。
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
        //我们自己重写的handler的handlerAdded方法会被执行。
        callHandlerAdded0(newCtx);
        return this;
    }

    private static void checkMultiplicity(ChannelHandler handler) {
        if (handler instanceof ChannelHandlerAdapter) {
            ChannelHandlerAdapter h = (ChannelHandlerAdapter) handler;
            if (!h.isSharable() && h.added) {//不是共享的，并且被添加过直接抛出异常
                throw new ChannelPipelineException(
                        h.getClass().getName() +
                        " is not a @Sharable handler, so can't be added or removed multiple times.");
            }
            h.added = true;//设置added 标志位为true
        }
    }
    //创建一个context，this是DefaultChannelPipeline，group为null，
    private AbstractChannelHandlerContext newContext(EventExecutorGroup group, String name, ChannelHandler handler) {
        return new DefaultChannelHandlerContext(this, childExecutor(group), name, handler);
    }
    //如果name为空，生成一个名字
    private String filterName(String name, ChannelHandler handler) {
        if (name == null) {
            return generateName(handler);
        }
        //判断名字是否重复
        checkDuplicateName(name);
        return name;
    }

//生成名字的私有方法，nameCaches是一个FastThreadLocal（ThreadLocal原生ThreadLocal的封装，区别在于ThreadLocal是使用hash散列的
方式，而FastThreadLocal使用的是数组，用的索引定位，比ThreadLocal性能上稍微快了一些，可以看到netty对性能要求非常高。）
    private String generateName(ChannelHandler handler) {
        Map<Class<?>, String> cache = nameCaches.get();
        Class<?> handlerType = handler.getClass();
        String name = cache.get(handlerType);
        if (name == null) {
            name = generateName0(handlerType);
            cache.put(handlerType, name);
        }

        // It's not very likely for a user to put more than one handler of the same type, but make sure to avoid
        // any name conflicts.  Note that we don't cache the names generated here.
        if (context0(name) != null) {
            String baseName = name.substring(0, name.length() - 1); // Strip the trailing '0'.
            for (int i = 1;; i ++) {
                String newName = baseName + i;
                if (context0(newName) == null) {
                    name = newName;
                    break;
                }
            }
        }
        return name;
    }
//添加一个context到pipline操作（pipline默认只有tail和head2个节点），其实就是双向 链表的添加节点的操作。
    private void addLast0(AbstractChannelHandlerContext newCtx) {
        AbstractChannelHandlerContext prev = tail.prev;
        newCtx.prev = prev;
        newCtx.next = tail;
        prev.next = newCtx;
        tail.prev = newCtx;
    }
	//建立一个稍后执行的任务。
    private void callHandlerCallbackLater(AbstractChannelHandlerContext ctx, boolean added) {
        assert !registered;
        PendingHandlerCallback task = added ? new PendingHandlerAddedTask(ctx) : new PendingHandlerRemovedTask(ctx);
        PendingHandlerCallback pending = pendingHandlerCallbackHead;
        if (pending == null) {
            pendingHandlerCallbackHead = task;
        } else {
            // Find the tail of the linked-list.
            //将新建的任务添加到链表里边
            while (pending.next != null) {
                pending = pending.next;
            }
            pending.next = task;
        }
    }

    //context被添加到pipline之后调用callHandlerAdded0，我们自己写的handler的handlerAdded方法会被执行，这也是handlerAdded
    //为什么会被首先执行的原因。
    private void callHandlerAdded0(final AbstractChannelHandlerContext ctx) {
       ...略
            ctx.handler().handlerAdded(ctx);
            ctx.setAddComplete();
           ...略      
```

[FastThreadLocal](https://github.com/netty/netty/blob/eb7f751ba519cbcab47d640cd18757f09d077b55/common/src/main/java/io/netty/util/concurrent/FastThreadLocal.java) 详细请参考git源码。
DefaultChannelHandlerContext：

```
final class DefaultChannelHandlerContext extends AbstractChannelHandlerContext {
    private final ChannelHandler handler;//持有Handler的引用，从这里可以看出一个context对应一个Handler。
    DefaultChannelHandlerContext(
            DefaultChannelPipeline pipeline, EventExecutor executor, String name, ChannelHandler handler) {
        super(pipeline, executor, name, isInbound(handler), isOutbound(handler));
        if (handler == null) {
            throw new NullPointerException("handler");
        }
        this.handler = handler;
    }

    //获取持有的Handler
    public ChannelHandler handler() {
        return handler;
    }
//入栈处理器是ChannelInboundHandler的实现
    private static boolean isInbound(ChannelHandler handler) {
        return handler instanceof ChannelInboundHandler;
    }
//出栈处理器是ChannelOutboundHandler的实现
    private static boolean isOutbound(ChannelHandler handler) {
        return handler instanceof ChannelOutboundHandler;
    }
}
```
DefaultChannelHandlerContext的super构造器结构：

```
    AbstractChannelHandlerContext(DefaultChannelPipeline pipeline, EventExecutor executor, String name,
                                  boolean inbound, boolean outbound) {
        this.name = ObjectUtil.checkNotNull(name, "name");
        this.pipeline = pipeline;//赋值pipeline（ private final DefaultChannelPipeline pipeline;）
        //DefaultChannelPipeline 持有Channel的引用
        this.executor = executor;
        this.inbound = inbound;//入栈处理器
        this.outbound = outbound;//出栈处理器
        // Its ordered if its driven by the EventLoop or the given Executor is an instanceof OrderedEventExecutor.
        ordered = executor == null || executor instanceof OrderedEventExecutor;
    }
```
可以看到DefaultChannelHandlerContext持有pipeline 、handler  、channel（DefaultChannelPipeline的接口ChannelPipeline有    Channel channel();方法），Context是这三者的一个桥梁，并且pipline里边添加的对象准确的说不是handler而是Context，而Context持有handler  对象，到此为止我们已经非常清楚的知道addlast方法的逻辑是什么样子了。
我们回到ServerBootstrap的init方法看一下ChannelInitializer：

```
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
ChannelInitializer部分逻辑
```
public abstract class ChannelInitializer<C extends Channel> extends ChannelInboundHandlerAdapter {
....略
    /**
     * This method will be called once the {@link Channel} was registered. After the method returns this instance
     * will be removed from the {@link ChannelPipeline} of the {@link Channel}.
     *当initChannel方法被调用完毕返回的时候，当前ChannelInitializer对象会被从pipline里边删除掉。
     * @param ch            the {@link Channel} which was registered.
     * @throws Exception    is thrown if an error occurs. In that case it will be handled by
     *                      {@link #exceptionCaught(ChannelHandlerContext, Throwable)} which will by default close
     *                      the {@link Channel}.
     */
    protected abstract void initChannel(C ch) throws Exception;


    /**
     * {@inheritDoc} If override this method ensure you call super!
     * 如果重写，确保调用父类的方法。
     */
    @Override
    public void handlerAdded(ChannelHandlerContext ctx) throws Exception {
        if (ctx.channel().isRegistered()) {
            // This should always be true with our current DefaultChannelPipeline implementation.
            // The good thing about calling initChannel(...) in handlerAdded(...) is that there will be no ordering
            // surprises if a ChannelInitializer will add another ChannelInitializer. This is as all handlers
            // will be added in the expected order.
            initChannel(ctx);
        }
    }
    //
    @SuppressWarnings("unchecked")
    private boolean initChannel(ChannelHandlerContext ctx) throws Exception {
        if (initMap.putIfAbsent(ctx, Boolean.TRUE) == null) { // Guard against re-entrance.
            try {
            //初始化。
                initChannel((C) ctx.channel());
            } catch (Throwable cause) {
                // Explicitly call exceptionCaught(...) as we removed the handler before calling initChannel(...).
                // We do so to prevent multiple calls to initChannel(...).
                exceptionCaught(ctx, cause);
            } finally {
            掉完initChannel之后从pipline删除当前对象
                remove(ctx);
            }
            return true;
        }
        return false;
    }
//删除逻辑，首先拿到ChannelPipeline ，然后remove掉
    private void remove(ChannelHandlerContext ctx) {
        try {
            ChannelPipeline pipeline = ctx.pipeline();
            if (pipeline.context(this) != null) {
                pipeline.remove(this);
            }
        } finally {
        //同时删除对应的context
            initMap.remove(ctx);
        }
    }
```
ChannelInitializer的使命就是对handlers的一个暂时的封装处理，把所有的handler添加到pipline之后，他的使命就完成了，所以调用完initChannel之后会被清除掉。
比如：

```
public class MyChatClientInitializer extends ChannelInitializer<SocketChannel> {
    @Override
    protected void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline channelPipeline =  ch.pipeline();
        channelPipeline.addLast(new DelimiterBasedFrameDecoder(4096, Delimiters.lineDelimiter()));
        channelPipeline.addLast(new StringEncoder(CharsetUtil.UTF_8));
        channelPipeline.addLast(new StringDecoder(CharsetUtil.UTF_8));
        channelPipeline.addLast(new MyChatClientHandler());
    }
}
```
以上这些handler加添到pipline之后，即调用完initChannel方法之后，MyChatClientInitializer对象会被删除
