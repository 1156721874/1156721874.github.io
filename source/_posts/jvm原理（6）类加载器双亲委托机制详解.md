---
title: jvm原理（6）类加载器双亲委托机制详解
date: 2018-10-04 15:48:28
tags: 双亲委托机制
categories: jvm
---

类加载器层级：
![这里写图片描述](20180227223057487.png)

**类加载器的父类委托机制**
  在父类委托机制中，各个加载器按照按照父子关系形成**树形结构**（逻辑意义的树形结构），除了根类加载器之外，其余的类加载器都有且只有一个父加载器。

加载过程举例：
![这里写图片描述](20180303143640952.png)
![这里写图片描述](20180303143718490.png)
loader1拿到Sample的字节码的时候会把Sample交给loader1的父级加载器【系统类加载器】加载，【系统类加载器】还有一个父级加载器【扩展类加载器】然后将Sample交给了【扩展类加载器】，但是【扩展类加载器】还有一个父级加载器【根类加载器】，最终到了Sample到了【根类加载器】，由于【根类加载器】是顶层的加载器，所以【根类加载器】尝试加载Sample，但是【根类加载器】只加载规定目录下的类，显然Sample不在指定的目录下，【根类加载器】无法加载它，然后【根类加载器】把Sample交给了【扩展类加载器】，同样的道理【扩展类加载器】也是只能加载规定目录下的类，Sample不在【扩展类加载器】指定的目录下，从而无法加载，然后把Sample交给了【系统类加载器】，【系统类加载器】的加载目录包含Sample类的字节码，【系统类加载器】完成了Sample的加载，最后结果返回给了loader1
![这里写图片描述](20180303145132407.png)
![这里写图片描述](20180303145503257.png)
上例中【系统类加载器】就是定义类加载器，loader1是初始类加载器。

实例讲解：

```
public class MyTest7 {
    public static void main(String[] args) throws Exception{
        Class<?> str = Class.forName("java.lang.String");
        System.out.println(str.getClassLoader());//打印null 因为java.lang.String是有根类加载器加载，getClassLoader()方法看下边介绍。

        Class<?> c = Class.forName("com.twodragonlake.jvm.classloader.C");//返回系统类加载器
        System.out.println(c.getClassLoader());
    }
}

class C{

}
```
打印结果：
```
null
sun.misc.Launcher$AppClassLoader@18b4aac2
```

getClassLoader（）方法：
```
    /**
     * Returns the class loader for the class.  Some implementations may use
     * null to represent the bootstrap class loader. This method will return
     * null in such implementations if this class was loaded by the bootstrap
     * class loader.
     * 返回这个class的类加载器，有些实现使用null代替bootstrap 加载器，如果这个类的加载器是bootstrap 那么这个方法返回null
     * <p> If a security manager is present, and the caller's class loader is
     * not null and the caller's class loader is not the same as or an ancestor of
     * the class loader for the class whose class loader is requested, then
     * this method calls the security manager's {@code checkPermission}
     * method with a {@code RuntimePermission("getClassLoader")}
     * permission to ensure it's ok to access the class loader for the class.
     * 如果使用了安全管理器，调用者的类加载器不是null，并且调用者的类加载器和类的加载器的层次关系不相等，那么就会用RuntimePermission("getClassLoader")调用安全管理器的getClassLoader方法来确认是否可以允许这个类的加载器去加载它。
     * <p>If this object
     * represents a primitive type or void, null is returned.
     *
     * @return  the class loader that loaded the class or interface
     *          represented by this object.
     * 返回加载了当前对象对应类的接口的加载器
     * @throws SecurityException
     *    if a security manager exists and its
     *    {@code checkPermission} method denies
     *    access to the class loader for the class.
     * @see java.lang.ClassLoader
     * @see SecurityManager#checkPermission
     * @see java.lang.RuntimePermission
     */
    @CallerSensitive
    public ClassLoader getClassLoader() {
   ...
   }
   ```
