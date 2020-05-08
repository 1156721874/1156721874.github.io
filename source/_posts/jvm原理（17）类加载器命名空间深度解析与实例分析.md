---
title: jvm原理（17）类加载器命名空间深度解析与实例分析
date: 2018-10-04 16:11:20
tags: classLoader namespace
categories: jvm
---

我们在 [上一节](https://blog.csdn.net/wzq6578702/article/details/79829341)讲到实例基础上做一下改动：

<!-- more -->
```
public class MyTest21 {
    public static void main(String[] args)  throws Exception{
        MyTest16 loader1 = new MyTest16("loader1") ;
        MyTest16 loader2 = new MyTest16("loader2") ;
        loader1.setPath("E:\\data\\classes\\");
        loader2.setPath("E:\\data\\classes\\");
        Class<?> clazz1 = loader1.loadClass("com.twodragonlake.jvm.classloader.MyPerson");
        Class<?> clazz2 = loader2.loadClass("com.twodragonlake.jvm.classloader.MyPerson");
        System.out.println(clazz1 ==  clazz2);
        Object object1 = clazz1.newInstance();
        Object object2 = clazz2.newInstance();

        Method method   = clazz1.getMethod("setMyPerson",Object.class);
        method.invoke(object1,object2);
    }
}
```
即指定了loader1和loader2的path路径，然后我们重新编译当前工程，将com.twodragonlake.jvm.classloader.MyPerson的class文件复制一份到【E:\\data\\classes\\】下边，然后删除当前工程的MyPerson的class文件，然后运行MyTest21 的main函数,打印 结果会是什么呢？

```
findClass invoked com.twodragonlake.jvm.classloader.MyPerson
 this.classLoaderName : loader1
findClass invoked com.twodragonlake.jvm.classloader.MyPerson
 this.classLoaderName : loader2
false
Exception in thread "main" java.lang.reflect.InvocationTargetException
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:498)
	at com.twodragonlake.jvm.classloader.MyTest21.main(MyTest21.java:18)
Caused by: java.lang.ClassCastException: com.twodragonlake.jvm.classloader.MyPerson cannot be cast to com.twodragonlake.jvm.classloader.MyPerson
	at com.twodragonlake.jvm.classloader.MyPerson.setMyPerson(MyPerson.java:6)
	... 5 more
```
分析：首先loader1和loader2虽然都是MyTest16的对象，但是他们之间在类加载的层次上没有任何的关系，loader1加载MyPerson的时候通过向上委托一直到启动类加载器然后又往下到应用类加载器都无法加载，只能通过loader1加载器来加载，loader1加载的MyPerson的class对象clazz1属于loader1的命名空间，同样的道理clazz2属于loader2的命名空间，clazz1和clazz2是不同的2个class对象，所以我们在通过反射调用clazz1的实体object1的setMyPerson方法的时候，传入的是clazz2的实体对象，clazz2和clazz1属于不同的命名空间，相互之间不可见，在强制向下转型的时候肯定是抛出转型失败的错误。
![这里写图片描述](20180406153748449.png)
![这里写图片描述](20180406153811702.png)
子加载器加载的类可以看到父加载器加载的类；
父加载器加载的类无法看到子加载器加载的类；
