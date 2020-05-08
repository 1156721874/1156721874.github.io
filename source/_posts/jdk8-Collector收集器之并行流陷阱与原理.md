---
title: jdk8-Collector收集器之并行流陷阱与原理
date: 2018-10-04 10:32:39
tags: jdk8 并发收集器
categories: javaBase
---

收集器Collector是jdk8中最为重要的接口之一，一个Collector可分为5个部分（第五个是我自己加上的）：
1、supplier
<!-- more -->
2、accumulator
3、combiner
4、finisher
5、characteristics

Collector有三个泛型：<T, A, R>分别是：
T：被操作集合的每个元素类型
A：supplier提供的中间容器类型
R：返回的结果类型

从收集器源码可以看出他的组成：

```
public interface Collector<T, A, R> {
    /**
     * A function that creates and returns a new mutable result container.
     * @return a function which returns a new, mutable result container
     * 容器提供者
     */
    Supplier<A> supplier();

    /**
     * A function that folds a value into a mutable result container.
     * @return a function which folds a value into a mutable result container
     * 累加操作
     */
    BiConsumer<A, T> accumulator();

    /**
     * A function that accepts two partial results and merges them.  The
     * combiner function may fold state from one argument into the other and
     * return that, or may return a new result container.
     *
     * @return a function which combines two partial results into a combined
     * result
     * 并发的情况将每个线程的中间容器A合并
     */
    BinaryOperator<A> combiner();

    /**
     * Perform the final transformation from the intermediate accumulation type
     * {@code A} to the final result type {@code R}.
     *
     * <p>If the characteristic {@code IDENTITY_TRANSFORM} is
     * set, this function may be presumed to be an identity transform with an
     * unchecked cast from {@code A} to {@code R}.
     *
     * @return a function which transforms the intermediate result to the final
     * result
     * 终止操作
     */
    Function<A, R> finisher();

    /**
     * Returns a {@code Set} of {@code Collector.Characteristics} indicating
     * the characteristics of this Collector.  This set should be immutable.
     *
     * @return an immutable set of collector characteristics
     * 收集器特性
     */
    Set<Characteristics> characteristics();

    /**
     * Returns a new {@code Collector} described by the given {@code supplier},
     * {@code accumulator}, and {@code combiner} functions.  The resulting
     * {@code Collector} has the {@code Collector.Characteristics.IDENTITY_FINISH}
     * characteristic.
     *
     * @param supplier The supplier function for the new collector
     * @param accumulator The accumulator function for the new collector
     * @param combiner The combiner function for the new collector
     * @param characteristics The collector characteristics for the new
     *                        collector
     * @param <T> The type of input elements for the new collector
     * @param <R> The type of intermediate accumulation result, and final result,
     *           for the new collector
     * @throws NullPointerException if any argument is null
     * @return the new {@code Collector}
     */
    public static<T, R> Collector<T, R, R> of(Supplier<R> supplier,
                                              BiConsumer<R, T> accumulator,
                                              BinaryOperator<R> combiner,
                                              Characteristics... characteristics) {
        Objects.requireNonNull(supplier);
        Objects.requireNonNull(accumulator);
        Objects.requireNonNull(combiner);
        Objects.requireNonNull(characteristics);
        Set<Characteristics> cs = (characteristics.length == 0)
                                  ? Collectors.CH_ID
                                  : Collections.unmodifiableSet(EnumSet.of(Collector.Characteristics.IDENTITY_FINISH,
                                                                           characteristics));
        return new Collectors.CollectorImpl<>(supplier, accumulator, combiner, cs);
    }

    /**
     * Returns a new {@code Collector} described by the given {@code supplier},
     * {@code accumulator}, {@code combiner}, and {@code finisher} functions.
     *
     * @param supplier The supplier function for the new collector
     * @param accumulator The accumulator function for the new collector
     * @param combiner The combiner function for the new collector
     * @param finisher The finisher function for the new collector
     * @param characteristics The collector characteristics for the new
     *                        collector
     * @param <T> The type of input elements for the new collector
     * @param <A> The intermediate accumulation type of the new collector
     * @param <R> The final result type of the new collector
     * @throws NullPointerException if any argument is null
     * @return the new {@code Collector}
     */
    public static<T, A, R> Collector<T, A, R> of(Supplier<A> supplier,
                                                 BiConsumer<A, T> accumulator,
                                                 BinaryOperator<A> combiner,
                                                 Function<A, R> finisher,
                                                 Characteristics... characteristics) {
        Objects.requireNonNull(supplier);
        Objects.requireNonNull(accumulator);
        Objects.requireNonNull(combiner);
        Objects.requireNonNull(finisher);
        Objects.requireNonNull(characteristics);
        Set<Characteristics> cs = Collectors.CH_NOID;
        if (characteristics.length > 0) {
            cs = EnumSet.noneOf(Characteristics.class);
            Collections.addAll(cs, characteristics);
            cs = Collections.unmodifiableSet(cs);
        }
        return new Collectors.CollectorImpl<>(supplier, accumulator, combiner, finisher, cs);
    }

    /**
     * Characteristics indicating properties of a {@code Collector}, which can
     * be used to optimize reduction implementations.
     */
    enum Characteristics {
        /**
         * Indicates that this collector is <em>concurrent</em>, meaning that
         * the result container can support the accumulator function being
         * called concurrently with the same result container from multiple
         * threads.
         *
         * <p>If a {@code CONCURRENT} collector is not also {@code UNORDERED},
         * then it should only be evaluated concurrently if applied to an
         * unordered data source.
         */
        CONCURRENT,

        /**
         * Indicates that the collection operation does not commit to preserving
         * the encounter order of input elements.  (This might be true if the
         * result container has no intrinsic order, such as a {@link Set}.)
         */
        UNORDERED,

        /**
         * Indicates that the finisher function is the identity function and
         * can be elided.  If set, it must be the case that an unchecked cast
         * from A to R will succeed.
         */
        IDENTITY_FINISH
    }
}

```

Javadoc对前边四个做了说明：

  A {@code Collector} is specified by four functions that work together to
  accumulate entries into a mutable result container, and optionally perform
  a final transform on the result.  They are:
      creation of a new result container ({@link #supplier()})
      incorporating a new data element into a result container ({@link #accumulator()})
      combining two result containers into one ({@link #combiner()})
      performing an optional final transform on the container ({@link #finisher()})
  

**supplier:**是一个容器提供者，提供容器A,比如：List list = new ArrayList()；
**accumulator:**是要操作的集合的每个元素以怎样的形式添加到supplier提供的容器A当中，即做累加操作，比如：List.add(item)；
**combiner:**用于在多线程并发的情况下，每个线程都有一个supplier和，如果有N个线程那么就有N个supplier提供的容器A，执行的是类似List.addAll(listB)这样的操作,只有在characteristics没有被设置成CONCURRENT并且是并发的情况下 才会被调用。ps：characteristics被设置成CONCURRENT时，整个收集器只有一个容器，而不是每个线程都有一个容器，此时combiner()方法不会被调用，这种情况会出现java.util.ConcurrentModificationException异常,此时需要使用线程安全的容器作为supplier返回的对象。
**finisher:**是终止操作，如果收集器的characteristics被设置成IDENTITY_FINISH，那么会将中间集合A牵制转换为结果R类型，如果A和R没有父子之类的继承关系，会报类型转换失败的错误，如果收集器的characteristics没有被设置成IDENTITY_FINISH，那么finisher()方法会被调用，返回结果类型R。

关于枚举**Characteristics**是用来控制收集器的相关特性，它在Collector接口内部：

```
 /**
     * Characteristics indicating properties of a {@code Collector}, which can
     * be used to optimize reduction implementations.
     */
    enum Characteristics {
        /**
         * Indicates that this collector is <em>concurrent</em>, meaning that
         * the result container can support the accumulator function being
         * called concurrently with the same result container from multiple
         * threads.
         *如果一个收集器被标记为concurrent特性，那么accumulator 方法可以被多线程并发的的调用，并且只使用一个容器A
         * <p>If a {@code CONCURRENT} collector is not also {@code UNORDERED},
         * then it should only be evaluated concurrently if applied to an
         * unordered data source.
         * 如果收集器被标记为concurrent，但是要操作的集合失败有序的，那么最终得到的结果不能保证原来的顺序
         */
        CONCURRENT,

        /**
         * Indicates that the collection operation does not commit to preserving
         * the encounter order of input elements.  (This might be true if the
         * result container has no intrinsic order, such as a {@link Set}.)
         * 适用于无序的集合
         */
        UNORDERED,

        /**
         * Indicates that the finisher function is the identity function and
         * can be elided.  If set, it must be the case that an unchecked cast
         * from A to R will succeed.
         * 如果收集器特性被设置IDENTITY_FINISH，那么会强制将中间容器A类型转换为结果类型R
         */
        IDENTITY_FINISH
    }
```

下面我们写一个自定义的收集器了解他的原理：


```
package com.ceaser.jdk8lambda.stream2;

import java.util.*;
import java.util.function.BiConsumer;
import java.util.function.BinaryOperator;
import java.util.function.Function;
import java.util.function.Supplier;
import java.util.stream.Collector;
import java.util.stream.Collectors;

import static java.util.stream.Collector.Characteristics.CONCURRENT;
import static java.util.stream.Collector.Characteristics.IDENTITY_FINISH;
import static java.util.stream.Collector.Characteristics.UNORDERED;

/**
 * Created by CeaserWang on 2017/2/27.
 * 此收集器的作用是将Set集合转换为Map
 */
public class MyCollectorA<T> implements Collector<T,Set<T>,Map<T,T>> {
    @Override
    public Supplier<Set<T>> supplier() {
        System.out.println("supplier invoked...");
        return HashSet::new;//实例化一个存放中间结果的集合Set
    }

    @Override
    public BiConsumer<Set<T>,T> accumulator() {
        System.out.println("accumulator invoked...");
        return (item1,item2) -> {

            /**
             *  *  A a1 = supplier.get();
             *     accumulator.accept(a1, t1);
             *     accumulator.accept(a1, t2);
             *     R r1 = finisher.apply(a1);  // result without splitting
             *
             *     A a2 = supplier.get();
             *     accumulator.accept(a2, t1);
             *     A a3 = supplier.get();
             *     accumulator.accept(a3, t2);
             *     R r2 = finisher.apply(combiner.apply(a2, a3));  // result with splitting
             */

           // System.out.println("current thread : "+item1+" , "+Thread.currentThread().getName());
            item1.add(item2);//将遍历的每个元素加入到Set当中
        };

    }

    @Override
    public BinaryOperator<Set<T>> combiner() {
        System.out.println("combiner invoked...");
        return (item1,item2) -> {
            item1.addAll(item2);//多线程下，集合Set的合并操作
            System.out.println("--------");
            return item1;
        };
    }

    @Override
    public Function<Set<T>,Map<T,T>> finisher() {
        System.out.println("finisher invoked...");
        return (item1) ->{
            Map<T,T> rm = new HashMap<T,T>();
            item1.stream(). forEach( (bean) -> rm.put(bean,bean) );//将Set集合的每个元素加入到新的map之中
          return rm;
        };
    }

    @Override
    public Set<Characteristics> characteristics() {
        System.out.println("characteristics invoked...");
        return Collections.unmodifiableSet(EnumSet.of(UNORDERED,CONCURRENT));//支持并发操作，并且是不能保证原始集合的顺序。
    }
}
```

测试类：

```
/**
 * Created by Ceaser Wang on 2017/2/27.
 */
public class MyCollectorATest {
    public static void main(String[] args) {
        List<String> list = Arrays.asList("hello","world","welcome","helloworld","helloworldA");
        Set<String> set = new HashSet<>();
        set.addAll(list);
        Map<String,String> maped =  set.parallelStream().collect(new MyCollectorA<>());
    }
}
```

输入出结果：

```
characteristics invoked...
supplier invoked...
accumulator invoked...
characteristics invoked...
finisher invoked...
```
**并发陷阱分析：**

	可以看到收集器的特性被设置成CONCURRENT，并且是parallelStream，执行过程中没有调用combiner()方法。因为只有一个公用的容器没必要再去掉combiner()合并中间结果。PS：在单线程模式下，并且特性设置成CONCURRENT，combiner()会被调用。
接下来我们将accumulator的这行注释放开：

```
System.out.println("current thread : "+item1+" , "+Thread.currentThread().getName());
```
再去运行，会报错（如果一次没有出现，多运行几次）：

```
Exception in thread "main" java.util.ConcurrentModificationException: java.util.ConcurrentModificationException
	at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:62)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at java.util.concurrent.ForkJoinTask.getThrowableException(ForkJoinTask.java:593)
	at java.util.concurrent.ForkJoinTask.reportException(ForkJoinTask.java:677)
	at java.util.concurrent.ForkJoinTask.invoke(ForkJoinTask.java:735)
	at java.util.stream.ForEachOps$ForEachOp.evaluateParallel(ForEachOps.java:160)
	at java.util.stream.ForEachOps$ForEachOp$OfRef.evaluateParallel(ForEachOps.java:174)
	at java.util.stream.AbstractPipeline.evaluate(AbstractPipeline.java:233)
	at java.util.stream.ReferencePipeline.forEach(ReferencePipeline.java:418)
	at java.util.stream.ReferencePipeline$Head.forEach(ReferencePipeline.java:583)
	at java.util.stream.ReferencePipeline.collect(ReferencePipeline.java:496)
	at com.ceaser.jdk8lambda.stream2.MyCollectorATest.main(MyCollectorATest.java:17)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:498)
	at com.intellij.rt.execution.application.AppMain.main(AppMain.java:147)
Caused by: java.util.ConcurrentModificationException
	at java.util.HashMap$HashIterator.nextNode(HashMap.java:1437)
	at java.util.HashMap$KeyIterator.next(HashMap.java:1461)
	at java.util.AbstractCollection.toString(AbstractCollection.java:461)
	at java.lang.String.valueOf(String.java:2994)
	at java.lang.StringBuilder.append(StringBuilder.java:131)
	at com.ceaser.jdk8lambda.stream2.MyCollectorA.lambda$accumulator$0(MyCollectorA.java:43)
	at java.util.stream.ReferencePipeline.lambda$collect$1(ReferencePipeline.java:496)
	at java.util.stream.ForEachOps$ForEachOp$OfRef.accept(ForEachOps.java:184)
	at java.util.HashMap$KeySpliterator.forEachRemaining(HashMap.java:1548)
	at java.util.stream.AbstractPipeline.copyInto(AbstractPipeline.java:481)
	at java.util.stream.ForEachOps$ForEachTask.compute(ForEachOps.java:291)
	at java.util.concurrent.CountedCompleter.exec(CountedCompleter.java:731)
	at java.util.concurrent.ForkJoinTask.doExec(ForkJoinTask.java:289)
	at java.util.concurrent.ForkJoinPool$WorkQueue.runTask(ForkJoinPool.java:1056)
	at java.util.concurrent.ForkJoinPool.runWorker(ForkJoinPool.java:1692)
	at java.util.concurrent.ForkJoinWorkerThread.run(ForkJoinWorkerThread.java:157)
```

为什么呢？
我们只是输出了中间容器的内容，我们看下这行错误信息对应的代码：

```
	at java.util.AbstractCollection.toString(AbstractCollection.java:461)
```
对应的是AbstractCollection的toString：

```
    public String toString() {
        Iterator<E> it = iterator();
        if (! it.hasNext())
            return "[]";

        StringBuilder sb = new StringBuilder();
        sb.append('[');
        for (;;) {
            **E e = it.next();**//这样代码是对Set集合进行遍历
            sb.append(e == this ? "(this Collection)" : e);
            if (! it.hasNext())
                return sb.append(']').toString();
            sb.append(',').append(' ');
        }
    }
```
E e = it.next();
此行代码是对集合进行遍历，在多线程下对未同步的集合同时遍历和修改操作会导致ConcurrentModificationException这种异常（其他的HashMap多线程下回出现死循环问题），
为此我们需要替换使用线程安全的集合，比如ConcurrentHashMap等等。

**IDENTITY_FINISH特性：**

打开collect方法的源码我们看到：

```
    @Override
    @SuppressWarnings("unchecked")
    public final <R, A> R collect(Collector<? super P_OUT, A, R> collector) {
        A container;
        if (isParallel()
                && (collector.characteristics().contains(Collector.Characteristics.CONCURRENT))
                && (!isOrdered() || collector.characteristics().contains(Collector.Characteristics.UNORDERED))) {
            container = collector.supplier().get();
            BiConsumer<A, ? super P_OUT> accumulator = collector.accumulator();
            forEach(u -> accumulator.accept(container, u));
        }
        else {
            container = evaluate(ReduceOps.makeRef(collector));
        }
        return collector.characteristics().contains(Collector.Characteristics.IDENTITY_FINISH)
               ? (R) container
               : collector.finisher().apply(container);
    }
```
当收集器的特性包含IDENTITY_FINISH特性时，会把收集器内部的中间集合A强制转换为R（当中间容器类型A和结果类型R不同时，但是又设置了IDENTITY_FINISH特性，那么会抛出java.lang.ClassCastException），否则才会调用收集器的finisher()方法。
