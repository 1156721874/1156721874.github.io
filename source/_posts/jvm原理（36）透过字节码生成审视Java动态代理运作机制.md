---
title: jvm原理（36）透过字节码生成审视Java动态代理运作机制
date: 2018-10-05 10:42:19
tags: [动态代理,字节码,反射]
categories: jvm
---

我们在使用spring这类框架的时候，基于动态代理的使用，比如AOP，会使得开发更加灵活，那么在字节码的层面动态代理是什么样子的呢，生成出来的代理类结构是什么，本次我们首先写一个动态代理的例子，然后得到生成的动态代理类。
定义接口：
```
public interface SubJect {
    void request();
}
```
定义实现类：
```
public class RealSubJect implements SubJect {
    @Override
    public void request() {
        System.out.println("method calling");
    }
}
```
定义动态代理类：
```
public class DynamicSubject implements InvocationHandler {

    private Object sub;

    public DynamicSubject(Object obj){
        this.sub = obj;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        System.out.println("befor method call");
        method.invoke(sub,args);
        System.out.println("after method call");
        return null;
    }
}
```

定义客户端：
```
public class Client {
    public static void main(String[] args) {
        RealSubJect realSubJect = new RealSubJect();
        InvocationHandler invocationHandler = new DynamicSubject(realSubJect);
        SubJect subJect = (SubJect) Proxy.newProxyInstance(realSubJect.getClass().getClassLoader(),realSubJect.getClass().getInterfaces(),invocationHandler);
        subJect.request();
        System.out.println(subJect.getClass());//打印动态代理类的class
        System.out.println(subJect.getClass().getSuperclass()); //打印父类
    }
}
```
运行客户端得到结果：
```
befor method call
method calling
after method call
class com.sun.proxy.$Proxy0
class java.lang.reflect.Proxy
```

那么这个com.sun.proxy.$Proxy0是怎么出来的呢，这个需要进入到Proxy.newProxyInstance()里边看一下他的逻辑：
```
Proxy.newProxyInstance()
  -->getProxyClass0()
     -->proxyClassCache.get()[通过ProxyClassFactory获取]
        -->WeakCache.Factory.get()
          -->valueFactory.apply(key, parameter)
             -->Proxy.apply()
               -->byte[] proxyClassFile = ProxyGenerator.generateProxyClass(proxyName, interfaces, accessFlags);
                  -->byte[] proxyClassFile = ProxyGenerator.generateClassFile();
```
ProxyGenerator是 sun.misc包里边的，我们得到的代码是ide反编译的结果，我们贴出来，var4是生成出来的字节数组，然后
saveGeneratedFiles是一个开关，如果为true就会把class文件输出到磁盘
```
public static byte[] generateProxyClass(final String var0, Class<?>[] var1, int var2) {
    ProxyGenerator var3 = new ProxyGenerator(var0, var1, var2);
    final byte[] var4 = var3.generateClassFile();//返回最终的字节数组
    if (saveGeneratedFiles) {
        AccessController.doPrivileged(new PrivilegedAction<Void>() {
            public Void run() {
                try {
                    int var1 = var0.lastIndexOf(46);
                    Path var2;
                    if (var1 > 0) {
                        Path var3 = Paths.get(var0.substring(0, var1).replace('.', File.separatorChar));
                        Files.createDirectories(var3);
                        var2 = var3.resolve(var0.substring(var1 + 1, var0.length()) + ".class");
                    } else {
                        var2 = Paths.get(var0 + ".class");
                    }

                    Files.write(var2, var4, new OpenOption[0]);
                    return null;
                } catch (IOException var4x) {
                    throw new InternalError("I/O exception saving generated file: " + var4x);
                }
            }
        });
    }

    return var4;
}
```
saveGeneratedFiles的定义：
```
 private static final boolean saveGeneratedFiles =
 ((Boolean)AccessController.doPrivileged(new GetBooleanAction("sun.misc.ProxyGenerator.saveGeneratedFiles"))).booleanValue();
```
ok 我们设置一下sun.misc.ProxyGenerator.saveGeneratedFiles就可以得到class文件。下边这行代码放在Client main方法的第一行，提前设置。
```
System.getProperties().put("sun.misc.ProxyGenerator.saveGeneratedFiles","true");
```
运行Client,然后在我们的工程里边就会出现一个目录
com.sun.proxy.$Proxy0
这个就是动态代理类：
```
package com.sun.proxy;

import com.twodragonlake.jvm.bytecode.SubJect;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.lang.reflect.UndeclaredThrowableException;

public final class $Proxy0 extends Proxy implements SubJect {
    private static Method m1;
    private static Method m2;
    private static Method m3;
    private static Method m0;

    /**
    构造方法
    这个构造方法在Proxy类的newProxyInstance方法里边，有一个地方是获取代理类的构造器：
     Class<?> cl = getProxyClass0(loader, intfs); //代理类
     final Constructor<?> cons = cl.getConstructor(constructorParams);//获取代理类的构造器
     return cons.newInstance(new Object[]{h});//实例化代理类；
     h是InvocationHandler，InvocationHandler是我们定义的DynamicSubject的接口，这个时候就会调用当前的这个构造方法
     动态代理类的父类Proxy持有InvocationHandler的引用，完成这个引用的赋值。
    */
    public $Proxy0(InvocationHandler var1) throws  {
        super(var1);
    }

    public final boolean equals(Object var1) throws  {
        try {
          /**
            调用Proxy的InvocationHandler的invoke方法，其实就是调用DynamicSubject的invoke方法，
            因为DynamicSubject实现了InvocationHandler，m1是Object类的equals方法，new Object[]{var1}是equals的方法参数
            如果DynamicSubject重新了equals方法就会转发到DynamicSubject的equals方法，否则就是调用Object的equals方法
          */
            return ((Boolean)super.h.invoke(this, m1, new Object[]{var1})).booleanValue();
        } catch (RuntimeException | Error var3) {
            throw var3;
        } catch (Throwable var4) {
            throw new UndeclaredThrowableException(var4);
        }
    }

    /**
    和equals方法道理了一样
    */
    public final String toString() throws  {
        try {
            return (String)super.h.invoke(this, m2, (Object[])null);
        } catch (RuntimeException | Error var2) {
            throw var2;
        } catch (Throwable var3) {
            throw new UndeclaredThrowableException(var3);
        }
    }

    public final void request() throws  {
        try {
            super.h.invoke(this, m3, (Object[])null);
        } catch (RuntimeException | Error var2) {
            throw var2;
        } catch (Throwable var3) {
            throw new UndeclaredThrowableException(var3);
        }
    }

    /**
    和equals方法道理了一样
    */
    public final int hashCode() throws  {
        try {
            return ((Integer)super.h.invoke(this, m0, (Object[])null)).intValue();
        } catch (RuntimeException | Error var2) {
            throw var2;
        } catch (Throwable var3) {
            throw new UndeclaredThrowableException(var3);
        }
    }

    static {
        try {
          //类加载的时候，将Object类的是个方法拿出来
            m1 = Class.forName("java.lang.Object").getMethod("equals", Class.forName("java.lang.Object"));
            m2 = Class.forName("java.lang.Object").getMethod("toString");
            m3 = Class.forName("com.twodragonlake.jvm.bytecode.SubJect").getMethod("request");
            m0 = Class.forName("java.lang.Object").getMethod("hashCode");
        } catch (NoSuchMethodException var2) {
            throw new NoSuchMethodError(var2.getMessage());
        } catch (ClassNotFoundException var3) {
            throw new NoClassDefFoundError(var3.getMessage());
        }
    }
}
```
除了equals、toString、hashCode的其他的Object的方法，都不会得到代理类的转发，原来是什么样子的，代理后也还是什么样子的，不会发生变化。
好，到目前为止我们分析了动态代理类的源码，那回到client的代码：
```
  SubJect subJect = (SubJect) Proxy.newProxyInstance(realSubJect.getClass().getClassLoader(),realSubJect.getClass().getInterfaces(),invocationHandler);
```
subJect返回的是一个动态代理类，这个类的名字是$Proxy0，$Proxy0的父类是Proxy，父类持有InvocationHandler的引用，也就是持有DynamicSubject的引用，同时$Proxy0实现了SubJect接口，$Proxy0里边生成了DynamicSubject里边所声明的方法，并且转发到了DynamicSubject里边。当我们调用subJect.request();
的时候就是调用了$Proxy0.request();$Proxy0将方法的调用通过父类Proxy持有的InvocationHandler的引用，即【super.h.invoke(this, m0, (Object[])null))】进行了转发，转发到DynamicSubject的invoke方法。所以说DynamicSubject的invoke方法的第一个参数是proxy，接下里就会打印：
```
befor method call
method calling
after method call
```
动态代理的优势：
代理对象可以在没有真实对象不存在的情况下提前生成代理对象，代理对象可以代理多种真实对象，而且jdk的动态代理是面向接口的。
 cglib：
 面向继承的代理，子类可以重写父类的实现，同时代理类可以调用父类的方法（jdk动态代理没有这个优势，因为jdk动态代理是面向接口的）
