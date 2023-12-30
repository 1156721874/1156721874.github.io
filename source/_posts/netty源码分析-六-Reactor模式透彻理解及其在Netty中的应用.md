---
title: netty源码分析(六)Reactor模式透彻理解及其在Netty中的应用
date: 2018-10-04 14:24:05
tags: Reactor模式 netty的异步
categories: netty
---

前边讲了EventLoopGroup的一些知识，在netty的架构这块我们使用一种bossGroup加workerGroup的方式，bossGroup只负责请求的转发，workerGroup是具体的数据处理，其实netty整个框架使用的是Reactor(响应器)的设计模式。这方面知名的大佬就是Doug Lea，Java.util.current包的很多线程的API和工具都出自大佬之手。
![这里写图片描述](2018/10/04/netty源码分析-六-Reactor模式透彻理解及其在Netty中的应用/20170923142146979.jpg)
<!-- more -->
大佬的一片文章对这种模式做了非常细致的介绍,《[Scalable IO in Java](http://gee.cs.oswego.edu/dl/cpjslides/nio.pdf)》
![这里写图片描述](2018/10/04/netty源码分析-六-Reactor模式透彻理解及其在Netty中的应用/20170923142426064.png)  

大多数的网络服务都是下面的流程：
读取请求
对请求进行解码
处理服务（业务逻辑）
编码相应
发送响应
经典的io模式是这样的：
![这里写图片描述](2018/10/04/netty源码分析-六-Reactor模式透彻理解及其在Netty中的应用/20170923142529241.png)

```
class Server implements Runnable {
	public void run() {
	try {
		ServerSocket ss = new ServerSocket(PORT);
		while (!Thread.interrupted())
			new Thread(new Handler(ss.accept())).start();
		// or, single-threaded, or a thread pool
	} catch (IOException ex) { /* ... */ }
	}
	static class Handler implements Runnable {
		final Socket socket;
		Handler(Socket s) { socket = s; }
		public void run() {
		try {
			byte[] input = new byte[MAX_INPUT];
			socket.getInputStream().read(input);
			byte[] output = process(input);
			socket.getOutputStream().write(output);
		} catch (IOException ex) { /* ... */ }
	}
	private byte[] process(byte[] cmd) { /* ... */ }
	}
}
```

每一个请求开一个线程去处理。

这种方式不是一直能够好的做法，会有阻塞和瓶颈。接下来是Reactor Design的方式：
![这里写图片描述](2018/10/04/netty源码分析-六-Reactor模式透彻理解及其在Netty中的应用/20170923143326543.png)

```
class Reactor implements Runnable {
	final Selector selector;
	final ServerSocketChannel serverSocket;
Reactor(int port) throws IOException {
	selector = Selector.open();
	serverSocket = ServerSocketChannel.open();
	serverSocket.socket().bind(new InetSocketAddress(port));
	serverSocket.configureBlocking(false);
	SelectionKey sk =serverSocket.register(selector,SelectionKey.OP_ACCEPT);
	sk.attach(new Acceptor());
}
/*
Alternatively, use explicit SPI provider:
SelectorProvider p = SelectorProvider.provider();
selector = p.openSelector();
serverSocket = p.openServerSocketChannel();
*/
// class Reactor continued
public void run() { // normally in a newThread
	try {
		while (!Thread.interrupted()) {
			selector.select();
			Set selected = selector.selectedKeys();
			Iterator it = selected.iterator();
			while (it.hasNext())
			dispatch((SelectionKey)(it.next());
			selected.clear();
		}
	} catch (IOException ex) { /* ... */ }
	}
}
void dispatch(SelectionKey k) {
	Runnable r = (Runnable)(k.attachment());
		if (r != null)
		r.run();
}
```
Reactor 只负责请求的接受，和nio变成一样初始化注册的是OP_ACCEPT，然后绑定一个Acceptor（实现Runnable接口），主循环中，收到准备好的selectedKeys，并且遍历selectedKeys，将每一个keydispatch下去，在dispatch里边通过selectedKey得到绑定的Acceptor,看一下Acceptor的逻辑：

```
// class Reactor continued
class Acceptor implements Runnable { // inner
	public void run() {
		try {
		SocketChannel c = serverSocket.accept();
		if (c != null)
		new Handler(selector, c);
		}catch(IOException ex) { /* ... */ }
		}
	}
}

final class Handler implements Runnable {
	final SocketChannel socket;
	final SelectionKey sk;
	ByteBuffer input = ByteBuffer.allocate(MAXIN);
	ByteBuffer output = ByteBuffer.allocate(MAXOUT);
	static final int READING = 0, SENDING = 1;
	int state = READING;
	Handler(Selector sel, SocketChannel c)
		throws IOException {
		socket = c; c.configureBlocking(false);
		// Optionally try first read now
		sk = socket.register(sel, 0);
		sk.attach(this);
		sk.interestOps(SelectionKey.OP_READ);
		sel.wakeup();//注册OP_READ兴趣之后，让select()方法返回，接受要读取的数据
	}
	boolean inputIsComplete() { /* ... */ }
	boolean outputIsComplete() { /* ... */ }
	void process() { /* ... */ }

// class Handler continued
	public void run() {
		try {
			if (state == READING) read();
			else if (state == SENDING) send();
		} catch (IOException ex) { /* ... */ }
	}
	void read() throws IOException {
	socket.read(input);
		if (inputIsComplete()) {
			process();
			state = SENDING;
			// Normally also do first write now
			sk.interestOps(SelectionKey.OP_WRITE);//将状态变为SENDING之后，接下来就是往外写数据，对写感兴趣。
		}
	}
	void send() throws IOException {
		socket.write(output);
		if (outputIsComplete()) sk.cancel();
		}
	}
```
Acceptor 获得SocketChannel接着进入到实际的处理类Handler里边，Handler有SocketChannel	和SelectionKey的引用，Handler的构造器将当前类（Handler）加入到绑定里边，并且对READ感兴趣，之后调sel.wakeup()意思是让select( )方法立刻返回，如果当前没有select()方法阻塞的话，那么下一次调用select()会立即返回，然后执行run()方法，是通过判断状态的方式来决定是写还是读 ，这个在Netty3中就是需要这样实现handler代码的，需要自己判断状态来决定业务逻辑。Netty4已经改成各种回调了，比如channelRead，channelActive等。
：’
文档接着介绍了 基于模式的设计，提前绑定合适的handler作为attachment：

```
//A simple use of GoF State-Object pattern
//Rebind appropriate handler as attachment
class Handler { // ...
	public void run() { // initial state is reader
		socket.read(input);
		if (inputIsComplete()) {
		process();
		sk.attach(new Sender());//绑定UI个发送者。
		sk.interest(SelectionKey.OP_WRITE);//由于发送者是写操作，因此兴趣是OP_WRITE
		sk.selector().wakeup();//让select方法立刻返回，执行写的逻辑。
	}
}
class Sender implements Runnable {
	public void run(){ // ...
		socket.write(output);
		if (outputIsComplete()) sk.cancel();
	}
	}
}
```

接着是handler基于线程池的实现：
![这里写图片描述](2018/10/04/netty源码分析-六-Reactor模式透彻理解及其在Netty中的应用/20170923160427112.png)

这个版本是对于handler的减压，接着多个selector的Reactor：

![这里写图片描述](2018/10/04/netty源码分析-六-Reactor模式透彻理解及其在Netty中的应用/20170923161803582.png)
mainReactor相当于bossGroup,subReactorx 相当于netty里边的workerGroup.整个过程下来其实就是netty的 框架内在的模式。
