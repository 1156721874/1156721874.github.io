---
title: jvm原理（44）阈值和垃圾收集器类型对于对象分配的影响实战分析
date: 2019-05-18 14:27:24
tags: [阈值 jvm 垃圾收集器]
categories: jvm
---

### 命令介绍：
java -XX:+PrintCommandLineFlags -version

打印jvm默认启动参数，以及jvm的版本号
运行结果：
```
-XX:InitialHeapSize=267006656 -XX:MaxHeapSize=4272106496 -XX:+PrintCommandLineFlags -XX:+UseCompressedClassPointers -XX:+UseCompressedOops -XX:-UseLargePagesIndividualAllocation -XX:+UseParallelGC
java version "1.8.0_111"
Java(TM) SE Runtime Environment (build 1.8.0_111-b14)
Java HotSpot(TM) 64-Bit Server VM (build 25.111-b14, mixed mode)
```

-XX:InitialHeapSize=267006656：初始的堆大小是267006656，单位是字节。
-XX:MaxHeapSize=4272106496:最大的堆大小是4272106496字节。
-XX:+PrintCommandLineFlags：命令本身。
-XX:+UseCompressedClassPointers：使用压缩的类指针。
-XX:+UseCompressedOops：表示从32位的jvm迁移到64位的jvm的时候会有指针膨胀，如果开启这个参数，会对一些指针不去膨胀，减少空间的占用
-XX:+UseParallelGC：当我们不去指定新生代和老年代的收集器的时候，新生代垃圾收集器默认是 Parallel Scavenge，老年代垃圾收集器是Parallel Old。

#### 程序演示
```
/**
 -verbose:gc
 -Xms20M
 -Xmx20M
 -Xmn10M
 -XX:+PrintGCDetails
 -XX:SurvivorRatio=8
 -XX:PretenureSizeThreshold=4194304 当在新生代创建的对象大小是
 4M的时候，对象直接在老年代分配。
 */
public class MyTest2 {
    public static void main(String[] args) {
        int size = 1024 * 1024;
        byte[] myAlloc1 = new byte[5 * size];
    }
}
```

运行结果：
```
Heap
 PSYoungGen      total 9216K, used 7643K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
  eden space 8192K, 93% used [0x00000000ff600000,0x00000000ffd76f38,0x00000000ffe00000)
  from space 1024K, 0% used [0x00000000fff00000,0x00000000fff00000,0x0000000100000000)
  to   space 1024K, 0% used [0x00000000ffe00000,0x00000000ffe00000,0x00000000fff00000)
 ParOldGen       total 10240K, used 0K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  object space 10240K, 0% used [0x00000000fec00000,0x00000000fec00000,0x00000000ff600000)
 Metaspace       used 3482K, capacity 4498K, committed 4864K, reserved 1056768K
  class space    used 387K, capacity 390K, committed 512K, reserved 1048576K
```
我们可以看到我们分配了一个4M大小的对象，具名参数-XX:PretenureSizeThreshold=4194304 表示对象大小超过4M直接进入老年代，但是我们程序运行的jvm日志表示的是【PSYoungGen      total 9216K, used 7643K】和【ParOldGen       total 10240K, used 0K】，对象还是在新生代，对象没有直接进入老年代。

其实这里PretenureSizeThreshold参数需要搭配串行收集器，需要指定收集器为-XX:UseSerialGC。现在程序的jvm参数如下：
```
-verbose:gc
-Xms20M
-Xmx20M
-Xmn10M
-XX:+PrintGCDetails
-XX:SurvivorRatio=8
-XX:PretenureSizeThreshold=4194304

```
运行程序结果如下：
```
Heap
 def new generation   total 9216K, used 2523K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  eden space 8192K,  30% used [0x00000000fec00000, 0x00000000fee76f28, 0x00000000ff400000)
  from space 1024K,   0% used [0x00000000ff400000, 0x00000000ff400000, 0x00000000ff500000)
  to   space 1024K,   0% used [0x00000000ff500000, 0x00000000ff500000, 0x00000000ff600000)
 tenured generation   total 10240K, used 5120K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
   the space 10240K,  50% used [0x00000000ff600000, 0x00000000ffb00010, 0x00000000ffb00200, 0x0000000100000000)
 Metaspace       used 3475K, capacity 4496K, committed 4864K, reserved 1056768K
  class space    used 385K, capacity 388K, committed 512K, reserved 1048576K
```
**  tenured generation   total 10240K, used 5120K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000) **
5120K就是myAlloc1的大小，PretenureSizeThreshold参数生效。因此PretenureSizeThreshold参数要和串行收集器使用。

现在去掉【-XX:+UseSerialGC】启动参数，然后修改程序为：
```public class MyTest2 {
    public static void main(String[] args) {
        int size = 1024 * 1024;
        byte[] myAlloc1 = new byte[8 * size];
    }
}

```
运行结果：
```
Heap
 def new generation   total 9216K, used 2523K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  eden space 8192K,  30% used [0x00000000fec00000, 0x00000000fee76f28, 0x00000000ff400000)
  from space 1024K,   0% used [0x00000000ff400000, 0x00000000ff400000, 0x00000000ff500000)
  to   space 1024K,   0% used [0x00000000ff500000, 0x00000000ff500000, 0x00000000ff600000)
 tenured generation   total 10240K, used 8192K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
   the space 10240K,  80% used [0x00000000ff600000, 0x00000000ffe00010, 0x00000000ffe00200, 0x0000000100000000)
 Metaspace       used 3489K, capacity 4498K, committed 4864K, reserved 1056768K
  class space    used 387K, capacity 390K, committed 512K, reserved 1048576K
```
即创建一个8M的数组，eden是8M，肯定无法存放，这个时候对象会直接进入老年代(注意不是PretenureSizeThreshold的作用)，可以看到【 tenured generation】的已使用空间是8192K(8M).

接下来我们把程序修改为：

```public class MyTest2 {
    public static void main(String[] args) {
        int size = 1024 * 1024;
        byte[] myAlloc1 = new byte[10 * size];
    }
}

```
对象大小改为10M运行：
```
[GC (Allocation Failure) [Tenured: 0K->705K(10240K), 0.0056446 secs] 2359K->705K(19456K), [Metaspace: 3374K->3374K(1056768K)], 0.0057131 secs] [Times: user=0.00 sys=0.00, real=0.01 secs]
[Full GC (Allocation Failure) [Tenured: 705K->687K(10240K), 0.0016112 secs] 705K->687K(19456K), [Metaspace: 3374K->3374K(1056768K)], 0.0016357 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
Exception in thread "main" java.lang.OutOfMemoryError: Java heap space
	at com.twodragonlake.jvm.gc.MyTest2.main(MyTest2.java:32)
Heap
 def new generation   total 9216K, used 410K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  eden space 8192K,   5% used [0x00000000fec00000, 0x00000000fec66800, 0x00000000ff400000)
  from space 1024K,   0% used [0x00000000ff400000, 0x00000000ff400000, 0x00000000ff500000)
  to   space 1024K,   0% used [0x00000000ff500000, 0x00000000ff500000, 0x00000000ff600000)
 tenured generation   total 10240K, used 687K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
   the space 10240K,   6% used [0x00000000ff600000, 0x00000000ff6abf30, 0x00000000ff6ac000, 0x0000000100000000)
 Metaspace       used 3483K, capacity 4496K, committed 4864K, reserved 1056768K
  class space    used 387K, capacity 390K, committed 512K, reserved 1048576K
```
从运行结果上看最终是对象分配失败，出现了oom，这个对象在新生代和老年代都是无法存放的。


修改程序的jvm参数：
```
-verbose:gc
-Xms20M
-Xmx20M
-Xmn10M
-XX:+PrintGCDetails
-XX:SurvivorRatio=8
-XX:PretenureSizeThreshold=4194304
-XX:+UseSerialGC
```
程序也做修改：
```
public class MyTest2 {
    public static void main(String[] args) {
        int size = 1024 * 1024;
        byte[] myAlloc1 = new byte[5 * size];
        try {
            Thread.sleep(1000000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}
```
加入线程程等待是为了我们在运行程序之后要运行jvisualvm。
然后运行jvisualvm。
![gc1.png](gc1.png)
由于jvisualvm的监听要在jvm里边消耗内存，所以我们的程序会打印minor gc日志：
```
[GC (Allocation Failure) [DefNew: 8192K->1024K(9216K), 0.0108187 secs] 13312K->6888K(19456K), 0.0108706 secs] [Times: user=0.00 sys=0.00, real=0.01 secs]
[GC (Allocation Failure) [DefNew: 9216K->511K(9216K), 0.0091469 secs] 15080K->7397K(19456K), 0.0091785 secs] [Times: user=0.02 sys=0.00, real=0.01 secs]
[GC (Allocation Failure) [DefNew: 8703K->489K(9216K), 0.0019780 secs] 15589K->7375K(19456K), 0.0020053 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
[GC (Allocation Failure) [DefNew: 8681K->622K(9216K), 0.0024485 secs] 15567K->7508K(19456K), 0.0024825 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
[GC (Allocation Failure) [DefNew: 8814K->379K(9216K), 0.0038152 secs] 15700K->7627K(19456K), 0.0038642 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
[GC (Allocation Failure) [DefNew: 8571K->514K(9216K), 0.0017876 secs] 15819K->7762K(19456K), 0.0018148 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
```
对应的jvisualvm的堆曲线会发生下跌。


#### System.gc();
通知jvm是时候进行垃圾回收了，但是jvm不一定去执行垃圾回收，哪System.gc()的意义是什么呢？垃圾回收是只有在进行对象创建的时候jvm才会去进行垃圾回收，而System.gc()是在jvm中没有对象正在创建的时间点去执行垃圾回收，这个时候调用System.gc()jvm也会去进行响应，这就是System.gc()的作用所在。

#### jmc
上面程序运行的时候我们可以使用jmc查看jvm的使用情况：
![gc2.png](gc2.png)
从图中可以看到metaspace的使用量快满了的时候jvm会进行一次gc。
同时也可以可以查看jvm的启动参数：
![gc3.png](gc3.png)
#### jmc的飞行器
![gc4.png](gc4.png)
![gc5.png](gc5.png)


#### jcmd查看jvm启动参数
 ```
 C:\Users\Administrator>jps
 10612 Jps
 4324 Launcher
 17820
 8860 RemoteMavenServer
 9884
 9932 MyTest2

 C:\Users\Administrator>jcmd 9932 VM.flags
 9932:
 -XX:CICompilerCount=4 -XX:InitialHeapSize=20971520 -XX:MaxHeapSize=20971520 -XX:MaxNewSize=10485760 -XX:MinHeapDeltaBytes=196608 -XX:NewSize=10485760 -XX:OldSize=10485760 -XX:PretenureSizeThreshold=4194304 -XX:+PrintGC -XX:+PrintGCDetails -XX:SurvivorRatio=8 -XX:+UseCompressedClassPointers -XX:+UseCompressedOops -XX:+UseFastUnorderedTimeStamps -XX:-UseLargePagesIndividualAllocation -XX:+UseSerialGC
 ```

### MaxTenuringThreshold与阈值的动态调整详解
编写程序:
```
/**
 * jvm参数：
 -verbose:gc
 -Xms20M
 -Xmx20M
 -Xmn10M
 -XX:+PrintGCDetails
 -XX:+PrintCommandLineFlags
 -XX:MaxTenuringThreshold=5 在可以自动调节对象晋升(promote)到老年代阈值的GC中，设置该阈值的最大值， 对象晋升到老年代的最大存活年龄
 这里是理想的情况下，当对象年龄达到6的时候，对象晋升到 老年代，但是jvm会根据当前新生代的情况可能在对象年龄到了2就会晋升到老年代
 jvm会有一个自动调节的机制。但是最大年龄不会超过5的，对象年龄大于5的肯定会被晋升到老年代，但是小于5也有可能会被提前晋升到老年代。
 该参数默认值是15，CMS中默认值是6，G1中默认值是15(在JJVM中，，该数值是由4个bit来表示的，所以最大值是1111，即15)

 -XX:+PrintTenuringDistribution 打印的作用，打印年龄为1的对象的是那些，对象年龄为2的是那些等信息的打印。

 经历过多次GC，存活的对象会在From Survivor和To Survivor之间来回存放，
 而这里面的一个前提是这两个空间有足够得到大小来存放这些数据，在GC算法中会计算每个对象年龄的大小，如果达到某个年龄后发现总大小
 已经大于Survivor（其中一个Survivor）空间的50%，这个时候就需要调整阈值，不能再继续等到默认的15次后才完成晋升，因为这样会导致Survivor空间不足，所以
 需要调整阈值，让这些存活对象尽快完成晋升。
 */
public class MyTest3 {
    public static void main(String[] args) {
        int size = 1024 * 1024;
        byte[] myAlloc1 = new byte[2 * size];
        byte[] myAlloc2 = new byte[2 * size];
        byte[] myAlloc3 = new byte[2 * size];
        byte[] myAlloc4 = new byte[2 * size];
        byte[] myAlloc5 = new byte[2 * size];
        byte[] myAlloc6 = new byte[2 * size];
        System.out.println("hello world");
    }
}
```

运行程序得到结果：
```
-XX:InitialHeapSize=20971520 -XX:InitialTenuringThreshold=5 -XX:MaxHeapSize=20971520 -XX:MaxNewSize=10485760 -XX:MaxTenuringThreshold=5 -XX:NewSize=10485760 -XX:+PrintCommandLineFlags -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintTenuringDistribution -XX:SurvivorRatio=8 -XX:+UseCompressedClassPointers -XX:+UseCompressedOops -XX:-UseLargePagesIndividualAllocation -XX:+UseParallelGC
【PrintCommandLineFlags参数启用打印上述信息】
[GC (Allocation Failure)
Desired survivor size 1048576 bytes, new threshold 5 (max 5)
[PSYoungGen: 6455K->840K(9216K)] 6455K->4944K(19456K), 0.0036345 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
[GC (Allocation Failure) --[PSYoungGen: 7223K->7223K(9216K)] 11327K->15423K(19456K), 0.0039655 secs] [Times: user=0.11 sys=0.00, real=0.00 secs]
[Full GC (Ergonomics) [PSYoungGen: 7223K->2728K(9216K)] [ParOldGen: 8200K->8193K(10240K)] 15423K->10921K(19456K), [Metaspace: 3467K->3467K(1056768K)], 0.0059518 secs] [Times: user=0.00 sys=0.00, real=0.01 secs]
hello world
Heap
 PSYoungGen      total 9216K, used 5216K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
  eden space 8192K, 63% used [0x00000000ff600000,0x00000000ffb181b0,0x00000000ffe00000)
  from space 1024K, 0% used [0x00000000ffe00000,0x00000000ffe00000,0x00000000fff00000)
  to   space 1024K, 0% used [0x00000000fff00000,0x00000000fff00000,0x0000000100000000)
 ParOldGen       total 10240K, used 8193K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  object space 10240K, 80% used [0x00000000fec00000,0x00000000ff400500,0x00000000ff600000)
 Metaspace       used 3476K, capacity 4496K, committed 4864K, reserved 1056768K
  class space    used 385K, capacity 388K, committed 512K, reserved 1048576K
```

** Desired survivor size 1048576 bytes, new threshold 5 (max 5) **
 new threshold 5 是动态计算出来的，max 5是参数-XX:MaxTenuringThreshold=5的设定。

** Desired survivor size 1048576 bytes **
1048576是1M，因为我们的设置的survivor的大小就是1M。

**  ParOldGen       total 10240K, used 8193K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000) **
代表新生代已经有对象晋升到老年代了。

####  MaxTenuringThreshold实例讲解
编程程序：
```
/**

/**
 -verbose:gc
 -Xmx200M
 -Xmn50M
 -XX:TargetSurvivorRatio=60 表示Survivor空间存活的对象超过60%的时候，就会重新计算阈值 MaxTenuringThreshold
 -XX:+PrintTenuringDistribution
 -XX:+PrintGCDetails
 -XX:+PrintGCDateStamps 打印GC的时间戳
 -XX:+UseConcMarkSweepGC 老年代使用CMS收集器
 -XX:+UseParNewGC 新生代使用Paralle new GC
 -XX:MaxTenuringThreshold=3  阈值设置为3，理想情况对象超过三代就会晋升到老年代
 * @author : CeaserWang
 * @version : 1.0
 * @since : 2019/5/18 17:43
 */
public class MyTest4 {
    public static void main(String[] args) throws InterruptedException {
        byte [] byte_1 = new byte[1024 * 1024];
        byte [] byte_2 = new byte[1024 * 1024];
        myGc();
        Thread.sleep(1000);
        System.out.println("111111------------------------------------------------------------");
        myGc();
        Thread.sleep(1000);
        System.out.println("222222------------------------------------------------------------");
        myGc();
        Thread.sleep(1000);
        System.out.println("333333------------------------------------------------------------");
        myGc();
        Thread.sleep(1000);
        System.out.println("444444------------------------------------------------------------");

        byte [] byte_3 = new byte[1024 * 1024];
        byte [] byte_4 = new byte[1024 * 1024];
        byte [] byte_5 = new byte[1024 * 1024];

        myGc();
        Thread.sleep(1000);
        System.out.println("555555------------------------------------------------------------");

        myGc();
        Thread.sleep(1000);
        System.out.println("666666------------------------------------------------------------");
        System.out.println("hello world");
    }
    private static void myGc(){
        for(int i= 0;i <= 40;i++){
            byte [] byteArray = new byte[ 1024 * 1024];
        }
    }
}

```

程序运行结果：
```
2019-05-18T18:06:40.235+0800: [GC (Allocation Failure) 2019-05-18T18:06:40.235+0800: [ParNew
Desired survivor size 3145728 bytes, new threshold 3 (max 3)
- age   1:    2831800 bytes,    2831800 total
: 39973K->2814K(46080K), 0.0017638 secs] 39973K->2814K(199680K), 0.0019458 secs] [Times: user=0.00 sys=0.02, real=0.00 secs]
111111------------------------------------------------------------
【解释】：
[ParNew Desired survivor size 3145728 bytes：3145728 bytes 是3M，新生代空间是0M，eden：from: to = 40 : 5 : 5 ,由于我们的程序指定了-XX:TargetSurvivorRatio=60，所以 5M * 60% ≈ 3M。
- age   1:    2831800 bytes,    2831800 total： 年龄是1的对象个数是2831800个。
后面的是回收的处理， 39973K->2814K(46080K)，其中46080K是大约45M，eden是40M，survivor是5M，加起来一共是45M。

2019-05-18T18:06:41.240+0800: [GC (Allocation Failure) 2019-05-18T18:06:41.240+0800: [ParNew
Desired survivor size 3145728 bytes, new threshold 3 (max 3)
- age   1:        352 bytes,        352 total
- age   2:    2823392 bytes,    2823744 total
: 43544K->2974K(46080K), 0.0020563 secs] 43544K->2974K(199680K), 0.0020936 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
222222------------------------------------------------------------
【解释】：
[ParNew Desired survivor size 3145728 bytes, new threshold 3 (max 3)：新计算出来的threshold是3，但是我们现存的最大的年龄才是2，因此他们不会晋升到老年代。同时年龄为1的变成了2.新来的age是1.
后面是进行的一系列的垃圾回收。

2019-05-18T18:06:42.244+0800: [GC (Allocation Failure) 2019-05-18T18:06:42.244+0800: [ParNew
Desired survivor size 3145728 bytes, new threshold 3 (max 3)
- age   1:        176 bytes,        176 total
- age   2:        352 bytes,        528 total
- age   3:    2819312 bytes,    2819840 total
: 43497K->3050K(46080K), 0.0007877 secs] 43497K->3050K(199680K), 0.0008376 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
333333------------------------------------------------------------
【解释】：
这次threshold重新计算的是3，同时对象年龄是2的年龄变成了3，年龄是1的变成了2，3已经是上限了。

2019-05-18T18:06:43.247+0800: [GC (Allocation Failure) 2019-05-18T18:06:43.247+0800: [ParNew
Desired survivor size 3145728 bytes, new threshold 3 (max 3)
- age   1:     339624 bytes,     339624 total
- age   2:        176 bytes,     339800 total
- age   3:        352 bytes,     340152 total
: 43776K->854K(46080K), 0.0056892 secs] 43776K->3629K(199680K), 0.0057258 secs] [Times: user=0.03 sys=0.00, real=0.01 secs]
444444------------------------------------------------------------
【解释】：
第四次垃圾回收，这个时候第三个垃圾回收存活的对象到了第四次垃圾回收年龄会变成4,4已经是阈值上限了，因此就会被晋升到老年代，这里只存在年龄到3的，没有哦年龄到4的。

2019-05-18T18:06:44.258+0800: [GC (Allocation Failure) 2019-05-18T18:06:44.258+0800: [ParNew
Desired survivor size 3145728 bytes, new threshold 1 (max 3)
- age   1:    3145952 bytes,    3145952 total
- age   2:     339208 bytes,    3485160 total
- age   3:        176 bytes,    3485336 total
: 41571K->3484K(46080K), 0.0024575 secs] 44345K->6258K(199680K), 0.0025451 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
555555------------------------------------------------------------
【解释】：
这里new threshold已经变成了1，计算的方式是取当前age和max的最小值，最小值肯定就是1了，这样的在下次垃圾回收age为1、age为2、age为3的都会晋升到老年代。

2019-05-18T18:06:45.265+0800: [GC (Allocation Failure) 2019-05-18T18:06:45.265+0800: [ParNew
Desired survivor size 3145728 bytes, new threshold 3 (max 3)
- age   1:        176 bytes,        176 total
: 44209K->39K(46080K), 0.0027207 secs] 46983K->6239K(199680K), 0.0027832 secs] [Times: user=0.06 sys=0.01, real=0.00 secs]
666666------------------------------------------------------------
【解释】：
这次回收把上次剩下的age为1、age为2、age3为都被晋升到老年代，已经卡看不到了，但是新生代还会有新的对象涌入，所以出现了新涌入的对象，他们的age为1.这次重新调整了threshold为3，但是永远不会超过MaxTenuringThreshold=3.


hello world
Heap
 par new generation   total 46080K, used 25818K [0x00000000f3800000, 0x00000000f6a00000, 0x00000000f6a00000)
  eden space 40960K,  62% used [0x00000000f3800000, 0x00000000f512cf48, 0x00000000f6000000)
  from space 5120K,   0% used [0x00000000f6000000, 0x00000000f6009c10, 0x00000000f6500000)
  to   space 5120K,   0% used [0x00000000f6500000, 0x00000000f6500000, 0x00000000f6a00000)
 concurrent mark-sweep generation total 153600K, used 6200K [0x00000000f6a00000, 0x0000000100000000, 0x0000000100000000)
 Metaspace       used 3993K, capacity 4568K, committed 4864K, reserved 1056768K
  class space    used 447K, capacity 460K, committed 512K, reserved 1048576K
【解释】：
老年代已经使用了6200K。
```
