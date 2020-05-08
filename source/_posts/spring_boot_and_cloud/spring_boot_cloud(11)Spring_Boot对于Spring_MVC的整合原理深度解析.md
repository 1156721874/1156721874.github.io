---
title: spring_boot_cloud(11)Spring_Boot对于Spring_MVC的整合原理深度解析
date: 2019-8-10 18:13:32
tags: [springmvc SpringBoot]
categories: spring_boot_cloud
---

### 引言
现在我们使用spring boot搭建的工程和之前spring mvc的方式有一个很大的不同点就是：web.xml已经不需要配置，而之前的spring mvc需要配置web.xml，在里边配置DsipatcherServlet，spring boot之所以不需要这个配置是一位servlet的升级，之前用的是servlet2.5的标准，现在boot的方式是servlet3.0，而servlet3.0允许以spi的方式去实现servlet的初始化。
<!-- more -->

### ServletContainerInitializer
我们打开我们项目依赖的jar包：
![servletContainerInitializer.png](servletContainerInitializer.png)
这个文件里边 只有一个类：
org.springframework.web.SpringServletContainerInitializer
它实现了ServletContainerInitializer，看一下ServletContainerInitializer的doc：

ServletContainerInitializer是通过META-INF/service/javax.servlet.ServletConotainerInitializer注册的，它的实现必须包含在一个jar文件中。
ServletContainerInitializer可以通过javax.servlet.annotation.handlesTypes注解来注册感兴趣的注解，比如class,method,field等。

```
public interface ServletContainerInitializer {
    void onStartup(Set<Class<?>> var1, ServletContext var2) throws ServletException;
}
```
onStartup方法有一个参数ServletContext，即上下文，web应用启动的时候会收到一些通知，onStartup得到调用，通知来源就是javax.servlet.annotation.handlesTypes标记的。

### SpringServletContainerInitializer
 ServletContainerInitializer是一个Servlet 3.0的，他的设计目的是基于代码servlet容器的配置。而且会使用到WebApplicationInitializer SPI 搭配使用支撑web.xml的实现方式。


这个类会被加载和实例化，它的onStartup方法会被任意一个servlet3.0兼容的容器(比如tomcat)在启动的时候被调用，并且假设spring-web的jar包出现在classpath下边。 这个过程发生在通过jar包服务api ServiceLoader.load(Class) 方法探测spring-web模块的META-INF/services/javax.servlet.ServletContainerInitializer服务提供配置文件。

#### 与web.xml搭配使用
一个应用在启动的时候可以选择限制classpath扫描的servlet容器的数量，或者通过 web.xml当中的 metadata-complete 属性，它会控制servlet注解的扫描机制，或者通过web.xml中的<absolute-ordering> 标签，它会控制那些web片段允许去被执行ServletContainerInitializer的扫描，当使用在这种特性的时候，SpringServletContainerInitializer可以添加"spring_web"到web.xml的片段列表里边去，形式如下：
```
<absolute-ordering>
  <name>some_web_fragment</name>
  <name>spring_web</name>
</absolute-ordering>
```
#### 与WebApplicationInitializer的关系
WebApplicationInitializer是一个spi，只有一个方法WebApplicationInitializer.onStartup(ServletContext).这个签名和 ServletContainerInitializer.onStartup(Set, ServletContext)很像，简单来说SpringServletContainerInitializer负责实例化和将ServletContext委托给任何WebApplicationInitializer的实现，接下来是由WebApplicationInitializer接管，完成ServletContext的初始化，具体的委托处理过程描述在onStartup的doc里面。

SpringServletContainerInitializer应该被看成是一种支撑的基础设施，目的是为了更加重要的用户面对的WebApplicationInitializer的spi所服务的，使用这个容器的初始化器是可选的，如果WebApplicationInitializer的实现没有出现在classpath下面，容器的初始化器不不会受到影响的。
WebApplicationInitializer并没有绑定到spring mvc上边，任何的servlet，filter，listener都可以使用WebApplicationInitializer注册，并不仅仅针对于spring mvc。

用户不用去使用SpringServletContainerInitializer，用户应该去使用WebApplicationInitializer的具体实现。

#### SpringServletContainerInitializer的onStartup方法
将ServletContext委托任何一个WebApplicationInitializer的实现，这个实现要以jar包的形式出现在classpath里边。
由于这个类声明了 @HandlesTypes(WebApplicationInitializer.class)这个注解，servlet3.0容器会自动扫描WebApplicationInitializer接口的实现，并且把所有实现类组成的set集合作为onStartup方法的webAppInitializerClasses参数。
如果在classpath里边没有WebApplicationInitializer的实现，这个方法相当于什么都不做，系统只是打印日志，提示SpringServletContainerInitializer被调用了，但是并没有找到WebApplicationInitializer的实现，假设有多个WebApplicationInitializer实现被检测到，他们都会被实例化，如果加上`@Order`直接还会被排序，接下来每个实例的 WebApplicationInitializer.onStartup(ServletContext)方法都会被调用，将ServletContext进行委托，这样每一个实例都会被注册，比如说 Spring的 DispatcherServlet。监听器，比如ContextLoaderListener，或者其他servlet 挨批，比如过滤器之类的，等等。


#### @HandlesTypes注解
```
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface HandlesTypes {
    Class<?>[] value();
}
```

SpringServletContainerInitializer类上声明了@HandlesTypes注解，@HandlesTypes注解的class是WebApplicationInitializer，那么在SpringServletContainerInitializer的onStartup方法的webAppInitializerClasses参数就是从classpath扫描出来的WebApplicationInitializer实现的集合。

```
@HandlesTypes(WebApplicationInitializer.class)
public class SpringServletContainerInitializer implements ServletContainerInitializer {

  public void onStartup(@Nullable Set<Class<?>> webAppInitializerClasses, ServletContext servletContext)
			throws ServletException {

		List<WebApplicationInitializer> initializers = new LinkedList<>();

		if (webAppInitializerClasses != null) {
			for (Class<?> waiClass : webAppInitializerClasses) {
				// Be defensive: Some servlet containers provide us with invalid classes,
				// no matter what @HandlesTypes says...
        //首先不是接口，不是抽象类，并且实现了WebApplicationInitializer接口
				if (!waiClass.isInterface() && !Modifier.isAbstract(waiClass.getModifiers()) &&
						WebApplicationInitializer.class.isAssignableFrom(waiClass)) {
					try {
            //使用反射实例化，加入到initializers集合
						initializers.add((WebApplicationInitializer)
								ReflectionUtils.accessibleConstructor(waiClass).newInstance());
					}
					catch (Throwable ex) {
						throw new ServletException("Failed to instantiate WebApplicationInitializer class", ex);
					}
				}
			}
		}
    //如果在classpath下没有找到任何WebApplicationInitializer的实现，打印info日志。
		if (initializers.isEmpty()) {
			servletContext.log("No Spring WebApplicationInitializer types detected on classpath");
			return;
		}

		servletContext.log(initializers.size() + " Spring WebApplicationInitializers detected on classpath");
    //排序
		AnnotationAwareOrderComparator.sort(initializers);
    //将servlet上下文servletContext委托给每一个WebApplicationInitializer的实现。
		for (WebApplicationInitializer initializer : initializers) {
			initializer.onStartup(servletContext);
		}
	}

}

```
