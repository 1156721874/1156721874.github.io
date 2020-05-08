---
title: jvm原理（29）构造方法与静态代码块字节码指令详解
date: 2018-10-04 17:08:33
tags: [静态方法,构造方法,字节码指令]
categories: jvm
---

上一节解析完了常量池，接下来是**访问标记**，
![这里写图片描述](20180804134250848.png)
<!-- more -->
00 21 ： ACC_SUPPER + ACC_PUBLIC
紧接着是**类的名字**，2个字节：00 05 是5号常量 【#5 = Class              #49            // com/twodragonlake/jvm/bytecode/MyTest2】
**父类的名字**，占2个字节：00 0D 是13号常量：【#13 = Class              #59            // java/lang/Object】
**接口的信息**：00 00 没有接口。
**成员变量信息**：00 03 有三个成员变量。
第一个字段：
访问标记：00 00 为默认访问标记。
名字索引：00 0E 是14号常量：【#14 = Utf8               str】
 描述符索引：00 0F 是15号常量：【#15 = Utf8               Ljava/lang/String;】
 字段属性数量：00 00 没有属性
 第二个字段：
 访问标记：00 02 私有的，private
 名字索引：00 10 是16号常量：【#16 = Utf8               x】
 描述符索引：00 11 是17号常量：【 #17 = Utf8               I】
 字段属性数量：00 00 没有字段属性
 第三个字段：
  访问标记：00 09 是public + static
  名字索引：00 12是18号常量：【#18 = Utf8               in】
  描述符索引：00 13 是19号常量：【#19 = Utf8               Ljava/lang/Integer;】
  字段属性数量：00 00 没有
然后是方法：
方法的数量：00 06 是6个方法：
init 、 main、setX、test、test2、clinit（静态代码块）
第一方法：
访问标记：00 01 是public
名字索引：00 14 是20号常量：【#20 = Utf8               `<init>`】
描述符索引：00 15 是21号常量：【#21 = Utf8               ()V】
方法属性数量：00 01 包含一个属性
第一个属性：
属性名字索引：00 16是22号索引：【#22 = Utf8               Code】
属性长度：00 00  0 42 为66个长度，默认构造方法完成了成员变量的赋值，注意只是对非静态的赋值：

PS：对于字节码文件来说，在方法区的字节码这里可以不包含任何含有初始化构造方法的字节码，很多人认为java代码如果没有默认的构造器，那么java编译器
会生成一个没有参数的构造方法，但是这是错误的，字节码规范里边没有要求，方法区必须要有默认的构造方法，java语言规范和jvm规范是不一样的。

```
 0 aload_0
 1 invokespecial #1 <java/lang/Object.<init>> 调用父类构造器
 4 aload_0
 5 ldc #2 <Welcome>  加载字符串Welcome
 7 putfield #3 <com/twodragonlake/jvm/bytecode/MyTest2.str>  把字符窜Welcome赋值给str变量
10 aload_0
11 iconst_5  加载整数5
12 putfield #4 <com/twodragonlake/jvm/bytecode/MyTest2.x> 把整数5赋值给x变量
15 return  方法返回
```
如果我们自己声明一个构造方法，是不是也会存在对成员变量的赋值？我们加入一个有参数的构造方法：

```
    public MyTest2(){

    }

    public MyTest2(int i){

    }
```
![这里写图片描述](2018082613275196.png)
![这里写图片描述](20180826132829940.png)

可以看到默认的无参构造器和有参数的构造器字节码是一样的，都会对成员变量进行赋值。
其他的方法的字节码解析和之前的程序大致相同，不再熬述。
着重说一下test方法：

```
 0 aload_1
 1 dup
 2 astore_2
 3 monitorenter  
 4 getstatic #10 <java/lang/System.out>
 7 ldc #11 <hello world>
 9 invokevirtual #12 <java/io/PrintStream.println>
12 aload_2
13 monitorexit
14 goto 22 (+8)
17 astore_3
18 aload_2
19 monitorexit
20 aload_3
21 athrow
22 return
```
[monitorenter](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.monitorenter)  是synchronized的监视器加锁的地方，oracle的官方doc：
**monitorenter**
```
Operation
Enter monitor for object
进入对象的监视器
Format

monitorenter
Forms
monitorenter = 194 (0xc2)

Operand Stack
..., objectref →

...

Description
The objectref must be of type reference.
监视的对象必须是引用类型
Each object is associated with a monitor. A monitor is locked if and only if it has an owner.
The thread that executes monitorenter attempts to gain ownership of the monitor associated with objectref,
 as follows:
每一个对象都有一个监视器，如果一个monitor 是拥有者那么它就获得了锁，线程获得monitorenter 的使用权遵循下边的过程：
If the entry count of the monitor associated with objectref is zero,
the thread enters the monitor and sets its entry count to one. The thread is then the owner of the monitor.
如果monitor关联对象的进入次数是0，当前线程进入monitor并且设置进入次数是1，那么接下来这个线程就是这个monitor的拥有者。
If the thread already owns the monitor associated with objectref,
 it reenters the monitor, incrementing its entry count.
如果一个线程已经是关联对象的monitor的拥有者，那么线程再次进入monitor，会使得进入次数加1
If another thread already owns the monitor associated with objectref,
 the thread blocks until the monitor's entry count is zero, then tries again to gain ownership.
如果另外一个线程已经是关联对象的monitor 的拥有者，那么当前线程会一直阻塞到进入次数为0，才能再次尝试获取monitor 的使用权。
```

**monitorexit**
```
monitorexit
Operation
Exit monitor for object
为了退出对象的monitor
Format

monitorexit
Forms
monitorexit = 195 (0xc3)

Operand Stack
..., objectref →

...

Description
The objectref must be of type reference.
关联的对象必须是引用类型的。
The thread that executes monitorexit must be the owner of the monitor associated with
the instance referenced by objectref.
当前执行monitorexit 的线程必须是关联对象实例对象的引用上的monitor 的拥有者。
The thread decrements the entry count of the monitor associated with objectref.
If as a result the value of the entry count is zero, the thread exits the monitor and is no longer its owner.
Other threads that are blocking to enter the monitor are allowed to attempt to do so.
当前线程减1个进入次数，正对与关联对象上的monitor 的进入此时，如果减一之后变成0，那么当前线程退出monitor ，
不再是拥有者，其他阻塞的线程此时可以被允许尝试获取拥有权。
```

回到我们的字节码，看一下clinit 对静态代码块的操作：

```
0 bipush 10
2 invokestatic #8 <java/lang/Integer.valueOf>
5 putstatic #9 <com/twodragonlake/jvm/bytecode/MyTest2.in> 对静态变量in进行赋值
8 return
```

如果我们加入一个static代码块，那么clinit 会有什么变化？

```
    static {
        System.out.println("test");
    }
```
clinit代码块：

```
 0 bipush 10
 2 invokestatic #8 <java/lang/Integer.valueOf>
 5 putstatic #9 <com/twodragonlake/jvm/bytecode/MyTest2.in>
 8 getstatic #10 <java/lang/System.out>
11 ldc #13 <test>
13 invokevirtual #12 <java/io/PrintStream.println>
16 return
```
可以看到静态的代码块的内容被加到了 clinit里边去了，不管有多少个静态代码块 都会合并到clinit里边去。
