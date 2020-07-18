---
title: spring_core(5)注解的注入配置
date: 2020-07-16 19:30:00
tags: [spring annotation]
categories: spring_core
---

本节讲解使用注解的方式加载bean到工厂的过程，其流程和使用xml的方式大同小异。
<!-- more -->
### 事例
定义一个bean：
```
public class Person {
    private int id;
    private  String name;

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }
}
```

定义一个bean的配置类：
```
@Configuration
public class PersonConfiguration {

    @Bean(name="person")
    public Person getPerson(){
        Person  person =  new Person();
        person.setId(222);
        person.setName("kkkk");
        return person;
    }
}
```

新建一个启动类:
```
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

public class SpringClient {
    public static void main(String[] args) {
        //相当于xml方式的工厂，内置了reader和scanner
        AnnotationConfigApplicationContext annotationConfigApplicationContext =
                new AnnotationConfigApplicationContext();
        //相当于xml的读取器要读取的位置
        annotationConfigApplicationContext.register(PersonConfiguration.class);
        //刷新工厂
        annotationConfigApplicationContext.refresh();
        Person person = (Person)annotationConfigApplicationContext.getBean("person");
        System.out.println(person.getId());
        System.out.println(person.getName());
    }
}
```
输出：
222
kkkk

### bean对象创建时机
AnnotationConfigApplicationContext的构造器：
```
private final AnnotatedBeanDefinitionReader reader;

private final ClassPathBeanDefinitionScanner scanner;
public AnnotationConfigApplicationContext() {
  //读取器
  this.reader = new AnnotatedBeanDefinitionReader(this);
  //扫描器
  this.scanner = new ClassPathBeanDefinitionScanner(this);
}
```
#### AnnotatedBeanDefinitionReader
AnnotatedBeanDefinitionReader构造器：
```
public AnnotatedBeanDefinitionReader(BeanDefinitionRegistry registry) {
  this(registry, getOrCreateEnvironment(registry));
}
//Environment封装了properties和profile
public AnnotatedBeanDefinitionReader(BeanDefinitionRegistry registry, Environment environment) {
  Assert.notNull(registry, "BeanDefinitionRegistry must not be null");
  Assert.notNull(environment, "Environment must not be null");
  this.registry = registry;
  this.conditionEvaluator = new ConditionEvaluator(registry, environment, null);
  AnnotationConfigUtils.registerAnnotationConfigProcessors(this.registry);
}
```

org.springframework.context.annotation.AnnotationConfigUtils完成注解配置处理器的注册过程。
```
public static void registerAnnotationConfigProcessors(BeanDefinitionRegistry registry) {
  registerAnnotationConfigProcessors(registry, null);
}

public static Set<BeanDefinitionHolder> registerAnnotationConfigProcessors(
    BeanDefinitionRegistry registry, @Nullable Object source) {
  //得到工厂
  DefaultListableBeanFactory beanFactory = unwrapDefaultListableBeanFactory(registry);
  if (beanFactory != null) {
    if (!(beanFactory.getDependencyComparator() instanceof AnnotationAwareOrderComparator)) {
      beanFactory.setDependencyComparator(AnnotationAwareOrderComparator.INSTANCE);
    }
    if (!(beanFactory.getAutowireCandidateResolver() instanceof ContextAnnotationAutowireCandidateResolver)) {
      beanFactory.setAutowireCandidateResolver(new ContextAnnotationAutowireCandidateResolver());
    }
  }

  Set<BeanDefinitionHolder> beanDefs = new LinkedHashSet<>(8);
  //各种注册处理器的注册
  if (!registry.containsBeanDefinition(CONFIGURATION_ANNOTATION_PROCESSOR_BEAN_NAME)) {
    RootBeanDefinition def = new RootBeanDefinition(ConfigurationClassPostProcessor.class);
    def.setSource(source);
    beanDefs.add(registerPostProcessor(registry, def, CONFIGURATION_ANNOTATION_PROCESSOR_BEAN_NAME));
  }

  if (!registry.containsBeanDefinition(AUTOWIRED_ANNOTATION_PROCESSOR_BEAN_NAME)) {
    RootBeanDefinition def = new RootBeanDefinition(AutowiredAnnotationBeanPostProcessor.class);
    def.setSource(source);
    beanDefs.add(registerPostProcessor(registry, def, AUTOWIRED_ANNOTATION_PROCESSOR_BEAN_NAME));
  }

  // Check for JSR-250 support, and if present add the CommonAnnotationBeanPostProcessor.
  if (jsr250Present && !registry.containsBeanDefinition(COMMON_ANNOTATION_PROCESSOR_BEAN_NAME)) {
    RootBeanDefinition def = new RootBeanDefinition(CommonAnnotationBeanPostProcessor.class);
    def.setSource(source);
    beanDefs.add(registerPostProcessor(registry, def, COMMON_ANNOTATION_PROCESSOR_BEAN_NAME));
  }

  // Check for JPA support, and if present add the PersistenceAnnotationBeanPostProcessor.
  if (jpaPresent && !registry.containsBeanDefinition(PERSISTENCE_ANNOTATION_PROCESSOR_BEAN_NAME)) {
    RootBeanDefinition def = new RootBeanDefinition();
    try {
      def.setBeanClass(ClassUtils.forName(PERSISTENCE_ANNOTATION_PROCESSOR_CLASS_NAME,
          AnnotationConfigUtils.class.getClassLoader()));
    }
    catch (ClassNotFoundException ex) {
      throw new IllegalStateException(
          "Cannot load optional framework class: " + PERSISTENCE_ANNOTATION_PROCESSOR_CLASS_NAME, ex);
    }
    def.setSource(source);
    beanDefs.add(registerPostProcessor(registry, def, PERSISTENCE_ANNOTATION_PROCESSOR_BEAN_NAME));
  }

  if (!registry.containsBeanDefinition(EVENT_LISTENER_PROCESSOR_BEAN_NAME)) {
    RootBeanDefinition def = new RootBeanDefinition(EventListenerMethodProcessor.class);
    def.setSource(source);
    beanDefs.add(registerPostProcessor(registry, def, EVENT_LISTENER_PROCESSOR_BEAN_NAME));
  }

  if (!registry.containsBeanDefinition(EVENT_LISTENER_FACTORY_BEAN_NAME)) {
    RootBeanDefinition def = new RootBeanDefinition(DefaultEventListenerFactory.class);
    def.setSource(source);
    beanDefs.add(registerPostProcessor(registry, def, EVENT_LISTENER_FACTORY_BEAN_NAME));
  }
  //beanDefs里边有如下5个注解处理器：
  //org.springframework.context.annotation.internalConfigurationAnnotationProcessor
  //org.springframework.context.annotation.internalAutowiredAnnotationProcessor
  //org.springframework.context.annotation.internalCommonAnnotationProcessor
  //org.springframework.context.event.internalEventListenerProcessor
  //org.springframework.context.event.internalEventListenerFactory
  return beanDefs;
}
```

#### ClassPathBeanDefinitionScanner
即，从什么地方去扫描我么注解的类或者方法之类的。
ClassPathBeanDefinitionScanner的构造器
```
public ClassPathBeanDefinitionScanner(BeanDefinitionRegistry registry) {
  this(registry, true);
}

public ClassPathBeanDefinitionScanner(BeanDefinitionRegistry registry, boolean useDefaultFilters) {
  this(registry, useDefaultFilters, getOrCreateEnvironment(registry));
}
public ClassPathBeanDefinitionScanner(BeanDefinitionRegistry registry, boolean useDefaultFilters,
    Environment environment) {

  this(registry, useDefaultFilters, environment,
      (registry instanceof ResourceLoader ? (ResourceLoader) registry : null));
}

public ClassPathBeanDefinitionScanner(BeanDefinitionRegistry registry, boolean useDefaultFilters,
    Environment environment, @Nullable ResourceLoader resourceLoader) {

  Assert.notNull(registry, "BeanDefinitionRegistry must not be null");
  this.registry = registry;

  if (useDefaultFilters) {
    registerDefaultFilters();
  }
  setEnvironment(environment);
  setResourceLoader(resourceLoader);
}
```
同样也是对环境以及资源加载器的设置。

####   注册
接下来回到main函数的【annotationConfigApplicationContext.register(PersonConfiguration.class);】
将需要读取的bean，放入到工厂里边，读取入口是PersonConfiguration。
org.springframework.context.annotation.AnnotationConfigApplicationContext
```
//注册一个或多个组件到读取器上，注册完毕之后要调用一下refresh方法
public void register(Class<?>... componentClasses) {
  Assert.notEmpty(componentClasses, "At least one component class must be specified");
  this.reader.register(componentClasses);
}
```
读取器的注册方法：
org.springframework.context.annotation.AnnotatedBeanDefinitionReader
```
public void register(Class<?>... componentClasses) {
  for (Class<?> componentClass : componentClasses) {
    registerBean(componentClass);
  }
}

public void registerBean(Class<?> beanClass) {
  doRegisterBean(beanClass, null, null, null, null);
}

private <T> void doRegisterBean(Class<T> beanClass, @Nullable String name,
    @Nullable Class<? extends Annotation>[] qualifiers, @Nullable Supplier<T> supplier,
    @Nullable BeanDefinitionCustomizer[] customizers) {
      //bean的定义
  AnnotatedGenericBeanDefinition abd = new AnnotatedGenericBeanDefinition(beanClass);
  if (this.conditionEvaluator.shouldSkip(abd.getMetadata())) {
    return;
  }

  abd.setInstanceSupplier(supplier);
  ScopeMetadata scopeMetadata = this.scopeMetadataResolver.resolveScopeMetadata(abd);
  abd.setScope(scopeMetadata.getScopeName());
  //生成bean的名字：personConfiguration
  String beanName = (name != null ? name : this.beanNameGenerator.generateBeanName(abd, this.registry));

  AnnotationConfigUtils.processCommonDefinitionAnnotations(abd);
  if (qualifiers != null) {
    for (Class<? extends Annotation> qualifier : qualifiers) {
      if (Primary.class == qualifier) {
        abd.setPrimary(true);
      }
      else if (Lazy.class == qualifier) {
        abd.setLazyInit(true);
      }
      else {
        abd.addQualifier(new AutowireCandidateQualifier(qualifier));
      }
    }
  }
  if (customizers != null) {
    for (BeanDefinitionCustomizer customizer : customizers) {
      customizer.customize(abd);
    }
  }
  //持有bean定义的持有者，bean的名字，bean的定义，还有bean的别名
  BeanDefinitionHolder definitionHolder = new BeanDefinitionHolder(abd, beanName);
  definitionHolder = AnnotationConfigUtils.applyScopedProxyMode(scopeMetadata, definitionHolder, this.registry);
  //执行注册
  BeanDefinitionReaderUtils.registerBeanDefinition(definitionHolder, this.registry);
}
```
注册逻辑：
org.springframework.beans.factory.support.BeanDefinitionReaderUtils
```
public static void registerBeanDefinition(
    BeanDefinitionHolder definitionHolder, BeanDefinitionRegistry registry)
    throws BeanDefinitionStoreException {

  // Register bean definition under primary name.
  String beanName = definitionHolder.getBeanName();
  //将bean的名字作为key，bean的定义作为value，注册到工厂，注意BeanDefinitionRegistry就是工厂
  registry.registerBeanDefinition(beanName, definitionHolder.getBeanDefinition());

  // Register aliases for bean name, if any.
  String[] aliases = definitionHolder.getAliases();
  if (aliases != null) {
    for (String alias : aliases) {
      registry.registerAlias(beanName, alias);
    }
  }
}
```

#### refresh刷新
【annotationConfigApplicationContext.refresh();】的执行会触发PersonConfiguration.getPerson()方法的执行。
xml的方式创建bean的时机是在getBean的时候(首次从工厂获取bean的时候)创建，但是注解的方式是在refresh的时候会创建bean的实例，
基于注解的配置方式，bean对象的创建是在注解处理器解析相应的@Bean注解时调用了该注解所修饰的方法，当该方法执行后，相应的对象自然就已经被创建出来了，这时，spring就会将该对象纳入到工厂的管理范围之内，当我们首次尝试从工厂获取到该bean对象时，该bean对象实际上已经完成了创建并已经被纳入到工厂的管理范围之内-------**这个是xml的方式和注解的方式的唯一的不同**。

运行程序：
```
public class SpringClient {
    public static void main(String[] args) {
        //相当于xml方式的工厂，内置了reader和scanner
        AnnotationConfigApplicationContext annotationConfigApplicationContext =
                new AnnotationConfigApplicationContext();
        //相当于xml的读取器
        annotationConfigApplicationContext.register(PersonConfiguration.class);
        //刷新工厂
        annotationConfigApplicationContext.refresh();
        PersonConfiguration personConfiguration = (PersonConfiguration)annotationConfigApplicationContext.getBean("personConfiguration");
        Person person = (Person)annotationConfigApplicationContext.getBean("person");
        System.out.println(personConfiguration.getClass());
        System.out.println(person.getClass());
    }
}
```
打印：
class com.tdl.spring.anotation.PersonConfiguration$$EnhancerBySpringCGLIB$$8455c0b9
class com.tdl.spring.anotation.Person
由此可以看到得到的personConfiguration是一个PersonConfiguration的子类，是在运行的时候生成的一个子类（代理类），并且将这个子类放在spring的工厂里边。
refresh方法实现：
org.springframework.context.support.AbstractApplicationContext
```
//
public void refresh() throws BeansException, IllegalStateException {
  synchronized (this.startupShutdownMonitor) {
    // Prepare this context for refreshing.
      //注册监听器、环境的校验、占位符
    prepareRefresh();

    // Tell the subclass to refresh the internal bean factory.
    //返回一个bean工厂，DefaultListableBeanFactory(和xml的方式殊途同归)
    ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

    // Prepare the bean factory for use in this context.
    //配置上下文、bean的类加载器之类的(appClassLoader),一些处理器等
    prepareBeanFactory(beanFactory);

    try {
      // Allows post-processing of the bean factory in context subclasses.
      //bean工厂创建的后置处理器
      postProcessBeanFactory(beanFactory);

      // Invoke factory processors registered as beans in the context.
      //自定义bean的BeanDefinationn被注入(但是没有实例化)
      invokeBeanFactoryPostProcessors(beanFactory);

      // Register bean processors that intercept bean creation.
      //bean的后置处理器
      registerBeanPostProcessors(beanFactory);

      // Initialize message source for this context.
      //初始化消息源
      initMessageSource();

      // Initialize event multicaster for this context.
      initApplicationEventMulticaster();

      // Initialize other special beans in specific context subclasses.
      onRefresh();

      // Check for listener beans and register them.
      registerListeners();

      // Instantiate all remaining (non-lazy-init) singletons.
      //bean的实例初始化和创建。对应PersonConfiguration.getPerson()方法会执行
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

protected void invokeBeanFactoryPostProcessors(ConfigurableListableBeanFactory beanFactory) {
  PostProcessorRegistrationDelegate.invokeBeanFactoryPostProcessors(beanFactory, getBeanFactoryPostProcessors());

  // Detect a LoadTimeWeaver and prepare for weaving, if found in the meantime
  // (e.g. through an @Bean method registered by ConfigurationClassPostProcessor)
  if (beanFactory.getTempClassLoader() == null && beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
    beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
    beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
  }
}

//完成bean工厂的初始化，初始化所有的单例的bean
protected void finishBeanFactoryInitialization(ConfigurableListableBeanFactory beanFactory) {
  // Initialize conversion service for this context.
  if (beanFactory.containsBean(CONVERSION_SERVICE_BEAN_NAME) &&
      beanFactory.isTypeMatch(CONVERSION_SERVICE_BEAN_NAME, ConversionService.class)) {
    beanFactory.setConversionService(
        beanFactory.getBean(CONVERSION_SERVICE_BEAN_NAME, ConversionService.class));
  }

  // Register a default embedded value resolver if no bean post-processor
  // (such as a PropertyPlaceholderConfigurer bean) registered any before:
  // at this point, primarily for resolution in annotation attribute values.
  if (!beanFactory.hasEmbeddedValueResolver()) {
    beanFactory.addEmbeddedValueResolver(strVal -> getEnvironment().resolvePlaceholders(strVal));
  }

  // Initialize LoadTimeWeaverAware beans early to allow for registering their transformers early.
  String[] weaverAwareNames = beanFactory.getBeanNamesForType(LoadTimeWeaverAware.class, false, false);
  for (String weaverAwareName : weaverAwareNames) {
    getBean(weaverAwareName);
  }

  // Stop using the temporary ClassLoader for type matching.
  beanFactory.setTempClassLoader(null);

  // Allow for caching all bean definition metadata, not expecting further changes.
  beanFactory.freezeConfiguration();

  // Instantiate all remaining (non-lazy-init) singletons.
  //初始化单例bean
  beanFactory.preInstantiateSingletons();
}
```
PostProcessorRegistrationDelegate#invokeBeanFactoryPostProcessors的实现：
```
public static void invokeBeanFactoryPostProcessors(
    ConfigurableListableBeanFactory beanFactory, List<BeanFactoryPostProcessor> beanFactoryPostProcessors) {
    ......略
  List<BeanDefinitionRegistryPostProcessor> currentRegistryProcessors = new ArrayList<>();
  BeanDefinitionRegistry registry = (BeanDefinitionRegistry) beanFactory;
  //注册bean定义
	invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
  ......略
}
private static void invokeBeanDefinitionRegistryPostProcessors(
    Collection<? extends BeanDefinitionRegistryPostProcessor> postProcessors, BeanDefinitionRegistry registry) {

  for (BeanDefinitionRegistryPostProcessor postProcessor : postProcessors) {
    postProcessor.postProcessBeanDefinitionRegistry(registry);
  }
}
```
org.springframework.context.annotation.ConfigurationClassPostProcessor#postProcessBeanDefinitionRegistry实现：
```
public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) {
    ......略
  processConfigBeanDefinitions(registry);
}

public void processConfigBeanDefinitions(BeanDefinitionRegistry registry) {
  List<BeanDefinitionHolder> configCandidates = new ArrayList<>();
  String[] candidateNames = registry.getBeanDefinitionNames();

  for (String beanName : candidateNames) {
    //registry是DefaultListableBeanFactory，其持有
    //【	private final Map<String, BeanDefinition> beanDefinitionMap = new ConcurrentHashMap<>(256);】
    //用来存放bean的定义
    BeanDefinition beanDef = registry.getBeanDefinition(beanName);
    if (beanDef.getAttribute(ConfigurationClassUtils.CONFIGURATION_CLASS_ATTRIBUTE) != null) {
      if (logger.isDebugEnabled()) {
        logger.debug("Bean definition has already been processed as a configuration class: " + beanDef);
      }
    }
    else if (ConfigurationClassUtils.checkConfigurationClassCandidate(beanDef, this.metadataReaderFactory)) {
      configCandidates.add(new BeanDefinitionHolder(beanDef, beanName));
    }
  }
      ......略
  //读取被@Bean修饰的方法代表的Bean，加载bean的定义
  /*
  *for (BeanMethod beanMethod : configClass.getBeanMethods()) {
  *  loadBeanDefinitionsForBeanMethod(beanMethod);
  *}  
  this.reader.loadBeanDefinitions(configClasses);
    ......略
```
preInstantiateSingletons的实现：
org.springframework.beans.factory.support.DefaultListableBeanFactory
```
public void preInstantiateSingletons() throws BeansException {
  if (logger.isTraceEnabled()) {
    logger.trace("Pre-instantiating singletons in " + this);
  }

  // Iterate over a copy to allow for init methods which in turn register new bean definitions.
  // While this may not be part of the regular factory bootstrap, it does otherwise work fine.
  List<String> beanNames = new ArrayList<>(this.beanDefinitionNames);

  // Trigger initialization of all non-lazy singleton beans...
  //beanNames：
  //0 = "org.springframework.context.annotation.internalConfigurationAnnotationProcessor"
  //1 = "org.springframework.context.annotation.internalAutowiredAnnotationProcessor"
  //2 = "org.springframework.context.annotation.internalCommonAnnotationProcessor"
  //3 = "org.springframework.context.event.internalEventListenerProcessor"
  //4 = "org.springframework.context.event.internalEventListenerFactory"
  //5 = "personConfiguration"
  //6 = "person"
  for (String beanName : beanNames) {
    //bean的元数据信息
    RootBeanDefinition bd = getMergedLocalBeanDefinition(beanName);
    if (!bd.isAbstract() && bd.isSingleton() && !bd.isLazyInit()) {
      //是不是一个工厂bean
      if (isFactoryBean(beanName)) {
        //getBean和xml的方式的实现是一样的。
        Object bean = getBean(FACTORY_BEAN_PREFIX + beanName);
        if (bean instanceof FactoryBean) {
          final FactoryBean<?> factory = (FactoryBean<?>) bean;
          boolean isEagerInit;
          if (System.getSecurityManager() != null && factory instanceof SmartFactoryBean) {
            isEagerInit = AccessController.doPrivileged((PrivilegedAction<Boolean>)
                    ((SmartFactoryBean<?>) factory)::isEagerInit,
                getAccessControlContext());
          }
          else {
            isEagerInit = (factory instanceof SmartFactoryBean &&
                ((SmartFactoryBean<?>) factory).isEagerInit());
          }
          if (isEagerInit) {
            getBean(beanName);
          }
        }
      }
      else {
        getBean(beanName);
      }
    }
  }
......略
}
```
最终注解的方式也是使用工厂来获取bean的实例，单例的也会缓存到工厂里边。

####  bean的创建和缓存流程
接上次的代码位置。进入getBean方法。
和xml的方式一样，只不过获取bean的流程进行到如下的分支(得到beanWraper)的时候出现了区别：
org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory
```
protected BeanWrapper createBeanInstance(String beanName, RootBeanDefinition mbd, @Nullable Object[] args) {
  // Make sure bean class is actually resolved at this point.
  Class<?> beanClass = resolveBeanClass(mbd, beanName);

  if (beanClass != null && !Modifier.isPublic(beanClass.getModifiers()) && !mbd.isNonPublicAccessAllowed()) {
    throw new BeanCreationException(mbd.getResourceDescription(), beanName,
        "Bean class isn't public, and non-public access not allowed: " + beanClass.getName());
  }

  Supplier<?> instanceSupplier = mbd.getInstanceSupplier();
  if (instanceSupplier != null) {
    return obtainFromSupplier(instanceSupplier, beanName);
  }
  //注解定义的时候会进入这个分支
  if (mbd.getFactoryMethodName() != null) {
    //使用工厂方法(PersonConfiguration.getPerson)
    return instantiateUsingFactoryMethod(beanName, mbd, args);
  }
  ......略
}
//使用工厂方法实例化bean
protected BeanWrapper instantiateUsingFactoryMethod(
    String beanName, RootBeanDefinition mbd, @Nullable Object[] explicitArgs) {

  return new ConstructorResolver(this).instantiateUsingFactoryMethod(beanName, mbd, explicitArgs);
}
```
org.springframework.beans.factory.support.ConstructorResolver实现：
```
public BeanWrapper instantiateUsingFactoryMethod(
    String beanName, RootBeanDefinition mbd, @Nullable Object[] explicitArgs) {
      //bean的包装器
      BeanWrapperImpl bw = new BeanWrapperImpl();
  		this.beanFactory.initBeanWrapper(bw);

  		Object factoryBean;
  		Class<?> factoryClass;
  		boolean isStatic;
      //bean的工厂的名字(personConfiguration)
  		String factoryBeanName = mbd.getFactoryBeanName();
      //设置bean的实例
      bw.setBeanInstance(instantiate(beanName, mbd, factoryBean, uniqueCandidate, EMPTY_ARGS));
      .....略
}
//instantiate实现，即创建bean实例
private Object instantiate(String beanName, RootBeanDefinition mbd,
    @Nullable Object factoryBean, Method factoryMethod, Object[] args) {

  try {
    if (System.getSecurityManager() != null) {
      return AccessController.doPrivileged((PrivilegedAction<Object>) () ->
          this.beanFactory.getInstantiationStrategy().instantiate(
              mbd, beanName, this.beanFactory, factoryBean, factoryMethod, args),
          this.beanFactory.getAccessControlContext());
    }
    else {
      //使用工厂的创建实例的策略创建bean
      return this.beanFactory.getInstantiationStrategy().instantiate(
          mbd, beanName, this.beanFactory, factoryBean, factoryMethod, args);
    }
  }
  catch (Throwable ex) {
    throw new BeanCreationException(mbd.getResourceDescription(), beanName,
        "Bean instantiation via factory method failed", ex);
  }
}
```
this.beanFactory.getInstantiationStrategy().instantiate的实现是
org.springframework.beans.factory.support.SimpleInstantiationStrategy：
```
//使用反射获取bean的实例
public Object instantiate(RootBeanDefinition bd, @Nullable String beanName, BeanFactory owner,
			@Nullable Object factoryBean, final Method factoryMethod, Object... args) {

		try {
			if (System.getSecurityManager() != null) {
				AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
					ReflectionUtils.makeAccessible(factoryMethod);
					return null;
				});
			}
			else {
				ReflectionUtils.makeAccessible(factoryMethod);
			}

			Method priorInvokedFactoryMethod = currentlyInvokedFactoryMethod.get();
			try {
				currentlyInvokedFactoryMethod.set(factoryMethod);
        //factoryMethod: getPerson,
        //factoryBean: com.tdl.spring.anotation.PersonConfiguration$$EnhancerBySpringCGLIB$$8455c0b9,
        //args: getPerson方法的参数
				Object result = factoryMethod.invoke(factoryBean, args);
				if (result == null) {
					result = new NullBean();
				}
				return result;
			}
			finally {
				if (priorInvokedFactoryMethod != null) {
					currentlyInvokedFactoryMethod.set(priorInvokedFactoryMethod);
				}
				else {
					currentlyInvokedFactoryMethod.remove();
				}
			}
		}
		catch (IllegalArgumentException ex) {
			throw new BeanInstantiationException(factoryMethod,
					"Illegal arguments to factory method '" + factoryMethod.getName() + "'; " +
					"args: " + StringUtils.arrayToCommaDelimitedString(args), ex);
		}
		catch (IllegalAccessException ex) {
			throw new BeanInstantiationException(factoryMethod,
					"Cannot access factory method '" + factoryMethod.getName() + "'; is it public?", ex);
		}
		catch (InvocationTargetException ex) {
			String msg = "Factory method '" + factoryMethod.getName() + "' threw exception";
			if (bd.getFactoryBeanName() != null && owner instanceof ConfigurableBeanFactory &&
					((ConfigurableBeanFactory) owner).isCurrentlyInCreation(bd.getFactoryBeanName())) {
				msg = "Circular reference involving containing bean '" + bd.getFactoryBeanName() + "' - consider " +
						"declaring the factory method as static for independence from its containing instance. " + msg;
			}
			throw new BeanInstantiationException(factoryMethod, msg, ex.getTargetException());
		}
	}
```
PersonConfiguration会被当做getPerson的工厂。
【本章代码位置：https://github.com/1156721874/spring-kernel-lecture】
