---
title: jvm原理（18）类加载器命名空间总结与扩展类加载器要点分析
date: 2018-10-04 16:13:07
tags: classLoader namespace summary
categories: jvm
---

**类加载双亲委托模型的好处：**
1、可以确保Java核心库的类型安全：所有的Java应用都至少会引用Java.lang.Object类，也就是说在运行期，java.lang.Object这个类会被加载到Java虚拟机中，如果这个加载过程是由Java应用自己的类加载器所完成的，
那么很有可能就会在JVM中存在多个版本的java.lang.Object类，而且这些类库中的类的加载工作都是由启动类加载器来统一完成，从而确保了Java应用所使用的都是同一个版本的Java核心类库，他们之间是相互兼容的。
2、可以确保Java核心类库所提供的类不会被自定义的类所替代。
3、不同的类加载器可以为相同名称(binary name)的类创建额外的命名空间，相同名称的类可以并存在Java虚拟机中，只需要用不同的类加载器来加载他们即可。不同类加载器所加载的类之间是不兼容的，这就相当于在Java
虚拟机内部创建了一个又一个相互隔离的Java类空间，这类技术在很多框架中得到了实际应用。

**扩展类加载器：**
看一段程序：

```
public class MyTest22 {
    static{
        System.out.println("MyTest22 initializer=");
    }
    public static void main(String[] args) {
        System.out.println(MyTest22.class.getClassLoader());
        System.out.println(MyTest.class.getClassLoader());
    }
}

```
运行结果：

```
MyTest22 initializer=
sun.misc.Launcher$AppClassLoader@18b4aac2
sun.misc.Launcher$AppClassLoader@18b4aac2
```
很明显他们都是由应用类加载器加载，我们能不能想办法让扩展类加载器加载他们呢，试想我们修改变量【Java.ext.dirs】指向当前程序所在的路径是不是就可以了呢?
为此我们定位到【jvm_lecture\out\production\classes】下边，执行命令：
java -Djava.ext.dirs=./ com.twodragonlake.jvm.classloader.MyTest22
![这里写图片描述](20180406163908960.png)
奇怪的是按照双亲委托模型，在去加载MyTest22的时候先是应用类加载器委托扩展类加载器，扩展类加载器的加载路径是当前路径，MyTest22也在当前路径下边，但是为什么还是应用类加载器加载的呢？
这是因为扩展类加载器只能通过jar的形式来加载，不能加载class文件的形式，因此我们把MyTest文件放到jar里边：

```
E:\Study\intelIde\jvm_lecture\out\production\classes>jar cvf test.jar com/twodragonlake/jvm/classloader/MyTest.class
已添加清单
正在添加: com/twodragonlake/jvm/classloader/MyTest.class(输入 = 657) (输出 = 373)(压缩了 43%)
```
然后我们运行MyTest22程序：
```
E:\Study\intelIde\jvm_lecture\out\production\classes>java -Djava.ext.dirs=./ com.twodragonlake.jvm.classloader.MyTest22
MyTest22 initializer=
sun.misc.Launcher$AppClassLoader@2a139a55
sun.misc.Launcher$ExtClassLoader@75b84c92
```
结果发生了变化，MyTest22是由应用类加载器加载器没啥问题，MyTest由于放到jar包里边，应用类加载器在委托给扩展类加载器的时候，扩展类加载器在当前目录里边的test.jar里边找到了MyTest的class文件，为此扩展类加载器加载了MyTest。
如果我们运行【java -Djava.ext.dirs=/ com.twodragonlake.jvm.classloader.MyTest22】即将根目录作为扩展类加载的加载路径，运行结果肯定都是由应用类加载器加载，因为扩展类加载器在根目录下找不到MyTest。

```
E:\Study\intelIde\jvm_lecture\out\production\classes>java -Djava.ext.dirs=/ com.twodragonlake.jvm.classloader.MyTest22
MyTest22 initializer=
sun.misc.Launcher$AppClassLoader@73d16e93
sun.misc.Launcher$AppClassLoader@73d16e93
```
