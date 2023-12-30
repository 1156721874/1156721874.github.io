---
title: SPRING技术内幕-笔记（七）WEB环境中的springMVC
date: 2018-09-28 19:43:25
tags: spring
categories: spring
---
**7.1Tomcat的web.XML对springMVC 的描述**：
![这里写图片描述](2018/09/28/SPRING技术内幕-笔记（七）WEB环境中的springMVC/20150610221403198.png)

<!-- more -->
dispatcherServlet定义了对应的URL的映射，context-param制定了bean的定义文件的路径，contextLoaderListener作为简历IOC容器的入口，加载IOC容器到servletContext中，即上下文。

**7.2上下文在？WEB容器中的启动**
在WEB容器中启动spring应用的过程：
![这里写图片描述](2018/09/28/SPRING技术内幕-笔记（七）WEB环境中的springMVC/20150610222104616.png)

ContextLoaderListener是一个监听器应为实现了servletAPI的ServletContextListener，就有了contextInitialized，contextDestroyed，而IOC容器的载入过程是由ContextLoaderListener的基类ContextLoader完成的：
他们关系：
![这里写图片描述](2018/09/28/SPRING技术内幕-笔记（七）WEB环境中的springMVC/20150610222828706.png)

**7.3WEB容器中的上下文设置**

WebApplicationContext的上下文设置：
![这里写图片描述](2018/09/28/SPRING技术内幕-笔记（七）WEB环境中的springMVC/20150610223037173.png)

在这个体系中XMLWebAppliocationContext初始化过程中建立了IOC容器：

```
public class XmlWebApplicationContext extends AbstractRefreshableWebApplicationContext {

	/** Default config location for the root context */
	//bean定义文件定义为常量
	public static final String DEFAULT_CONFIG_LOCATION = "/WEB-INF/applicationContext.xml";

	/** Default prefix for building a config location for a namespace */
	  //配置文件父级路径
	public static final String DEFAULT_CONFIG_LOCATION_PREFIX = "/WEB-INF/";

	/** Default suffix for building a config location for a namespace */
	//配置文件默认的后缀名是.XML
	public static final String DEFAULT_CONFIG_LOCATION_SUFFIX = ".xml";


	/**
	 * Loads the bean definitions via an XmlBeanDefinitionReader.
	 * @see org.springframework.beans.factory.xml.XmlBeanDefinitionReader
	 * @see #initBeanDefinitionReader
	 * @see #loadBeanDefinitions
	 */
	@Override
	protected void loadBeanDefinitions(DefaultListableBeanFactory beanFactory) throws BeansException, IOException {
		// Create a new XmlBeanDefinitionReader for the given BeanFactory.
		 //使用XmlBeanDefinitionReader进行BeanDefination的解析
		XmlBeanDefinitionReader beanDefinitionReader = new XmlBeanDefinitionReader(beanFactory);

		// Configure the bean definition reader with this context's
		// resource loading environment.
		beanDefinitionReader.setEnvironment(this.getEnvironment());
		//因为XmlWebApplicationContext 是defaultResourceLoader的子类，因此传入this
		beanDefinitionReader.setResourceLoader(this);
		beanDefinitionReader.setEntityResolver(new ResourceEntityResolver(this));

		// Allow a subclass to provide custom initialization of the reader,
		// then proceed with actually loading the bean definitions.
		//允许子类为reader配置自定的初始化过程
		initBeanDefinitionReader(beanDefinitionReader);
		//使用定义好的XmlBeanDefinitionReader载入BeanDefinition
		loadBeanDefinitions(beanDefinitionReader);
	}
```
loadBeanDefinitions方法代码：
```
//有多个beanDefination定义要逐个载入
	protected void loadBeanDefinitions(XmlBeanDefinitionReader reader) throws IOException {
		String[] configLocations = getConfigLocations();
		if (configLocations != null) {
			for (String configLocation : configLocations) {
				reader.loadBeanDefinitions(configLocation);
			}
		}
	}
```
得到Resource的路径默认是“/WEB-INF/applicationContext.xml”
```
	protected String[] getDefaultConfigLocations() {
		if (getNamespace() != null) {
			return new String[] {DEFAULT_CONFIG_LOCATION_PREFIX + getNamespace() + DEFAULT_CONFIG_LOCATION_SUFFIX};
		}
		else {
			return new String[] {DEFAULT_CONFIG_LOCATION};
		}
	}
```

ContextLoaderListener的contextInitialized初始化：
```
	public void contextInitialized(ServletContextEvent event) {
		this.contextLoader = createContextLoader();
		if (this.contextLoader == null) {
			this.contextLoader = this;
		}
		this.contextLoader.initWebApplicationContext(event.getServletContext());
	}
```
我们再到他的基类ContextLoader中WEB容器的加载过程：

```
public WebApplicationContext initWebApplicationContext(ServletContext servletContext) {
//如果已经加载会抛出异常
		if (servletContext.getAttribute(WebApplicationContext.ROOT_WEB_APPLICATION_CONTEXT_ATTRIBUTE) != null) {
			throw new IllegalStateException(
					"Cannot initialize context because there is already a root application context present - " +
					"check whether you have multiple ContextLoader* definitions in your web.xml!");
		}

		Log logger = LogFactory.getLog(ContextLoader.class);
		servletContext.log("Initializing Spring root WebApplicationContext");
		if (logger.isInfoEnabled()) {
			logger.info("Root WebApplicationContext: initialization started");
		}
		long startTime = System.currentTimeMillis();

		try {
			// Store context in local instance variable, to guarantee that
			// it is available on ServletContext shutdown.
			if (this.context == null) {
			  // 创建上下文
				this.context = createWebApplicationContext(servletContext);
			}
			if (this.context instanceof ConfigurableWebApplicationContext) {
				configureAndRefreshWebApplicationContext((ConfigurableWebApplicationContext)this.context, servletContext);
			}
			 //将创建好的上下文放在servletContext中
			servletContext.setAttribute(WebApplicationContext.ROOT_WEB_APPLICATION_CONTEXT_ATTRIBUTE, this.context);

			ClassLoader ccl = Thread.currentThread().getContextClassLoader();
			if (ccl == ContextLoader.class.getClassLoader()) {
				currentContext = this.context;
			}
			else if (ccl != null) {
				currentContextPerThread.put(ccl, this.context);
			}

			if (logger.isDebugEnabled()) {
				logger.debug("Published root WebApplicationContext as ServletContext attribute with name [" +
						WebApplicationContext.ROOT_WEB_APPLICATION_CONTEXT_ATTRIBUTE + "]");
			}
			if (logger.isInfoEnabled()) {
				long elapsedTime = System.currentTimeMillis() - startTime;
				logger.info("Root WebApplicationContext: initialization completed in " + elapsedTime + " ms");
			}

			return this.context;
		}
		catch (RuntimeException ex) {
			logger.error("Context initialization failed", ex);
			servletContext.setAttribute(WebApplicationContext.ROOT_WEB_APPLICATION_CONTEXT_ATTRIBUTE, ex);
			throw ex;
		}
		catch (Error err) {
			logger.error("Context initialization failed", err);
			servletContext.setAttribute(WebApplicationContext.ROOT_WEB_APPLICATION_CONTEXT_ATTRIBUTE, err);
			throw err;
		}
	}
```
createWebApplicationContext(servletContext)即实例化上下文：

```
	protected WebApplicationContext createWebApplicationContext(ServletContext sc) {
	//探查将那个类在WEB容器中作为IOC容器
		Class<?> contextClass = determineContextClass(sc);
		if (!ConfigurableWebApplicationContext.class.isAssignableFrom(contextClass)) {
			throw new ApplicationContextException("Custom context class [" + contextClass.getName() +
					"] is not of type [" + ConfigurableWebApplicationContext.class.getName() + "]");
		}
		 //实例化IOC 容器
		ConfigurableWebApplicationContext wac =
				(ConfigurableWebApplicationContext) BeanUtils.instantiateClass(contextClass);
		return wac;
	}
```

默认是WebApplicationContext作为容器：

```
	protected Class<?> determineContextClass(ServletContext servletContext) {
	//CONTEXT_CLASS_PARAM是WEB.xml的配置参数
		String contextClassName = servletContext.getInitParameter(CONTEXT_CLASS_PARAM);
		if (contextClassName != null) {
			try {
				return ClassUtils.forName(contextClassName, ClassUtils.getDefaultClassLoader());
			}
			catch (ClassNotFoundException ex) {
				throw new ApplicationContextException(
						"Failed to load custom context class [" + contextClassName + "]", ex);
			}
		}
		else {
		//默认是WebApplicationContext
			contextClassName = defaultStrategies.getProperty(WebApplicationContext.class.getName());
			try {
				return ClassUtils.forName(contextClassName, ContextLoader.class.getClassLoader());
			}
			catch (ClassNotFoundException ex) {
				throw new ApplicationContextException(
						"Failed to load default context class [" + contextClassName + "]", ex);
			}
		}
	}
```

configureAndRefreshWebApplicationContext方法接着设置IOC的各个参数，随后通过refresh启动容器的初始化，refresh参考前边的 FileSystemXmlApplicationContext的IOC的初始化过程。

```
	protected void configureAndRefreshWebApplicationContext(ConfigurableWebApplicationContext wac, ServletContext sc) {
		if (ObjectUtils.identityToString(wac).equals(wac.getId())) {
			// The application context id is still set to its original default value
			// -> assign a more useful id based on available information
			String idParam = sc.getInitParameter(CONTEXT_ID_PARAM);
			if (idParam != null) {
				wac.setId(idParam);
			}
			else {
				// Generate default id...
				if (sc.getMajorVersion() == 2 && sc.getMinorVersion() < 5) {
					// Servlet <= 2.4: resort to name specified in web.xml, if any.
					wac.setId(ConfigurableWebApplicationContext.APPLICATION_CONTEXT_ID_PREFIX +
							ObjectUtils.getDisplayString(sc.getServletContextName()));
				}
				else {
					wac.setId(ConfigurableWebApplicationContext.APPLICATION_CONTEXT_ID_PREFIX +
							ObjectUtils.getDisplayString(sc.getContextPath()));
				}
			}
		}

		// Determine parent for root web application context, if any.
		ApplicationContext parent = loadParentContext(sc);
      //设置双亲上下文
		wac.setParent(parent);
		 //设置servletcontext以及配置文件的位置参数
		wac.setServletContext(sc);
		String initParameter = sc.getInitParameter(CONFIG_LOCATION_PARAM);
		if (initParameter != null) {
			wac.setConfigLocation(initParameter);
		}
		customizeContext(sc, wac);
		//调用refresh初始化IOC容器
		wac.refresh();
	}
```
