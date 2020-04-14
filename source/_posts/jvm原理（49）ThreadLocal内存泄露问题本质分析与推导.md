---
title: jvm原理（49）ThreadLocal内存泄露问题本质分析与推导
date: 2020-04-0 21:37:13
tags: [ThreadLocal、存泄露]
categories: jvm
---

### threadLocal内存溢出分析
![threadlocal-stack-heap.png](threadlocal-stack-heap.png)
我们使用ThreadLocal的方式一般是static的。
public static ThreadLocal<String> threadlocal = new ThreadLocal();

假设：
entry的key指向的threadlocal的引用是强引用，那么如果栈里边的threadlocal = null;，此时由于key指向ThreadLocal的对象是强引用，无法回收，此时出现内存泄露。

那么如果将key指向ThreadLocal的对象改成弱引用，那么threadlocal = null;的时候，现在只有key指向ThreadLocal，而且是弱引用，那么下次gc，ThreadLocal会被回收掉。

还有一种情况是是key指向的ThreadLocal被置成null，key指向null，那么value还没有被回收，这种情况也是内存泄露，对于这种情况ThreadLocal的实现里边做了规避。即在get和set方法里边调用了expungeStaleEntry()方法。

### 防止内存泄露
使用完毕之后调用一下set和get，或者remove方法，清除key为null的entry。
