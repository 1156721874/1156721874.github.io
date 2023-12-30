---
title: jvm原理（15）类加载器命名空间实战剖析与透彻理解
date: 2018-10-04 16:08:08
tags: 类加载器命名空间
categories: jvm
---

新建类MyTest17_1：

<!-- more -->
```
public class MyTest17_1 {
    public static void main(String[] args)  throws Exception{
        MyTest16 loader1 = new MyTest16("loader1");
        loader1.setPath("E:\\data\\classes\\");
        Class<?> clazz = loader1.loadClass("com.twodragonlake.jvm.classloader.MySample");
        System.out.println("class :"+clazz.hashCode());
        //如果注释掉改行，那么并不会实例化MySample对象，即MySample构造方法不会被调用
        //因此不会实例化MyCat对象，既没有对MyCat进行主动使用，这里就不会加载MyCat class
        Object object = clazz.newInstance();
    }
}
```
和MyTest17不同的是我们指定了Path，运行结果还是：

```
class :1735600054
MySample is loaded by : sun.misc.Launcher$AppClassLoader@18b4aac2
MyCat is loaded by : sun.misc.Launcher$AppClassLoader@18b4aac2
```
ok，现在我们把当前工程下的MySample和MyCat的class文件删除掉，然后copy一份到E:\\data\\classes\\下边，运行程序：

```
findClass invoked com.twodragonlake.jvm.classloader.MySample【加载MySample时MyTest16的打印】
 this.classLoaderName : loader1                             【MySample是由MyTest16加载，MyTest16的打印】
class :2133927002                                           【MyTest17_1的打印】
MySample is loaded by : com.twodragonlake.jvm.classloader.MyTest16@677327b6   【MySample构造器】
findClass invoked com.twodragonlake.jvm.classloader.MyCat   【MySample的构造器new MyCat的时候要先加载MyCat】
 this.classLoaderName : loader1                              【MyCat是由MyTest16加载的】
MyCat is loaded by : com.twodragonlake.jvm.classloader.MyTest16@677327b6  【MyCat构造器的打印】
```
好，我们继续做一个实验，重新编译当前工程，让MyCat和MySample的class文件出现，然后删除MyCat的class文件，注意此时MySample在当前工程和【E:\\data\\classes\\】下都有一份，而MyCat只在【E:\\data\\classes\\】有一份，当前工程不存在MyCat的class文件，运行程序：

```
class :1735600054
Exception in thread "main" java.lang.NoClassDefFoundError: com/twodragonlake/jvm/classloader/MyCat
MySample is loaded by : sun.misc.Launcher$AppClassLoader@18b4aac2
	at com.twodragonlake.jvm.classloader.MySample.<init>(MySample.java:6)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:62)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at java.lang.Class.newInstance(Class.java:442)
	at com.twodragonlake.jvm.classloader.MyTest17_1.main(MyTest17_1.java:11)
Caused by: java.lang.ClassNotFoundException: com.twodragonlake.jvm.classloader.MyCat
	at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
	at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
	at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:331)
	at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
	... 7 more
```
**分析：**【 Class<?> clazz = loader1.loadClass("com.twodragonlake.jvm.classloader.MySample");】运行的时候应用类加载器可以在当前classpath下找到MySample所以就会加载，因此打印【class :1735600054】然后在执行【 Object object = clazz.newInstance();】的时候，MySample的构造器里边进行new MyCat的操作，这个时候加载了MySample的加载器（应用类加载器）会去尝试加载MyCat的class（应用类加载器先委托扩展类加载器，无法加载然后在委托系统类加载器加载，也无法加载，最后只能应用类加载器加载），但是MyCat的class已经被我们删除了，因此抛出ClassNotFoundException。

那好如果我们理解了这一步，接下来我们重新编译工程，重新让MyCat和MySample的class文件出现，然后我们删掉当前工程的MySample的class文件，保留当前工程的MyCat的class文件（PS：【E:\\data\\classes\\】下边存在MyCat和MySample的class文件），运行程序，打印结果是啥呢？？？

```
findClass invoked com.twodragonlake.jvm.classloader.MySample
 this.classLoaderName : loader1
class :2133927002
MySample is loaded by : com.twodragonlake.jvm.classloader.MyTest16@677327b6
MyCat is loaded by : sun.misc.Launcher$AppClassLoader@18b4aac2
```
首先MySample在当前工程已经被删除了，所以应用类加载器无法加载，会使用我们自定义的类加载器MyTest16去加载MySample，因此打印：

```
findClass invoked com.twodragonlake.jvm.classloader.MySample
 this.classLoaderName : loader1
```
之后【class :2133927002】是MyTest17_1的打印，在MySample的构造器new MyCat的时候，加载器了MySample的加载器（MyTest16）会尝试加载MyCat，MyTest16自己并不会去加载MyCat，它首先会委托应用类加载器去加载，，应用类加载器能不能加载呢?答案是可以加载，因为MyCat在当前classPath下（当前工程里边的，不是【E:\\data\\classes\\】下边的），所以后边不会出现自定义加载MyTest16的log日志，之后直接打印MyCat构造器的输出【MyCat is loaded by : sun.misc.Launcher$AppClassLoader@18b4aac2】。MySample和MyCat是由2个不同的加载器加载出来的。

ok，继续下一个实验：我们在MyCat 构造器里边加入一行代码：

```
public class MyCat {
    public MyCat(){
        System.out.println("MyCat is loaded by : "+this.getClass().getClassLoader());
        System.out.println("from MyCat : "+MySample.class);//加入打印MySample的一行代码
    }
}
```
重新build当前工程让MySample和MyCat文件出现在当前工程下，然后copy MyCat的class文件到【E:\\data\\classes\\】下边，之后删除当前工程下的MySample的class文件，运行MyTest17_1程序。打印如下：

```
findClass invoked com.twodragonlake.jvm.classloader.MySample
 this.classLoaderName : loader1
Exception in thread "main" java.lang.NoClassDefFoundError: com/twodragonlake/jvm/classloader/MySample
	at com.twodragonlake.jvm.classloader.MyCat.<init>(MyCat.java:6)
	at com.twodragonlake.jvm.classloader.MySample.<init>(MySample.java:6)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:62)
	at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	at java.lang.Class.newInstance(Class.java:442)
	at com.twodragonlake.jvm.classloader.MyTest17_1.main(MyTest17_1.java:11)
Caused by: java.lang.ClassNotFoundException: com.twodragonlake.jvm.classloader.MySample
	at java.net.URLClassLoader.findClass(URLClassLoader.java:381)
	at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
	at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:331)
	at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
	... 8 more
class :2133927002
MySample is loaded by : com.twodragonlake.jvm.classloader.MyTest16@677327b6
MyCat is loaded by : sun.misc.Launcher$AppClassLoader@18b4aac2
```
**分析：**
首先这个例子和上一个例子只有一个地方不同就是在MyCat的构造器里边加了一行打印MySample的代码，而且MySample和MyCat是由不同的类加载器加载的：

```
MySample is loaded by : com.twodragonlake.jvm.classloader.MyTest16@677327b6  【MySample由MyTest16加载】
MyCat is loaded by : sun.misc.Launcher$AppClassLoader@18b4aac2                【MyCat由AppClassLoader加载】
```
但是为什么出现MySample的ClassNotFoundException的异常呢，原因就是类的命名空间：
![这里写图片描述](2018/10/04/jvm原理（15）类加载器命名空间实战剖析与透彻理解/20180405180203363.png)
即，子加载器可以看到父加载器加载的类，但是父加载器看不到子加载器加载的类，这个例子当中，MySample由子加载器MyTest16加载，MyCat由父加载器AppClassLoader加载，因此在父加载器里边看不到子加载器MyTest16加载的类MySample，所以抛出ClassNotFoundException异常。

ok，最后一个例子，
MySample（加入MyCat的打印） ：
```
public class MySample {
    public MySample(){
        System.out.println("MySample is loaded by : "+this.getClass().getClassLoader());
        new MyCat();
        System.out.println("form MySample :"+MyCat.class);
    }
}
```
MyCat （注释掉MySample的打印）：
```
public class MyCat {
    public MyCat(){
        System.out.println("MyCat is loaded by : "+this.getClass().getClassLoader());
       // System.out.println("from MyCat : "+MySample.class);
    }
}
```
重新buid当前工程，生成MyCat 和MySample的class文件，拷贝一份到【E:\\data\\classes\\】下边，然后删除当前工程的MySample的class文件，运行MyTest17_1程序，打印结果：

```
findClass invoked com.twodragonlake.jvm.classloader.MySample
 this.classLoaderName : loader1
class :2133927002
MySample is loaded by : com.twodragonlake.jvm.classloader.MyTest16@677327b6
MyCat is loaded by : sun.misc.Launcher$AppClassLoader@18b4aac2
form MySample :class com.twodragonlake.jvm.classloader.MyCat
```
**分析：**
首先MySample的class不在当前工程下，因此会使用自定义加载器MyTest16加载，MySample的构造器里边出现new MyCat，因此会使用子加载器MyTest16的父加载器应用类加载器加载MyCat，之后【System.out.println("form MySample :"+MyCat.class);】这行代码是在子类加载器MyTest16里边出现，由于子类加载器可以看到父类加载器加载的类，因此不会抛出异常。

**关于命名空间的重要说明**
1、子加载器所加载的类能够访问到父加载器所加载的类
2、父加载器所加载的类无法访问到子类加载器所加载的类
