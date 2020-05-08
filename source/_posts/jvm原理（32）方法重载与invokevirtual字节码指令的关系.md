---
title: jvm原理（32）方法重载与invokevirtual字节码指令的关系
date: 2018-10-04 17:18:36
tags: [方法重载,invokevirtual指令]
categories: jvm
---

* 1、invokeinterface:调用接口中的方法，实际上是在运行期决定的，决定到底调用实现该接口的那个对象的特定方法。4
* 2、invokestatic : 调用静态方法
<!-- more -->
* 3、invokespecial: 调用自己的私有方法，构造方法(<init>)以及父类的方法。
* 4、invokevirtual: 调用虚方法，运行期动态查找的过程。
* 5、invokedynamic: 动态调用方法。

**invokestatic**
写一段调用invokestatic 的代码：
```
public class MyTest4 {
    public static void test(){
        System.out.println("test invoked");
    }

   public static void main(String[] args) {
       test();
   }
}
```
打开jclasslib可以看到main方法会有invokestatic 的调用：
![这里写图片描述](20180915090702298.png)

**方法的静态分派（invokevirtual ）**

```
public class MyTest5 {
   //方法的重载是一种静态的行为，在编译期就可以完全确定。
   public void test(GrandPa grandPa){
       System.out.println("grandpa");
   }

   public void test(Father father){
       System.out.println("father");
   }

   public void test(Son son){
       System.out.println("son");
   }

   public static void main(String[] args) {
       GrandPa grandPa1 = new Father();
       GrandPa grandPa2 = new Son();
       MyTest5 myTest5 = new MyTest5();
       myTest5.test(grandPa1);
       myTest5.test(grandPa2);
   }

}


class GrandPa{

}

class Father extends GrandPa{

}

class Son extends Father{

}
```
运行结果：

```
grandpa
grandpa
```

*  GrandPa g1 = new Father();
*  以上代码，g1的静态类型是Gandpa，而g1的实际类型（真正指向的类型）是Father。调用test方法的时候会根据g1的静态类型（Gandpa）去寻找重载的具体的方法。
*  我们可以得出这样的结论：变量的静态类型是不会发生变化的，而变量的实际类型则是可以发生变化的（多态的一种体现），实际类型是在运行期方可确定。
看一下main方法的字节码：


```
0 new #7 <com/twodragonlake/jvm/bytecode/Father>
3 dup
4 invokespecial #8 <com/twodragonlake/jvm/bytecode/Father.<init>>
7 astore_1
8 new #9 <com/twodragonlake/jvm/bytecode/Son>
11 dup
12 invokespecial #10 <com/twodragonlake/jvm/bytecode/Son.<init>>
15 astore_2
16 new #11 <com/twodragonlake/jvm/bytecode/MyTest5>
19 dup
20 invokespecial #12 <com/twodragonlake/jvm/bytecode/MyTest5.<init>>
23 astore_3
24 aload_3
25 aload_1
26 invokevirtual #13 <com/twodragonlake/jvm/bytecode/MyTest5.test>
29 aload_3
30 aload_2
31 invokevirtual #13 <com/twodragonlake/jvm/bytecode/MyTest5.test>
34 return
```
可以看到2个 test方法的调用使用的是invokevirtual 指令。
