---
title: jvm原理（3）编译期常量与运行期常量的区别及数组创建本质分析
date: 2018-10-04 15:40:50
tags: 编译期常量 运行期常量
categories: jvm
---

上一个[例子](http://blog.csdn.net/wzq6578702/article/details/79370149)我们用的final是一个字面量“hello world”，这次我们改一下使用UUID为常量赋值，注意：UUID是多少只有在运行期间才会被确定。

<!-- more -->
```
public class MyTest3 {
    public static void main(String[] args) {
        System.out.println(MyParent3.str);
    }
}

class MyParent3{
    public static final String str =UUID.randomUUID().toString();
    static{
        System.out.println("Myparnet3 static bloack");
    }
}
```

运行结果：

```
        Myparnet3 static bloack
        04d27b8c-5480-497d-83cc-8b924e5889a5
```

当一个常量的值并非编译期可以确定的，那么其值就不会被放到调用类的常量池中，
这时的程序运行时，会导致主动使用这个常量所在的类，显然会导致这个类被初始化。

接下来看一下数组的形式

```
public class MyTest4 {
    public static void main(String[] args) {
       // MyParent4 myParent4 = new MyParent4(); 毫无疑问这个会触发初始化，属于主动调用
        MyParent4 [] myParent4s =  new MyParent4[1];
        System.out.println(myParent4s.getClass());
        System.out.println(myParent4s.getClass().getSuperclass());
        MyParent4 [][] myParent4s1 =  new MyParent4[1][1];
        System.out.println(myParent4s1.getClass());
        System.out.println(myParent4s1.getClass().getSuperclass());

        System.out.println("==============");
        int [] ints = new int[1];
        System.out.println(ints.getClass());
        System.out.println(ints.getClass().getSuperclass());

        byte [] bytes = new byte[1];
        System.out.println(bytes.getClass());
        System.out.println(bytes.getClass().getSuperclass());

        short [] shorts = new short[1];
        System.out.println(shorts.getClass());
        System.out.println(shorts.getClass().getSuperclass());

        boolean [] booleans =new boolean[1];
        System.out.println(booleans.getClass());
        System.out.println(booleans.getClass().getSuperclass());


    }
}

class MyParent4{
    static {
        System.out.println("MyParent4 static bloack");
    }
}

```

运行结果：

```
class [Lcom.twodragonlake.jvm.classloader.MyParent4;
class java.lang.Object
class [[Lcom.twodragonlake.jvm.classloader.MyParent4;
class java.lang.Object
==============
class [I
class java.lang.Object
class [B
class java.lang.Object
class [S
class java.lang.Object
class [Z
class java.lang.Object
```

对于数组实例来说，其类型是由JVM在运行期间动态生成的，
表示为[Lcom.twodragonlake.jvm.classloader.MyParent4这种形式。
动态生成的类型（类似于动态代理），其父类型就是Object

对于数组来说，JavaDoc经常讲构成数组的元素称为Component，实际上就是将数组降低一个维度后的类型。
    助记词：
    anewarray : 表示创建一个引用类型的(如类、接口、数组)数组，并将其引用值压入栈顶
    newarray : 表示创建一个指定的原始类型（如int、float、char等）的数组，并将其压入栈顶
