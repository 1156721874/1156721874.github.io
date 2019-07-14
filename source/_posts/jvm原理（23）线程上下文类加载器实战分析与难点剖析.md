---
title: jvm原理（23）线程上下文类加载器实战分析与难点剖析
date: 2018-10-04 16:37:50
tags: 线程上下文类加载器
categories: jvm
---

我们紧接着上一个例子的代码进行：

```
public class MyTest26 {
    public static void main(String[] args) {
        ServiceLoader<Driver> serviceLoader = ServiceLoader.load(Driver.class);
        Iterator<Driver> iterator = serviceLoader.iterator();

        while(iterator.hasNext()){
            Driver driver =  iterator.next();
            System.out.println("driver: "+driver.getClass() + "loader: "+ driver.getClass().getClassLoader() );
        }

        System.out.println("当前线程上下文类加载器: " + Thread.currentThread().getContextClassLoader());

        System.out.println("ServiceLoader的类加载器: "+ServiceLoader.class.getClassLoader());

    }
}
```
首先MyTest26的类加载器是系统类加载器，
程序运行到【**ServiceLoader<Driver> serviceLoader = ServiceLoader.load(Driver.class);**】的时候回去加载ServiceLoader，系统类加载器会根据双亲委托模型往上委派，直到最后ServiceLoader被启动类加载器加载，那么我们看一下ServiceLoader.load()方法的实现：

```
    public static <S> ServiceLoader<S> load(Class<S> service) {
        ClassLoader cl = Thread.currentThread().getContextClassLoader();
        return ServiceLoader.load(service, cl);
    }
```
 既然ServiceLoader是由启动类加载器加载，那么ServiceLoader里边的类都会用启动类加载器去加载，但是呢我们的mysql驱动不在启动类加载器加载的目录下边，我们的mysql驱动位于classpath下边，无法用启动类加载器加载，这个时候，我们可以看到load方法使用了线程上下文加载器，线程上下文加载器默认是系统类加载器[上一节](https://blog.csdn.net/wzq6578702/article/details/80058286)已经介绍过，所以load方法得到的ClassLoader cl是AppClassLoader，然后将cl传递给ServiceLoader.load(service, cl)方法:


```
	//加载器的缓存
    // Cached providers, in instantiation order
    private LinkedHashMap<String,S> providers = new LinkedHashMap<>();
    public static <S> ServiceLoader<S> load(Class<S> service,ClassLoader loader)
    {
    //调用ServiceLoader构造器
        return new ServiceLoader<>(service, loader);
    }
	//ServiceLoader构造器
    private ServiceLoader(Class<S> svc, ClassLoader cl) {
    //判空
        service = Objects.requireNonNull(svc, "Service interface cannot be null");
        //加载器判空，空的情况是使用系统类加载器
        loader = (cl == null) ? ClassLoader.getSystemClassLoader() : cl;
        //安全相关的
        acc = (System.getSecurityManager() != null) ? AccessController.getContext() : null;
        //调用reload，刷新缓存
        reload();
    }

    //刷新缓存
    public void reload() {
    //清空缓存
        providers.clear();
        //LazyIterator是ServiceLoader的私有内部类
        lookupIterator = new LazyIterator(service, loader);
    }


//LazyIterator 部分代码
// Private inner class implementing fully-lazy provider lookup
//用来实现懒加载方式 的提供者的查找的私有内部类
    private class LazyIterator implements Iterator<S>
    {
       Class<S> service;
        ClassLoader loader;
        Enumeration<URL> configs = null;
        Iterator<String> pending = null;
        String nextName = null;

        private LazyIterator(Class<S> service, ClassLoader loader) {
            this.service = service;
            this.loader = loader;
        }

 private boolean hasNextService() {
 ....
 }
  private S nextService() {
            if (!hasNextService())
                throw new NoSuchElementException();
            String cn = nextName;
            nextName = null;
            Class<?> c = null;
            try {
            //cn相当于java.sql.Drive文件下的某一行的全限定名，false表示不初始化，loader加载器是我们传递进来的线程上下文类加载器
            //（即，系统类加载器或者应用类加载器）
            //Class.forName()方法见之前的介绍：https://blog.csdn.net/wzq6578702/article/details/79950220
                c = Class.forName(cn, false, loader);
            } catch (ClassNotFoundException x) {
                fail(service,
                     "Provider " + cn + " not found");
            }
            if (!service.isAssignableFrom(c)) {
                fail(service,
                     "Provider " + cn  + " not a subtype");
            }
            try {
                S p = service.cast(c.newInstance());
                providers.put(cn, p);
                return p;
            } catch (Throwable x) {
                fail(service,
                     "Provider " + cn + " could not be instantiated",
                     x);
            }
            throw new Error();          // This cannot happen
  }
  public boolean hasNext() {
  ...
  }
  public S next() {
  ...
  }
     }

```

到此为止我们看到的程序的打印结果

```
driver: class com.mysql.jdbc.Driverloader: sun.misc.Launcher$AppClassLoader@18b4aac2
driver: class com.mysql.fabric.jdbc.FabricMySQLDriverloader: sun.misc.Launcher$AppClassLoader@18b4aac2
当前线程上下文类加载器: sun.misc.Launcher$AppClassLoader@18b4aac2
ServiceLoader的类加载器: null
```
前2行driver就是java.sql.Drive文件里边的2行，而上下文类加载器是默认的系统类加载器，ServiceLoader属于rt.jar是由启动类加载器加载。

接下来改一下程序成如下：
```
public class MyTest26 {
    public static void main(String[] args) {
    //添加这行代码
     Thread.currentThread().setContextClassLoader(MyTest26.class.getClassLoader().getParent());
        ServiceLoader<Driver> serviceLoader = ServiceLoader.load(Driver.class);
        Iterator<Driver> iterator = serviceLoader.iterator();

        while(iterator.hasNext()){
            Driver driver =  iterator.next();
            System.out.println("driver: "+driver.getClass() + "loader: "+ driver.getClass().getClassLoader() );
        }

        System.out.println("当前线程上下文类加载器: " + Thread.currentThread().getContextClassLoader());

        System.out.println("ServiceLoader的类加载器: "+ServiceLoader.class.getClassLoader());

    }
}
```
打印结果：
```
当前线程上下文类加载器: sun.misc.Launcher$ExtClassLoader@14ae5a5
ServiceLoader的类加载器: null
```
可以看到循环没有去执行，上下文类加载器是扩展类加载器没啥问题，因为系统类加载器的上级是扩展类加载器，但是为什么循环是空的呢？原因就是扩展类加载器无法加载classpath下边的类，mysql的jar包是放在classpath下边的。
其实加上-XX:+TraceClassLoading启动参数，我们可以显式的看到驱动被加载。
