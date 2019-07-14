---
title: jvm原理（20）Launcher类源码分析以及forName方法底层剖析
date: 2018-10-04 16:17:22
tags: [launcher,forName]
categories: jvm
---

上一节我们通过【ClassLoader.getSystemClassLoader()】得到系统类加载器，那么本节看一下这个方法的doc以及一些细节，方便我们更好的理解：
<font color="#FF0000">
public static ClassLoader getSystemClassLoader()
Returns the system class loader for delegation. This is the default delegation parent for new ClassLoader instances, and is typically the class loader used to start the application.
</font>
返回用于代理的系统类加载器，对于一个类加载器实例来说这是默认的父级代理，也是最典型的用于启动应用的类加载器。
<font color="#FF0000">
This method is first invoked early in the runtime's startup sequence, at which point it creates the system class loader and sets it as the context class loader of the invoking Thread.
</font>
这个方法最早在运行时启动的就会被调用，在这个调用点上会去创建系统类加载器，并且将其设置在调用线程为【上下文加载器】。
<font color="#FF0000">
The default system class loader is an implementation-dependent instance of this class.
</font>
默认的系统类加载器是一个与这个类实现相关的实例
<font color="#FF0000">
If the system property "java.system.class.loader" is defined when this method is first invoked then the value of that property is taken to be the name of a class that will be returned as the system class loader. The class is loaded using the default system class loader and must define a public constructor that takes a single parameter of type ClassLoader which is used as the delegation parent. An instance is then created using this constructor with the default system class loader as the parameter. The resulting class loader is defined to be the system class loader.
</font>
如果系统属性【java.system.class.loader】被定义，那么这个属性的值对应的class会被默认的系统类加载器 加载，并且作为系统类加载器，这个被定义的加载器必须有一个单个参数的构造器，参数的类型是ClassLoader，用来代理父加载器，使用这个构造器传入默认的的系统类加载器会创建一个类加载器的实例，这个实例会成为系统类加载器。
<font color="#FF0000">
If a security manager is present, and the invoker's class loader is not null and the invoker's class loader is not the same as or an ancestor of the system class loader, then this method invokes the security manager's checkPermission method with a RuntimePermission("getClassLoader") permission to verify access to the system class loader. If not, a SecurityException will be thrown.
</font>
安全略过，主要是介绍一些安全接入的权限是否可以接入

伏笔：
1、【上下文加载器】
2、定义ClassLoader类型的构造器
方法体：

```
    public static ClassLoader getSystemClassLoader() {
        initSystemClassLoader();//初始化系统类加载器
        if (scl == null) {
            return null;
        }
        //下边的是安全相关的，不做介绍
        SecurityManager sm = System.getSecurityManager();
        if (sm != null) {
            checkClassLoaderPermission(scl, Reflection.getCallerClass());
        }
        return scl;
    }
```
进入到initSystemClassLoader():

```
PS:
sclSet、scl 成员变量介绍：
    // The class loader for the system
    // @GuardedBy("ClassLoader.class")
    系统类加载器在ClassLoader的引用
    private static ClassLoader scl;

    // Set to true once the system class loader has been set
    // @GuardedBy("ClassLoader.class")
    //如果系统类加载器被加载过，即scl成员变量不是null，那么sclSet的值为true
    private static boolean sclSet;

    private static synchronized void initSystemClassLoader() {
        //系统类加载器是否被设置
        if (!sclSet) {
             //双重判断，即sclSet是true，但是系统类加载器是null，排除非法异常
            if (scl != null)
                throw new IllegalStateException("recursive invocation");
                //通过sun.misc.Launcher获取系统类加载器。sun.misc.Launcher是系统类加载器，扩展类加载器上层的一个概念，并且Oracle不是开源的
            sun.misc.Launcher l = sun.misc.Launcher.getLauncher();
            if (l != null) {
                Throwable oops = null;
                scl = l.getClassLoader();
                try {
                    scl = AccessController.doPrivileged(
                        new SystemClassLoaderAction(scl));
                } catch (PrivilegedActionException pae) {
                    oops = pae.getCause();
                    if (oops instanceof InvocationTargetException) {
                        oops = oops.getCause();
                    }
                }
                if (oops != null) {
                    if (oops instanceof Error) {
                        throw (Error) oops;
                    } else {
                        // wrap the exception
                        throw new Error(oops);
                    }
                }
            }
            sclSet = true;
        }
    }
```
我们在idea里边看到的sun.misc.Launcher.getLauncher()的实现是反编译工具给出的，oracle并没有给出源码，但是我们可以去[openjdk](http://openjdk.java.net/)获取他的源码，也可以使用http://grepcode.com/search查看源码：
http://grepcode.com/search/?query=sun.misc.launcher
http://grepcode.com/file/repository.grepcode.com/java/root/jdk/openjdk/8u40-b25/sun/misc/Launcher.java#Launcher
sun.misc.Launcher.getLauncher()z返回值是sun.misc.Launcher内部的一个静态成员变量【 private static Launcher launcher = new Launcher();】
那么我们看一下Launcher的构造器：

```
public Launcher() {
68         // Create the extension class loader
			//获得系统类加载器
69         ClassLoader extcl;
70         try {
				//ExtClassLoader是Launcher的一个内部类，getExtClassLoader()getExtClassLoader()获取扩展类加载器，
				/**
					getExtClassLoader()方法里边返回扩展类加载器实例，并且通过系统属性java.ext.dirs加载其需要加载的类
				*/
71             extcl = ExtClassLoader.getExtClassLoader();
72         } catch (IOException e) {
73             throw new InternalError(
74                 "Could not create extension class loader", e);
75         }
76
77         // Now create the class loader to use to launch the application
			//获取系统类加载器，并且将扩展类加载器作为他的委托传入
78         try {
79             loader = AppClassLoader.getAppClassLoader(extcl);
80         } catch (IOException e) {
81             throw new InternalError(
82                 "Could not create application class loader", e);
83         }
84
85         // Also set the context class loader for the primordial thread.
			//将系统类加载器作为当前线程上下文的加载器
86         Thread.currentThread().setContextClassLoader(loader);
87
88         // Finally, install a security manager if requested
89         String s = System.getProperty("java.security.manager");
90         if (s != null) {
91             SecurityManager sm = null;
92             if ("".equals(s) || "default".equals(s)) {
93                 sm = new java.lang.SecurityManager();
94             } else {
95                 try {
96                     sm = (SecurityManager)loader.loadClass(s).newInstance();
97                 } catch (IllegalAccessException e) {
98                 } catch (InstantiationException e) {
99                 } catch (ClassNotFoundException e) {
100                } catch (ClassCastException e) {
101                }
102            }
103            if (sm != null) {
104                System.setSecurityManager(sm);
105            } else {
106                throw new InternalError(
107                    "Could not create SecurityManager: " + s);
108            }
109        }
110    }
```
扩展类加载器获取加载文件数组：
```
169        private static File[]  getExtDirs() {
				//加载来源来自于系统属性java.ext.dirs
170            String s = System.getProperty("java.ext.dirs");
171            File[] dirs;
172            if (s != null) {
173                StringTokenizer st =
174                    new StringTokenizer(s, File.pathSeparator);
175                int count = st.countTokens();
176                dirs = new File[count];
177                for (int i = 0; i < count; i++) {
178                    dirs[i] = new File(st.nextToken());
179                }
180            } else {
181                dirs = new File[0];
182            }
183            return dirs;
184        }
```
getAppClassLoader的方法：
入参是扩展类加载器
```
267        public static ClassLoader getAppClassLoader(final ClassLoader extcl)
268            throws IOException
269        {
				//通过系统属性java.class.path获取加载路径
270            final String s = System.getProperty("java.class.path");
271            final File[] path = (s == null) ? new File[0] : getClassPath(s);
272
273            // Note: on bugid 4256530
274            // Prior implementations of this doPrivileged() block supplied
275            // a rather restrictive ACC via a call to the private method
276            // AppClassLoader.getContext(). This proved overly restrictive
277            // when loading  classes. Specifically it prevent
278            // accessClassInPackage.sun.* grants from being honored.
279            //
280            return AccessController.doPrivileged(
281                new PrivilegedAction<AppClassLoader>() {
282                    public AppClassLoader More ...run() {
283                    URL[] urls =
284                        (s == null) ? new URL[0] : pathToURLs(path);
						//构造系统类加载器的时候将他的委托父类传入，以及加载路径数组
285                    return new AppClassLoader(urls, extcl);
286                }
287            });
288        }
289
290        final URLClassPath ucp;
291
292        /*
293         * Creates a new AppClassLoader
294         */
295        AppClassLoader(URL[] urls, ClassLoader parent) {
				//调用父类URLClassLoader,注意不管是系统类加载器还是扩展类加载器都是继承来自ClassLoader
				//CLassLoader里边之前说过有一个硬编码的成员变量【private final ClassLoader parent;】
				//此处的parent一直溯源到ClassLoader 类，将ClassLoader 的parent赋值为当前方法传入的parent入参，
				//也就说明了系统类加载器的委托父类就是扩展类加载器
296            super(urls, parent, factory);
297            ucp = SharedSecrets.getJavaNetAccess().getURLClassPath(this);
298            ucp.initLookupCache(this);
299        }
```
然后我们再回过头来看看idea里边反编译出来的获取系统类加载器的方法：
![这里写图片描述](20180415145420761.png)
大家可能会有疑问，为什么反编译出来的变量都是var1、var2之类的呢？其实这个在龙哥的[kotlin](http://www.iprogramming.cn/kotlin_lesson.html)课程中【27_Kotlin函数使用综述与显式返回类型分析】一讲里边介绍过，Java中并不总是在class 字节码中携带变量名，但是在kotlin里边就不是这样的，因为kotlin里边有具名参数的概念。

ok，我们回到initSystemClassLoader()方法,通过调用【 sun.misc.Launcher l = sun.misc.Launcher.getLauncher();】获取到系统类加载器之后，赋值给ClassLoader的scl成员变量之后，还有一块代码：

```
                try {
                    scl = AccessController.doPrivileged(
                        new SystemClassLoaderAction(scl));
                } catch (PrivilegedActionException pae) {
                    oops = pae.getCause();
                    if (oops instanceof InvocationTargetException) {
                        oops = oops.getCause();
                    }
                }
```

这块逻辑的作用是看看是否设置了系统属性【java.system.class.loader】，即自定义的系统类加载器，如果设置了那么实例化自定义的系统类加载器返回，替代之前获取的系统类加载器，如果没有设置直接返回默认的系统类加载器。

```
class SystemClassLoaderAction
    implements PrivilegedExceptionAction<ClassLoader> {
    private ClassLoader parent;

    SystemClassLoaderAction(ClassLoader parent) {
        this.parent = parent;
    }

    public ClassLoader run() throws Exception {
        String cls = System.getProperty("java.system.class.loader");
        //自定义系统类加载器未定义，直接返回之前默认获取的系统类加载器
        if (cls == null) {
            return parent;
        }
		//如果定义了自定义的系统类加载器那么实例化并返回，替代默认的系统类加载器
		//etDeclaredConstructor(new Class<?>[] { ClassLoader.class })这个就是我们之前
		//（https://blog.csdn.net/wzq6578702/article/details/79835695）
		//在MyTest16里边加入一个参数是ClassLoader的构造器的原因，
		//因为自定义的的加载器在这里会被反射调用，
		//
        Constructor<?> ctor = Class.forName(cls, true, parent)
            .getDeclaredConstructor(new Class<?>[] { ClassLoader.class });
        ClassLoader sys = (ClassLoader) ctor.newInstance(
            new Object[] { parent });
            //同样的道理 将自定义系统类加载器作为当前线程的上下文加载器。
        Thread.currentThread().setContextClassLoader(sys);
        return sys;
    }
}
```
那么接下来介绍一下 Class.forName(cls, true, parent)，Class.forName方法大部分做web开发的都是在开始写jdbc的时候接触，那么先看一下doc：
java.lang.Class
public static Class<?> forName(@NonNls String name,
                               boolean initialize,
                               ClassLoader loader)
                       throws ClassNotFoundException
接收三个参数。
第一参数是要被加载的类的全名，第二个参数是用来表示是否初始化这个要被加载的类，第三个参数是类加载器。
<font color="#FF0000">
Returns the Class object associated with the class or interface with the given string name, using the given class loader. Given the fully qualified name for a class or interface (in the same format returned by getName) this method attempts to locate, load, and link the class or interface. The specified class loader is used to load the class or interface. If the parameter loader is null, the class is loaded through the bootstrap class loader. The class is initialized only if the initialize parameter is true and if it has not been initialized earlier.
</font>
通过给定的类加载器，即入参loader，返回入参name对应的类或接口的Class对象，通过给定的接口或者类的全名(通过getName方法获取)尝试去定位，加载，连接，给定的loader用来加载类或者接口，如果参数loader是null，那么就会使用启动类加载器去加载，，只在在入参initialize 为true并且类从来没有被加载的情况下才去初始化这个类。
<font color="#FF0000">
If name denotes a primitive type or void, an attempt will be made to locate a user-defined class in the unnamed package whose name is name. Therefore, this method cannot be used to obtain any of the Class objects representing primitive types or void.
</font>
如果name是原生类型或者是void，那么就会尝试在用户定义类的没有包名的包（default package）下边去定位，因为这个方法不能用于包含原生类型或者void类型
<font color="#FF0000">
If name denotes an array class, the component type of the array class is loaded but not initialized.
</font>
如果name对应的是一个数组类型，这个数组的组件类型会被加载但是不会初始化。
<font color="#FF0000">
For example, in an instance method the expression:
Class.forName("Foo")
is equivalent to:
Class.forName("Foo", true, this.getClass().getClassLoader())
Note that this method throws errors related to loading, linking or initializing as specified in Sections 12.2, 12.3 and 12.4 of The Java Language Specification. Note that this method does not check whether the requested class is accessible to its caller.
</font>
这个方法会抛出Java语言规范的12.2，12.3，12.4章节里边的相关的对于加载，连接，初始化相关的异常，注意这个方法并不会检查对于调用者来说是否访问。
<font color="#FF0000">
If the loader is null, and a securiy manager is present, and the caller's class loader is not null, then this method calls the security manager's checkPermission method with a RuntimePermissin("getClassLoader") permission to ensure it's ok to access the bootstrap class loader.
</font>
如果laoder是null，并且安全管理器指定了，并且调用者的加载器不是null，那么这个方法会调用安全管理器的checkPermission 方法，使用RuntimePermissin("getClassLoader") 来确定是否可以接入启动类加载器【这块了解即可】
代码：

```
    public static Class<?> forName(String name, boolean initialize,
                                   ClassLoader loader)
        throws ClassNotFoundException
    {
        Class<?> caller = null;
        SecurityManager sm = System.getSecurityManager();
        if (sm != null) {
            // Reflective call to get caller class is only needed if a security manager
            // is present.  Avoid the overhead of making this call otherwise.
            //获取调用此forName方法的类的Class对象A
            caller = Reflection.getCallerClass();
            if (sun.misc.VM.isSystemDomainLoader(loader)) {
	            //获取A的类加载器
                ClassLoader ccl = ClassLoader.getClassLoader(caller);
                //安全检查
                if (!sun.misc.VM.isSystemDomainLoader(ccl)) {
                    sm.checkPermission(
                        SecurityConstants.GET_CLASSLOADER_PERMISSION);
                }
            }
        }
        //name：要被加载的|initialize：是否初始化|loader：指定的类加载器（自定义加载器此处是系统类加载器）|caller调用者的Class对象
        return forName0(name, initialize, loader, caller);
    }
	//forName0是一个本地方法
    /** Called after security check for system loader access checks have been made. */
    private static native Class<?> forName0(String name, boolean initialize,
                                            ClassLoader loader,
                                            Class<?> caller)
        throws ClassNotFoundException;
```
另外和只有一个参数的forName的区别：

```
   public static Class<?> forName(String className)
                throws ClassNotFoundException {
        Class<?> caller = Reflection.getCallerClass();
        // className：要加载的Class名字 | 是否初始化：此处需要初始化 |调用者的类加载器 | 调用者的Class对象
        return forName0(className, true, ClassLoader.getClassLoader(caller), caller);
    }
```
