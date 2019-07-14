---
title: spring_boot_cloud(5)SpringApplication源码分析与作用详解
date: 2019-06-30 16:54:32
tags: [SpringBootApplication,源码解析]
categories: spring_boot_cloud
---


### SpringApplication的启动流程源码分析

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
  ResourceLoader：用来加载资源的策略接口（class path，类路劲，文件资源），org.springframework.context.ApplicationContext被要求提供这个功能，再加上org.springframework.core.io.support.ResourcePatternResolver这样一个支持。DefaultResourceLoader是一个独立的实现，他被用在ApplicationContext之外，也是被资源编辑器ResourceEditor所使用。
  ResourceLoader结构：
  ```
  ResourceLoader
    //加载资源都离不开类加载器
    getClassLoader
    getResource
    CLASSPATH_URL_PREFIX
  ```

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
通常用于在web应用当这种需要编程的方式初始化应用的上下文。
比如我们初始化一个属性源，激活profile这对于上下文的环境。
ApplicationContextInitializer被鼓励探测spring排序接口是不是被实现或者`@Order`注解是不是存在，存在的话用来排序。
ApplicationContextInitializer主要用来完成初始化工作。

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
//进入loadSpringFactories
private static Map<String, List<String>> loadSpringFactories(@Nullable ClassLoader classLoader) {
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
接下往下走就会看到这七哥接口：
![url2.png](url2.png)
最后loadSpringFactories返回的result是一个map，key是接口的名称，value是接口的实现类：
比如刚才的spring.factories里边 org.springframework.boot.autoconfigure.EnableAutoConfiguration有118个实现，那么map的key就是 org.springframework.boot.autoconfigure.EnableAutoConfiguration，value是她的118个实现。

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
