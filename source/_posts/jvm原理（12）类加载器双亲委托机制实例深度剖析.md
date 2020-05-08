---
title: jvm原理（12）类加载器双亲委托机制实例深度剖析
date: 2018-10-04 16:01:41
tags: [双亲委托]
categories: jvm
---

我们在之前写过的一个[自定义类加载器](http://blog.csdn.net/wzq6578702/article/details/79548157):
我们修改一下程序的findClass方法：
<!-- more -->

```
    protected Class<?> findClass(String className) throws ClassNotFoundException {
        System.out.println("findClass invoked "+className);
        System.out.println(" this.classLoaderName : "+ this.classLoaderName);
        byte [] data = loadClassData(className);//中间调用子类的findClass方法
        return defineClass(className,data,0,data.length);
    }
```
还有test方法我们加一些跟踪打印：

```

    public  static void test(ClassLoader classLoader) throws Exception{
        Class<?> clazz = classLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        Object object = clazz.newInstance();
        System.out.println(object.getClass().getClassLoader());
    }
```

然后我们在运行main方法，你会看到findClass的2行并没有打印，并且test方法打印的类加载器是应用类加载器， 也就是意味着我们的自定义类加载器并没有没使用，原因很简单，因为我们的MyTest16构造器：

```
    public MyTest16(String classLoaderName){
        super();//使用系统类加载器作为当前类的父类委托加载器
        this.classLoaderName = classLoaderName;
    }
```
使用的父类委托加载器是应用类加载器，我们当前的类“com.twodragonlake.jvm.classloader.MyTest”属于classpath下边，应用类加载可以加载classpath下边的类，所以最终是由应用类加载器加载的。

接下来我们打算加载一个外部的类，我们不把class文件放在当前工程里边，比我放在“E:\data\classes\com\twodragonlake\jvm\classloader.MyTest.class”这里，然后修改程序：

```
public class MyTest16 extends  ClassLoader {

    private String classLoaderName;
    private final String fileExtension = ".class";
    private String path;

    public void setPath(String path) {
        this.path = path;
    }

    public MyTest16(String classLoaderName){
        super();//使用系统类加载器作为当前类的父类委托加载器
        this.classLoaderName = classLoaderName;
    }

    public MyTest16(ClassLoader classLoader,String classLoaderName){
        super(classLoader);//使用自定义的类加载器作为当前类的父类委托加载器
        this.classLoaderName = classLoaderName;
    }

    private byte[] loadClassData(String name ){
        InputStream inputStream = null;
        ByteArrayOutputStream baos = null;
        byte [] bytes = null;

        try{
            //this.classLoaderName = this.classLoaderName.replace(".","\\");
            name = name.replace(".","\\");//将包名里边的"."替换为路径分隔符
            inputStream = new FileInputStream(new File(this.path + name + this.fileExtension));//文件来自于加载路径path下的包里边的class文件
            baos = new ByteArrayOutputStream();
            int ch = 0;
            while (-1 !=(ch = inputStream.read())){
                baos.write(ch);
            }
            bytes = baos.toByteArray();
        }catch (Exception e){
            e.printStackTrace();
        }finally {
            try{
                inputStream.close();
                baos.close();
            }catch (Exception e){
                e.printStackTrace();
            }
        }
        return bytes;
    }

    @Override
    protected Class<?> findClass(String className) throws ClassNotFoundException {
        System.out.println("findClass invoked "+className);
        System.out.println(" this.classLoaderName : "+ this.classLoaderName);
        byte [] data = loadClassData(className);//中间调用子类的findClass方法
        return defineClass(className,data,0,data.length);
    }

    public static void main(String[] args) throws Exception {
        MyTest16 myClassLoader = new MyTest16("myClassLoader");
        myClassLoader.setPath("E:\\data\\classes\\");//设置加载路径
        Class<?> clazz = myClassLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz.hashCode());
        Object object = clazz.newInstance();
        System.out.println(object);
    }
}

```

打印结果

```
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader
class :21685669
com.twodragonlake.jvm.classloader.MyTest@7f31245a
```
我们自定义的加载器的findClass 被调用，证明我们写的加载器起了作用。
注意：执行之前将当前工程下的MyTest.class文件删除，如果我们重新构建工程，让MyTest.class出现在当前工程里边，再去运行这个自定义类加载器，结果还是会被应用类加载器加载，我们删除MyTest.class的理由就是让应用类加载器加载失败，然后所有的父类委托都无法加载的时候最终让我们自定义的类加载器MyTest16 去加载。而MyTest16指定的加载路径在外部的一个路径，显然是可以的。

好，现在我们修改一下main方法，然后保留当前工程里边的MyTest.class文件：

```
    public static void main(String[] args) throws Exception {
        MyTest16 myClassLoader = new MyTest16("myClassLoader");
        myClassLoader.setPath("E:\\data\\classes\\");
        Class<?> clazz = myClassLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazz.hashCode());
        Object object = clazz.newInstance();
        System.out.println(object);
        System.out.println("-----------------------------------------");
        MyTest16 myClassLoader1 = new MyTest16("myClassLoader1");
        myClassLoader1.setPath("E:\\data\\classes\\");
        Class<?> clazza = myClassLoader1.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        System.out.println("class :"+clazza.hashCode());
        Object objecta = clazza.newInstance();
          System.out.println(objecta);
    }
```
打印结果：

```
class :356573597
com.twodragonlake.jvm.classloader.MyTest@677327b6
-----------------------------------------
class :356573597
com.twodragonlake.jvm.classloader.MyTest@14ae5a5
```
我们new了2个自定义加载器，结果可以看到使用了系统类加载器加载的，并且第二次加载使用了之前加载出来的结果，这是因为myClassLoader 和myClassLoader1 的父类加载器都是应用类加载器， 这个在[之前的loadClass方法的介绍](http://blog.csdn.net/wzq6578702/article/details/79600435)里边说过，中间会有一个判断是否加载过的方法 ，loadClass会去调用这个判重方法。

之后我们删除当前工程的MyTest.class文件，再去运行这个main方法:
```
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader
class :21685669
com.twodragonlake.jvm.classloader.MyTest@7f31245a
-----------------------------------------
findClass invoked com.twodragonlake.jvm.classloader.MyTest
 this.classLoaderName : myClassLoader1
class :1173230247
com.twodragonlake.jvm.classloader.MyTest@330bedb4
```
首先使用了我们自定义的类加载器加载的，并且被加载了2次！！因为类的hashCode编码不同。这两个class(clazz 和clazza )不是同一个class对象，这个和我们之前说过的一个类只能被加载一次是相互矛盾的，这个怎么解释呢，其实是不矛盾的，这里有一个命名空间的问题：
![这里写图片描述](20180318164433605.png)
在我们这个例子中myClassLoader和myClassLoader1虽然都是同一个类，但是他们是不同的2个对象，而且他们都去尝试用应用类加载器加载的时候都会失败，因为当前工程下的MyTest.class被删除了，导致应用类加载器加载MyTest.class失败，从而让我们自定义的类加载器有机会执行加载逻辑，myClassLoader和myClassLoader1不同的2个对象，同时对应不同的2个命名空间，在不同的命名空间里边，因此加载出来的类也是不同的。
