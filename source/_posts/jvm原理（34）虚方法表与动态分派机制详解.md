---
title: jvm原理（34）虚方法表与动态分派机制详解
date: 2018-10-04 17:23:45
tags: [虚方法,动态分配机制]
categories: jvm
---

编写代码：

<!-- more -->
```
public class MyTest7 {
    public static void main(String[] args) {
        Animal animal = new Animal();
        Animal dog = new Dog();

        animal.test("hello");
        dog.test(new Date());
    }

}

class Animal{
    public void test(String str){
        System.out.println("animal str");
    }

    public void test(Date date){
        System.out.println("animal date");
    }
}

class Dog extends Animal{
    @Override
    public void test(Date date) {
        System.out.println("dog date");
    }

    @Override
    public void test(String str) {
        System.out.println("dog str");
    }
}
```
运行结果：

```
animal str
dog date
```
**方法表：**
  针对方法调用动态分派的过程，虚拟机会在类的方法区建立一个虚拟方法表的数据结构(virtual method table,vtable),
 针对于invokeinterface指令来说，虚拟机会建立一个叫做接口方法表的数据结构(interface method table,itable)

方法表会在类的连接阶段初始化，方法表存储的是该类方法入口的一个映射，比如父类的方法A的索引号是1，方法B的索引号是2。。。
如果子类继承了父类，但是某个父类的方法没有被子类重写，那么在子类的方法表里边该方法指向的是父类的方法的入口，子类并不会重新生成一个方法，然后让方法表去指向这个生成的，这样做是没有意义的。还有一点，如果子类重写了父类的方法，那么子类这个被重写的方法的索引和父类的该方法的索引是一致。比如父类
A的test方法被子类C重写了，那么子类C的test方法的索引和父类A的test方法的索引都是1（打个比方），这样做的目的是为了快速查找，比如说在子类里边找不到一个方法索引为1的方法，那么jvm会直接去父类查找方法索引为1的方法，不需要重新在父类里边遍历。
