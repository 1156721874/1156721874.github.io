---
title: jvm原理（10）自定义类加载器深入详解
date: 2018-10-04 15:58:57
tags: 自定义类加载器
categories: jvm
---

上一节走读了类加载器的Java doc，这一节我们实现一个自定义的类加载器：
```
public class MyTest16 extends  ClassLoader {

    private String classLoaderName;
    private final String fileExtension = ".class";

    public MyTest16(String classLoaderName){
		/**
		父类ClassLoader的构造器
		protected ClassLoader() {
            this(checkCreateClassLoader(), getSystemClassLoader());
	    }
		**/
		//使用系统类加载器作为当前类的父类委托加载器
		super();
        this.classLoaderName = classLoaderName;
    }

    public MyTest16(ClassLoader classLoader,String classLoaderName){
    /*
	    父类ClassLoader带参数的构造器
        protected ClassLoader(ClassLoader parent) {
        this(checkCreateClassLoader(), parent);
    }
	*/
	//使用自定义的类加载器作为当前类的父类委托加载器
        super(classLoader);
        this.classLoaderName = classLoaderName;
    }

    private byte[] loadClassData(String name ){
        InputStream inputStream = null;
        ByteArrayOutputStream baos = null;
        byte [] bytes = null;

        try{
            this.classLoaderName = this.classLoaderName.replace(".","/");
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
        byte [] data = loadClassData(className);//中间调用子类的findClass方法
        return defineClass(className,data,0,data.length);
    }

    public  static void test(ClassLoader classLoader) throws Exception{
        Class<?> clazz = classLoader.loadClass("com.twodragonlake.jvm.classloader.MyTest");
        Object object = clazz.newInstance();
        System.out.println(object);
    }

    public static void main(String[] args) throws Exception {
        MyTest16 myTest16 = new MyTest16(MyTest16.class.getClassLoader(),"myClassLoader");
        MyTest16.test(myTest16);
    }
}

```
‘
输出：

```
com.twodragonlake.jvm.classloader.MyTest@1540e19d
```
