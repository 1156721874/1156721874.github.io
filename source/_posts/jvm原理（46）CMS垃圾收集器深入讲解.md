---
title: jvm原理（46）CMS垃圾收集器深入讲解
date: 2019-05-19 15:16:32
tags: [CMS]
categories: jvm
---

### CMS收集器
- CMS (concurrent mark sweep)收集器，以获取最短回收停顿时间为目标，多数应用于互联网站或者b/s系统的服务器上。
- cms是基于“标记-清除”算法实现的，整个过程分为4个步骤：
  - 初始标记(cms initial mark)
  - 并发标记(cms concurrent mark)
  - 重新标记(cms remark)
  - 并发清除(cms concurrent sweep)

- 其中，初始标记、重新标记这两个步骤需要stw（stop the world）
- 初始标记只是标记一下GC root能直接关联到的对象速度很快
- 并发标记阶段就是进行Gc roots tracing的过程。
 重新标记阶段则是为了修正并发标记期间因用户程序继续运作而导致的标记产生变动的那一部分对象的标记记录，这个阶段的停顿时间一般
 会比初始标记阶段稍长一些，但远比并发标记的时间短。

- cms收集器的运作步骤哦如下图所示，在整个过程中耗时最长的并发标记和并发清除过程收集器线程都可以与用户线程一起工作，因此，从总体上看，cms收集器的内存回收过程是与用户线程一起并发执行的。
![cms1.png](cms1.png)
 - 优点
  - 并发收集、低停顿，oracle公司的一些官方文档中也称之为并发底停顿(concurrent low pause collector)
 - 缺点
  - cms收集器对cpu资源非常敏感
  - cms收集器无法处理浮动垃圾(floating garbage)，可能出现“concurrent mode failure”失败而导致另一次full gc的产生，如果在应用中
  老年代增长不是太快，可以适当调高参数-XX：CMSInitiatingOccupancyFraction的值来提高触发百分比，以便降低内存回收次数从而获取更好的性能，要是cms运行期间预留的百分比无法满足程序需要时，这样停顿时间就很长了。所以说参数-XX：CMSInitiatingOccupancyFraction设置得太高容易很容易导致大量"concurrent mode Failure"失败，性能反而降低
  - 收集结束会有大量空间碎片产生，空间碎片过多时，将会给大对象分配带来很大麻烦，往往出现老年代还有很大空间剩余，但是无法找到足够大的连续空间来分配当前对象，不得不提前进行一次full gc。cms收集器提供了一个-XX:UseCMSCompactAtFullCollection开关参数（默认就是开启的），用于在cms收集器顶不住要进行full gc时开启内存碎片的合并整理过程，内存整理的过程无法并发的，空间碎片问题就没有了，但是停顿时间不得不边长。

#### 空间分配担保
- 在发生minor gc之前，虚拟机会先检查老年代最大可用的连续空间是否大于新生代所有对象总空间，如果这个条件成立，那么minor gc可以确保是安全的。当大量对象在minor gc后仍然存活，就需要老年代进行空间分配担保，把survivor无法容纳的对象直接进入老年代。如果老年代判断到剩余空间不足（根据以往每一次回收晋升到老年代对象容量的平均值作为经验），则进行一次full gc。



#### cms收集器收集步骤
- phase1：initial mark
- phase2：concurrent mark
- phase3：concurrent preclean
- phase4：concurrent abortable Preclean
- phase5：final remark
- phase6：concurrent sweep
- phase7：concurrent reset

#### phase1 initial mark
- 这个是cms两次stop-the-world事件的其中一次，这个阶段的目标是：标记那些直接被gc root引用或者被年轻代存活对象所引用的所有对象。
![cms2.png](cms2.png)

#### phase2：concurrent mark
- 在这个阶段garbage collecor会遍历老年代，然后标记所存活的对象，他会根据上个阶段找到gc roots遍历查找，并发标记阶段，她会与用户的应用程序并发运行。并不是老年代所有的存活对象会被标记，因为在标记期间用户的程序可能会改变一些引用
![cms3.png](cms3.png)
在上面的图中，与阶段一的图进行比对，就会发现有一个对象的引用已经发生了变化。

#### phase3：concurrent preclean
- 这也是一个并发阶段，与应用的线程并发运行，并不会stop应用的线程，在并发运行的过程中，一些对象的引用可能会发生变化，但是这种情况发生时，jvm会将包含这个对象的区域(card)标记为Dirty，这也是Card Marking
- 在pre-clean阶段，那些能够从Dirty对象到达的对象也会被标记，这个标记做完之后，dirty card标记就会被清除了
![cms4.png](cms4.png)

#### phase4：concurrent abortable Preclean
- 这也是一个并发阶段，但是同样不会影响用户的应用线程，这个阶段就是为了尽量承担stw中最终标记阶段的工作。这个阶段持续时间依赖于很多的
因素，由于这个阶段是在重复做相同的工作，直接满足一些条件（比如：重复迭代的次数、完成的工作量或时钟时间等）


#### phase5：final remark
- 这个是第二个stw阶段，也是cms中的最后一个，这个阶段的目标是标记老年代所有的存活对象，由于之前的阶段是并发执行的，gc线程可能跟不上
应用程序的变化，为了完成标记老年代所有存活对象的目标，stw就非常油必要了。
- 通常cms的final remark阶段会在年轻代尽可能干净的时候运行，目的是为了减少连续stw发生的可能性（年轻代存活对象多的话，也会导致老年代涉及的存活对象会很多），这个阶段会比前面的几个阶段更复杂一些

#### 标记阶段完成
- 经历过五个阶段之后，老年代所有存活对象都被标记过了，现在可以通过清楚算法去清理那些老年代不再使用的对象。

#### phase6：concurrent sweep
- 这里不需要stw，它是与用户的应用程序并发运行，这个阶段是：清除那些不再使用的对象，回收它们的占用空间将来使用。
![cms5.png](cms5.png)

#### phase7：concurrent reset
- 这个阶段也是并发执行的，它会重设cms内部的数据结构，为了下次的gc做准备。

#### 总结
- cms通过将大量的工作分散到并发处理阶段来减少stw时间，在这块做得非常优秀，但是cms也有一些其他的问题。
- cms收集器无法处理浮动垃圾（floating garbage），可能出现“concurrent mode failure”失败而导致一次full gc的产生，可能引发串行full gc；
- 空间碎片，导致无法分配大对象，cms收集器提供了一个-XX:+UseCMSCompactAtCollection 开关参数（默认就是开启的），用于在cms收集器顶不住要进行full gc时开启内存碎片的合并整理过滤，内存整理的过程是无法并发的，空间碎片问题没有了，但停顿时间不得不变长。
- 对于堆比较大应用，gc的时间难以预估。

#### 演示
编写程序：
```

/**
 -verbose:gc
 -Xms20M
 -Xmx20M
 -Xmn10M
 -XX:+PrintGCDetails
 -XX:SurvivorRatio=8
 -XX:+UseConcMarkSweepGC
 * @author : CeaserWang
 * @version : 1.0
 * @since : 2019/5/25 13:33
 */
public class MyTest5 {
    public static void main(String[] args) {
        int size = 1024 * 1024;
        byte[] myAlloc1 = new byte[5 * size];
        System.out.println("111111");
        byte[] myAlloc2 = new byte[5 * size];
        System.out.println("22222");
        byte[] myAlloc3 = new byte[2 * size];
        System.out.println("333333");
        byte[] myAlloc4 = new byte[3 * size];
        System.out.println("444444");

    }
}

```

运行结果：
```
111111
[GC (Allocation Failure) [ParNew: 7479K->727K(9216K), 0.0041447 secs] 7479K->5849K(19456K), 0.0042252 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
22222
333333
[GC (Allocation Failure) [ParNew: 8135K->8135K(9216K), 0.0000160 secs][CMS: 5122K->5120K(10240K), 0.0037131 secs] 13257K->12996K(19456K), [Metaspace: 3484K->3484K(1056768K)], 0.0037862 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
[GC (CMS Initial Mark) [1 CMS-initial-mark: 8192K(10240K)] 16068K(19456K), 0.0007341 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
解释：
cms收集器的第一步初始标记，8192K老年代存活对象占用的空间大小，10240K是老年代总的大小10M，16068K是整个堆存活对象占用的空间，
19456K是整个堆的大小。

[CMS-concurrent-mark-start]
444444[CMS-concurrent-mark: 0.000/0.000 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
解释：
cms的第二步并发标记。

[CMS-concurrent-preclean-start]

[CMS-concurrent-preclean: 0.000/0.000 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
解释：cms的第三步，预清理阶段

[CMS-concurrent-abortable-preclean-start]
[CMS-concurrent-abortable-preclean: 0.000/0.000 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
解释：
cms的第四步清理步骤abortable-preclean

[GC (CMS Final Remark) [YG occupancy: 8192 K (9216 K)][Rescan (parallel) , 0.0005659 secs][weak refs processing, 0.0000219 secs][class unloading, 0.0002576 secs][scrub symbol table, 0.0003794 secs][scrub string table, 0.0000947 secs][1 CMS-remark: 8192K(10240K)] 16384K(19456K), 0.0013843 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
解释：
cms的最第五步，最终标重新记阶段，
[YG occupancy: 8192 K (9216 K)]：表示新生代存活对象占用的空间是 8192 K，新生代总的大小是9216 K，
Rescan (parallel)：要做最终标记需要进行的重新扫描。
[weak refs processing, 0.0000219 secs]：弱引用的处理。
[class unloading, 0.0002576 secs]：类的卸载。
[scrub symbol table, 0.0003794 secs]：符号表的处理。
[scrub string table, 0.0000947 secs]：字符串表的处理。

[CMS-concurrent-sweep-start]
解释：cms的并发清除开始

由于程序demo的原因这里还有一步是[CMS-concurrent-concurrent reset]的步骤。

[GC (Allocation Failure) [ParNew: 8192K->8192K(9216K), 0.0000165 secs][CMS[CMS-concurrent-sweep: 0.000/0.000 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
 (concurrent mode failure): 8192K->707K(10240K), 0.0024162 secs] 16384K->707K(19456K), [Metaspace: 3485K->3485K(1056768K)], 0.0024779 secs] [Times: user=0.02 sys=0.00, real=0.00 secs]
Heap
 par new generation   total 9216K, used 82K [0x00000000fec00000, 0x00000000ff600000, 0x00000000ff600000)
  eden space 8192K,   1% used [0x00000000fec00000, 0x00000000fec14938, 0x00000000ff400000)
  from space 1024K,   0% used [0x00000000ff500000, 0x00000000ff500000, 0x00000000ff600000)
  to   space 1024K,   0% used [0x00000000ff400000, 0x00000000ff400000, 0x00000000ff500000)
 concurrent mark-sweep generation total 10240K, used 707K [0x00000000ff600000, 0x0000000100000000, 0x0000000100000000)
 Metaspace       used 3491K, capacity 4498K, committed 4864K, reserved 1056768K
  class space    used 387K, capacity 390K, committed 512K, reserved 1048576K
```
通过上面程序的例子就能反证出cms收集器的一些收集的过程。
