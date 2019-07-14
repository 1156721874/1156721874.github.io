---
title: jvm原理（1）类加载器深入解析与阶段分解
date: 2018-10-04 15:36:45
tags: ClassLoader
categories: jvm
---

类加载
--

 - 在Java代码中，类型（class 、interface、 enum etc）的加载（将字节码从磁盘加载到内存），连接（类与类之间的关系的连接）与初始化过程都是在程序运行期间完成的，加载，连接，初始化顺序不是固定的，不同的虚拟机实现不一样。
 - 提供了更大的灵活性，增加了更多的可能性。

类加载器深入剖析
--
 - Java虚拟机与程序的周期
 - 在如下几种情况下，Java虚拟机将结束生命周期。
	 - 执行了System.ext()方法。
	 - 程序正常执行结束
	 - 程序在执行过程中遇到了异常或错误而异常终止。
	 - 由于操作系统错误而导致Java虚拟机进程终止。
	 -
类的加载、连接与初始化
--
 - 加载：查找并加载类的二进制数据
 - 连接：
	 - 验证：确保被加载类的正确性。
	 - 准备：为类的<font color=#ff0000 size=2 face="黑体">静态变量</font>分配内存，并将其初始化为<font color=#ff0000 size=2 face="黑体">默认值</font>。
	 - 解析：<font color=#ff0000 size=2 face="黑体">把类中的符号引用装换为直接引用</font>。
 - <font color=#ff0000 size=2 face="黑体">初始化：为类的静态变量赋予正确的初始值</font>。
***
 - Java程序对类的使用方式可分为2种：
		- 主动使用
		- 被动使用

 - 所有的Java虚拟机实现必须在每个类或者接口被Java程序“<font color=#ff0000 size=2 face="黑体">首次主动使用</font>”时才初始化他们。

 - 主动使用（七种）
     - 创建类的实例。
     - 访问某个类或者接口的静态变量，或者对该静态变量赋值。
     - 调用类的静态方法。
     - 反射 （如Class.forName("com.test.Test")）
     -  初始化一个类的子类
     - Jav啊虚拟机启动时被标明为启动类的类(Java Test)
     - JDK1.7开始提供的动态 语言支持：
	     Java.lang.invoke.MethodHandle实例的解析结果REF_getStattic REF_putStatic REF_invokeStatic句柄对应的类如果没有初始化，则初始化(了解)
  除了以上七中情况，其他使用Java类的方式都被看做是对类的被动使用，都不会导致类的<font color=#ff0000 size=2 face="黑体">初始化</font>(指的是加载，连接，初始化这个步骤的初始化)

实例介绍：

```

public class MyTest {
/*
对于静态字段来说，只有直接定义该字段的类才会被初始化
当一个类初始化时，要求其父类全部都已经初始化完毕了
-XX:+TraceClassLoading 用于追踪类的加载信息并打印出来
-XX:+<option> 表示开启option选项
-XX:-<option> 表示关闭option选项
-XX:<option>=<value>,表示将option的选项的值设置为value
 */
    public static void main(String[] args) {
        //直接使用父类的变量 ，子类不会初始化，虽有用了子类的标识符
        System.out.println(MyChild.str);
        /*
        MyParent1 static block
        hello world
         */

        //直接调用子类的变量 会首先初始化父类，然后再初始化子类
       // System.out.println(MyChild.str2);
        /*
        MyParent1 static block
        MyChild static bloack
        welcome
         */
    }

}

class MyParent1{
    public static String str  = "hello world";
    static{
        System.out.println("MyParent1 static block");
    }
}

class MyChild extends  MyParent1{
    public static String str2 = "welcome";
    static{
        System.out.println("MyChild static bloack");
    }
}

```


类的加载：

 - 类的加载指的是将类的.class文件中的二进制数据读入到内存中，将其放在运行时数据区的方法区，然后在内存中创建一个Java.lang.Class对象(规范并未说明Class对象位于哪里，HotPot虚拟机将其放在了方法区中)用来封装类在方法区内的数据结构。
 - 加载.class文件的方式
	 - 从本地系统中直接加载
	 - 通过网络下载.class文件
	 - 从zip，jar等归档文件中加载.class文件
	 - 从专有数据库中提取 .class文件
	 - 将Java源文件动态编译为.class文件


类的使用与卸载
--
 - 使用 ：正常的使用，调用类的方法等
 - 卸载 ：从内存中卸载。
