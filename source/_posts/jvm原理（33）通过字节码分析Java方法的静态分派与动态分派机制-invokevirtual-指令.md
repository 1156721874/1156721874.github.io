---
title: jvm原理（33）通过字节码分析Java方法的静态分派与动态分派机制(invokevirtual 指令)
date: 2018-10-04 17:20:15
tags: [静态分派,动态分派]
categories: jvm
---

编写代码：

```
public class MyTest6 {
    public static void main(String[] args) {
        Fruit apple = new Apple();
        Fruit orange = new Orange();
        apple.test();
        orange.test();

        apple = new Orange();
        apple.test();
    }
}

class Fruit{
    public void test(){
        System.out.println("fruit");
    }
}

class Apple extends  Fruit{
    @Override
    public void test() {
        System.out.println("apple");
    }
}

class Orange extends Fruit{
    @Override
    public void test() {
        System.out.println("orange");
    }
}
```
运行结果：

```
apple
orange
orange
```
看一下main方法的字节码指令:

 0 new #2 <com/twodragonlake/jvm/bytecode/Apple>  //new指令在堆里边创建一个对象
 3 dup  //压入栈顶
 4 invokespecial #3 <com/twodragonlake/jvm/bytecode/Apple.`<init>`> //invokespecial 指令调用父类的构造器
 7 astore_1  //返回对象引用赋值给apple  
 8 new #4 <com/twodragonlake/jvm/bytecode/Orange>
11 dup
12 invokespecial #5 <com/twodragonlake/jvm/bytecode/Orange.`<init>>`
15 astore_2
16 [aload_1](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.aload_n)  
//从局部变量加载一个引用 aload1是加载索引为1的引用（apple），局部变量有三个（0：args; 1 :apple ; 2 :orange）
17 invokevirtual #6 <com/twodragonlake/jvm/bytecode/Fruit.test> //invokevirtual 指令，注意参数是Fruit.test，不是Apple.test
20 aload_2 //加载引用orange
21 invokevirtual #6 <com/twodragonlake/jvm/bytecode/Fruit.test> //调用invokevirtual 指令，注意参数是Fruit.test，不是orange.test
24 new #4 <com/twodragonlake/jvm/bytecode/Orange>  //堆里边创建一个对象
27 dup  //推到栈顶
28 invokespecial #5 <com/twodragonlake/jvm/bytecode/Orange.`<init>>`  //调用对象的构造器
31 astore_1  //将对应的引用赋值给apple
32 aload_1   //加载引用apple
33 invokevirtual #6 <com/twodragonlake/jvm/bytecode/Fruit.test> //invokevirtual 指令，调用引用apple的test，注意参数是Fruit.test，不是apple.test
36 return //返回

ok，ok~~到现在为止这个程序的在字节码层面我们已经知道是怎么走的了，，还有一个invokevirtual ，在字节码层面指向的是Fruit.test的但是运行的时候是具体事例的方法，这个问题需要解释一下。

 invokevirtual 运行期执行的时候首先：
 找到操作数栈顶的第一个元素它所指向对象的实际类型，在这个类型里边，然后查找和常量里边Fruit的方法描述符和方法名称都一致的
 方法，如果在这个类型下，常量池里边找到了就会返回实际对象方法的直接引用。

 如果找不到，就会按照继承体系由下往上(Apple-->Fruit-->Object)查找，查找匹配的方式就是
 上面描述的方式，一直找到位为止。如果一直找不到就会抛出异常。

 比较方法重载（overload）和方法重写（overwrite），我们可以得出这样的结论：
  方法重载是静态的，是编译器行为；方法重写是动态的，是运行期行为。
