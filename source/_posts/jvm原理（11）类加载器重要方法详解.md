---
title: jvm原理（11）类加载器重要方法详解
date: 2018-10-04 16:00:26
tags: 类加载器解析
categories: jvm
---

[上一节](http://blog.csdn.net/wzq6578702/article/details/79548157) 我们写了一个类加载器的实现，其中一个重要的方法是findClass，看一下它的介绍：
https://docs.oracle.com/javase/7/docs/api/java/lang/ClassLoader.html#loadClass(java.lang.String,%20boolean)
<!-- more -->
**findClass：**
```
/**
     * Finds the class with the specified <a href="#name">binary name</a>.
     * This method should be overridden by class loader implementations that
     * follow the delegation model for loading classes, and will be invoked by
     * the {@link #loadClass <tt>loadClass</tt>} method after checking the
     * parent class loader for the requested class.  The default implementation
     * throws a <tt>ClassNotFoundException</tt>.
     *返回了指定二进制名字的class，这个方法应该被遵循父类委托机制的子类去重写，当检查完当前类的父类加载器之后，
     * 然后会被loadClass 调动，这个方法默认抛出ClassNotFoundException异常
     * @param  name The <a href="#name">binary name</a> of the class
     * @return  The resulting <tt>Class</tt> object
     * @throws  ClassNotFoundExceptionIf the class could not be found
     * @since  1.2
     */
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        throw new ClassNotFoundException(name);
    }
```

在findClass方法里边，先去加载类的字节码，然后给ClassLoader类的defineClass方法，将字节码转换为一个Class类型（为了调用newInstance()实例化），
看一下defineClass的介绍：

**defineClass**

Converts an array of bytes into an instance of class Class. Before the Class can be used it must be resolved.
This method assigns a default ProtectionDomain to the newly defined class. The ProtectionDomain is effectively granted the same set of permissions returned when Policy.getPolicy().getPermissions(new CodeSource(null, null)) is invoked. The default domain is created on the first invocation of defineClass, and re-used on subsequent invocations.
**将一个字节数组转换为一个Class类的实例，在这之前需要对Class进行过解析(类的加载过程[加载：连接[验证，准备，解析]]，初始化).**
**这个方法会给新建立的Class分配一个保护域，保护域是用来保证返回的新的Class的访问信息是正确的（比如相同包下边的包的包名是一样的），默认的域在第一创建的时候会被创建，之后再去调用会被复用。**
To assign a specific ProtectionDomain to the class, use the defineClass method that takes a ProtectionDomain as one of its arguments.
**如果想要手动指定保护域，需要调用另外一个重载的方法，有5个参数，最后一个参数指定要传入的保护域。**


```
protected final Class<?> defineClass(String name,byte[] b,int off,int len) throws ClassFormatError;
```

Parameters:
name - The expected binary name of the class, or null if not known
**指定了二进制名字的类，如果不确定就填入null**
b - The bytes that make up the class data. The bytes in positions off through off+len-1 should have the format of a valid class file as defined by The Java™ Virtual Machine Specification.
**字节数组存储的是符合Java虚拟机对class文件规范的class文件字节码，否则是解析不出来的。**
off - The start offset in b of the class data
**类数据的起始偏移量**
len - The length of the class data
**class字节码与类数据相关的长度**

Returns:
The Class object that was created from the specified class data.
**返回指定了class字节数组的Class的对象。**

Throws:
ClassFormatError - If the data did not contain a valid class
**如果字节码数据不是合法的符合虚拟机规范的直接抛出错误**
IndexOutOfBoundsException - If either off or len is negative, or if off+len is greater than b.length.
**偏移量不合法或者计算后不合法抛出IndexOutOfBoundsException**
SecurityException - If an attempt is made to add this class to a package that contains classes that were signed by a different set of
certificates than this class (which is unsigned), or if name begins with "java.".
**jdk不允许我们定义以"java."开头的包名的类，这样会抛出安全异常**


defineClass方法一直往下跟，会跟到如下的真正实现的方法，是一个native方法：
private native Class<?> defineClass1(String name, byte[] b, int off, int len, ProtectionDomain pd, String source);


```
protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException
```
**loadClass方法**
Loads the class with the specified binary name. The default implementation of this method searches for classes in the following order:
**加载指定二进制名字的类，这个方法的默认实现是按照如下的规则查找**
Invoke findLoadedClass(String) to check if the class has already been loaded.
**调用findLoadedClass确定这个类是否已经被加载**
Invoke the loadClass method on the parent class loader. If the parent is null the class loader built-in to the virtual machine is used, instead.
**调用委托父类的loadClass，如果委托父类是是空的，那么会使用jvm内建的启动类加载器代替**
Invoke the findClass(String) method to find the class.
**调用findClass查找这个类。**
If the class was found using the above steps, and the resolve flag is true, this method will then invoke the resolveClass(Class) method on the resulting Class object.
**如果使用上述步骤找到了这个类，并且resolve 是true，那么就会将解析结果作为resolveClass的参数调用resolveClass方法。**
Subclasses of ClassLoader are encouraged to override findClass(String), rather than this method.
**子类被鼓励重写findClass方法，不推荐重写当前方法**
Unless overridden, this method synchronizes on the result of getClassLoadingLock method during the entire class loading process.
**除非被重写，否则这个方法会被同步，保证类只能被加载一次。**
Parameters:
name - The binary name of the class
resolve - If true then resolve the class
Returns:
The resulting Class object
Throws:
ClassNotFoundException - If the class could not be found
```
