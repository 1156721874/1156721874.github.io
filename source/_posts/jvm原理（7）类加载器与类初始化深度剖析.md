---
title: jvm原理（7）类加载器与类初始化深度剖析
date: 2018-10-04 15:53:02
tags: classLoader
categories: jvm
---

**exampleA**：
![这里写图片描述](2018/10/04/jvm原理（7）类加载器与类初始化深度剖析/20180303154639636.png)
<!-- more -->
打印结果是3 ，并且静态代码块不会执行，原因是x是常量，在编译期就会放到MyTest8的常量池当中，然后FinalTest和MyTest8就没有任何关系了，可以通过反编译的结果看到。
把x的final去掉之后，静态代码块会打印，再去看反编译结果：

```
javap -c com.twodragonlake.jvm.classloader.MyTest8
Compiled from "MyTest8.java"
public class com.twodragonlake.jvm.classloader.MyTest8 {
  public com.twodragonlake.jvm.classloader.MyTest8();
    Code:
       0: aload_0
       1: invokespecial #1                  // Method java/lang/Object."<init>":()V
       4: return

  public static void main(java.lang.String[]);
    Code:
       0: getstatic     #2                  // Field java/lang/System.out:Ljava/io/PrintStream;
       3: getstatic     #3                  // Field com/twodragonlake/jvm/classloader/FinalTest.x:I
       6: invokevirtual #4                  // Method java/io/PrintStream.println:(I)V
       9: return
}

```
可以看到main方法的iconst_3变成
```
3: getstatic     #3                  // Field com/twodragonlake/jvm/classloader/FinalTest.x:I
```
意味着MyTest8需要引用到FinalTest，两者之间存在关系的。

**exampleB**：
```
class Parent{
    static int x = 3;
    static{
        System.out.println("Parent static block");
    }
}

class Child extends  Parent{
    static int b = 4;
    static {
        System.out.println("Child static block");
    }
}

public class MyTest9 {
    static {
        System.out.println("MyTest9 static block");
    }
    public static void main(String[] args) {
        System.out.println(Child.b);
    }
}

```
打印结果：

```
Parent static block
Child static block
4
```
即先加载运行类，然后是Parent和Child
我们可以在jvm启动参数里边加入-XX:TraceClassLoading 看到加载顺序：
![这里写图片描述](2018/10/04/jvm原理（7）类加载器与类初始化深度剖析/20180303160528398.png)

**exampleC**:

```
class Parent2{
    static int a = 3;
    static {
        System.out.println("Parent2 static block");
    }
}

class Child2 extends Parent2{
    static int b = 4;
    static {
        System.out.println("Child2 static block");
    }
}

public class MyTest10 {
    static {
        System.out.println("MyTest10 static block");
    }

    public static void main(String[] args) {
        Parent2 parent;
        System.out.println("-----------------");
        parent = new Parent2();
        System.out.println("------------------");
        System.out.println(parent.a);
        System.out.println("------------------");
        System.out.println(Child2.b);

    }
}
```
打印结果：

```
MyTest10 static block
-----------------
Parent2 static block
------------------
3
------------------
Child2 static block
4
```
解析：
		运行main方法之前MyTest10初始化，MyTest10的静态代码块执行
        Parent2 parent;//此行代码不会发生任何作用。
        System.out.println("-----------------");
        parent = new Parent2();//Parent2主动使用，触发Parent2的初始化，静态代码块被执行，打印【Parent2 static block】
        System.out.println("------------------");
        System.out.println(parent.a);//打印Parent2的静态变量
        System.out.println("------------------");
        System.out.println(Child2.b);//调用Child2的静态变量 触发Child2的初始化，从而执行Child2 的静态代码块，先打印Child2 static block，在打印4

**exampleD**:

```
class Parent3{
    static int a = 3;
    static {
        System.out.println("Parent3 static block");
    }

    static void doSomething(){
        System.out.println("doSomething...");
    }
}

class Child3 extends  Parent3 {
    static {
        System.out.println("Child3 static block");
    }
}

public class MyTest11 {
    public static void main(String[] args) {
        System.out.println(Child3.a); //a属于父类，属于对父类Parent3的主动使用，
        //虽然名字是Child3但是却不是对Child3的主动使用，导致Parent3的初始化，然后Parent3的静态代码块被执行
        Child3.doSomething();//调用父类Parent3的静态方法，是对服了的主动使用，触发父类Parent3的初始化。
    }
}
```
打印结果：

```
Parent3 static block
3
doSomething...
```
结论：
主动使用发生在静态变量定义在哪个类里边，而不是是谁调用了变量，定义变量的类会触发初始化。

**exampleE**:
```
class CL{
    static {
        System.out.println("Class CL");
    }
}

public class MyTest12 {
    public static void main(String[] args) throws Exception {
        ClassLoader classLoader = ClassLoader.getSystemClassLoader();
        Class<?> cl = classLoader.loadClass("com.twodragonlake.jvm.classloader.CL");////不会触发类的初始化
        System.out.println(cl);
        System.out.println("-------------------------");
        cl = Class.forName("com.twodragonlake.jvm.classloader.CL");////使用了反射，这属于类初始化时机的反射时机。会触发类的初始化。
        System.out.println(cl);
    }
}
```
打印结果：

```
class com.twodragonlake.jvm.classloader.CL
-------------------------
Class CL
class com.twodragonlake.jvm.classloader.CL
```
调用classLoader类的loadClass方法加载一个类，并不是对类的主动使用，不会导致类的初始化
这个例子验证了类的初始化时机的反射时机，具体参考之前的文章：[主动使用（七种）](http://blog.csdn.net/wzq6578702/article/details/79369460)
