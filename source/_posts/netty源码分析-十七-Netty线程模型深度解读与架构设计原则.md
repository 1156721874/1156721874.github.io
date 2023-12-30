---
title: netty源码分析(十七)Netty线程模型深度解读与架构设计原则
date: 2018-10-04 14:50:02
tags: 线程模型 架构设计
categories: netty
---

上次分析到：
```
<!-- more -->
public abstract class SingleThreadEventLoop extends SingleThreadEventExecutor implements EventLoop
  public ChannelFuture register(final ChannelPromise promise) {
      ObjectUtil.checkNotNull(promise, "promise");
      promise.channel().unsafe().register(this, promise);
      return promise;
  }
}
```
之前提到的ChannelPromise 结构，其实是一个异步返回结果的封装，它持有channel和当前的SingleThreadEventLoop :
![这里写图片描述](2018/10/04/netty源码分析-十七-Netty线程模型深度解读与架构设计原则/20171105134757100.png)

进入unsafe实现类AbstractUnsafe的register方法：

```
protected abstract class AbstractUnsafe implements Unsafe {

      private volatile ChannelOutboundBuffer outboundBuffer = new ChannelOutboundBuffer(AbstractChannel.this);
      private RecvByteBufAllocator.Handle recvHandle;
      private boolean inFlush0;
      /** true if the channel has never been registered, false otherwise */
      private boolean neverRegistered = true;
public final void register(EventLoop eventLoop, final ChannelPromise promise) {
          if (eventLoop == null) {
              throw new NullPointerException("eventLoop");
          }
          if (isRegistered()) {
              promise.setFailure(new IllegalStateException("registered to an event loop already"));
              return;
          }
          if (!isCompatible(eventLoop)) {
              promise.setFailure(
                      new IllegalStateException("incompatible event loop type: " + eventLoop.getClass().getName()));
              return;
          }
           //上边的逻辑主要是一些非空判断之类的东西
          AbstractChannel.this.eventLoop = eventLoop;
    //主要的注册逻辑分支，if和else分支可以看到最后调用的都是register0，但是else里边加了一个外壳---线程
          if (eventLoop.inEventLoop()) {
              register0(promise);
          } else {
              try {
                  eventLoop.execute(new Runnable() {
                      @Override
                      public void run() {
                          register0(promise);
                      }
                  });
              } catch (Throwable t) {
                  logger.warn(
                          "Force-closing a channel whose registration task was not accepted by an event loop: {}",
                          AbstractChannel.this, t);
                  closeForcibly();
                  closeFuture.setClosed();
                  safeSetFailure(promise, t);
              }
          }
      }
}
```
eventLoop.inEventLoop()是分支逻辑的主要判断依据(eventLoop实体是SingleThreadEventExecutor):
```
public interface EventExecutor extends EventExecutorGroup {
...略
  /**
   * Calls {@link #inEventLoop(Thread)} with {@link Thread#currentThread()} as argument
   * 将当前线程作为参数。
   */
  boolean inEventLoop();
  ...略
  }
```
找到他的实现类:

```
public abstract class AbstractEventExecutor extends AbstractExecutorService implements EventExecutor {
  ...略
  public boolean inEventLoop() {
      return inEventLoop(Thread.currentThread());//参数为当前线程。
  }
  ...略
}
```
在SingleThreadEventExecutor:
```
  public boolean inEventLoop(Thread thread) {
      return thread == this.thread;
  }
```
很简单，即，判断当前线程是不是SingleThreadEventExecutor里边维护的线程。所以else里边的逻辑是SingleThreadEventExecutor里边的线程不是当前线程的时候，新建一个Thread去执行register0，下边看一下register0的逻辑：

```
      private void register0(ChannelPromise promise) {
          try {
              // check if the channel is still open as it could be closed in the mean time when the register
              // call was outside of the eventLoop
              if (!promise.setUncancellable() || !ensureOpen(promise)) {
                  return;
              }
              boolean firstRegistration = neverRegistered;
              doRegister();//核心注册方法
              neverRegistered = false;
              registered = true;

              // Ensure we call handlerAdded(...) before we actually notify the promise. This is needed as the
              // user may already fire events through the pipeline in the ChannelFutureListener.
              pipeline.invokeHandlerAddedIfNeeded();

              safeSetSuccess(promise);
              pipeline.fireChannelRegistered();
              // Only fire a channelActive if the channel has never been registered. This prevents firing
              // multiple channel actives if the channel is deregistered and re-registered.
              if (isActive()) {
                  if (firstRegistration) {
                      pipeline.fireChannelActive();
                  } else if (config().isAutoRead()) {
                      // This channel was registered before and autoRead() is set. This means we need to begin read
                      // again so that we process inbound data.
                      //
                      // See https://github.com/netty/netty/issues/4805
                      beginRead();
                  }
              }
          } catch (Throwable t) {
              // Close the channel directly to avoid FD leak.
              closeForcibly();
              closeFuture.setClosed();
              safeSetFailure(promise, t);
          }
      }
```
看一下doRegister()：
看一下AbstractNioChannel 实现类的doRegister逻辑：
```
public abstract class AbstractNioChannel extends AbstractChannel {
...略
  protected void doRegister() throws Exception {
      boolean selected = false;
      for (;;) {
          try {
              selectionKey = javaChannel().register(eventLoop().unwrappedSelector(), 0, this);
              //javaChannel()返回的是SelectableChannel(jdk的java.nio.channels.SelectableChannel)
              //javaChannel().register是将channel注册到Selector上去，所以eventLoop().unwrappedSelector()返回的是Selector
              //（jdk的java.nio.channels.Selector）
              return;
          } catch (CancelledKeyException e) {
              if (!selected) {
                  // Force the Selector to select now as the "canceled" SelectionKey may still be
                  // cached and not removed because no Select.select(..) operation was called yet.
                  eventLoop().selectNow();
                  selected = true;
              } else {
                  // We forced a select operation on the selector before but the SelectionKey is still cached
                  // for whatever reason. JDK bug ?
                  throw e;
              }
          }
      }
  }
  ...略
}
```
到这里我们看到了最终netty的JavaNio的注册实现。最后说一下比较重要的一点，上边提到的主要的注册逻辑分支，if和else分支可以看到最后调用的都是register0，但是else里边加了一个外壳---线程，这个地方有这么五点需要注意：

1. 一个EventLoopGroup当中会包含一个或多个EventLoop。
2. 一个EventLoop在它的整个生命周期当中都只会与唯一一个Thread进行绑定。
3. 所有由EventLoop所处理的各种I/O事件都将在它所关联的那个Thread上进行处理。
4. 一个Channel在它的整个生命周期中只会注册在一个EventLoop上。
5. 一个EventLoop在运行过程中，会被分配给一个或多个Channel。

这是netty的核心的架构理念，非常重要！！！
