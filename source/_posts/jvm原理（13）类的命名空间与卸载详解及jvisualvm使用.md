---
title: jvm原理（13）类的命名空间与卸载详解及jvisualvm使用
date: 2018-10-04 16:04:00
tags: [命名空间,卸载]
categories: jvm
---

**类的命名空间**
[上篇文章](http://blog.csdn.net/wzq6578702/article/details/79601719)的结尾到了命名空间的问题，我们接下来继续演进程序，我们删除当前工程的MyTest.class文件，然后修改main方法：
<!-- more -->

```
    public static void main(String[] args) throws Exception {
        MyTest16 myClassLoader = new MyTest16("myClassLoader");
        myClassLoader.setPath("E:\\data\\classes\\");
        Class<?> clazz = myClassLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz.hashCode());
        Object object = clazz.newInstance();
        System.out.println(object);
        System.out.println("-----------------------------------------");
        MyTest16 myClassLoader1 = new MyTest16(myClassLoader,"myClassLoader1");
        myClassLoader1.setPath("E:\\data\\classes\\");
        Class<?> clazza = myClassLoader1.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazza.hashCode());
        Object objecta = clazza.newInstance();
        System.out.println(objecta);
    }
```
修改的地方是【MyTest16 myClassLoader1 = new MyTest16(myClassLoader,"myClassLoader1");】
用myClassLoader作为myClassLoader1 的父加载器。
打印结果：

```
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader
class :21685669
com.twodragonlake.jvm.classloader.MyTest@7f31245a
-----------------------------------------
class :21685669
com.twodragonlake.jvm.classloader.MyTest@6d6f6e28
```
是不是懵逼了呢？首先MyTest.class文件被删除了，然后myClassLoader去加载的时候委托父加载器（应用类加载器）没有找到MyTest.class，所以myClassLoader完成加载任务，之后myClassLoader1去加载同一个类，首先会委托myClassLoader1的父加载器myClassLoader去加载，myClassLoader已经加载过MyTest.class，所以会直接返回之前的接在结果，因此看到的被加载类的hashcode编码是相同的，并且myClassLoader1没有再一次执行加载过程。

继续修改main方法，然后保留当前项目的MyTest.class文件：

```
    public static void main(String[] args) throws Exception {
        MyTest16 myClassLoader = new MyTest16("myClassLoader");
        myClassLoader.setPath("E:\\data\\classes\\");
        Class<?> clazz = myClassLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz.hashCode());
        Object object = clazz.newInstance();
        System.out.println(object);
        System.out.println("-----------------------------------------");
        MyTest16 myClassLoader1 = new MyTest16(myClassLoader,"myClassLoader1");
        myClassLoader1.setPath("E:\\data\\classes\\");
        Class<?> clazza = myClassLoader1.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazza.hashCode());
        Object objecta = clazza.newInstance();
        System.out.println(objecta);

        System.out.println("---------------------------------------------");

        MyTest16 myClassLoader2 = new MyTest16("myClassLoader2");
        myClassLoader2.setPath("E:\\data\\classes\\");
        Class<?> clazz2 = myClassLoader2.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz2.hashCode());
        Object object2 = clazz2.newInstance();
        System.out.println(object2);
    }
```
没错，new了一个myClassLoader2 然后运行结果如下：

```
class :356573597
com.twodragonlake.jvm.classloader.MyTest@677327b6
-----------------------------------------
class :356573597
com.twodragonlake.jvm.classloader.MyTest@14ae5a5
---------------------------------------------
class :356573597
com.twodragonlake.jvm.classloader.MyTest@7f31245a
```
这个结果还是挺简单的，从myClassLoader开始都是应用类加载器，下边的myClassLoader1 和 myClassLoader2都是用的系统类加载器。

如果我们把当前工程下的MyTest.class删除呢？~
打印结果：

```
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader
class :21685669
com.twodragonlake.jvm.classloader.MyTest@7f31245a
-----------------------------------------
class :21685669
com.twodragonlake.jvm.classloader.MyTest@6d6f6e28
---------------------------------------------
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader2
class :856419764
com.twodragonlake.jvm.classloader.MyTest@2503dbd3

```
myClassLoader和myClassLoader1的打印结果之前分析过了这次略过，myClassLoader2的结果是怎么回事呢。首先MyTest.class被删除了，myClassLoader2的父加载器是应用类加载器，在当前工程下找不到，所以使用了myClassLoader2去加载，因此myClassLoader2的加载逻辑被调用，同时myClassLoader2有属于自己的命名空间，所以MyTest.class被加载，它的hashcode是和其他的加载器不一样的。

我们继续，再修改main方法一行代码：

```
 MyTest16 myClassLoader2 = new MyTest16(myClassLoader1,"myClassLoader2");
```
即将myClassLoader2 的父加载器指定为myClassLoader1，然后保留当前工程的MyTest.class文件，打印结果：

```
class :356573597
com.twodragonlake.jvm.classloader.MyTest@677327b6
-----------------------------------------
class :356573597
com.twodragonlake.jvm.classloader.MyTest@14ae5a5
---------------------------------------------
class :356573597
com.twodragonlake.jvm.classloader.MyTest@7f31245a
```
显然都是应用类加载器加载的MyTest.class，因为能在当前工程找到MyTest.class文件。
如果我们把MyTest.class文件删除掉，再去运行，结果：

```
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader
class :21685669
com.twodragonlake.jvm.classloader.MyTest@7f31245a
-----------------------------------------
class :21685669
com.twodragonlake.jvm.classloader.MyTest@6d6f6e28
---------------------------------------------
class :21685669
com.twodragonlake.jvm.classloader.MyTest@135fbaa4
```
可以看到myClassLoader从E:\data\classes\com\twodragonlake\jvm\classloader下边加载了一次之后，myClassLoader1和myClassLoader2都会使用之前myClassLoader加载的结果，因为myClassLoader1和myClassLoader2的父加载器都是myClassLoader。

**类的卸载**
![这里写图片描述](20180318175607171.png)
![这里写图片描述](20180318175636684.png)
![这里写图片描述](20180318180041169.png)
即Java虚拟机自带的加载器加载的类不会在整个jvm的生命周期中被卸载，而自定义加载器加载的类可以被卸载。

修改MyTest16的main方法：

```
    public static void main(String[] args) throws Exception {
        MyTest16 myClassLoader = new MyTest16("myClassLoader");
        myClassLoader.setPath("E:\\data\\classes\\");
        Class<?> clazz = myClassLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz.hashCode());
        Object object = clazz.newInstance();
        System.out.println(object);
        System.out.println("-----------------------------------------");

        myClassLoader = new MyTest16("myClassLoader3");
        myClassLoader.setPath("E:\\data\\classes\\");
        clazz = myClassLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz.hashCode());
        object = clazz.newInstance();
        System.out.println(object);
        System.out.println("-----------------------------------------");
     }
```

打印：

```
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader
class :21685669
com.twodragonlake.jvm.classloader.MyTest@7f31245a
-----------------------------------------
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader3
class :1173230247
com.twodragonlake.jvm.classloader.MyTest@330bedb4
-----------------------------------------
```

我们怎么才能证明myClassLoader被卸载了呢，在启动参数里边加入【-XX:+TraceClassUnloading】运行也是没有结果可以看到被卸载，我们将将要被卸载的变量显示的置空一下：

```
        MyTest16 myClassLoader = new MyTest16("myClassLoader");
        myClassLoader.setPath("E:\\data\\classes\\");
        Class<?> clazz = myClassLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz.hashCode());
        Object object = clazz.newInstance();
        System.out.println(object);
        System.out.println("-----------------------------------------");
		// 显式置空
        myClassLoader= null;
        clazz = null;
        object = null;
        System.gc();

        myClassLoader = new MyTest16("myClassLoader3");
        myClassLoader.setPath("E:\\data\\classes\\");
        clazz = myClassLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz.hashCode());
        object = clazz.newInstance();
        System.out.println(object);
        System.out.println("-----------------------------------------");
```
打印结果：

```
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader
class :21685669
com.twodragonlake.jvm.classloader.MyTest@7f31245a
-----------------------------------------
[Unloading class com.twodragonlake.jvm.classloader.MyTest 0x00000007c0061828]
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader3
class :1173230247
com.twodragonlake.jvm.classloader.MyTest@330bedb4
-----------------------------------------
```
可以看到【[Unloading class com.twodragonlake.jvm.classloader.MyTest 0x00000007c0061828]】证明之前的被卸载了。
为了直观的看到jvm对它的回收我们使用jvisualvm工具，我们在System.gc();这行代码后面加上 Thread.sleep(100000);以便于我们观察。
先运行jvisualvm：
![这里写图片描述](20180318194540694.png)
然后运行我们的main方法在visualvm里边打开我们的程序进程，找到监视，可以看到有一个类被卸载：
![这里写图片描述](20180318194809142.png)
