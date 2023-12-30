---
title: jvm原理（40）JVM元空间深度解析
date: 2019-04-21 21:45:28
tags: [meta space]
categories: jvm
---

### metaspace
jdk8当中class的元数据放在元空间里边，元空间是os的一部分内存，对元空间的管理会存在元空间不够会动态扩容，如果扩容还不够就会oomm异常，为了模拟这种错误，我们可以限制metaspace的大小，下面是
<!-- more -->
测试代码，我们使用cglib的api不断的动态生成class,限制metaspace的大小是10兆：
```
/**
 * 引入cglib："cglib:cglib:3.2.8"
 * 方法区产生内存溢出的情况。.
 * 指定metaspace大小：-XX:MaxMetaspaceSize=10m
 * @author : CeaserWang
 * @version : 1.0
 * @since : 2019/4/21 21:34
 */
public class MyTest4 {
    public static void main(String[] args) {
        for(;;){
            Enhancer enhancer = new Enhancer();
            enhancer.setSuperclass(MyTest4.class);
            enhancer.setUseCache(false);
            enhancer.setCallback((MethodInterceptor)(obj, method, args1, proxy) -> proxy.invokeSuper(obj,args));
            System.out.println("hello world");
            enhancer.create();
        }
    }
}
```

运行结果：
```
....
hello world
hello world
Exception in thread "main"
Exception: java.lang.OutOfMemoryError thrown from the UncaughtExceptionHandler in thread "main"
```
现在修改-XX:MaxMetaspaceSize=200m运行，打开jvisualvm监控类的和metasapce的曲线：
![metaspace](2019/04/21/jvm原理（40）JVM元空间深度解析/metaspace.png)
metaspace是一直上升的，等程序出现oom的时候，会看到metaspace的上升停止了：
![metaspace](2019/04/21/jvm原理（40）JVM元空间深度解析/metaspace1.png)
验证了MaxMetaspaceSize的作用。
目前我们通过程序和监控的方式知道metaspace会出现oom，那么metaspace到底是什么呢？通过这篇文章：
[Java 永久代去哪儿了](https://www.infoq.cn/article/Java-PERMGEN-Removed) 我们就能知道。
