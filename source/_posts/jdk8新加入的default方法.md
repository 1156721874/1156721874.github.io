---
title: jdk8新加入的default方法
date: 2018-10-04 10:32:39
tags: jdk8 default method
categories: javaBase
---

default方法的加入是为了兼容jdk8以前的版本的需要。
（1）当前有两个接口MyInterface和MyInterface1，它们都有相同名字的default方法，之后实现类Myclass同时implements了MyInterface和MyInterface1，同时Myclass实现了default方法，此时Myclass调用default调的是谁的？
（2）一个接口I有一个default方法，另一个实现类A实现了了此接口，并且重写了default方法，之后另一个类B继承了实现类A并且实现了接口I，那么在这种情况下，实现类B调用的default方法又是谁的呢？针对这两种情况编写测试代码：

接口MyInterface
```
/**
 * Created by CeaserWang on 2017/1/16.
 */
public interface MyInterface {
default void  meyhod(){
    System.out.println("MyInterface");
}
}
```
接口MyInterface1
```
public interface MyInterface1 {
    default void  meyhod(){
        System.out.println("MyInterface1");
    }
}
```
实现类ExtendsClass
```
public class ExtendsClass implements  MyInterface {

    public void  meyhod(){
        System.out.println("ExtendsClass");
    }
}
```

实现类FixClass
```
public class FixClass extends  ExtendsClass implements  MyInterface1 {

}
```
测试类Myclass
```
public class Myclass implements  MyInterface,MyInterface1 {

  public  void  meyhod(){
       System.out.println("Myclass");
      //MyInterface1.super.meyhod();
    }

    public static void main(String[] args) {
        Myclass myclass = new Myclass();
        myclass.meyhod();

        FixClass fixClass = new FixClass();
        fixClass.meyhod();
    }

}
```

运行Myclass 结果：

```
Myclass
ExtendsClass
```

结论:
针对于第一种情况，default方法调用的是自身的实现的default方法。
针对于第二种情况，default方法调用的是“就近原则”，ExtendsClass 首先被实现，那么首选是ExtendsClass 的default方法，因此输出“ExtendsClass”。
