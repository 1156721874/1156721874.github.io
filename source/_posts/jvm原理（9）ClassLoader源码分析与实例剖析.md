---
title: jvm原理（9）ClassLoader源码分析与实例剖析
date: 2018-10-04 15:57:23
tags: ClassLoader 解析
categories: jvm
---

https://docs.oracle.com/javase/8/docs/api/java/lang/ClassLoader.html

**public abstract class ClassLoader extends Object**

A class loader is an object that is responsible for loading classes. The class ClassLoader is an abstract class. Given the binary name of a class, a class loader should attempt to locate or generate data that constitutes a definition for the class. A typical strategy is to transform the name into a file name and then read a "class file" of that name from a file system.

**一个类加载器是用于加载类的这么一个对象，ClassLoader是一个抽象类，给定一个二进制的名字，类加载器应该尝试定位（找到类定义数据的位置）和生成(动态代理就是动态生成的)构成了这个类定义的数据，一个典型的策略就是将一个名字装换为一个文件名字，之后从文件系统读取这个文件包含的字节码。**
Every Class object contains a reference to the ClassLoader that defined it.
**任何一个类都有一个定义这个类的ClassLoader的引用**

Class objects for array classes are not created by class loaders, but are created automatically as required by the Java runtime. The class loader for an array class, as returned by Class.getClassLoader() is the same as the class loader for its element type; if the element type is a primitive type, then the array class has no class loader.
**对于数组类的class对象并不是由类加载器创建的，而是由java运行时在需要的时候自动创建**【回顾：http://blog.csdn.net/wzq6578702/article/details/79370662】
**对于数组的类加载器来说，通过Class.getClassLoader() 返回的和数组元素的类型类加载器是一样的，如果数组的元素是原生类型的，**
**那么这个数组是没有类加载器的。**
**举例：**

```
public class MyTest15 {
    public static void main(String[] args) {
        String[] strings = new String[2];
        System.out.println(strings.getClass().getClassLoader());

        MyTest15[] myTest15s = new MyTest15[2];
        System.out.println(myTest15s.getClass().getClassLoader());

        int [] ints = new int[2];
        System.out.println(ints.getClass().getClassLoader());

        HashMap[] maps = new HashMap[2];
        System.out.println(maps.getClass().getClassLoader());
    }
}
```
输出：

```
null 【这个null指的是根类加载器】
sun.misc.Launcher$AppClassLoader@18b4aac2  【数组的加载器和数组元素扥加载器一样】
null 【指的是没有类加载器】
null  【这个null指的是根类加载器】
```


Applications implement subclasses of ClassLoader in order to extend the manner in which the Java virtual machine dynamically loads classes.
**应用实现了ClassLoader 的子类是为了扩展Java虚拟机动态加载类的这种方式**
Class loaders may typically be used by security managers to indicate security domains.
**类加载器一般使用安全管理器确保在安全区域**
The ClassLoader class uses a delegation model to search for classes and resources. Each instance of ClassLoader has an associated parent class loader. When requested to find a class or resource, a ClassLoader instance will delegate the search for the class or resource to its parent class loader before attempting to find the class or resource itself. The virtual machine's built-in class loader, called the "bootstrap class loader", does not itself have a parent but may serve as the parent of a ClassLoader instance.
**ClassLoader 使用了一种委托模型用来寻找类和资源，每个ClassLoader 的实例都有一个与之相关的父级的类加载器，当一个请求要去寻找一个类或者资源的时候，ClassLoader 实例在它自己发现类或者资源本身之前会委托他的父级类加载器去加载类或者发现资源。虚拟机内建的类加载器成为“启动类加载器”，它本身是没有双亲的，但是他本身可以作为一个类加载器的双亲。**
Class loaders that support concurrent loading of classes are known as parallel capable class loaders and are required to register themselves at their class initialization time by invoking the ClassLoader.registerAsParallelCapable method. Note that the ClassLoader class is registered as parallel capable by default. However, its subclasses still need to register themselves if they are parallel capable.
**如果类加载器支持并发，就是并发类加载器，并发类加载器要求在类的初始期间通过ClassLoader.registerAsParallelCapable方法注册上，当前的ClassLoader默认就是被注册为并行的，然而他的子类如果是可以并行加载的也需要进行注册上。**
In environments in which the delegation model is not strictly hierarchical, class loaders need to be parallel capable, otherwise class loading can lead to deadlocks because the loader lock is held for the duration of the class loading process (see loadClass methods).
**在委托模型并不是严格的层次化的环境下，类加载器是需要并行的，否则类加载过程中是会死锁的，因为类加载的过程中是持有锁的（查看getClass方法）**
Normally, the Java virtual machine loads classes from the local file system in a platform-dependent manner. For example, on UNIX systems, the virtual machine loads classes from the directory defined by the CLASSPATH environment variable.
**通常来说Java虚拟机以平台相关的形式从本地的文件系统加载类，举例，在UNIX系统，虚拟机通过CLASSPATH 环境变量的路径来加载类。**
However, some classes may not originate from a file; they may originate from other sources, such as the network, or they could be constructed by an application. The method defineClass converts an array of bytes into an instance of class Class. Instances of this newly defined class can be created using Class.newInstance.
**然后，一些类并不是来自于一个文件，他们可能来自于网络或者他们是应用本身构建出来的（动态代理），defineClass 方法会将一个字节数组转换为Class类的实例，这个新定义的类可以通过Class.newInstance去创建类的对象。**
The methods and constructors of objects created by a class loader may reference other classes. To determine the class(es) referred to, the Java virtual machine invokes the loadClass method of the class loader that originally created the class.
**由类加载器创建的对象的构造方法或者方法可能引用其他的类，	为了确定被它所引用的其他的类，Java虚拟机通过调用loadClass 去解决。**
For example, an application could create a network class loader to download class files from a server. Sample code might look like:
**举例，一个应用通过网络类加载器从网络上的一个服务来下载class文件，实例代码就像这样：**
   ClassLoader loader = new NetworkClassLoader(host, port);
   Object main = loader.loadClass("Main", true).newInstance();
        . . .

The network class loader subclass must define the methods findClass and loadClassData to load a class from the network. Once it has downloaded the bytes that make up the class, it should use the method defineClass to create a class instance. A sample implementation is:
**网络加载器的子类必须定义loadClassData 和findClass方法来从网络加载class，一旦下载完毕类的字节码就会构建这个class，他需要使用defineClass 方法来创建一个类的实例，一个实现的实例：**
     class NetworkClassLoader extends ClassLoader {
         String host;
         int port;

         public Class findClass(String name) {
             byte[] b = loadClassData(name);
             return defineClass(name, b, 0, b.length);
         }

         private byte[] loadClassData(String name) {
             // load the class data from the connection
              . . .
         }
     }

Binary names
Any class name provided as a String parameter to methods in ClassLoader must be a binary name as defined by The Java™ Language Specification.
**二进制名字**
**任何类的名字都是通过字符串的形式，作为类加载器的方法的参数，称之为二进制的名字，这是Java虚拟机规范制定的。**
Examples of valid class names include:
**二进制名字举例**

```
   "java.lang.String" （String类）
   "javax.swing.JSpinner$DefaultEditor"（DefaultEditor是在JSpinner的内部类）
   "java.security.KeyStore$Builder$FileBuilder$1"（KeyStore里边的内部类Builder的内部类FileBuilder里边的第一个匿名内部类）
   "java.net.URLClassLoader$3$1"（URLClassLoader里边的第三个匿名内部类里边的第一个匿名内部类）
```
