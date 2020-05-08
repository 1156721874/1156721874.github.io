---
title: netty源码分析(二十一)Netty数据容器ByteBuf底层数据结构深度剖析与ReferenceCounted初探
date: 2018-10-04 15:09:42
tags: ByteBuf ReferenceCounted
categories: netty
---

**ByteBuf**
ByteBuf是Netty提供的代替jdk的ByteBuffer的一个容器，首先看一下他的具体用法：
<!-- more -->

```
public class ByteBufTest0 {
    public static void main(String[] args) {
        ByteBuf byteBuf = Unpooled.buffer(10);//堆缓冲区
        for(int i=0;i<byteBuf.capacity();i++){
            byteBuf.writeByte(i);
        }
//绝对方式  不会改变readerIndex
        for(int i=0;i<byteBuf.capacity();i++){
            System.out.println(byteBuf.getByte(i));
        }
//相对方式 会改变writerIndex
        for(int i=0;i<byteBuf.capacity();i++){
            System.out.println(byteBuf.readByte());
        }
    }
}
```
Netty ByteBuf内部有几个游标：

```
 /*      +-------------------+------------------+------------------+
         *      | discardable bytes |  readable bytes  |  writable bytes  |
         *      |                   |     (CONTENT)    |                  |
         *      +-------------------+------------------+------------------+
         *      |                   |                  |                  |
         *      0      <=      readerIndex   <=   writerIndex    <=    capacity
*/
```
readerIndex   控制读的游标，writerIndex    控制写的游标，capacity是容量。

再看一下例子：
```
public class ByteBufTest1 {
    public static void main(String[] args) {

        /**
         * ByteBuf有2种维度，一种是堆内还是堆外
         * 另一种是池化还是非池化
         */
        //utf-8字符编码，一个汉字占3个字节
        ByteBuf byteBuf = Unpooled.copiedBuffer("张hello world", Charset.forName("utf-8"));

        //如果是在堆上的返回true
        if(byteBuf.hasArray()){
            //ByteBuf内部的堆数组
            byte[] cotent =  byteBuf.array();
            System.out.println(new String(cotent,Charset.forName("utf-8")));

            //ByteBuf实际实现类的类型
            System.out.println(byteBuf);
            System.out.println(byteBuf.arrayOffset());
            System.out.println(byteBuf.readerIndex());
            System.out.println(byteBuf.writerIndex());
            System.out.println(byteBuf.capacity());

            int length  = byteBuf.readableBytes();
            for (int i=0;i<length;i++){
                System.out.println((char)byteBuf.getByte(i));
            }
            System.out.println(byteBuf.getCharSequence(0,4,Charset.forName("utf-8")));
            //输出"张h"
        }
    }
}
```
Netty ByteBuf所提供的三种缓冲区类型：
1、heap buffer。
2、direct buffer。
3、composite buffer。

Heap Buffer（堆缓冲区）
这是最常用的类型，ByteBuf将数据存储到JVM的堆空间中，并且将实际的数据存放到byte array中来实现。
优点：由于数据是存储在JVM的堆中，因此可以快速的创建于快速的释放，并且它提供了直接访问内部字节数组的方法。

缺点：每次读写数据时，都需要先将数据复制到直接缓冲区中再进行网络传输。

Direct Buffer（直接缓冲区）

在堆之外直接分配内存空间，直接缓冲区并不会占用堆的容量空间，因为它是由操作系统在本地内存进行的数据分配。

优点：在使用Socket进行数据传递时，性能非常好，因为数据直接位于操作系统的本地内存中，所以不需要从JVM将数据复制到直接缓冲区，性能很好。
缺点：因为Direct Buffer是直接在操作系统内存中的，所以内存的分配与释放要比堆空间更加复杂，而且速度要慢一些。

Netty通过提供内存池来解决这个问题，直接缓冲区并不支持通过字节数组的方式来访问数据。
重点：对于后端的业务消息的编解码来说，推荐使用HeapByteBuf；对于I/O通信线程在读写缓冲区时，推荐使用DirectByteBuf。

CompositeByteBuf：

```
public class ByteBufTest2 {
    public static void main(String[] args) {
        CompositeByteBuf compositeByteBuf = Unpooled.compositeBuffer();
        ByteBuf heapBuf = Unpooled.buffer(10);
        ByteBuf directBuf = Unpooled.directBuffer(8);
        compositeByteBuf.addComponents(heapBuf,directBuf);
       // compositeByteBuf.removeComponent(0);
        Iterator iterator = compositeByteBuf.iterator();
        while(iterator.hasNext()){
            System.out.println(iterator.next());
        }
        compositeByteBuf.forEach(System.out::println);
    }
}
```
Composite Buffer(符合缓冲区)

JDK的ByteBuffer和Netty的ByteBuf之间的差异对比：
1、Netty的ByteBuf采用读写索引分离的策略（readerIndex与writerIndex），一个初始化（里面尚未有任何数据）的ByteBuf的readerIndex与writerIndex值都为0.
2、当读索引与写索引处于同一个位置时，如果我们继续读取，那么就会抛出IndexOutOfBoundException。
3、对于ByteBuf的任何读写操作都会分别单独维护读索引与写索引，maxCapacity最大 容量默认的限制就是Integer.MAX_VALUE

JDK的ByteBuffer的缺点：
1、final byte[] bb 这是JDK的ByteBuffer对象中用于存储数据的对象声明，可以看到，其字节数组是被声明为final的，也就是长度是固定不变的，一旦分配好后不能动态扩容与收缩，
而且当待存储的数据字节很大时就很有可能出现那么就会抛出IndexOutOfBoundException，如果要预防这个异常，那就需要在存储事前完全确定好待存储的字节大小。如果ByteBuffer的空间不足，我们只有一种解决方案：
创建一个全新的ByteBuffer对象，然后再将之前的ByteBuffer中的数据复制过去，这一切都需要开发者自己来手动完成。
2、ByteBuffer只是用一个position指针来标示位置信息，在进行读写切换时就需要调用flip方法或是rewind方法，使用起来很不方便。

Netty的ByteBuf的优点：
1、存储字节的数组是动态的，其最大值默认是Integer.MAX_VALUE，这里的动态性是体现在write方法中的，write方法在执行时会判断buffer容量，如果不足则自动扩容。

```
    final void ensureWritable0(int minWritableBytes) {
        ensureAccessible();
        if (minWritableBytes <= writableBytes()) {
            return;
        }

        if (minWritableBytes > maxCapacity - writerIndex) {
            throw new IndexOutOfBoundsException(String.format(
                    "writerIndex(%d) + minWritableBytes(%d) exceeds maxCapacity(%d): %s",
                    writerIndex, minWritableBytes, maxCapacity, this));
        }

        // Normalize the current capacity to the power of 2.
        int newCapacity = alloc().calculateNewCapacity(writerIndex + minWritableBytes, maxCapacity);//计算新的容量

        // Adjust to the new capacity.
        capacity(newCapacity);//自动调节容量
    }
```

2、ByteBuf的读写索引是完全分开的，使用起来很方便。

**ReferenceCounted**

```
/**
 * A reference-counted object that requires explicit deallocation.
 * 引用计数回收对象
 * <p>
 * When a new {@link ReferenceCounted} is instantiated, it starts with the reference count of {@code 1}.
 * {@link #retain()} increases the reference count, and {@link #release()} decreases the reference count.
 * If the reference count is decreased to {@code 0}, the object will be deallocated explicitly, and accessing
 * the deallocated object will usually result in an access violation.
 * </p>
 * 当一个ReferenceCounted创建的时候他的初始引用数量是1，retain方法增加一个引用数量，release方法减少一个引用数量，如果引用数量是
 * 变成0，那么对象就会被死亡回收，加入引用一个已经被定义为死亡的对象的结果通常是会出现问题的。
 * <p>
 * If an object that implements {@link ReferenceCounted} is a container of other objects that implement
 * {@link ReferenceCounted}, the contained objects will also be released via {@link #release()} when the container's
 * reference count becomes 0.
 * </p>
 * 如果一个实现了ReferenceCounted接口的这个对象作为一个容器，他的内部的对象也是实现了ReferenceCounted接口，那么当外边的容器的
 * count引用数量变为0的时候，容器内部的对象也会别回收。
 */
```
引用加1的逻辑：

```
    public ByteBuf retain(int increment) {
        return retain0(checkPositive(increment, "increment"));
    }

    private ByteBuf retain0(int increment) {
        for (;;) {//回旋锁
            int refCnt = this.refCnt;
            final int nextCnt = refCnt + increment;

            // Ensure we not resurrect (which means the refCnt was 0) and also that we encountered an overflow.
            //如果refCnt 是0那么就会出现nextCnt = increment的情况，但是这样违背了netty的回收计数器的原则，程序就可以往下走，这是
            //不合法的，当为0的时候正常的情况是要被回收的。
            if (nextCnt <= increment) {
                throw new IllegalReferenceCountException(refCnt, increment);
            }
            //    private static final AtomicIntegerFieldUpdater<AbstractReferenceCountedByteBuf> refCntUpdater =
           //     AtomicIntegerFieldUpdater.newUpdater(AbstractReferenceCountedByteBuf.class, "refCnt");
           //首先使用的是AtomicIntegerFieldUpdater进行的cas操作（基于硬件的更新实现），其次refCnt是
           //    private volatile int refCnt = 1;即是volatile 类型的，在多线程的情况下保证相互之间的可见性。
            if (refCntUpdater.compareAndSet(this, refCnt, nextCnt)) {//cas操作增加引用计数
                break;
            }
        }
        return this;
    }
```
此处用了回旋锁+cas保证操作的原子性。
AtomicIntegerFieldUpdater使用反射 更新某个类的内部的一个int类型的并且是volatitle的变量。
这里提一下AtomicIntegerFieldUpdater：
1、更新器更新的必须int类型的变量	，不能是其包装类型。
2、更新器更新的必须是volatitle类型变量，确保线程之间共享变量时的立即可见性。
AtomicIntegerFieldUpdater.newUpdater()方法的实现是AtomicIntegerFieldUpdaterImpl:
AtomicIntegerFieldUpdaterImpl的构造器会对类型进行验证：
```

            if (field.getType() != int.class)
                throw new IllegalArgumentException("Must be integer type");

            if (!Modifier.isVolatile(modifiers))
                throw new IllegalArgumentException("Must be volatile type");

```
由此验证我们说的第一和第二条原则。
3、变量不能是static的，必须是实例变量，因为Unsafe.objectFieldOffset()方法不支持静态变量(cas操作本质上是通过对象实例的偏移量来直接进行赋值)
4、更新器只能修改可见范围内的变量，因为更新器是通过反射来得到这个变量，如果变量不可见就会报错。
实际验证：

```
	public class AtomicUpdatorTest {
    public static void main(String[] args) {
        Person person = new Person();
 /*       for(int i=0;i<10;++i){
            Thread thread = new Thread(() -> {
                try {
                    Thread.sleep(20);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                System.out.println( person.age++);
            });
            thread.start();
            //会有严重的问题，会出现多次打印1之类的问题。。这个时候是AtommicIntegerUpdator登场的时候了
        }*/

//原子方式更新
        AtomicIntegerFieldUpdater<Person> atomicIntegerFieldUpdater = AtomicIntegerFieldUpdater.newUpdater(Person.class,"age");
        for(int i=0;i<10;++i){
            Thread thread = new Thread(() -> {
                try {
                    Thread.sleep(20);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                System.out.println( atomicIntegerFieldUpdater.getAndIncrement(person));
            });
            thread.start();
        }

    }

}

class Person{
   volatile int age = 1;
}

```

volatile变量自身具有下列特性。
·可见性。对一个volatile变量的读，总是能看到（任意线程）对这个volatile变量最后的写
入。
·原子性：对任意单个volatile变量的读/写具有原子性，但类似于volatile++这种复合操作不
具有原子性。

对volatile写和volatile读的内存语义：
·线程A写一个volatile变量，实质上是线程A向接下来将要读这个volatile变量的某个线程
发出了（其对共享变量所做修改的）消息。
·线程B读一个volatile变量，实质上是线程B接收了之前某个线程发出的（在写这个volatile
变量之前对共享变量所做修改的）消息。
·线程A写一个volatile变量，随后线程B读这个volatile变量，这个过程实质上是线程A通过
主内存向线程B发送消息。

关于[引用计数器可以参考netty的官方文档](http://netty.io/wiki/reference-counted-objects.html)的介绍。
