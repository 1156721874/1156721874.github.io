---
title: netty源码分析(二十)NIO堆外内存与零拷贝深入讲解
date: 2018-10-04 14:57:45
tags: nio 堆外内存 零拷贝
categories: netty
---

![这里写图片描述](20171118184319019.png)


ByteBuffer byteBuffer = ByteBuffer.allocateDirect(512);
直接内存：返回DirectByteBuffer对象，DirectByteBuffer的父类是MappedByteBuffer ，MappedByteBuffer 的父类是ByteBuffer ， 在ByteBuffer的上边是Buffer，在
          Buffer里边有一个address 他的声明和注释如下：
                // Used only by direct buffers
                // NOTE: hoisted here for speed in JNI GetDirectBufferAddress
                long address;
                address是专门为DirectByteBuffer使用的，存储是堆外内存的地址。在 DirectByteBuffer 的构造器里边，会对 address 进行赋值。
 DirectByteBuffer使用的是直接的对外内存，去除了使用HeapByteBuffer方式的内存拷贝，因此有另外一个说法叫“零拷贝”，address对应的内存区域在os的内存空间，这块内存直接与io设备进行交互，当jvm对DirectByteBuffer内存垃圾回收的时候，会通过address调os，os将address对应的区域回收。

ByteBuffer byteBuffer = ByteBuffer.allocate(512);
堆内存：返回 HeapByteBuffer
           HeapByteBuffer是在jvm的内存范围之内，然后在调io的操作时会将数据区域拷贝一份到os的内存区域，这样造成了不必要的性能上的降低，这样做是有原因的，试想假设如果os和jvm都是用jvm里边的数据区域， 但是jvm会对这块内存区域进行GC回收，可能会对这块内存的数据进行更改，根据我们的假设，由于这块区域os也在使用，jvm对这块共享数据发生了变更，os那边就会出现数据错乱的情况。那么如果不让jvm对这块共享区域进行GC是不是可以避免这个问题呢？答案是不行的，也会存在问题，如果jvm不对其进行GC回收，jvm这边可能会出现OOM的内存溢出。因此，最后这个地方非常尴尬，只能拷贝jvm的那一份到os的内存空间，即使jvm那边的数据区域被改变，但是os里边的不会受到影响，等os使用io结束后会对这块区域进行回收，因为这是os的管理范围之内。

 如果你想了解更详细的说明请看知乎的一个回答：https://www.zhihu.com/question/57374068
 RednaxelaFX是一个大牛，在社区中参与到jvm的很多工作。

再说一下NIO的零拷贝，如图：
**case1非零拷贝(传统的方式)：**
传统方式的NIO存在数据拷贝问题，实例代码：
客户端：
```
public class OldClient {
    public static void main(String[] args) throws  Exception {
        Socket socket = new Socket("localhost",8899);
        InputStream inputStream = new FileInputStream("niofiles/spark-2.2.0-bin-hadoop2.7.tgz");
        DataOutputStream dataOutputStream = new DataOutputStream(socket.getOutputStream());

        int totalSend = 0;
        int readCount = 0;
        byte[] buff =new byte[4096];
        long startTime = System.currentTimeMillis();
        while((readCount=inputStream.read(buff))>=0){
            totalSend+=readCount;
            dataOutputStream.write(buff);
        }
        System.out.println("send bytes :"+totalSend+",timecost:"+(System.currentTimeMillis()-startTime));
        dataOutputStream.close();
        socket.close();
        inputStream.close();
    }
}
```
服务端代码：

```
public class OldServer  {

    public static void main(String[] args)  throws  Exception{
        ServerSocket serverSocket = new ServerSocket(8899);
        while(true){
            Socket socket  = serverSocket.accept();
            DataInputStream dataInputStream = new DataInputStream(socket.getInputStream());
            byte[] buff = new byte[4096];

            while(true){
                int readcount = dataInputStream.read(buff,0,buff.length);

                if(-1==readcount){
                    break;
                }
            }
        }
    }
}
```
图示：
![这里写图片描述](20171118214504920.png)
注意第一次数据拷贝是必须的。
**case2零拷贝：**
新的IO即NIO是零拷贝的方式：
实例代码：
客户端
```
public class NewClient {
    public static void main(String[] args)  throws  Exception{
        SocketChannel socketChannel = SocketChannel.open();
        socketChannel.connect(new InetSocketAddress("localhost",8899));
        socketChannel.configureBlocking(true);
        String name = "niofiles/spark-2.2.0-bin-hadoop2.7.tgz";
        FileChannel fileChannel = new FileInputStream(name).getChannel();
        long start = System.currentTimeMillis();
        //零拷贝关键代码
        /**
         * This method is potentially much more efficient than a simple loop
         * that reads from this channel and writes to the target channel.  Many
         * operating systems can transfer bytes directly from the filesystem cache
         * to the target channel without actually copying them.
         */
       long  transCount =  fileChannel.transferTo(0,fileChannel.size(),socketChannel);

        System.out.println("发送字节数:"+transCount+",耗时："+(System.currentTimeMillis()-start));
        fileChannel.close();
    }
}
```
服务端：

```
public class NewServer {
    public static void main(String[] args) throws  Exception {
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        ServerSocket serverSocket =  serverSocketChannel.socket();
        serverSocket.bind(new InetSocketAddress(8899));
        serverSocket.setReuseAddress(true);

        ByteBuffer byteBuffer =  ByteBuffer.allocate(4096);

        while(true){

            try {
                SocketChannel socketChannel =  serverSocketChannel.accept();
                socketChannel.configureBlocking(true);

                int readcount = 0;
                while(-1!=readcount){
                    readcount = socketChannel.read(byteBuffer);
                    byteBuffer.rewind();
                }
            } catch (IOException e) {
                e.printStackTrace();
            }

        }
    }
}
```
图示：
![这里写图片描述](20171118215619952.png)
数据首先通过DMA从硬件设备（硬盘）读取到内核空间，然后将内核空间数据copy对接到socket buffer，socket buffer是一个缓冲区，之后socket buffer数据拷贝到协议引擎写到服务器端。这里减去了传统io在内核和用户之间的拷贝，但是内核里边的拷贝还是存在。
到时到了Linux2.4又有了改善：
![这里写图片描述](20171118225322248.png)

再看最后一个图，Linux2.4以后的版本：
![这里写图片描述](20171118230603907.png)
socket buffer 在这里不是一个缓冲区了，而是一个文件描述符，描述的是数据在kernel buffer的数据从哪里开始，长度是多少，里边基本上不存储数据大部分是指针，然后协议引擎protocol engine也是通过DMA 拷贝的方式从文件描述符socket buffer读取。
首先首先从硬件设备读取数据到kernel buffer，kernel buffer可能是多个字节数组，然后socket buffer 通过gatter的方式直接从kernel buffer映射（从哪个位置，读取多少长度，即gatter操作）数据，最后协议引擎protocol engine通过socket buffer的映射读到kernel buffer数据，再也没有数据拷贝的问题。
