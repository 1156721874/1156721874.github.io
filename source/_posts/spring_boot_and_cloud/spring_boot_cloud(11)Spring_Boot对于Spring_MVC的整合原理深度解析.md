---
title: spring_boot_cloud(11)Spring_Boot对于Spring_MVC的整合原理深度解析
date: 2019-8-10 18:13:32
tags: [springmvc SpringBoot]
categories: spring_boot_cloud
---

### 引言
现在我们使用spring boot搭建的工程和之前spring mvc的方式有一个很大的不同点就是：web.xml已经不需要配置，而之前的spring mvc需要配置web.xml，在里边配置DsipatcherServlet，spring boot之所以不需要这个配置是一位servlet的升级，之前用的是servlet2.5的标准，现在boot的方式是servlet3.0，而servlet3.0允许以spi的方式去实现servlet的初始化。

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
