---
title: jvm原理（42）JVM垃圾回收重要理论剖析以及算法分析与演示
date: 2019-05-01 18:34:12
tags: [垃圾收集器]
categories: jvm
---

### 内存区域的回顾
垃圾收集器和java的内存分布有着紧密的联系，因此我们要对jvm的内存布局回顾一下，jvm的内存布局大致分为如下：
<!-- more -->
![memarea](memarea.png)
![memarea1](memarea1.png)

JVM运行时数据区域-例子
```
public void method(){
  Object obj = new Object();
}
```

- 生成了2个部分的内存区域，1）obj这个引用变量，因为是方法内的变量，放到JVM Stack里面，2）真正Object class的实例对象，放到Heap里面。
- 上述的new 语句一共消耗12个bytes，JVM规定引用占用4个bytes（在JVM stack），而空对象是8个bytes（在 Heap）
- 方法结束后，对应Stack中的变量马上回收，但是Heap中的对象要等到GC来回收。

### 垃圾判断算法

#### 引用计数算法（Reference Counting）
- 给对象添加一个引用计数器，当有一个地方引用它，计数器加1，当引用失效，计数器减一，任何时刻计数器为0的对象就是不可能再被使用的。
- 引用计数器算法无法解决对象循环引用的问题。
![countreference](countreference.png)
上图所示，A引用B，B引用A，但是外界引用都断了，不存在对“环”的引用，但是他们的引用计数器都是1，引用计数算法就不会对他们进行回收，会一直在内存中。


#### 根搜索算法（Root Tracing）
- 在实际的生产语言中（java、C#等）都是使用根搜索算法判定对象是否存活
- 算法基本思路 就是通过一系列的称为“GC Roots”的点作为起始进行向下搜索，当一个对象到GC Roots没有任何引用链（
Reference Chain）相连，则证明此对象是不可用的

- 在java语言中，GCRoots 包括
  - 在JVM栈(帧中的本地变量)中的引用
  - 方法区中的静态引用
  - JNI(即一般说的Native方法)中的引用

##### 方法区
- java虚拟机规范表示可以不要求虚拟机在这区实现GC，这区GC的“性价比”一般比较低。
- 在堆中，尤其是在新生代，常规应用进行一次GC一般可以回收70%-95%的空间，而方法区的FC效率远小于此。
- 当前的商业JVM都有实现方法区的GC，主要回收两部分内容：废弃常量与无用类。
- 类回收需要满足如下三个条件
  - 该类所有的实例都已经被GC，也就是JVM中不存在该Class的任何实例
  - 加载该类的ClassLoader已经被GC
  - 该类对应的java.lang.Class对象没有在任何地方呗引用，如不能在任何地方通过反射访问该类的方法。
  - 在大量使用反射、冬天代理、CGlib等字节码框架、动态生成jsp以及OSGI这类频繁自定义一ClassLoader的场景都需要
  JVM具备类卸载的支持以保证方法区不会溢出。


### GC算法
- 标记 -清楚算法(Mark-Sweep)
- 标记-整理算法(Mark-Compact)
- 复制算法(Copying)
- 分代算法(Generational)

#### 标记 -清楚算法(Mark-Sweep)
- 算法分为“标记”和"清除" 两个阶段，首先标记出所有需要回收的对象，然后回收所有需要回收的对象。
- 缺点
  - 效率问题，标记和清理两个过程效率都不高
  - 空间问题，标记清理之后会产生大量不连续的内存碎片，空间碎片太多可能会导致后续使用中无法找到足够的连续内存而提前
  触发另一次的垃圾搜索集动作。
  ![runtimeStack-Heap.png](runtimeStack-Heap.png)
  ![runtimeStack-Heap1.png](runtimeStack-Heap1.png)
  ![runtimeStack-Heap2.png](runtimeStack-Heap2.png)  
  ![runtimeStack-Heap3.png](runtimeStack-Heap3.png)  
  ![runtimeStack-Heap4.png](runtimeStack-Heap4.png)  
  最后阴影部分被回收掉，F、J、M不能被root trace到，因此也会被回收。

- 效率不高，需要扫描所有对象，堆越大，GC越大。碎片越严重。
- 存在内存碎片问题，GC次数越多，

#### 复制(Coping)搜集算法
- 将可用内存划分为两块，每次只是用其中的一块，当半区内存用完了，仅将还存活的对象复制到另外一块上面，然后就把原来的整块内存空间一次性清理掉
- 这样使得每次内存回收都是对整个半区的回收，内存分配时也就不用考虑内存碎片等复杂情况，只要移动堆顶指针、按顺序分配内存
就可以了，实现简单，运行效率高。
只是这种算法的代价是将内存缩小为原来的一半，代价昂贵。
- 现在的商业虚拟机中都是用了这一种收集算法回收新生代。
- 将内存分为一块较大的eden空间和快较少的survival空间，每次使用eden和其中一块survivor，当回收时将eden和survivor还存活的对象一次性
拷贝到另外一块survival空间上，然后清理掉eden和用过的survivor：
- Oracle Hotspot虚拟机默认eden和survivor的大小比例是8:1，也就是每次只有10% 的内存是"浪费"的。
- 复制收集算法在对象存活率高的时候，效率有所下降。
- 如果不想浪费50%的空间，就需要有额外的空间进行分配担保用于应付半区内存中所有对象都有100%存活的极端情况，所以在老年代一般不能直接选用这种算法。
![coping1.png](coping1.png)
![coping2.png](coping2.png)
![coping3.png](coping3.png)
![coping4.png](coping4.png)
![coping5.png](coping5.png)
- 只需要扫描存活的对象，效率更高
- 不会产生碎片
- 需要浪费额外的内存作为复制区
- 复制的算法非常适合生命周期比较短的对象，每次GC总能回收大部分的对象，复制的开销比较小
- 根据IBM的专门研究，98%的java对象只会存活一个GC周期，对这些对象很适合用复制算法。而且不用1:1的划分工作区和复制区的空间

#### 标记整理算法(Mark-Compact)
- 标记过程仍然一样，但后续步骤不是进行直接清理，而是令所有存活的对象一端移动，然后直接清理掉这端边界以外的内存。
![mark-compact1.png](mark-compact1.png)
- 没有内存碎片
- 比Mark-Sweep耗费更多的时间进行compact


#### 分代收集算法(Genaratinal Collecting)
- 当前商业虚拟机的垃圾收集都是采用“分代收集”算法根据对象不同存活周期将内存划分为几块
- 一般是把java堆分作新生代和老年代，这样就可以根据各个年代的特点采用最适当的收集算法，譬如新生代每次GC都有大批量对象死去，
只有少量存活，那就选用复制算法只需要付出少量存活对象的复制成本就可以完成收集。

综合前面几种GC算法的优缺点，针对不同生命周期的对象采用不同的GC算法。
![choice.png](choice.png)
- Hotspot JVM 6(jdk8之前)中共划分为三个代：年轻代(Ypung Generation)\老年代(Old Generation)和永久代(Permanent Generation)
![choice1.png](choice1.png)
- 年轻代
  - 新生代的对象都放在新生代，年轻代用复制算法进行GC（理论上年轻代的对象的生命周期非常短，所以适合复制算法）
  - 年轻代分三个区。一个Eden区，两个Survivor区（可以通过参数设置Survivor个数）。对象在Eden区中生成，当Eden区满时，
  此区的存活对象被复制到另外一个survivor区，当第二个Survivor区也满了的时候，从第一个Survivor区复制过来的并且此时还存活的对象，将被复制到老年代，2个Survivor
  是完全对称，轮流替换。
  - Eden和2个Survivor的缺省比例是8:1:1，也就是10%的空间会被浪费，可以根据GC log的信息调整大小的比例。
- 老年代
  - 存放了经过一次或多次GC还存活的对象
  - 一般采用Mark-Sweep或者Mark-Compact算法进行GC
  - 有多种垃圾收集器可以选择。每种垃圾收集器可以看作一个GC算法的具体实现。可以根据具体应用的需求选用合适的垃圾收集器
  (追求吞吐量？追求最短的响应时间？)

- ~~永久代~~
  - 比不属于堆(Heap)但是GC也会涉及到这个区域
  - 存放了每个Class的结构信息，包括常量池、字段描述、方法描述、与垃圾收集要收集的对象关系不大。

  ![memstruct.png](memstruct.png)

### 内存分配
1. 堆上分配
大多数情况在eden上分配，偶尔会直接在old上分配
2. 栈上分配
原子类型的局部变量

### 内存回收
- GC要做的是将那些dead的对象所占用的内存回收掉
  - hotspot认为没有引用的对象是dead的
  - hotspot将引用分为四种：Strong、Soft、Week、Phantom
    - Strong即默认通过Object o = newObject()这种方式赋值的引用‘
    - Soft、Week、Phantom这三种则都是继承Reference
- 在Full GC时会对Reference类型的引用进行特殊处理
  - Soft：内存不够时一定会被GC、长期不用也会被GC
  - Week：一定会被GC，当被mark为dead，会在ReferenceQueue中通知
  - Phantom：贝莱就没有引用，当jvm heap中释放时会通知

###垃圾收集算法
![Recycling_algorithm.png](Recycling_algorithm.png)

### GC的时机
- 在分代模型的基础上，GC从时机上分为两种：scavenge GC和Full GC
- Scavenge GC(Minor GC)
  - 触发时机：新对象生成时，Eden空间满了
  - 理论上Eden区大多数对象会在Scavenge GC回收，复制算法的执行效率会很高，Scavenge GC时间比较短。
- Full GC
  - 对整个JVM进行整理，包括Young、Old和Perm
  - 主要的触发时机：1）、old满了 2）Perm满了 3）system.gc()
  - 效率很低，尽量减少Full GC。


### 垃圾回收器的实现和选择
#### 垃圾回收器的实现和选择
- 分代模型：GC的宏观愿景；
- 垃圾回收器：GC的具体实现
- Hotspot JVM提供多种垃圾回收器，我们需要根据具体应用的需要采用不同的回收器
- 没有万能的垃圾回收器，每种垃圾回收器都有自己的适合场景

#### 垃圾收集器的“并行”和“并发”
- 并行(Parallel)：指多个收集器的线程同时工作，但是用户线程处于等待状态
- 并发(Concurrent):指收集器工作的同时，可以允许用户线程工作。
  - 并发不代表解决了GC停顿的问题，在关键的步骤还是要停顿。比如在收集器标记垃圾的时候但在清除垃圾的时候，用户线程可以和
  GC线程并发执行。

#### Serial收集器
- 单线程收集器，收集时会暂停所有的工作线程(Stop The world，简称STW)，使用复制收集算法，虚拟机运行在client模式时的默认新生代收集器。
- 最早的收集器，单线程进行GC
- new和Old Generation都可以使用
- 在新生代，采用复制算法；在老年代，采用Mark-comopact算法
- 因为是单线程GC，没有多线程切换的额外开销，简单实用
- Hotspot Client模式缺省的收集器
![serial.png](serial.png)

#### ParNew收集器
- ParNew收集器就是Serial的多线程版本，除了使用多个收集器线程外，其余行为包括算法、stw、对象分配规则、回收策略等都与serial收集器一模一样。
- 对应的这种收集器是虚拟机运行在Server模式的默认新生代收集器，在单CPU的环境中，ParNew收集器并不会比Serial
收集器有更好的效果。
- 使用复制算法(因为针对新生代)
- 只有在多CPU的环境下，效率才会比Serial收集器高
- 可以通过-XX:ParallelGCThreads来控制GC线程数的多少。需要结合具体CPU的个数
- Server模式下新生代的缺省收集器

#### Parallel Scavenge收集器
- Parallel Scavenge收集器也是单线程收集器，也是使用复制算法，但它的对象分配规则与回收策略都与ParNew收集器
有所不同，它是以吞吐量最大化(即GC时间占用运行时间最小)为目标的收集器实现，它允许较长时间的STW换取总吞吐量最大化。

#### serial Old收集器
- serial Old是单线程收集器，使用标记-整理算法，是老年代的收集器

#### Parallel Old收集器
- 老年代版本吞吐量优先收集器，使用多线程和标记-整理算法，JVM 1.6提供，在此之前，新生代使用PS收集器的话，老年代除
serial OLd外别无选择，因为PS无法与CMS收集器配合工作
- Parallel Scavenge在老年代的实现
- 在、具名 1.6才出现Parallel Old
- 采用多线程，Mark-compact算法
- 更注重吞吐量
- Parallel Scavenge + Parallel Old = 高吞吐量，但GC停顿可能不理想。
![parallel_old.png](parallel_old.png)


#### CMS收集器(Concurrent Mark Sweep)
- CMS是一种以最短停顿时间为目标的收集器，使用CMS并不能达到GC效率最高(总体GC时间最小)，但它能尽可能降低GC时
服务的停顿时间，CMS收集器使用的是标记-清除算法

- CMS以牺牲CPU资源的代价来减少用户线程的停顿。当CPU个数少的时候，有可能对吞吐量影响非常大。
- CMS在并发清理的过程中，用户线程还在跑，这时候需要预留一部分空间给用户线程。
- CMS用Mark-Sweep，会带来碎片问题，碎片过多的时候会容易频繁触发Ful GC



### java内存泄露的经典原因
- 对象定义在错误的范围内
- 异常(Exception)处理不当。
- 集合数据管理不当

#### 对象定义在错误的范围(wrong scope)
- 如果Foo实例对象的生命较长，会导致临时性内存泄露。（这里指的names变量其实只有临时作用）
```
class Foo{
  private String[] names;
  public void doit(int length){
    if(names == null || names.length < length)
      names = new String[length];
    populate(names);
    print(names);
  }
}
```

- JVM 喜欢生命周期短的对象，这样做已经足够高效
```
class Foo{

  public void doit(int length){
      private String[] names =  new String[length];
      populate(names);
      print(names);
  }
}
```

#### 异常处理不当
```
Connection con = new DriverManager.getConnection(url,name,passwd);
try{
  String sql = "do a query sql";
  PrepareStatement stmt = conn.PrepareStatement(sql);
  ResultStatment rs = stmt.executeQuery();
  while(re.next()){
    doSomeStuff();
  }
  rs.close();
  conn.close();
}catch(Exception e){
  //如果doSomeStuff()抛出异常
  //rs.close和conn.close()不会被调用，
  //会导致内存泄露和db连接泄露
}
```

#### 集合数据管理不当
- 当使用Array-based的数据结构(ArrayList,HashMap等)时，尽量减少resize
  - 比如new ArrayList时，尽量估算size，在创建的时候把size确定
  - 减少resize可以避免没有必要的array coping，gc碎片等问题
- 如果一个List只需要顺序访问，不需要随机访问(Random Access),用LingkList代替ArrayList
  - LinkList本质是是链表，不需要resize，但是适用于顺序访问。
