---
title: 设计模式(1)-单例模式Singleton
date: 2018-09-28 20:08:54
tags: DesignPatterns
categories: DesignPatterns
---
![这里写图片描述](20151010111725317.png)
单例模式的四种实现方式：
**1、饿汉模式**
<!-- more -->
```
public class Singleton2{
        //饿汉模式，声明时不创建实例对象
	public static Singleton2 instance;
	//单类模式的构造方法必须为private，以避免通过构造方法创建对象实例，
        //并且必须显示声明构造方法，以防止使用默认构造方法
	private Singleton2(){}
        //单类模式必须对外提供获取实例对象的方法，延迟初始化的单类模式必须使用synchronized同步关键字，否则多线程情况下很容易产生多个实例对象
        public static synchronized Singleton2 geInstance(){
	       //延迟初始化，只有当第一次使用时才创建对象实例
	       if(instance == null){
	           return new Singleton2();
                }
               return instance;
        }
}

```
**2、饱汉模式**

```
public class Singleton1{
        //饱汉模式，声明时就创建实例对象
	public static final Singleton1 instance = new Singleton1();
	//单类模式的构造方法必须为private，以避免通过构造方法创建对象实例，
        //并且必须显示声明构造方法，以防止使用默认构造方法
	private Singleton1(){}
        //单类模式必须对外提供获取实例对象的方法
        public static Singleton1 geInstance(){
	       return instance;
        }
}

```
**3、使用枚举**
枚举可以保证真个程序生命周期中只有一个实例对象存在，同时还避免了常规Singleton单类模式private构造方法被反射调用和序列化问题(枚举提供了序列化保证机制，确保多次序列化和反序列化不会创建多个实例对象)。
```
public enum Singleton4{
	INSTANCE{
		public void doSomething(){
			……
		}
	};
	public abstract void doSomething();  
}
```
**4】静态内部类的实现方式：**

```
 public class Singleton3 {  
    /**
     * 类级的内部类，也就是静态的成员式内部类，该内部类的实例与外部类的实例
     * 没有绑定关系，而且只有被调用到才会装载，从而实现了延迟加载
     */  
    private static class SingletonHolder{  
        /**
         * 静态初始化器，由JVM来保证线程安全
         */  
        private static Singleton3 instance = new Singleton3();  
    }  
    /**
     * 私有化构造方法
     */  
    private Singleton3(){  
    }  
    public static  Singleton3 getInstance(){  
        return SingletonHolder.instance;  
    }  
}
```
