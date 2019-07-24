---
title: spring_boot_cloud(5)SpringApplication源码分析与作用详解
date: 2019-06-30 16:54:32
tags: [SpringBootApplication,源码解析]
categories: spring_boot_cloud
---


### SpringApplication的初始化流程源码分析

#### SpringApplication入口
```
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class,args);
    }
}
```
我们的spring boot的启动都是从这个main方法开始的，，那么这个方法的主要的一行代码就是SpringApplication.run(MyApplication.class,args);我们本次要看一下他的执行流程。
run方法点进去之后：
```
public static ConfigurableApplicationContext run(Class<?> primarySource, String... args) {
  return run(new Class<?>[] { primarySource }, args);
}
```
ConfigurableApplicationContext是一个即使不是所有应用上下文 也是大部分的应用上下文实现的spi接口，提供了一些设施用来配置应用上下文，配置和生命周期方法封装在这里，避免他们出现在应用上下文的客户端代码里边，ConfigurableApplicationContext罗列的方法用来启动和关闭的代码里边。
run方法的入参是一个Class类型的参数，然后掉了另一个重载的run方法，这个run方法的第一个入参是Class类型的数组，第二个参数是传进来的args，这种变成风格很常见，一般一个方法是通用的，接受数组类型的，一个方法是只接受一个参数的，一个参数的方法是接受数组参数方法的特例，那么接受一个参数的方法会调用通用的那个方法。跟进去：
```
public static ConfigurableApplicationContext run(Class<?>[] primarySources,
    String[] args) {
  return new SpringApplication(primarySources).run(args);
}
```
这个方法new 了一个SpringApplication的实例执行了SpringApplication实例的run方法，返回值就是SpringApplication的run方法的返回值。
接着往里走：
```
public SpringApplication(Class<?>... primarySources) {
  this(null, primarySources);
}
```

#### SpringApplication构造器的主流程
最终来到了这个构造器：
```
/**
Create a new SpringApplication instance. The application context will load beans from the specified primary sources (see class-level documentation for details. The instance can be customized before calling run(String...).
创建一个应用上下文，应用 上下文会从指定的primarySources加载，这个实例可以在调用run方法之前进行一个定制化。
*/
public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
  this.resourceLoader = resourceLoader;//为null
  Assert.notNull(primarySources, "PrimarySources must not be null");
  this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));//com.twodragonlake.boot.MyApplication.class
  this.webApplicationType = WebApplicationType.deduceFromClasspath();
  setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
  setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
  this.mainApplicationClass = deduceMainApplicationClass();
}
```

####  ResourceLoader
  ResourceLoader：用来加载资源的策略接口（class path，类路劲，文件资源），org.springframework.context.ApplicationContext被要求提供这个功能，再加上org.springframework.core.io.support.ResourcePatternResolver这样一个支持。DefaultResourceLoader是一个独立的实现，他被用在ApplicationContext之外，也是被资源编辑器ResourceEditor所使用。
  ResourceLoader结构：
  ```
  ResourceLoader
    //加载资源都离不开类加载器
    getClassLoader
    getResource
    CLASSPATH_URL_PREFIX
  ```

#### WebApplicationType探测应用类型逻辑
  this.webApplicationType = WebApplicationType.deduceFromClasspath();这一行是确定应用类型，进到枚举WebApplicationType看一下:
```
public enum WebApplicationType {

  	/**
  	 * The application should not run as a web application and should not start an
  	 * embedded web server.
  	 */
     什么类型也不是
  	NONE,

  	/**
  	 * The application should run as a servlet-based web application and should start an
  	 * embedded servlet web server.
  	 */
     servlet应用类型
  	SERVLET,

  	/**
  	 * The application should run as a reactive web application and should start an
  	 * embedded reactive web server.
  	 */
     反应式应用类型
  	REACTIVE;


    	private static final String[] SERVLET_INDICATOR_CLASSES = { "javax.servlet.Servlet",
    			"org.springframework.web.context.ConfigurableWebApplicationContext" };

    	private static final String WEBMVC_INDICATOR_CLASS = "org.springframework."
    			+ "web.servlet.DispatcherServlet";

    	private static final String WEBFLUX_INDICATOR_CLASS = "org."
    			+ "springframework.web.reactive.DispatcherHandler";

    	private static final String JERSEY_INDICATOR_CLASS = "org.glassfish.jersey.servlet.ServletContainer";

    	private static final String SERVLET_APPLICATION_CONTEXT_CLASS = "org.springframework.web.context.WebApplicationContext";

    	private static final String REACTIVE_APPLICATION_CONTEXT_CLASS = "org.springframework.boot.web.reactive.context.ReactiveWebApplicationContext";


    //推断应用类型
    	static WebApplicationType deduceFromClasspath() {
        //反应式应用的推荐条件
    		if (ClassUtils.isPresent(WEBFLUX_INDICATOR_CLASS, null)
    				&& !ClassUtils.isPresent(WEBMVC_INDICATOR_CLASS, null)
    				&& !ClassUtils.isPresent(JERSEY_INDICATOR_CLASS, null)) {
    			return WebApplicationType.REACTIVE;
    		}
        //SERVLET_INDICATOR_CLASSES里边的都没有出现就是什么类型都不是的应用
        //因为工程里边引入了tomcat的jar包所有javax.servlet.Servlet肯定存在classpath下，而ConfigurableWebApplicationContext
        //是spring里边的类，也会出现在classpath里边。
    		for (String className : SERVLET_INDICATOR_CLASSES) {
    			if (!ClassUtils.isPresent(className, null)) {
    				return WebApplicationType.NONE;
    			}
    		}
        //其他的都是servlet应用[当前的demo会返回这个值，即，当前demo是一个servlet类型的应用]
    		return WebApplicationType.SERVLET;
    	}
}
```

#### ApplicationContextInitializer的加载和初始化逻辑

##### ApplicationContextInitializer介绍
接下来是 setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
getSpringFactoriesInstances的作用就是加载实现了ApplicationContextInitializer接口的这些工厂的实例。
首先看一下getSpringFactoriesInstances的参数ApplicationContextInitializer.class
看一下doc:
```
Callback interface for initializing a Spring ConfigurableApplicationContext prior to being refreshed.
Typically used within web applications that require some programmatic initialization of the application context. For example, registering property sources or activating profiles against the context's environment. See ContextLoader and FrameworkServlet support for declaring a "contextInitializerClasses" context-param and init-param, respectively.
ApplicationContextInitializer processors are encouraged to detect whether Spring's Ordered interface has been implemented or if the @Order annotation is present and to sort instances accordingly if so prior to invocation.
```
在bean刷新之前初始化 Spring ConfigurableApplicationContext的一个回调接口。
通常用于在web应用当中，需要编程的方式初始化应用的上下文。
比如我们注册 一个属性源，激活profile这对于上下文的环境。
ApplicationContextInitializer被鼓励探测spring排序接口是不是被实现或者`@Order`注解是不是存在，存在的话用来排序。
ApplicationContextInitializer主要用来完成初始化工作。

##### 加载所有工厂并缓存
那为什么getSpringFactoriesInstances方法要传入初始化器呢，跟进去看一下：
```
private <T> Collection<T> getSpringFactoriesInstances(Class<T> type) {
  return getSpringFactoriesInstances(type, new Class<?>[] {});
}

private <T> Collection<T> getSpringFactoriesInstances(Class<T> type,
    Class<?>[] parameterTypes, Object... arg s) {
  ClassLoader classLoader = getClassLoader();//应用类加载器
  // Use names and ensure unique to protect against duplicates
  Set<String> names = new LinkedHashSet<>(
      SpringFactoriesLoader.loadFactoryNames(type, classLoader));
  List<T> instances = createSpringFactoriesInstances(type, parameterTypes,
      classLoader, args, names);
  AnnotationAwareOrderComparator.sort(instances);
  return instances;
}
```
getClassLoader()方法是获取类的加载器：
```
//如果resourceLoader不是空，就返回resourceLoader的类加载器，此处resourceLoader是空的，if语句不会执行
public ClassLoader getClassLoader() {
  if (this.resourceLoader != null) {
    return this.resourceLoader.getClassLoader();
  }
  return ClassUtils.getDefaultClassLoader();
}
```
然后看一下ClassUtils.getDefaultClassLoader()：
```
逻辑很简单，默认返回线程上下文类加载器
public static ClassLoader getDefaultClassLoader() {
  ClassLoader cl = null;
  try {
    cl = Thread.currentThread().getContextClassLoader();
  }
  catch (Throwable ex) {
    // Cannot access thread context ClassLoader - falling back...
  }
  //如果线程上下文类加载器是空的，就返回ClassUtils的类加载器
  if (cl == null) {
    // No thread context class loader -> use class loader of this class.
    cl = ClassUtils.class.getClassLoader();
    //如果ClassUtils的类加载器也是空的就返回系统类加载器
    if (cl == null) {
      // getClassLoader() returning null indicates the bootstrap ClassLoader
      try {
        cl = ClassLoader.getSystemClassLoader();
      }
      catch (Throwable ex) {
        // Cannot access system ClassLoader - oh well, maybe the caller can live with null...
      }
    }
  }
  return cl;
}

```
我们的程序返回的是系统类加载器(线程上下文类加载器中的)
Set<String> names = new LinkedHashSet<>(SpringFactoriesLoader.loadFactoryNames(type, classLoader));
type是ApplicationContextInitializer.class，
这里SpringFactoriesLoader加载了工厂的名字：
SpringFactoriesLoader解析:
doc：
General purpose factory loading mechanism for internal use within the framework.
SpringFactoriesLoader loads and instantiates factories of a given type from "META-INF/spring.factories" files which may be present in multiple JAR files in the classpath. The spring.factories file must be in Properties format, where the key is the fully qualified name of the interface or abstract class, and the value is a comma-separated list of implementation class names. For example:
example.MyService=example.MyServiceImpl1,example.MyServiceImpl2
where example.MyService is the name of the interface, and MyServiceImpl1 and MyServiceImpl2 are two implementations.
在框架内部所使用的的一种通用工厂加载机制。
SpringFactoriesLoader从文件 "META-INF/spring.factories" 里边指定的类型工厂进行加载和实例化。
这个文件可能位于classpath下多个jar文件当中。spring.factories文件必须要是Properties格式的，其中key就是接口或者抽象类的完全限定的名字，值是逗号分隔的实现类名字的列表。举例：
example.MyService=example.MyServiceImpl1,example.MyServiceImpl2
其中example.MyService是接口的名字，example.MyServiceImpl1,example.MyServiceImpl2是2个实现类。


```
public static List<String> loadFactoryNames(Class<?> factoryClass, @Nullable ClassLoader classLoader) {
  String factoryClassName = factoryClass.getName();//ApplicationContextInitializer.class的全限定名
  return loadSpringFactories(classLoader).getOrDefault(factoryClassName, Collections.emptyList());
}

```
######  factoryClass.getName扩展
 factoryClass.getName()：
这里做一下扩展结合之前jvm字节码的章节，我们看一下这个方法的doc：
![getName.png](getName.png)
返回调用getName的class对象的实体（类，接口，数组，原生类型，或者void）的名字。并且作为字符串的形式返回
如果class对象代表的是引用类新型，并且不是数组类型，就会返回这个类的二进制的名字，名字是java 语言规范规定的格式返回的。
如果class的对象代表的是原生类型或者是void，调用getName返回的名称就是原生类型的名字或者void。
如果class对象表示的是数组类，那么返回的名字的内部形式就会包含元素类型的名字，其中"["代表的是数组的维度数量。

接下来回到主流程，进入到loadSpringFactories()：
```
//进入loadSpringFactories
private static Map<String, List<String>> loadSpringFactories(@Nullable ClassLoader classLoader) {
  //cache的结构：Map<ClassLoader, MultiValueMap<String, String>>
  MultiValueMap<String, String> result = cache.get(classLoader);
  //缓存加载出来的是null，继续往下走
  if (result != null) {
    return result;
  }

  try {
    /**
    	 * The location to look for factories.
    	 * <p>Can be present in multiple JAR files.
       寻找工厂的位置，可以存在于多个jar文件当中
       public static final String FACTORIES_RESOURCE_LOCATION = "META-INF/spring.factories";
    */
    Enumeration<URL> urls = (classLoader != null ?
        classLoader.getResources(FACTORIES_RESOURCE_LOCATION) :
        ClassLoader.getSystemResources(FACTORIES_RESOURCE_LOCATION));
    result = new LinkedMultiValueMap<>();
    while (urls.hasMoreElements()) {
      //
      URL url = urls.nextElement();
      UrlResource resource = new UrlResource(url);
      Properties properties = PropertiesLoaderUtils.loadProperties(resource);
      for (Map.Entry<?, ?> entry : properties.entrySet()) {
        String factoryClassName = ((String) entry.getKey()).trim();
        for (String factoryName : StringUtils.commaDelimitedListToStringArray((String) entry.getValue())) {
          result.add(factoryClassName, factoryName.trim());
        }
      }
    }
    cache.put(classLoader, result);
    return result;
  }
  catch (IOException ex) {
    throw new IllegalArgumentException("Unable to load factories from location [" +
        FACTORIES_RESOURCE_LOCATION + "]", ex);
  }
}
```
###### classLoader.getResources扩展：
classLoader.getResources(FACTORIES_RESOURCE_LOCATION) 解析：
```
根据名称得到资源（图片、音频、文本等），这些资源可以被class字节码访问，并且和字节码在位置上是独立存在的。
name对应的资源路径是被"/"分隔的。
返回值是一个枚举，如果资源找不到，枚举就是空的，如果资源没法访问，那么资源就不会出现在枚举里边。
CompoundEnumeration是sun.misc包下的枚举的实现，它的结构如下：
public class CompoundEnumeration<E> implements Enumeration<E> {
    private Enumeration<E>[] enums;
    private int index = 0;
}    
从代码结构来看它实现了Enumeration，就有Enumeration的一些特性，同时它有一个Enumeration数组，意味着它下面还可以存在Enumeration
是一个多级的结构。
public Enumeration<URL> getResources(String name) throws IOException {
    @SuppressWarnings("unchecked")
    Enumeration<URL>[] tmp = (Enumeration<URL>[]) new Enumeration<?>[2];
    if (parent != null) {
        tmp[0] = parent.getResources(name);
    } else {
        tmp[0] = getBootstrapResources(name);
    }
    tmp[1] = findResources(name);

    return new CompoundEnumeration<>(tmp);
}
```
##### 加载三个spring jar的工厂
我们debug可以看到url的位置
!(url.png)[url.png]
jar:file:/D:/gradlerepo/caches/modules-2/files-2.1/org.springframework.boot/spring-boot-autoconfigure/2.1.3.RELEASE/58e07f69638a3ca13dffe8a2b68d284af376d105/spring-boot-autoconfigure-2.1.3.RELEASE.jar!/META-INF/spring.factories
![url.png](url.png)
然后打开这个spring.factories
![url1.png](url1.png)
里边有七个主要的类(接口)：
- org.springframework.context.ApplicationContextInitializer
- org.springframework.context.ApplicationListener
- org.springframework.boot.autoconfigure.AutoConfigurationImportListener
- org.springframework.boot.autoconfigure.AutoConfigurationImportFilter
- org.springframework.boot.autoconfigure.EnableAutoConfiguration
- org.springframework.boot.diagnostics.FailureAnalyzer
- org.springframework.boot.autoconfigure.template.TemplateAvailabilityProvider
接下往下走就会看到这七个接口：
![url2.png](url2.png)
最后loadSpringFactories返回的result是一个map，key是接口的名称，value是接口的实现类：
比如刚才的spring.factories里边 org.springframework.boot.autoconfigure.EnableAutoConfiguration有118个实现，那么map的key就是 org.springframework.boot.autoconfigure.EnableAutoConfiguration，value是她的118个实现。

然后再看一下第二个工厂的jar位置：
jar:file:/D:/gradlerepo/caches/modules-2/files-2.1/org.springframework.boot/spring-boot/2.1.3.RELEASE/92bb92cd73212cefc1e5112e3bbf1f31c154c3fd/spring-boot-2.1.3.RELEASE.jar!/META-INF/spring.factories
看一下它里边的结构：
![url2.png](url2.png)
主要接口如下：
- org.springframework.boot.diagnostics.FailureAnalysisReporter
- org.springframework.boot.diagnostics.FailureAnalyzer
- org.springframework.boot.env.EnvironmentPostProcessor
- org.springframework.boot.env.PropertySourceLoader
- org.springframework.boot.SpringApplicationRunListener
- org.springframework.boot.SpringBootExceptionReporter
- org.springframework.context.ApplicationContextInitializer
- org.springframework.context.ApplicationListener

我们看到有一个org.springframework.context.ApplicationListener但是在spring-boot-autoconfigure-2.1.3.RELEASE.jar里边也有一个org.springframework.context.ApplicationListener，这个时候就能看到MultiValueMap<String, String>所起的作用，相同key的value会进行合并。

继续放下看下一个工厂jar的位置：
jar:file:/D:/gradlerepo/caches/modules-2/files-2.1/org.springframework/spring-beans/5.1.5.RELEASE/58b10c61f6bf2362909d884813c4049b657735f5/spring-beans-5.1.5.RELEASE.jar!/META-INF/spring.factories

然后打开对应的spring.factories文件：
这里边只有一行：
```
org.springframework.beans.BeanInfoFactory=org.springframework.beans.ExtendedBeanInfoFactory
```

##### 所有工厂的合并结果
由此我们可以得出结论spring boot启动的时候会初始化三个jar包的工厂。
得到的result是三个jar包所有的数据进行了合并，合并之后一共有13个工厂接口：
```
0 = {LinkedHashMap$Entry@1746} "org.springframework.boot.autoconfigure.AutoConfigurationImportFilter" -> " size = 3"
1 = {LinkedHashMap$Entry@1747} "org.springframework.boot.diagnostics.FailureAnalyzer" -> " size = 17"
2 = {LinkedHashMap$Entry@1748} "org.springframework.boot.autoconfigure.AutoConfigurationImportListener" -> " size = 1"
3 = {LinkedHashMap$Entry@1749} "org.springframework.context.ApplicationContextInitializer" -> " size = 6"
4 = {LinkedHashMap$Entry@1750} "org.springframework.boot.autoconfigure.template.TemplateAvailabilityProvider" -> " size = 5"
5 = {LinkedHashMap$Entry@1751} "org.springframework.context.ApplicationListener" -> " size = 10"
6 = {LinkedHashMap$Entry@1752} "org.springframework.boot.autoconfigure.EnableAutoConfiguration" -> " size = 118"
7 = {LinkedHashMap$Entry@1753} "org.springframework.boot.env.EnvironmentPostProcessor" -> " size = 3"
8 = {LinkedHashMap$Entry@1754} "org.springframework.boot.SpringApplicationRunListener" -> " size = 1"
9 = {LinkedHashMap$Entry@1755} "org.springframework.boot.env.PropertySourceLoader" -> " size = 2"
10 = {LinkedHashMap$Entry@1756} "org.springframework.boot.diagnostics.FailureAnalysisReporter" -> " size = 1"
11 = {LinkedHashMap$Entry@1757} "org.springframework.boot.SpringBootExceptionReporter" -> " size = 1"
12 = {LinkedHashMap$Entry@1758} "org.springframework.beans.BeanInfoFactory" -> " size = 1"
```

#### 得到ApplicationContextInitializer的所有实现
loadSpringFactories(classLoader)的结果就是上边的13个实例，然后loadSpringFactories(classLoader).getOrDefault(factoryClassName, Collections.emptyList());
里边getOrDefault方法的参数是factoryClassName是interface org.springframework.context.ApplicationContextInitializer，
意思是从13个接口里边找到ApplicationContextInitializer这个接口，是能找到的，一共有6个ApplicationContextInitializer的实现类:

```
0 = "org.springframework.boot.autoconfigure.SharedMetadataReaderFactoryContextInitializer"
1 = "org.springframework.boot.autoconfigure.logging.ConditionEvaluationReportLoggingListener"
2 = "org.springframework.boot.context.ConfigurationWarningsApplicationContextInitializer"
3 = "org.springframework.boot.context.ContextIdApplicationContextInitializer"
4 = "org.springframework.boot.context.config.DelegatingApplicationContextInitializer"
5 = "org.springframework.boot.web.context.ServerPortInfoApplicationContextInitializer"
```

#### 创建ApplicationContextInitializer所有实现的实例
接下来的逻辑是：
List<T> instances = createSpringFactoriesInstances(type, parameterTypes,classLoader, args, names);
type：interface org.springframework.context.ApplicationContextInitializer
parameterTypes：是空数组。
classLoader：应用类加载器
args：空数组
names：即我们上边得到的有6个对象的数组。
逻辑如下：
```
private <T> List<T> createSpringFactoriesInstances(Class<T> type,  Class<?>[] parameterTypes,
  ClassLoader classLoader,Object[] args,Set<String> names) {
  List<T> instances = new ArrayList<>(names.size());
  for (String name : names) {
    try {
      //先从ClassUtils内部的缓存加载，如果缓存不存在就会调用Class.forName(name, false, classLoader)这种原始的方式加载。
      Class<?> instanceClass = ClassUtils.forName(name, classLoader);
      Assert.isAssignable(type, instanceClass);
      //得到构造器
      Constructor<?> constructor = instanceClass
          .getDeclaredConstructor(parameterTypes);
      //创建实例，instantiateClass方法会尝试将不可访问（非public的）的改为可访问的，而且支持kotlin的类
      T instance = (T) BeanUtils.instantiateClass(constructor, args);
      instances.add(instance);
    }
    catch (Throwable ex) {
      throw new IllegalArgumentException(
          "Cannot instantiate " + type + " : " + name, ex);
    }
  }
  return instances;
}
```
#####  BeanUtils.instantiateClass扩展
 BeanUtils.instantiateClass：
 ```
 public static <T> T instantiateClass(Constructor<T> ctor, Object... args) throws BeanInstantiationException {
     Assert.notNull(ctor, "Constructor must not be null");

     try {
        /**
         ReflectionUtils.makeAccessible实现，即如果不可访问的改为可访问的。
        public static void makeAccessible(Constructor<?> ctor) {
          if ((!Modifier.isPublic(ctor.getModifiers()) ||
              !Modifier.isPublic(ctor.getDeclaringClass().getModifiers())) && !ctor.isAccessible()) {
            ctor.setAccessible(true);
          }
        }
        **/
         ReflectionUtils.makeAccessible(ctor);
         //对java和kotlin类型的进行生成。
         return KotlinDetector.isKotlinReflectPresent() && KotlinDetector.isKotlinType(ctor.getDeclaringClass()) ? BeanUtils.KotlinDelegate.instantiateClass(ctor, args) : ctor.newInstance(args);
     } catch (InstantiationException var3) {
         throw new BeanInstantiationException(ctor, "Is it an abstract class?", var3);
     } catch (IllegalAccessException var4) {
         throw new BeanInstantiationException(ctor, "Is the constructor accessible?", var4);
     } catch (IllegalArgumentException var5) {
         throw new BeanInstantiationException(ctor, "Illegal arguments for constructor", var5);
     } catch (InvocationTargetException var6) {
         throw new BeanInstantiationException(ctor, "Constructor threw exception", var6.getTargetException());
     }
 }
```
创建出来的对象：
![instance.png](instance.png)

#### setInitializers和排序
回到getSpringFactoriesInstances，返回的map类型的result放到LinkedHashSet里边：
Set<String> names = new LinkedHashSet<>(SpringFactoriesLoader.loadFactoryNames(type, classLoader));
接下来是  List<T> instances = createSpringFactoriesInstances(type, parameterTypes,classLoader, args, names);
创建工厂的实例。
AnnotationAwareOrderComparator.sort(instances);是进行排序，然后这个方法就返回了。

回到了SpringApplication的构造器，执行到了：
setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
setInitializers的操作：
```
public void setInitializers(
    Collection<? extends ApplicationContextInitializer<?>> initializers) {
  this.initializers = new ArrayList<>();
  this.initializers.addAll(initializers);
}
```
只是添加到集合当中。

注意：【setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));】和
【setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));】的执行流程是一模一样的。
#### ApplicationListener
org.springframework.context @FunctionalInterface
public interface ApplicationListener<E extends ApplicationEvent>
extends EventListener
Interface to be implemented by application event listeners. Based on the standard java.util.EventListener interface for the Observer design pattern.
As of Spring 3.0, an ApplicationListener can generically declare the event type that it is interested in. When registered with a Spring ApplicationContext, events will be filtered accordingly, with the listener getting invoked for matching event objects only.
一个用来被应用事件监听实现的接口，基于标准的java.util.EventListener接口，是一种观察者模式。
在Spring 3.0版本，一个应用监听器可以声明一个它感兴趣的事件类型，当注册到spring的应用上下文里边，事件将相应的过滤，当注册的事件发生的时候，监听器就会被触发。

```
ApplicationListener是一个函数式接口
@FunctionalInterface
public interface ApplicationListener<E extends ApplicationEvent> extends EventListener {

	/**
	 * Handle an application event.
	 * @param event the event to respond to
	 */
	void onApplicationEvent(E event);

}
```
它最终初始化的所有监听器：
```
0 = {BackgroundPreinitializer@1931}
1 = {ClearCachesApplicationListener@1966}
2 = {ParentContextCloserApplicationListener@1967}
3 = {FileEncodingApplicationListener@1968}
4 = {AnsiOutputApplicationListener@1969}
5 = {ConfigFileApplicationListener@1970}
6 = {DelegatingApplicationListener@1971}
7 = {ClasspathLoggingApplicationListener@1972}
8 = {LoggingApplicationListener@1973}
9 = {LiquibaseServiceLocatorApplicationListener@1974}
```

#### 主应用类获取deduceMainApplicationClass
SpringApplication的SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) 方法最后一行代码：
```
this.mainApplicationClass = deduceMainApplicationClass();
```
即获取主应用类的逻辑，我们进去看一下：
```
private Class<?> deduceMainApplicationClass() {
  try {
    StackTraceElement[] stackTrace = new RuntimeException().getStackTrace();
    for (StackTraceElement stackTraceElement : stackTrace) {
      if ("main".equals(stackTraceElement.getMethodName())) {
        return Class.forName(stackTraceElement.getClassName());
      }
    }
  }
  catch (ClassNotFoundException ex) {
    // Swallow and continue
  }
  return null;
```
这种获取主应用类的凡是非常讨巧，首先new一个运行时异常，同时得到它的堆栈信息，然后遍历堆栈信息，当某一条的堆栈信息调用的方式是main方法的时候，得到main方法所在的类就是主应用类。

### 小结
到目前为止SpringApplication的【public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources)】方法已经分析完毕，返回到上一层的逻辑：
SpringApplication(primarySources).run(args);
接下来会分析run方法的执行逻辑，，run方法逻辑分析完毕整个spring boot的启动流程也就完毕了。


### SpringApplication的run方法源码分析

run方法逻辑：
```
/**
运行spring应用，创建并且刷新一个新的ApplicationContext
args：main方法的参数
*/
public ConfigurableApplicationContext run(String... args) {
  //计时器
  StopWatch stopWatch = new StopWatch();
  //记录开始时间
  stopWatch.start();
  //配置上下文
  ConfigurableApplicationContext context = null;
  //异常构造器集合
  Collection<SpringBootExceptionReporter> exceptionReporters = new ArrayList<>();
  //是一个服务器端应用
  configureHeadlessProperty();
  //加载所有SpringApplicationRunListener监听器
  SpringApplicationRunListeners listeners = getRunListeners(args);
  //启动所有监听器，发布Application启动事件。
  listeners.starting();
  try {
    //将参数封装为ApplicationArguments
    ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
    //环境的准备
    ConfigurableEnvironment environment = prepareEnvironment(listeners,applicationArguments);
    //配置忽略的bean信息
    configureIgnoreBeanInfo(environment);
    //打印banner
    Banner printedBanner = printBanner(environment);
    //根据应用类型实例化上下文
    context = createApplicationContext();
    //之前介绍过的，加载接口的所有实现，context是它的实现类构造器的参数，这里会加载出一个异常报告器
    exceptionReporters = getSpringFactoriesInstances(SpringBootExceptionReporter.class,
        new Class[] { ConfigurableApplicationContext.class }, context);
    //准备上下文
    prepareContext(context, environment, listeners, applicationArguments,printedBanner);
    refreshContext(context);
    afterRefresh(context, applicationArguments);
    stopWatch.stop();
    if (this.logStartupInfo) {
      new StartupInfoLogger(this.mainApplicationClass).logStarted(getApplicationLog(), stopWatch);
    }
    listeners.started(context);
    callRunners(context, applicationArguments);
  }
  catch (Throwable ex) {
    handleRunFailure(context, ex, exceptionReporters, listeners);
    throw new IllegalStateException(ex);
  }

  try {
    listeners.running(context);
  }
  catch (Throwable ex) {
    handleRunFailure(context, ex, exceptionReporters, null);
    throw new IllegalStateException(ex);
  }
  return context;
}
```

#### StopWatch
看一下它的doc
Simple stop watch, allowing for timing of a number of tasks, exposing total running time and running time for each named task.
Conceals use of System.currentTimeMillis(), improving the readability of application code and reducing the likelihood of calculation errors.
Note that this object is not designed to be thread-safe and does not use synchronization.
This class is normally used to verify performance during proof-of-concepts and in development, rather than as part of production applications.
Since:
May 2, 2001

这个类的作者是Rod Johnson在20015月2号写的，时间飞逝，现在已经是2019年了，18年过去了，我也写了快5年的代码了，希望每个人技术爱好者能够坚持自己的初衷，也希望你们早日找到女朋友，闲言少叙看一下StopWatch的介绍。

一个简单的计数器，它支持一些列任务的计时工作，公开总的运行时间，还有具名任务的时间。
可以不去让我们使用 System.currentTimeMillis()得到系统时间，目的是为了应用代码的可读性以及可能的计算错误。

注意和这个对象没有设计为线程安全的，不能用于同步。
这个类通常用于在 proof-of-concepts阶段验证性能，并不是产品应用的一部分。
这里就用于统计我们应用的启动时间。

它的内部有一个private final List<TaskInfo> taskList = new LinkedList<>(); 因为可以用于多个任务的统计工作。

#### ConfigurableApplicationContext

##### ApplicationContext
ConfigurableApplicationContext继承了ApplicationContext，我们现在看到的应用启动过程都是围绕ApplicationContext进行的，有必要看一下ApplicationContext的doc：

org.springframework.context public interface ApplicationContext
extends EnvironmentCapable, ListableBeanFactory, HierarchicalBeanFactory, MessageSource, ApplicationEventPublisher, ResourcePatternResolver

Central interface to provide configuration for an application. This is read-only while the application is running, but may be reloaded if the implementation supports this.
An ApplicationContext provides:
- Bean factory methods for accessing application components. Inherited from ListableBeanFactory.
- The ability to load file resources in a generic fashion. Inherited from the org.springframework.core.io.ResourceLoader interface.
- The ability to publish events to registered listeners. Inherited from the ApplicationEventPublisher interface.
- The ability to resolve messages, supporting internationalization. Inherited from the MessageSource interface.
- Inheritance from a parent context. Definitions in a descendant context will always take priority. This means, for example, that a single parent context can be used by an entire web application, while each servlet has its own child context that is independent of that of any other servlet.

In addition to standard org.springframework.beans.factory.BeanFactory lifecycle capabilities, ApplicationContext implementations detect and invoke ApplicationContextAware beans as well as ResourceLoaderAware, ApplicationEventPublisherAware and MessageSourceAware beans.
See Also:
ConfigurableApplicationContext,
org.springframework.beans.factory.BeanFactory,
 org.springframework.core.io.ResourceLoader

一个用于提供应用配置的中心接口，当应用运行的时候是只读的，但是如果他的实现支持刷新，它也是会被刷新的。
一个应用上下文提供如下：
- bean工厂的方法，用于访问应用的组件，来自于ListableBeanFactory。
- 以一种通用的风格加载文件资源的能力，从org.springframework.core.io.ResourceLoader接口沿袭下来的能力
- 向注册的监听器发布事件的能力，来自于ApplicationEventPublisher接口
- 解析消息的能力，支持国际化，来自于MessageSource接口
- 可以从父的上下文继承能力，定义的后代的上下文拥有更高的优先级，这意味着，比如，一个单例的父上下文，可以被整个web应用使用，这样每个servlet的和其他的都是独立的。

#### ConfigurableApplicationContext
org.springframework.context public interface ConfigurableApplicationContext
extends ApplicationContext, Lifecycle, Closeable
SPI interface to be implemented by most if not all application contexts. Provides facilities to configure an application context in addition to the application context client methods in the ApplicationContext interface.
Configuration and lifecycle methods are encapsulated here to avoid making them obvious to ApplicationContext client code. The present methods should only be used by startup and shutdown code.

被大部分，但不是全部的应用上下文实现的spi接口，在ApplicationContext接口的基础上通过附加的应用上下文客户端方法的形式提供了一些配置应用上下文的基础设施。
配置与生命周期方法被封装在这里，以避免显式的公开给客户端代码，只能被启动和关闭代码使用。

#### SpringBootExceptionReporter
SpringBootExceptionReporter是一个函数式接口。
```
/**
Callback interface used to support custom reporting of SpringApplication startup errors. reporters are loaded via the SpringFactoriesLoader and must declare a public constructor with a single ConfigurableApplicationContext parameter.
用来支持对于SpringApplication启动错误的自定义的报告的回调接口，reporters是通过SpringFactoriesLoader加载的，并且声明一个public的带有ConfigurableApplicationContext类型的参数的构造器。
*/
@FunctionalInterface
public interface SpringBootExceptionReporter {

	/**
	 * Report a startup failure to the user.
	 * @param failure the source failure 失败的源
	 * @return {@code true} if the failure was reported or {@code false} if default
	 * reporting should occur.
   报告一个启动失败，
	 */
	boolean reportException(Throwable failure);

}
```

它有唯一一个实现类FailureAnalyzers，构造器如下：
```
FailureAnalyzers(ConfigurableApplicationContext context, ClassLoader classLoader) {
  Assert.notNull(context, "Context must not be null");
  this.classLoader = (classLoader != null) ? classLoader : context.getClassLoader();
  this.analyzers = loadFailureAnalyzers(this.classLoader);
  prepareFailureAnalyzers(this.analyzers, context);
}
```

#### configureHeadlessProperty()方法
```
private static final String SYSTEM_PROPERTY_JAVA_AWT_HEADLESS = "java.awt.headless";
private boolean headless = true;
private void configureHeadlessProperty() {
  System.setProperty(SYSTEM_PROPERTY_JAVA_AWT_HEADLESS, System.getProperty(
      SYSTEM_PROPERTY_JAVA_AWT_HEADLESS, Boolean.toString(this.headless)));
}
```
SYSTEM_PROPERTY_JAVA_AWT_HEADLESS属性表达意图：这是一个服务器应用，没有显示器，没有键盘，没有鼠标的应用。

#### getRunListeners()方法以及监听器模式的经典应用
```
private SpringApplicationRunListeners getRunListeners(String[] args) {
  // SpringApplicationRunListener的构造器需要2个参数：SpringApplication和string数组。
  Class<?>[] types = new Class<?>[] { SpringApplication.class, String[].class };
  return new SpringApplicationRunListeners(logger, getSpringFactoriesInstances(
      SpringApplicationRunListener.class, types, this, args));
}
```

最后返回的是SpringApplicationRunListeners，SpringApplicationRunListeners里边有一个集合【	private final List<SpringApplicationRunListener> listeners;】
因为有必要看那一下 SpringApplicationRunListener的doc
##### SpringApplicationRunListener类
org.springframework.boot public interface SpringApplicationRunListener
Listener for the SpringApplication run method. SpringApplicationRunListeners are loaded via the SpringFactoriesLoader and should declare a public constructor that accepts a SpringApplication instance and a String[] of arguments. A new SpringApplicationRunListener instance will be created for each run.

针对SpringApplication run方法的监听器，SpringApplicationRunListeners通过SpringFactoriesLoader加载的，而且声明一个public的构造器，并且接受一个SpringApplication类型的参数，和一个string类型的数组(这也是为什么上面介绍的getRunListeners方法携带【Class<?>[] types = new Class<?>[] { SpringApplication.class, String[].class };】参数的原因，SpringApplicationRunListener实例将会针对于运行一个新的SpringApplication的run被创建。
主要是对run方法的监听的作用。观察者模式的体现。
由于是一个监听器，它的方法接口都体现了声明周期的,SpringApplicationRunListener方法如下：
```
//ApplicationContext已经被加载，但是它还没有被刷新之前调用
contextLoaded
//ApplicationContext已经创建和准备好了，但是资源还没有被加载
contextPrepared
//环境准备完毕，但是ApplicationContext被创建之前调用
environmentPrepared
//应用启动失败的时候被调用
failed
//run方法已经完成，应用上下文已经被刷新，并且CommandLineRunners和ApplicationRunner也已经被调用，running才会被调用。
running
//ApplicationContext已经被刷新，应用也已经启动，但是CommandLineRunners和ApplicationRunner还没有被调用
started
//run方法已开始启动的时候就会被调用，常常用于非常早期的工作。
starting
```

##### SpringApplicationRunListeners

代码结构：
```
private final List<SpringApplicationRunListener> listeners;

SpringApplicationRunListeners(Log log,
    Collection<? extends SpringApplicationRunListener> listeners) {
  this.log = log;
  this.listeners = new ArrayList<>(listeners);
}

其他的方法：
callFailedListener
contextLoaded
contextPrepared
environmentPrepared
failed
running
started
starting
```
这些方法和SpringApplicationRunListener方法是一致的，SpringApplicationRunListeners对所有的SpringApplicationRunListener统一管理。


##### EventPublishingRunListener

我们断点一下看一下有几个监听器：
![EventPublishingRunListener.png](EventPublishingRunListener.png)
通过断点可以看到只有一个EventPublishingRunListener，用于发布SpringApplicationEvent，通过ApplicationEventMulticaster在上下文发布之前发布事件。

EventPublishingRunListener构造器如下：
```
private final SpringApplication application;

private final String[] args;

private final SimpleApplicationEventMulticaster initialMulticaster;

public EventPublishingRunListener(SpringApplication application, String[] args) {
  this.application = application;
  this.args = args;
  this.initialMulticaster = new SimpleApplicationEventMulticaster();
  for (ApplicationListener<?> listener : application.getListeners()) {
    this.initialMulticaster.addApplicationListener(listener);
  }
}
```
###### SimpleApplicationEventMulticaster
构造器里边初始化了一个SimpleApplicationEventMulticaster，看一下介绍：
org.springframework.context.event public class SimpleApplicationEventMulticaster
extends AbstractApplicationEventMulticaster
Simple implementation of the ApplicationEventMulticaster interface.
Multicasts all events to all registered listeners, leaving it up to the listeners to ignore events that they are not interested in. Listeners will usually perform corresponding instanceof checks on the passed-in event object.
By default, all listeners are invoked in the calling thread. This allows the danger of a rogue listener blocking the entire application, but adds minimal overhead. Specify an alternative task executor to have listeners executed in different threads, for example from a thread pool.
ApplicationEventMulticaster接口的简单实现。
广播所有的事件给所有注册的监听器，对于不感兴趣的事件的过滤的决定权留给每个监听器自己去处理。监听器对于传递过来的时间对象通常会进行instanceof检查，默认情况，所有的监听器都会在被调用的线程去执行，这样就会存在一种危险，某一些监听器会阻塞整个的应用，但确是最小的成本，用一个替代的任务执行器拥有这个监听器，这样在不同的线程去执行，比如在线程池里边。

看一下EventPublishingRunListener的starting方法：
```
public void starting() {
  this.initialMulticaster.multicastEvent(
      new ApplicationStartingEvent(this.application, this.args));
}
```
这里冒出来一个ApplicationStartingEvent。
###### ApplicationStartingEvent
org.springframework.boot.context.event public class ApplicationStartingEvent
extends SpringApplicationEvent
Event published as early as conceivably possible as soon as a SpringApplication has been started - before the Environment or ApplicationContext is available, but after the ApplicationListeners have been registered. The source of the event is the SpringApplication itself, but beware of using its internal state too much at this early stage since it might be modified later in the lifecycle.

当spring应用已经启动的时候尽早的把事件发布出去，并且在Environment或者ApplicationContext可用之前，但是在ApplicationListeners已经被注册之后，时间的源是SpringApplication本身，但是请注意使用它的内部状态太多的话，会对后续的生命周期有一些影响。
它的父类是SpringApplicationEvent，父类的实现类有如下事件：
ApplicationContextInitializedEvent
ApplicationEnvironmentPreparedEvent
ApplicationFailedEvent
ApplicationPreparedEvent
ApplicationReadyEvent
ApplicationStartedEvent
ApplicationStartingEvent
诠释了Application的生命周期。

##### 小结
应用在启动的时候，会在某一些时间点发布一些事件，发对对象是所有注册的事件监听器，事件监听器自己决定是否感兴趣和处理这个事件，这是一种监听器设计模式的体现，监听器都有一个源，就是监听器的主题，源是Application本身，SpringApplicationRunListeners在不同的时间点发布不同的事件对象。


#### environment组件的重要作用详解
##### Environment doc解读
我们走到了【ConfigurableEnvironment environment = prepareEnvironment(listeners,applicationArguments);】这行代码，首先理解下ConfigurableEnvironment,它的父类是Environment，看下Environment的doc：

org.springframework.core.env
public interface Environment extends PropertyResolver

Interface representing the environment in which the current application is running. Models two key aspects of the application environment: profiles and properties. Methods related to property access are exposed via the PropertyResolver superinterface.
A profile is a named, logical group of bean definitions to be registered with the container only if the given profile is active. Beans may be assigned to a profile whether defined in XML or via annotations; see the spring-beans 3.1 schema or the `@Profile` annotation for syntax details. The role of the Environment object with relation to profiles is in determining which profiles (if any) are currently active, and which profiles (if any) should be active by default.
Properties play an important role in almost all applications, and may originate from a variety of sources: properties files, JVM system properties, system environment variables, JNDI, servlet context parameters, ad-hoc Properties objects, Maps, and so on. The role of the environment object with relation to properties is to provide the user with a convenient service interface for configuring property sources and resolving properties from them.
Beans managed within an ApplicationContext may register to be EnvironmentAware or `@Inject` the Environment in order to query profile state or resolve properties directly.
In most cases, however, application-level beans should not need to interact with the Environment directly but instead may have to have ${...} property values replaced by a property placeholder configurer such as PropertySourcesPlaceholderConfigurer, which itself is EnvironmentAware and as of Spring 3.1 is registered by default when using <context:property-placeholder/>.
Configuration of the environment object must be done through the ConfigurableEnvironment interface, returned from all AbstractApplicationContext subclass getEnvironment() methods. See ConfigurableEnvironment Javadoc for usage examples demonstrating manipulation of property sources prior to application context refresh().

代表了一种当前应用正在运行的环境，有两个很重要应用环境的方面：prifile和properties,访问属性的方法通过PropertyResolver父接口提供。
profile是被具名的，逻辑的bean的分组，当给定的profile是活动的状态时，这些bean定义会被被注册到容器当中，bean无论是xml定义或者annotation的形式，bean会被关联一个profile，请看 spring-beans 3.1的schema了解Profile注解的语法详情，环境的角色用来决定它关联的profiles，那些profile当前是活动的，并且这些profiles默认情况下是活动的。
在大多数的应用中，Properties扮演了一个重要的角色，它可能来自各种各样的来源，比如属性文件，jvm的系统属性，系统环境变量，jndi，servlet山下文参数，及时变更的属性对象，map，等等，关联属性的environment对象的这种角色，为用户提供了方便的属性配置属性解析的接口服务。
ApplicationContext里边注册的这些bean可以是EnvironmentAware或者是 `@Inject`的，这些可以用来查询profile状态和属性解析。
在大多数的情况下，应用级别的bean不需要直接和Environment交互，但是可以用一种 ${...}这种形式的占位符配置器的方式去配置，比如PropertySourcesPlaceholderConfigurer，他自己本身就是环境组件，在Spring 3.1当中，通过使用<context:property-placeholder/>进行注册。
环境对象的配置必须通过ConfigurableEnvironment接口，从AbstractApplicationContext所有子类的getEnvironment方法返回。

##### ConfigurableEnvironment doc解读
接下来是ConfigurableEnvironment，也就是Environment的子类，看一下doc：
org.springframework.core.env public interface ConfigurableEnvironment extends Environment, ConfigurablePropertyResolver

Configuration interface to be implemented by most if not all Environment types. Provides facilities for setting active and default profiles and manipulating underlying property sources. Allows clients to set and validate required properties, customize the conversion service and more through the ConfigurablePropertyResolver superinterface.
Manipulating property sources
Property sources may be removed, reordered, or replaced; and additional property sources may be added using the MutablePropertySources instance returned from getPropertySources(). The following examples are against the StandardEnvironment implementation of ConfigurableEnvironment, but are generally applicable to any implementation, though particular default property sources may differ.
Example: adding a new property source with highest search priority
   ConfigurableEnvironment environment = new StandardEnvironment();
   MutablePropertySources propertySources = environment.getPropertySources();
   Map<String, String> myMap = new HashMap<>();
   myMap.put("xyz", "myValue");
   propertySources.addFirst(new MapPropertySource("MY_MAP", myMap));

Example: removing the default system properties property source
   MutablePropertySources propertySources = environment.getPropertySources();
   propertySources.remove(StandardEnvironment.SYSTEM_PROPERTIES_PROPERTY_SOURCE_NAME)

Example: mocking the system environment for testing purposes
   MutablePropertySources propertySources = environment.getPropertySources();
   MockPropertySource mockEnvVars = new MockPropertySource().withProperty("xyz", "myValue");
   propertySources.replace(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME, mockEnvVars);

When an Environment is being used by an ApplicationContext, it is important that any such PropertySource manipulations be performed before the context's refresh() method is called. This ensures that all property sources are available during the container bootstrap process, including use by property placeholder configurers.
一个不是被所有也是被大多数Environment类型所实现的配置接口，提供了设置活动的默认的profiles，以及操作底层的属性元的基础设施，允许客户端设置和验证所要求的属性，定制转换服务，都是通过ConfigurablePropertyResolver这样的一个父接口进行的。
如何操纵属性源？
属性源可以被删除，重排序也可以被替换，并且额外的属性来源可以通过MutablePropertySources进行添加，通过getPropertySources方法进行获取，接下来的举例针对于ConfigurableEnvironment的标准环境的实现，不过和特定的默认的属性源有点不同。
例子：添加了一个高搜索优先级的属性源：
```
ConfigurableEnvironment environment = new StandardEnvironment();
MutablePropertySources propertySources = environment.getPropertySources();
Map<String, String> myMap = new HashMap<>();
myMap.put("xyz", "myValue");
propertySources.addFirst(new MapPropertySource("MY_MAP", myMap));
```
举例：删除默认系统属性源：
```
MutablePropertySources propertySources = environment.getPropertySources();
propertySources.remove(StandardEnvironment.SYSTEM_PROPERTIES_PROPERTY_SOURCE_NAME)
```
举例：针对测试的目的模拟系统的环境：
```
MutablePropertySources propertySources = environment.getPropertySources();
MockPropertySource mockEnvVars = new MockPropertySource().withProperty("xyz", "myValue");
propertySources.replace(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME, mockEnvVars);
```
##### prepareEnvironment方法
它的逻辑如下：
```
private ConfigurableEnvironment prepareEnvironment(SpringApplicationRunListeners listeners,  ApplicationArguments applicationArguments) {
  // Create and configure the environment
  //存在环境就返回，不存在就创建
  ConfigurableEnvironment environment = getOrCreateEnvironment();
  configureEnvironment(environment, applicationArguments.getSourceArgs());
  listeners.environmentPrepared(environment);
  bindToSpringApplication(environment);
  if (!this.isCustomEnvironment) {
    environment = new EnvironmentConverter(getClassLoader())
        .convertEnvironmentIfNecessary(environment, deduceEnvironmentClass());
  }
  ConfigurationPropertySources.attach(environment);
  return environment;
}
```

###### getOrCreateEnvironment()方法
```
private ConfigurableEnvironment getOrCreateEnvironment() {
  //环境存在就返回
  if (this.environment != null) {
    return this.environment;
  }
  //根据应用类型返回对应应用类型的环境
  switch (this.webApplicationType) {
  case SERVLET:
    return new StandardServletEnvironment();
  case REACTIVE:
    return new StandardReactiveWebEnvironment();
  default:
    return new StandardEnvironment();
  }
}
```
###### configureEnvironment()方法
```
protected void configureEnvironment(ConfigurableEnvironment environment,
    String[] args) {
  if (this.addConversionService) {
    ConversionService conversionService = ApplicationConversionService
        .getSharedInstance();
    environment.setConversionService(
        (ConfigurableConversionService) conversionService);
  }
  configurePropertySources(environment, args);
  configureProfiles(environment, args);
}
```
ConversionService:一个用来进行类型转换的服务接口，装换系统的入口点，调用convert实现线程安全的转换。
ApplicationConversionService.getSharedInstance();用的单利模式，而且是线程安全的，这是经典的单利模式的使用，懒汉模式，注意配合volatile关键字。
```
private static volatile ApplicationConversionService sharedInstance;
public static ConversionService getSharedInstance() {
  ApplicationConversionService sharedInstance = ApplicationConversionService.sharedInstance;
  if (sharedInstance == null) {
    synchronized (ApplicationConversionService.class) {
      sharedInstance = ApplicationConversionService.sharedInstance;
      if (sharedInstance == null) {
        sharedInstance = new ApplicationConversionService();
        ApplicationConversionService.sharedInstance = sharedInstance;
      }
    }
  }
  return sharedInstance;
}
```

【configurePropertySources(environment, args);】
添加，移除，重排序属性源
```
protected void configurePropertySources(ConfigurableEnvironment environment,
    String[] args) {
  MutablePropertySources sources = environment.getPropertySources();
  if (this.defaultProperties != null && !this.defaultProperties.isEmpty()) {
    sources.addLast(
        new MapPropertySource("defaultProperties", this.defaultProperties));
  }
  if (this.addCommandLineProperties && args.length > 0) {
    String name = CommandLinePropertySource.COMMAND_LINE_PROPERTY_SOURCE_NAME;
    if (sources.contains(name)) {
      PropertySource<?> source = sources.get(name);
      CompositePropertySource composite = new CompositePropertySource(name);
      composite.addPropertySource(new SimpleCommandLinePropertySource(
          "springApplicationCommandLineArgs", args));
      composite.addPropertySource(source);
      sources.replace(name, composite);
    }
    else {
      sources.addFirst(new SimpleCommandLinePropertySource(args));
    }
  }
}
```
【configureProfiles(environment, args);】
针对于整个应用的环境，配置那些profile是活动的或者是默认的，其他额外的profile可以在配置文件处理过程中通过spring.profiles.active属性激活。

######   listeners.environmentPrepared(environment)
触发了一个新的事件------环境准备好的事件。
```
public void environmentPrepared(ConfigurableEnvironment environment) {
  for (SpringApplicationRunListener listener : this.listeners) {
    listener.environmentPrepared(environment);
  }
}
```

#### Banner
在进行往下进行之前，我们先对banner做一个实验，我们在resources目录下新建一个banner.txt文件，里边输入一段文字，然后启动应用，会看到打印了我们输入的信息，banner自定义生效：
![banner.png](banner.png)
Banner是一个函数式接口，里边有一个枚举，用于配置banner的模式：
```
enum Mode {

  /**
   * Disable printing of the banner.
   */
  OFF,

  /**
   * Print the banner to System.out.
   */
  CONSOLE,

  /**
   * Print the banner to the log file.
   */
  LOG

}
```
在主流程了printBanner()方法：
```
private Banner printBanner(ConfigurableEnvironment environment) {
  //默认是CONSOLE
  if (this.bannerMode == Banner.Mode.OFF) {
    return null;
  }
  //获取资源加载器
  ResourceLoader resourceLoader = (this.resourceLoader != null)
      ? this.resourceLoader : new DefaultResourceLoader(getClassLoader());
  SpringApplicationBannerPrinter bannerPrinter = new SpringApplicationBannerPrinter(
      resourceLoader, this.banner);
  //当前程序不会走这个if
  if (this.bannerMode == Mode.LOG) {
    return bannerPrinter.print(environment, this.mainApplicationClass, logger);
  }
  //当前程序会执行这个
  return bannerPrinter.print(environment, this.mainApplicationClass, System.out);
}
```

##### SpringApplicationBannerPrinter
用来打印application的banner，其内部有一个成员变量【static final String DEFAULT_BANNER_LOCATION = "banner.txt";】
即默认的banner文件。
构造器：
```
SpringApplicationBannerPrinter(ResourceLoader resourceLoader, Banner fallbackBanner) {
  //资源加载器，可能要使用resourceLoader加载banner文件
  this.resourceLoader = resourceLoader;
  //回退banner
  this.fallbackBanner = fallbackBanner;
}
```
看一下SpringApplicationBannerPrinter的print方法：
```
public Banner print(Environment environment, Class<?> sourceClass, PrintStream out) {
  //获取banner
  Banner banner = getBanner(environment);
  //打印banner
  banner.printBanner(environment, sourceClass, out);
  return new PrintedBanner(banner, sourceClass);
}
```
getBanner根据环境得到banner。
```
private Banner getBanner(Environment environment) {
  Banners banners = new Banners();
  //图像banner存在就会加载
  banners.addIfNotNull(getImageBanner(environment));
  //文字banner存在就会加载
  banners.addIfNotNull(getTextBanner(environment));
  if (banners.hasAtLeastOneBanner()) {
    return banners;
  }
  if (this.fallbackBanner != null) {
    return this.fallbackBanner;
  }
  //没有找到banner就会使用spring默认的banner（SpringBootBanner）
  return DEFAULT_BANNER;
}
```

其中看一下getTextBanner():
```
static final String DEFAULT_BANNER_LOCATION = "banner.txt";
private Banner getTextBanner(Environment environment) {
  String location = environment.getProperty(BANNER_LOCATION_PROPERTY,
      DEFAULT_BANNER_LOCATION);
  Resource resource = this.resourceLoader.getResource(location);
  //如果文件banner.txt存在就会加载这个资源。
  if (resource.exists()) {
    return new ResourceBanner(resource);
  }
  return null;
}
```
然后我们看一下SpringBootBanner的printBanner()方法：
```
private static final String[] BANNER = { "",
    "  .   ____          _            __ _ _",
    " /\\\\ / ___'_ __ _ _(_)_ __  __ _ \\ \\ \\ \\",
    "( ( )\\___ | '_ | '_| | '_ \\/ _` | \\ \\ \\ \\",
    " \\\\/  ___)| |_)| | | | | || (_| |  ) ) ) )",
    "  '  |____| .__|_| |_|_| |_\\__, | / / / /",
    " =========|_|==============|___/=/_/_/_/" };
public void printBanner(Environment environment, Class<?> sourceClass,PrintStream printStream) {
  for (String line : BANNER) {
    printStream.println(line);
  }
  String version = SpringBootVersion.getVersion();
  version = (version != null) ? " (v" + version + ")" : "";
  StringBuilder padding = new StringBuilder();
  while (padding.length() < STRAP_LINE_SIZE
      - (version.length() + SPRING_BOOT.length())) {
    padding.append(" ");
  }

  printStream.println(AnsiOutput.toString(AnsiColor.GREEN, SPRING_BOOT,
      AnsiColor.DEFAULT, padding.toString(), AnsiStyle.FAINT, version));
  printStream.println();
}
```
可以看到之前我们没有配置banner.txt的时候打印就是这个"spring"输出，即输出了BANNER数组。

#### createApplicationContext()方法
一个用来创建上下文的策略方法。
```
protected ConfigurableApplicationContext createApplicationContext() {
  //applicationContextClass默认是空的
  Class<?> contextClass = this.applicationContextClass;
  if (contextClass == null) {
    try {
      switch (this.webApplicationType) {
        //我们的应用是SERVLET
      case SERVLET:
      /**
      public static final String DEFAULT_SERVLET_WEB_CONTEXT_CLASS = "org.springframework.boot."
    			+ "web.servlet.context.AnnotationConfigServletWebServerApplicationContext";
      **/
        contextClass = Class.forName(DEFAULT_SERVLET_WEB_CONTEXT_CLASS);
        break;
      case REACTIVE:
        contextClass = Class.forName(DEFAULT_REACTIVE_WEB_CONTEXT_CLASS);
        break;
      default:
        contextClass = Class.forName(DEFAULT_CONTEXT_CLASS);
      }
    }
    catch (ClassNotFoundException ex) {
      throw new IllegalStateException(
          "Unable create a default ApplicationContext, "
              + "please specify an ApplicationContextClass",
          ex);
    }
  }
  //通过反射创建contextClass
  return (ConfigurableApplicationContext) BeanUtils.instantiateClass(contextClass);
}
```

#### prepareContext(context, environment, listeners, applicationArguments,printedBanner)方法

```
private void prepareContext(ConfigurableApplicationContext context,
    ConfigurableEnvironment environment, SpringApplicationRunListeners listeners,
    ApplicationArguments applicationArguments, Banner printedBanner) {
  context.setEnvironment(environment);
  //处理上下文
  postProcessApplicationContext(context);
  applyInitializers(context);
  //触发事件，上下文已经创建和准备完毕，但是资源还没有加载
  listeners.contextPrepared(context);
  if (this.logStartupInfo) {
    logStartupInfo(context.getParent() == null);
    //启动日志的处理
    logStartupProfileInfo(context);
  }
  // Add boot specific singleton beans
  ConfigurableListableBeanFactory beanFactory = context.getBeanFactory();
  beanFactory.registerSingleton("springApplicationArguments", applicationArguments);
  if (printedBanner != null) {
    beanFactory.registerSingleton("springBootBanner", printedBanner);
  }
  if (beanFactory instanceof DefaultListableBeanFactory) {
    ((DefaultListableBeanFactory) beanFactory)
        .setAllowBeanDefinitionOverriding(this.allowBeanDefinitionOverriding);
  }
  // Load the sources 加载资源
  Set<Object> sources = getAllSources();
  Assert.notEmpty(sources, "Sources must not be empty");
  load(context, sources.toArray(new Object[0]));
  //触发事件，上下文已经被加载，但是还没有被刷新
  listeners.contextLoaded(context);
}
```
#### refreshContext()刷新上下文
此方法按照规定的顺序执行， 这个方法做的事情非常多，不会过多介绍， 最终走到AbstractApplicationContext的refresh()方法：
```
public void refresh() throws BeansException, IllegalStateException {
  synchronized (this.startupShutdownMonitor) {
    // Prepare this context for refreshing.
    prepareRefresh();

    // Tell the subclass to refresh the internal bean factory.
    ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

    // Prepare the bean factory for use in this context.
    prepareBeanFactory(beanFactory);

    try {
      // Allows post-processing of the bean factory in context subclasses.
      postProcessBeanFactory(beanFactory);

      // Invoke factory processors registered as beans in the context.
      invokeBeanFactoryPostProcessors(beanFactory);

      // Register bean processors that intercept bean creation.
      registerBeanPostProcessors(beanFactory);

      // Initialize message source for this context.
      initMessageSource();

      // Initialize event multicaster for this context.
      initApplicationEventMulticaster();

      // Initialize other special beans in specific context subclasses.
      onRefresh();

      // Check for listener beans and register them.
      registerListeners();

      // Instantiate all remaining (non-lazy-init) singletons.
      finishBeanFactoryInitialization(beanFactory);

      // Last step: publish corresponding event.
      finishRefresh();
    }

    catch (BeansException ex) {
      if (logger.isWarnEnabled()) {
        logger.warn("Exception encountered during context initialization - " +
            "cancelling refresh attempt: " + ex);
      }

      // Destroy already created singletons to avoid dangling resources.
      destroyBeans();

      // Reset 'active' flag.
      cancelRefresh(ex);

      // Propagate exception to caller.
      throw ex;
    }

    finally {
      // Reset common introspection caches in Spring's core, since we
      // might not ever need metadata for singleton beans anymore...
      resetCommonCaches();
    }
  }
}
```

#### afterRefresh(context, applicationArguments)方法
这个方法没有做任何事情，目的是为了留给子类继承的想象空间的。

#### stopWatch.stop()秒表计时结束
不做过多解释。

#### 打印启动信息
![stopwatch.png](stopwatch.png)

#### listeners.started(context)
触发事件，上下文已经被刷新，应用已经启动，但是命令行运行器和应用运行器还没有被调用

#### callRunners()方法
看一下它的实现：
```
private void callRunners(ApplicationContext context, ApplicationArguments args) {
  List<Object> runners = new ArrayList<>();
  runners.addAll(context.getBeansOfType(ApplicationRunner.class).values());
  runners.addAll(context.getBeansOfType(CommandLineRunner.class).values());
  AnnotationAwareOrderComparator.sort(runners);
  for (Object runner : new LinkedHashSet<>(runners)) {
    if (runner instanceof ApplicationRunner) {
      //启动应用运行器
      callRunner((ApplicationRunner) runner, args);
    }
    if (runner instanceof CommandLineRunner) {
      //启动命令行运行器
      callRunner((CommandLineRunner) runner, args);
    }
  }
}
```
##### ApplicationRunner
Interface used to indicate that a bean should run when it is contained within a SpringApplication. Multiple ApplicationRunner beans can be defined within the same application context and can be ordered using the Ordered interface or @Order annotation.

用于标示一个bean应该被运行，当它包含在一个SpringApplication当中，一个应用上下文可以有多个ApplicationRunner，可以使用Ordered接口或者`@Order`直接进行排序。

```
@FunctionalInterface
public interface ApplicationRunner {

	/**
	 * Callback used to run the bean.
	 * @param args incoming application arguments
	 * @throws Exception on error
	 */
	void run(ApplicationArguments args) throws Exception;

}
```

##### CommandLineRunner
Interface used to indicate that a bean should run when it is contained within a SpringApplication. Multiple CommandLineRunner beans can be defined within the same application context and can be ordered using the Ordered interface or @Order annotation.
If you need access to ApplicationArguments instead of the raw String array consider using ApplicationRunner.

用于标示一个bean应该被运行，当它包含在一个SpringApplication当中，一个应用上下文可以有多个CommandLineRunner，可以使用Ordered接口或者`@Order`直接进行排序。
如果你想访问ApplicationArguments而不是原生的字符串数组，请使用ApplicationRunner。

```
@FunctionalInterface
public interface CommandLineRunner {

	/**
	 * Callback used to run the bean.
	 * @param args incoming main method arguments
	 * @throws Exception on error
	 */
	void run(String... args) throws Exception;

}
```

#### listeners.running(context)
run方法调用完毕之前立即会被触发和调用，应用上下文已经被刷新，CommandLineRunner和ApplicationRunner已经被调用。

### 结束
当listeners.running(context)调用完毕之后run也就结束了，run方法返回一个ConfigurableApplicationContext，会返回到我们的main方法,到此应用的启动过程分析完毕。

```
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
      ConfigurableApplicationContext configurableApplicationContext =   SpringApplication.run(MyApplication.class,args);
    }
}
```
