---
title: spring_boot_cloud(12)Spring_Boot集成内嵌服务器原理揭秘
date: 2019-11-10 18:13:32
tags: [tomcat SpringBoot 容器]
categories: spring_boot_cloud
---

### 断点SpringServletContainerInitializer
我们在SpringServletContainerInitializer的onStartup方法里边加一个断点，然后debug应用，让我们感到奇怪的是断点并不会进入到onStartup方法，那么我们看一下顶层接口ServletContainerInitializer的实现类有哪些：
![ServletContainerInitializer.png](ServletContainerInitializer.png)
会看到有TomcatStarter和还有我们的SpringServletContainerInitializer，这里不会进入断点的原因是如果我们是以jar包或者main方法的方式启动应用的时候会使用springboot内嵌的tomcat容器，如果我们使用传统的spring mvc或者war包的方式那么SpringServletContainerInitializer就会初始化，如果我们现在在TomcatStarter的onStartup方法加一个断点，那么断点一定会进入。

#### 传统的Spring mvc的容器初始化过程；
1. 通过SpringServletContainerInitializer来负责对容器启动时的相关组件的初始化。
2. 到底要初始化那些组件则是通过Servlet规范中所提供的注解HandlesTypes来指定的。
3. 在SpringServletContainerInitializer中，其HandlesTypes注解则明确指定为了WebApplicationInitializer.class类型。
4. 在SpringServletContainerInitializer的onStartup方法中，这主要完成了一些验证与组件装配的工作。
5. 在SpringServletContainerInitializer的onStartup方法中，由于某些容器并未遵循servlet规范，导致虽然明确指定了HandlesTypes注解的类型为WebApplicationInitializer.class类型，但还是可能会存在将一些非法类型传递过来的情况；所以，该方法还对传递进来的具体类型进行了细致的判断，只有符合条件的类型才会被纳入到List<WebApplicationInitializer>集合中。
6. 当以上判断完成以后，List<WebApplicationInitializer>就是接下来要进行初始化的组件了。
7. 最后，通过遍历List<WebApplicationInitializer>列表，取出其中的每一个WebApplicationInitializer对象，调用这些对象的onStartup方法，完成组件的启动初始化工作。

总结一下：
SpringServletContainerInitializer在整个初始过程中，其扮演的角色实际上是委托或是代理的角色，真正完成初始化工作的依旧是一个个WebApplicationInitializer实现类。

#### 现代的Spring Boot应用的容器初始化过程：
1. 对于Spring Boot应用来说，他并未使用SpringServletContainerInitializer来进行容器的初始化，而是使用了TomcatStarter进行的。
2. TomcatStarter存在三点因素使得它无法通过SPI机制进行初始化，它没有不带参数的构造方法；它的声明并非public；其所在jar包并没有META-INF.services目录，当然也就不存在javax.servlet.ServletContainerInitializer的文件了。
3. 综上，TomcaStarter并非通过SPI机制进行的查找与实例化。
4. 本质上，TomcatStarter是通过Spring Boot框架new出来的。
5. 与SpringServletContainerInitializer类似，TomcatStarter在容器的初始化过程中扮演着一个委托或是代理的角色，真正执行的初始化动作实际上是由所持有的ServletContextInitializer的onStartup方法来完成。


```
class TomcatStarter implements ServletContainerInitializer {

	private static final Log logger = LogFactory.getLog(TomcatStarter.class);

	private final ServletContextInitializer[] initializers;

	private volatile Exception startUpException;

	TomcatStarter(ServletContextInitializer[] initializers) {
		this.initializers = initializers;
	}

	@Override
	public void onStartup(Set<Class<?>> classes, ServletContext servletContext)
			throws ServletException {
		try {
			for (ServletContextInitializer initializer : this.initializers) {
				initializer.onStartup(servletContext);
			}
		}
		catch (Exception ex) {
			this.startUpException = ex;
			// Prevent Tomcat from logging and re-throwing when we know we can
			// deal with it in the main thread, but log for information here.
			if (logger.isErrorEnabled()) {
				logger.error("Error starting Tomcat context. Exception: "
						+ ex.getClass().getName() + ". Message: " + ex.getMessage());
			}
		}
	}

	public Exception getStartUpException() {
		return this.startUpException;
	}

}
```
TomcatStarter是ServletContainerInitializer的实现，并且记录ServletContextInitializer初始过程中的错误。
我们看一下ServletContextInitializer的doc:
```
@FunctionalInterface
public interface ServletContextInitializer {

	/**
	 * Configure the given {@link ServletContext} with any servlets, filters, listeners
	 * context-params and attributes necessary for initialization.
	 * @param servletContext the {@code ServletContext} to initialize
	 * @throws ServletException if any call against the given {@code ServletContext}
	 * throws a {@code ServletException}
	 */
	void onStartup(ServletContext servletContext) throws ServletException;

}
```
Interface used to configure a Servlet 3.0+ context programmatically. Unlike WebApplicationInitializer, classes that implement this interface (and do not implement WebApplicationInitializer) will not be detected by SpringServletContainerInitializer and hence will not be automatically bootstrapped by the Servlet container.
This interface is primarily designed to allow ServletContextInitializers to be managed by Spring and not the Servlet container.
For configuration examples see WebApplicationInitializer.

这是一个接口，以编程的方式配置Servlet 3.0+的上下文，与WebApplicationInitializer不同的是，实现了这是一个接口，以编程的方式配置Servlet 3.0+的上下文，与WebApplicationInitializer不同的是，实现了ServletContextInitializer接口的类（没有实现WebApplicationInitializer）将不会被SpringServletContainerInitializer检测到，因此它不会被servlet容器自动的进行启动。
这个接口的主要的设计目的是允许ServletContextInitializers被spring管理，而不是Servlet容器管理。


### Servlet 3.0 的一些重要特性：
ServletRegistration:
```
public interface ServletRegistration extends Registration {
    Set<String> addMapping(String... var1);

    Collection<String> getMappings();

    String getRunAsRole();

    public interface Dynamic extends ServletRegistration, javax.servlet.Registration.Dynamic {
        void setLoadOnStartup(int var1);

        Set<String> setServletSecurity(ServletSecurityElement var1);

        void setMultipartConfig(MultipartConfigElement var1);

        void setRunAsRole(String var1);
    }
}
```
ServletContext:
```
public interface ServletContext {
    String TEMPDIR = "javax.servlet.context.tempdir";
    String ORDERED_LIBS = "javax.servlet.context.orderedLibs";

    String getContextPath();

    ServletContext getContext(String var1);

    int getMajorVersion();

    int getMinorVersion();

    int getEffectiveMajorVersion();

    int getEffectiveMinorVersion();

    String getMimeType(String var1);

    Set<String> getResourcePaths(String var1);

    URL getResource(String var1) throws MalformedURLException;

    InputStream getResourceAsStream(String var1);

    RequestDispatcher getRequestDispatcher(String var1);

    RequestDispatcher getNamedDispatcher(String var1);

    /** @deprecated */
    @Deprecated
    Servlet getServlet(String var1) throws ServletException;

    /** @deprecated */
    @Deprecated
    Enumeration<Servlet> getServlets();

    /** @deprecated */
    @Deprecated
    Enumeration<String> getServletNames();

    void log(String var1);

    /** @deprecated */
    @Deprecated
    void log(Exception var1, String var2);

    void log(String var1, Throwable var2);

    String getRealPath(String var1);

    String getServerInfo();

    String getInitParameter(String var1);

    Enumeration<String> getInitParameterNames();

    boolean setInitParameter(String var1, String var2);

    Object getAttribute(String var1);

    Enumeration<String> getAttributeNames();

    void setAttribute(String var1, Object var2);

    void removeAttribute(String var1);

    String getServletContextName();

    Dynamic addServlet(String var1, String var2);

    Dynamic addServlet(String var1, Servlet var2);

    Dynamic addServlet(String var1, Class<? extends Servlet> var2);

    Dynamic addJspFile(String var1, String var2);

    <T extends Servlet> T createServlet(Class<T> var1) throws ServletException;

    ServletRegistration getServletRegistration(String var1);

    Map<String, ? extends ServletRegistration> getServletRegistrations();

    javax.servlet.FilterRegistration.Dynamic addFilter(String var1, String var2);

    javax.servlet.FilterRegistration.Dynamic addFilter(String var1, Filter var2);

    javax.servlet.FilterRegistration.Dynamic addFilter(String var1, Class<? extends Filter> var2);

    <T extends Filter> T createFilter(Class<T> var1) throws ServletException;

    FilterRegistration getFilterRegistration(String var1);

    Map<String, ? extends FilterRegistration> getFilterRegistrations();

    SessionCookieConfig getSessionCookieConfig();

    void setSessionTrackingModes(Set<SessionTrackingMode> var1);

    Set<SessionTrackingMode> getDefaultSessionTrackingModes();

    Set<SessionTrackingMode> getEffectiveSessionTrackingModes();

    void addListener(String var1);

    <T extends EventListener> void addListener(T var1);

    void addListener(Class<? extends EventListener> var1);

    <T extends EventListener> T createListener(Class<T> var1) throws ServletException;

    JspConfigDescriptor getJspConfigDescriptor();

    ClassLoader getClassLoader();

    void declareRoles(String... var1);

    String getVirtualServerName();

    int getSessionTimeout();

    void setSessionTimeout(int var1);

    String getRequestCharacterEncoding();

    void setRequestCharacterEncoding(String var1);

    String getResponseCharacterEncoding();

    void setResponseCharacterEncoding(String var1);
}

```

Servlet 3.0可以使用注解的方式增加filter、Servlet等，可以使用编程式的api，也可以使用web.xml的方式。
1. ServletRegistration.Dynamic servlet = servletContext.addServlet(MyServlet.class..getSimpleName(),MuServlet.class);
 servlet.addMapping("/myServlet");

### WebApplicationInitializer与ServletContextInitializer的关系详解
WebApplicationInitializer接口：
```
public interface WebApplicationInitializer {

	/**
	 * Configure the given {@link ServletContext} with any servlets, filters, listeners
	 * context-params and attributes necessary for initializing this web application. See
	 * examples {@linkplain WebApplicationInitializer above}.
	 * @param servletContext the {@code ServletContext} to initialize
	 * @throws ServletException if any call against the given {@code ServletContext}
	 * throws a {@code ServletException}
	 */
	void onStartup(ServletContext servletContext) throws ServletException;

}
```
首先看一下WebApplicationInitializer的doc：

Interface to be implemented in Servlet 3.0+ environments in order to configure the ServletContext programmatically -- as opposed to (or possibly in conjunction with) the traditional web.xml-based approach.
Implementations of this SPI will be detected automatically by SpringServletContainerInitializer, which itself is bootstrapped automatically by any Servlet 3.0 container. See its Javadoc for details on this bootstrapping mechanism.
#### Example
##### The traditional, XML-based approach
Most Spring users building a web application will need to register Spring's DispatcherServlet. For reference, in WEB-INF/web.xml, this would typically be done as follows:
```
   <servlet>
     <servlet-name>dispatcher</servlet-name>
     <servlet-class>
       org.springframework.web.servlet.DispatcherServlet
     </servlet-class>
     <init-param>
       <param-name>contextConfigLocation</param-name>
       <param-value>/WEB-INF/spring/dispatcher-config.xml</param-value>
     </init-param>
     <load-on-startup>1</load-on-startup>
   </servlet>

   <servlet-mapping>
     <servlet-name>dispatcher</servlet-name>
     <url-pattern>/</url-pattern>
   </servlet-mapping>
 ```
##### The code-based approach with WebApplicationInitializer
Here is the equivalent DispatcherServlet registration logic, WebApplicationInitializer-style:
   public class MyWebAppInitializer implements WebApplicationInitializer {

      @Override
      public void onStartup(ServletContext container) {
        XmlWebApplicationContext appContext = new XmlWebApplicationContext();
        appContext.setConfigLocation("/WEB-INF/spring/dispatcher-config.xml");

        ServletRegistration.Dynamic dispatcher =
          container.addServlet("dispatcher", new DispatcherServlet(appContext));
        dispatcher.setLoadOnStartup(1);
        dispatcher.addMapping("/");
      }

   }
As an alternative to the above, you can also extend from org.springframework.web.servlet.support.AbstractDispatcherServletInitializer. As you can see, thanks to Servlet 3.0's new ServletContext.addServlet method we're actually registering an instance of the DispatcherServlet, and this means that the DispatcherServlet can now be treated like any other object -- receiving constructor injection of its application context in this case.
This style is both simpler and more concise. There is no concern for dealing with init-params, etc, just normal JavaBean-style properties and constructor arguments. You are free to create and work with your Spring application contexts as necessary before injecting them into the DispatcherServlet.
Most major Spring Web components have been updated to support this style of registration. You'll find that DispatcherServlet, FrameworkServlet, ContextLoaderListener and DelegatingFilterProxy all now support constructor arguments. Even if a component (e.g. non-Spring, other third party) has not been specifically updated for use within WebApplicationInitializers, they still may be used in any case. The Servlet 3.0 ServletContext API allows for setting init-params, context-params, etc programmatically.
##### A 100% code-based approach to configuration
In the example above, WEB-INF/web.xml was successfully replaced with code in the form of a WebApplicationInitializer, but the actual dispatcher-config.xml Spring configuration remained XML-based. WebApplicationInitializer is a perfect fit for use with Spring's code-based @Configuration classes. See @Configuration Javadoc for complete details, but the following example demonstrates refactoring to use Spring's AnnotationConfigWebApplicationContext in lieu of XmlWebApplicationContext, and user-defined @Configuration classes AppConfig and DispatcherConfig instead of Spring XML files. This example also goes a bit beyond those above to demonstrate typical configuration of the 'root' application context and registration of the ContextLoaderListener:
   public class MyWebAppInitializer implements WebApplicationInitializer {

      @Override
      public void onStartup(ServletContext container) {
        // Create the 'root' Spring application context
        AnnotationConfigWebApplicationContext rootContext =
          new AnnotationConfigWebApplicationContext();
        rootContext.register(AppConfig.class);

        // Manage the lifecycle of the root application context
        container.addListener(new ContextLoaderListener(rootContext));

        // Create the dispatcher servlet's Spring application context
        AnnotationConfigWebApplicationContext dispatcherContext =
          new AnnotationConfigWebApplicationContext();
        dispatcherContext.register(DispatcherConfig.class);

        // Register and map the dispatcher servlet
        ServletRegistration.Dynamic dispatcher =
          container.addServlet("dispatcher", new DispatcherServlet(dispatcherContext));
        dispatcher.setLoadOnStartup(1);
        dispatcher.addMapping("/");
      }

   }
As an alternative to the above, you can also extend from org.springframework.web.servlet.support.AbstractAnnotationConfigDispatcherServletInitializer. Remember that WebApplicationInitializer implementations are detected automatically -- so you are free to package them within your application as you see fit.

这是一个在servlet3.0+环境下实现的一个接口，用来以编程的方式配置ServletContext，这种方式是和传统的web.xml相反的，或者也是可以和传统的方式搭配使用的。

这个SPI的实现可以被SpringServletContainerInitializer自动的探测到，SpringServletContainerInitializer本身又是可以被servlet3.0容器启动的。详细可以看文档。

#### 举例
##### 传统的web.xml方式是怎么做的
大多数的用户构建一个web应用将需要注册一个spring的DispatcherServlet，下面列出了一个引用，是一个经典的web.xml的使用方式：
```
<servlet>
	<servlet-name>dispatcher</servlet-name>
	<servlet-class>
		org.springframework.web.servlet.DispatcherServlet
	</servlet-class>
	<init-param>
		<param-name>contextConfigLocation</param-name>
		<param-value>/WEB-INF/spring/dispatcher-config.xml</param-value>
	</init-param>
	<load-on-startup>1</load-on-startup>
</servlet>

<servlet-mapping>
	<servlet-name>dispatcher</servlet-name>
	<url-pattern>/</url-pattern>
</servlet-mapping>
```
##### 基于WebApplicationInitializer使用编程式
下面是一个和web.xml等价的写法来注册DispatcherServlet的逻辑，WebApplicationInitializer的风格
```
public class MyWebAppInitializer implements WebApplicationInitializer {

	 @Override
	 public void onStartup(ServletContext container) {
		 XmlWebApplicationContext appContext = new XmlWebApplicationContext();
		 appContext.setConfigLocation("/WEB-INF/spring/dispatcher-config.xml");

		 ServletRegistration.Dynamic dispatcher =
			 container.addServlet("dispatcher", new DispatcherServlet(appContext));
		 dispatcher.setLoadOnStartup(1);
		 dispatcher.addMapping("/");
	 }

}
```
作为上述实现方式的另外一种实现手段，你也可以继承org.springframework.web.servlet.support.AbstractDispatcherServletInitializer:
```
public abstract class AbstractDispatcherServletInitializer extends AbstractContextLoaderInitializer {
	---- 略 ----
	@Override
	public void onStartup(ServletContext servletContext) throws ServletException {
		super.onStartup(servletContext);
		registerDispatcherServlet(servletContext);
	}
	protected void registerDispatcherServlet(ServletContext servletContext) {
		String servletName = getServletName();
		Assert.hasLength(servletName, "getServletName() must not return null or empty");

		WebApplicationContext servletAppContext = createServletApplicationContext();
		Assert.notNull(servletAppContext, "createServletApplicationContext() must not return null");

		FrameworkServlet dispatcherServlet = createDispatcherServlet(servletAppContext);
		Assert.notNull(dispatcherServlet, "createDispatcherServlet(WebApplicationContext) must not return null");
		dispatcherServlet.setContextInitializers(getServletApplicationContextInitializers());
		// 设置到servletContext
		ServletRegistration.Dynamic registration = servletContext.addServlet(servletName, dispatcherServlet);
		if (registration == null) {
			throw new IllegalStateException("Failed to register servlet with name '" + servletName + "'. " +
					"Check if there is another servlet registered under the same name.");
		}
		//设置启动顺序
		registration.setLoadOnStartup(1);
		//设置映射
		registration.addMapping(getServletMappings());
		registration.setAsyncSupported(isAsyncSupported());
		// 过滤器设置
		Filter[] filters = getServletFilters();
		if (!ObjectUtils.isEmpty(filters)) {
			for (Filter filter : filters) {
				registerServletFilter(servletContext, filter);
			}
		}

		customizeRegistration(registration);
 }
	---- 略 ----
}
```
以上就是servlet3.0+使用编程式api配置dispatcherServlet。
记住WebApplicationInitializer的所有实现都可以被自动探测到。
Ordering WebApplicationInitializer execution
WebApplicationInitializer implementations may optionally be annotated at the class level with Spring's @Order annotation or may implement Spring's Ordered interface. If so, the initializers will be ordered prior to invocation. This provides a mechanism for users to ensure the order in which servlet container initialization occurs. Use of this feature is expected to be rare, as typical applications will likely centralize all container initialization within a single WebApplicationInitializer.
WebApplicationInitializer执行的排序，WebApplicationInitializer可以被@Order注解在class级别进行标注，也可以实现spring的排序接口，如果是这样，初始化器在调用之前会进行一个排序，略。。。

Caveats
警告
web.xml versioning
web.xml 的版本化
WEB-INF/web.xml and WebApplicationInitializer use are not mutually exclusive; for example, web.xml can register one servlet, and a WebApplicationInitializer can register another. An initializer can even modify registrations performed in web.xml through methods such as ServletContext.getServletRegistration(String). However, if WEB-INF/web.xml is present in the application, its version attribute must be set to "3.0" or greater, otherwise ServletContainerInitializer bootstrapping will be ignored by the servlet container.
Mapping to '/' under Tomcat
Apache Tomcat maps its internal DefaultServlet to "/", and on Tomcat versions <= 7.0.14, this servlet mapping cannot be overridden programmatically. 7.0.15 fixes this issue. Overriding the "/" servlet mapping has also been tested successfully under GlassFish 3.1.
WEB-INF/web.xml和WebApplicationInitializer在使用上并不是互斥的，比如说web.xml 可以注册为一个servlet，WebApplicationInitializer也可以注册另外一个servlet，初始化器甚至可以通过ServletContext.getServletRegistration(String)方法修改在web.xml当中的注册，当然如果web.xml在应用中出现，那么其版本的属性应该设置成3.0或者更大，否则ServletContainerInitializer的启动将会被servlet容器忽略掉。
略。。。

##### 小结
以往的web.xml到了3.0可以使用WebApplicationInitializer的方式替换，而WebApplicationInitializer使用的是spi的机制，可以被自动探测到，并且去执行；对于dispatcherServlet是一个非常重要的组件，所以spring干脆就提供了一个AbstractDispatcherServletInitializer抽象类以及它的实现类AbstractAnnotationConfigDispatcherServletInitializer帮助我们更为轻松的实例化dispatcherServlet。
关于传统的spring mvc和现代的spring boot应用组件之间的对应关系：
1. SpringServletContainerInitializer对应TomcatStarter；
	SpringServletContainerInitializer是通过spi机制，使用servlet 容器加载；TomcatStarter是spring容器new出来的。
2. WebApplicationInitializer对应TomcatStarter里边的ServletContextInitializer；
