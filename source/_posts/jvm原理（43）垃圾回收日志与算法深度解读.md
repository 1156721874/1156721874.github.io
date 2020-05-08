---
title: jvm原理（43）垃圾回收日志与算法深度解读
date: 2019-05-12 14:17:52
tags:  [垃圾收集器日志]
categories: jvm
---

编写测试程序：
```
<!-- more -->
/**
jvm参数：
* -verbose:gc 输出打印详细的GC日志
* -Xms20M     堆空间最小值
* -Xmx20M     堆空间最大值
* -Xmn10M     堆空间新生代的大小
* -XX:+PrintGCDetails  打印GC的详细的信息
* -XX:SurvivorRatio=8  eden和survivor的比例是8:1
*/
public class MyTest1 {
    public static void main(String[] args) {
        int size = 1024 * 1024;
        byte[] myAlloc1 = new byte[3 * size];
        byte[] myAlloc2 = new byte[3 * size];
        byte[] myAlloc3 = new byte[3 * size];
        //byte[] myAlloc4 = new byte[3 * size];
        System.out.println("hello world");
    }
}
```
输出：
```
[GC (Allocation Failure) [PSYoungGen: 5431K->840K(9216K)] 5431K->3920K(19456K), 0.0027228 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
hello world
Heap
 PSYoungGen      total 9216K, used 7304K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
  eden space 8192K, 78% used [0x00000000ff600000,0x00000000ffc50230,0x00000000ffe00000)
  from space 1024K, 82% used [0x00000000ffe00000,0x00000000ffed2020,0x00000000fff00000)
  to   space 1024K, 0% used [0x00000000fff00000,0x00000000fff00000,0x0000000100000000)
 ParOldGen       total 10240K, used 3080K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  object space 10240K, 30% used [0x00000000fec00000,0x00000000fef02010,0x00000000ff600000)
 Metaspace       used 3471K, capacity 4496K, committed 4864K, reserved 1056768K
  class space    used 384K, capacity 388K, committed 512K, reserved 1048576K

```
** [GC (Allocation Failure) [PSYoungGen: 5431K->840K(9216K)] 5431K->3920K(19456K), 0.0027228 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] **
GC:表示是minor gc，如果是full gc就会显示“FULL GC”
Allocation Failure：表示失败原因，这里指的是内存分配失败，导致的GC
PSYoungGen：Parallel Scavenge 在新生代的收集器。
 5431K->840K(9216K)：垃圾回收之前在新生代存活的对象占据的空间是5431K -> 垃圾回收之后在新生代存活对象所占据的容量是840K(新生代总的空间是9216K,即9M，一个eden是8M + 一个survivor是1M = 9M)
 5431K->3920K(19456K)： 执行GC之前总的堆里边存活对象占据的大小是5431K -> GC执行完之后整个堆存活对象占据的大小是3920K(整个堆的容量是19456K，即19M，新生代浪费了一个survivor，所以是20M - 1M  = 19M)。
0.0027228 secs：指的是本次执行GC耗费的时间是  0.0027228秒。
[Times: user=0.00 sys=0.00, real=0.00 secs]：用户空间用了0.00秒，内核空间用了0.00秒，实际用的时间是0.00秒。

** PSYoungGen      total 9216K, used 7304K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000) **

Parallel Scavenge 在新生代，一共新生代的大小是9216K，已经使用了7304K。

** eden space 8192K, 78% used [0x00000000ff600000,0x00000000ffc50230,0x00000000ffe00000) **
eden空间是8192K，使用了78%的eden空间。

** from space 1024K, 82% used [0x00000000ffe00000,0x00000000ffed2020,0x00000000fff00000) **
from空间是1024K，使用了82%的from survivor空间。

** to   space 1024K, 0% used [0x00000000fff00000,0x00000000fff00000,0x0000000100000000) **
to空间是1024K，使用了0%的to survivor空间。

**  ParOldGen       total 10240K, used 3080K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000) **
老年代的收集器Parallel old，parOld收集器，老年代占据的空间是10240K，即10M，已经使用了3080K。
5431K - 840K = 4591K //指的是新生代释放的空间
5431K - 3920K = 1511K //指的是整个堆释放的空间，1511K是真正从整个堆里边彻底消失的的空间。

4591K -  1511K = 3080K， 3080K就是ParOldGen已经使用的空间大小，新生代释放的空间4591K一部分是彻底从堆里边消失的，另一部分去了老年代，那我们用新生代释放的空间4591K减去彻底从堆里边释放的1511K剩下的就是从新生代晋升到老年代的对象，这部分晋升的对象占据的空间就是老年代的使用空间3080K。


打开注释的【byte[] myAlloc4 = new byte[3 * size];】运行：
```
[GC (Allocation Failure) [PSYoungGen: 5431K->840K(9216K)] 5431K->3920K(19456K), 0.0028338 secs] [Times: user=0.08 sys=0.02, real=0.00 secs]
[GC (Allocation Failure) [PSYoungGen: 7222K->792K(9216K)] 10302K->10016K(19456K), 0.0051217 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
[Full GC (Ergonomics) [PSYoungGen: 792K->0K(9216K)] [ParOldGen: 9224K->9894K(10240K)] 10016K->9894K(19456K), [Metaspace: 3438K->3438K(1056768K)], 0.0064424 secs] [Times: user=0.00 sys=0.00, real=0.01 secs]
hello world
Heap
 PSYoungGen      total 9216K, used 3501K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
  eden space 8192K, 42% used [0x00000000ff600000,0x00000000ff96b7e8,0x00000000ffe00000)
  from space 1024K, 0% used [0x00000000fff00000,0x00000000fff00000,0x0000000100000000)
  to   space 1024K, 0% used [0x00000000ffe00000,0x00000000ffe00000,0x00000000fff00000)
 ParOldGen       total 10240K, used 9894K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  object space 10240K, 96% used [0x00000000fec00000,0x00000000ff5a9a48,0x00000000ff600000)
 Metaspace       used 3460K, capacity 4496K, committed 4864K, reserved 1056768K
  class space    used 383K, capacity 388K, committed 512K, reserved 1048576K
```
** [Full GC (Ergonomics) [PSYoungGen: 792K->0K(9216K)] [ParOldGen: 9224K->9894K(10240K)] 10016K->9894K(19456K), [Metaspace: 3438K->3438K(1056768K)], 0.0064424 secs] [Times: user=0.00 sys=0.00, real=0.01 secs] **

Ergonomics:失败原因是Ergonomics。
PSYoungGen：新生代的收集器。
[PSYoungGen: 792K->0K(9216K)]：新生代收集之前对象占用的空间是792K，回收之后对象占用的空间是0K，新生代一共9216K(9M)。
[ParOldGen: 9224K->9894K(10240K)]：老年代的收集器ParOldGen，回收之前老年代对象占用空间是9224K，回收之后老年代对象占用空间是
  9894K(没有减少反而增多，是因为新生代晋升到老年代的对象)，老年代总共的大小是10240K(10M)。
10016K->9894K(19456K)：整个堆空间里边回收之前对象占用的空间是10016K，回收之后对象占用的空间是9894K，整个堆大小是19456K。
[Metaspace: 3438K->3438K(1056768K)]：元空间回收之前对象占用空间是3438K，回收之后占用的空间是3438K，即没有变化，元空间总共大小是1056768K。
 0.0064424 secs：本次 Full GC执行花费时间是 0.0064424 secs。

**  ParOldGen       total 10240K, used 9894K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000) **
老年的收集器，总共空间是10240K，已经使用了9894K，和上面的Full GC收集完毕之后对象占用的空间9894K是一致的。


现在我们修改下程序：
```
/**
 * -verbose:gc 输出打印详细的GC日志
 * -Xms20M     堆空间最小值
 * -Xmx20M     堆空间最大值
 * -Xmn10M     堆空间新生代的大小
 * -XX:+PrintGCDetails  打印GC的详细的信息
 * -XX:SurvivorRatio=8  eden和survivor的比例是8:1
 *
 * @author : CeaserWang
 * @version : 1.0
 * @since : 2019/5/12 14:26
 */
public class MyTest1 {
    public static void main(String[] args) {
        int size = 1024 * 1024;
        byte[] myAlloc1 = new byte[3 * size];
        byte[] myAlloc2 = new byte[3 * size];
        byte[] myAlloc3 = new byte[4 * size];
        byte[] myAlloc4 = new byte[4 * size];
        System.out.println("hello world");
    }
}

```

myAlloc3和myAlloc4改成4倍的size(之前是倍的size)，然后运行程序：
```
[GC (Allocation Failure) [PSYoungGen: 5431K->872K(9216K)] 5431K->3952K(19456K), 0.0024476 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
hello world
Heap
 PSYoungGen      total 9216K, used 8360K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
  eden space 8192K, 91% used [0x00000000ff600000,0x00000000ffd50230,0x00000000ffe00000)
  from space 1024K, 85% used [0x00000000ffe00000,0x00000000ffeda020,0x00000000fff00000)
  to   space 1024K, 0% used [0x00000000fff00000,0x00000000fff00000,0x0000000100000000)
 ParOldGen       total 10240K, used 7176K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  object space 10240K, 70% used [0x00000000fec00000,0x00000000ff302020,0x00000000ff600000)
 Metaspace       used 3488K, capacity 4498K, committed 4864K, reserved 1056768K
  class space    used 387K, capacity 390K, committed 512K, reserved 1048576K
```

我们加大了内存申请的大小反而没有出现Full GC，如果是3倍的size会出现Full GC，这是什么原因？

myAlloc1、myAlloc2如果能在新生代存放，新生代是10M的空间，这时候myAlloc3来了，之前已被myAlloc1和myAlloc2占据了6M的新生代空间，
这次4M的myAlloc3肯定无法在新生代存放，这种情况JVM的策略是把myAlloc3直接放到老年代，myAlloc3加myAlloc4是8M空间，老年代是10M的
空间大小，是能够存放的。所以没有发生Full GC。

另外jdk1.8新生代和老年代默认收集器：
PSYoungGen: Parallel Scavenge(新生代垃圾收集器)
ParOldGen：Parallel Old (老年代垃圾收集器)
