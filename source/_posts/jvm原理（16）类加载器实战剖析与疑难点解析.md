---
title: jvm原理（16）类加载器实战剖析与疑难点解析
date: 2018-10-04 16:09:45
tags: classLoader
categories: jvm
---

三大类加载器所加载的路径范围：

<!-- more -->
```
public class MyTest18 {
    public static void main(String[] args) {
        System.out.println(System.getProperty("sun.boot.class.path"));//系统类加载器加载路径
        System.out.println(System.getProperty("java.ext.dirs"));//扩展类加载器加载路径
        System.out.println(System.getProperty("java.class.path"));//应用类加载器加载过程
    }
}
```
结果（根据自身环境不同会有所差异）：

```
C:\Program Files\Java\jdk1.8.0_111\jre\lib\resources.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\rt.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\sunrsasign.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\jsse.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\jce.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\charsets.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\jfr.jar;C:\Program Files\Java\jdk1.8.0_111\jre\classes
-------------------------------------------
C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext;C:\WINDOWS\Sun\Java\lib\ext
-------------------------------------------
C:\Program Files\Java\jdk1.8.0_111\jre\lib\charsets.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\deploy.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\access-bridge-64.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\cldrdata.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\dnsns.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\jaccess.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\jfxrt.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\localedata.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\nashorn.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\sunec.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\sunjce_provider.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\sunmscapi.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\sunpkcs11.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\ext\zipfs.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\javaws.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\jce.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\jfr.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\jfxswt.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\jsse.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\management-agent.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\plugin.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\resources.jar;C:\Program Files\Java\jdk1.8.0_111\jre\lib\rt.jar;E:\Study\intelIde\jvm_lecture\out\production\classes;D:\IntelliJ IDEA 2017.2.4\lib\idea_rt.jar

```
下面我写一个程序：

```
public class MyTest18_1 {
    public static void main(String[] args) throws Exception {
        MyTest16 loader1 = new MyTest16("loader1");
        loader1.setPath("E:\\data\\classes\\");
        Class<?> clazz = loader1.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class : "+clazz.hashCode());
        System.out.println("class loader :" + clazz.getClassLoader());
    }
}

```
打印结果：

```
class : 1735600054
class loader :sun.misc.Launcher$AppClassLoader@18b4aac2
```
MyTest是由应用类加载器加载，这个没啥毛病，那么我们能不能想办法让启动类加载器去加载MyTest呢？要想让启动类加载器加载MyTest必须让启动类加载器能够找到MyTest的class文件，那就需要把MyTest放到启动类加载器的加载目录里边。ok，那么我们找到启动类加载器的一个路径比如【C:\Program Files\Java\jdk1.8.0_111\jre\classes】我们定位到此目录下边，此时你会发现C:\Program Files\Java\jdk1.8.0_111\jre\下边并没有classes文件夹，我们新建一个classes即可，既然sun.boot.class.path变量指定了这个目录我们就能从里边尝试加载类，然后我们把工程下边的【com.twodragonlake.jvm.classloader.MyTest.class】放到C:\Program Files\Java\jdk1.8.0_111\jre\下边，
![这里写图片描述](2018040520113087.png)
OK，此时我们运行MyTest18_1 得到打印结果：

```
class : 2133927002
class loader :null
```
null表明是由启动类加载器加载。即，MyTest.class是由启动类加载器加载。做完实验时候可以把classes目录删除，以免造成混绕。

接下来看一下扩展类加载器：

```

public class MyTest19 {
    public static void main(String[] args) {
        AESKeyGenerator aesKeyGenerator = new AESKeyGenerator();
        System.out.println(aesKeyGenerator.getClass().getClassLoader());
        System.out.println(MyTest19.class.getClassLoader());
    }
}

```
打印结果：

```
sun.misc.Launcher$ExtClassLoader@12a3a380
sun.misc.Launcher$AppClassLoader@18b4aac2
```
那好我们能不能修改扩展类加载器的加载路径java.ext.dirs的值，让其从当前目录加载如何？
![这里写图片描述](20180405202814804.png)
显然AESKeyGenerator无法被加载，因为当前目录不存在这个类。

下一个例子：

```
public class MyTest20 {
    public static void main(String[] args)  throws Exception{
        MyTest16 loader1 = new MyTest16("loader1") ;
        MyTest16 loader2 = new MyTest16("loader2") ;
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
打印结果为true，原因是虽然loader1和loader2是2个不同的类加载器实例，但是他们都会委托应用类加载器去加载，如果应用类加载器加载过MyPerson，第二次不会再次加载。所以这2个加载器加载的类返回的结果是同一个类。
下边的我们用clazz1创建的Method，然后调用的时候我们传入的是clazz2的对象object2，由于object1和object2的class是同一个class，所以向下类型转换不会出现问题。
