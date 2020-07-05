---
title: spring_core(1)EnvironmentBuildAndExecuteProcessParse
date: 2020-07-02 22:22:00
tags: [EnvironmentBuildAndExecuteProcessParse spring环境搭建 执行流程分析]
categories: spring_core
---

我们要创建一个spring的工程，然后注册一个bean到容器当中。
### 环境搭建
#### 工程创建
创建工程spring-kernel-lecture，地址: https://github.com/1156721874/spring-kernel-lecture，引入依赖如下:
<!-- more -->
```
dependencies {
    compile(
            "org.springframework:spring-core:5.2.5.RELEASE",
            "org.springframework:spring-aop:5.2.5.RELEASE",
            "org.springframework:spring-beans:5.2.5.RELEASE",
            "org.springframework:spring-context:5.2.5.RELEASE",
            "org.springframework:spring-context-support:5.2.5.RELEASE",
            "org.springframework:spring-web:5.2.5.RELEASE",
            "org.springframework:spring-orm:5.2.5.RELEASE",
            "org.springframework:spring-aspects:5.2.5.RELEASE",
            "org.springframework:spring-webmvc:5.2.5.RELEASE",
            "org.springframework:spring-jdbc:5.2.5.RELEASE",
            "org.springframework:spring-instrument:5.2.5.RELEASE",
            "org.springframework:spring-tx:5.2.5.RELEASE",
            "mysql:mysql-connector-java:8.0.20",
            "org.apache.tomcat:tomcat-jdbc:9.0.34"
    )
}
```

####  新建一个bean class
```
package com.tdl.spring;

import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;

public class SpringClient {
    public static void main(String[] args) {
        Resource resource = new ClassPathResource("applicationContext.xml");

    }
}
```

#### 在applicationContext.xml当中配置bean

```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd">

    <bean id="student" class="com.tdl.spring.bean.Student">
        <property name="name" value="zhangsan"/>
        <property name="age" value="20"/>
    </bean>

</beans>
```

#### 创建资源的抽象:
在spring当中，类路径下的类和文件，文件系统当中的文件，网络上获取的信息等都被抽象为了资源，都是Resource的实现，这次我们要加载的资源是applicationContext.xml当中的bean，因此是从class path下的资源加载，使用ClassPathResource。
```
Resource resource = new ClassPathResource("applicationContext.xml");
```
spring当中的所有bean都会委托bean的工厂来管理，即，ioc.

IOC: [Inverse of control]控制反转
DI： [Dependency Injection] 依赖注入

对象的创建无需用户去创建，而是交给工厂来接手。
#### 工厂的创建
```
 DefaultListableBeanFactory defaultListableBeanFactory = new DefaultListableBeanFactory();
```
工厂创建完毕之后，我们要使用读取器读取资源，然后把资源放到工厂里边。
#### bean的读取器
```
BeanDefinitionReader beanDefinitionReader =
  new XmlBeanDefinitionReader(defaultListableBeanFactory);
  beanDefinitionReader.loadBeanDefinitions(resource);
```
XmlBeanDefinitionReader是xml文件读取器，它将要从applicationContext.xml读取资源，然后放到defaultListableBeanFactory
里边。

#### 从工厂获取bean
```
        Student student = defaultListableBeanFactory.getBean("student", Student.class);
        System.out.println(student.getName());
        System.out.println(student.getAge());
```

#### 小结
以上步骤汇总 就是一个spring的标准的过程。
```
import com.tdl.spring.bean.Student;
import org.springframework.beans.factory.support.BeanDefinitionReader;
import org.springframework.beans.factory.support.DefaultListableBeanFactory;
import org.springframework.beans.factory.xml.XmlBeanDefinitionReader;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;

public class SpringClient {
    public static void main(String[] args) {
        Resource resource = new ClassPathResource("applicationContext.xml");
        DefaultListableBeanFactory defaultListableBeanFactory
                = new DefaultListableBeanFactory();
        BeanDefinitionReader beanDefinitionReader =
                new XmlBeanDefinitionReader(defaultListableBeanFactory);
        beanDefinitionReader.loadBeanDefinitions(resource);

        Student student = defaultListableBeanFactory.getBean("student", Student.class);
        System.out.println(student.getName());
        System.out.println(student.getAge());

    }
}
```
关于spring容器管理bean以及加载模式：
1. 需要将bean的定义信息声明在bean的配置文件当中。
2. 需要通过spring抽象出的各种Resource来指定对应的配置文件。
3. 需要显式声明一个spring工厂，该工厂用来掌控我们在配置文件中所声明的各种bean以及bean之间的依赖关系与注入关系。
4. 需要定义一个配置信息读取器，该读取器用来读取之前所定义的bean配置文件信息。
5. 读取器的作用是读取我们所声明的配置文件信息，并且将读取后的信息装配到之前所声明的工厂当中。
6. 需要将读取器与工厂以及资源对象进行相应的关联处理。
7. 工厂所管理的全部对象装配完毕，可以供客户端直接调用，获取客户端想要使用的各种bean对象。

spring 对于bean管理的核心组件：
1. 资源抽象
2. 工厂
3. 配置信息读取器

BeanFactory：
BeanFactory是spring bean工厂最顶层的抽象
The root interface for accessing a Spring bean container. This is the basic client view of a bean container; further interfaces such as ListableBeanFactory and org.springframework.beans.factory.config.ConfigurableBeanFactory are available for specific purposes.

spring bean容器最根的访问接入接口，是客户端展现的基础bean容器，更进一步像ListableBeanFactory、ListableBeanFactory都是对特定目的使用的实现。
```
org.springframework.beans.factory.BeanFactory
org.springframework.beans.factory.BeanFactory#getBean(java.lang.String)
org.springframework.beans.factory.BeanFactory#getBean(java.lang.String, java.lang.Class<T>)
org.springframework.beans.factory.BeanFactory#getBean(java.lang.String, java.lang.Object...)
org.springframework.beans.factory.BeanFactory#getBean(java.lang.Class<T>)
org.springframework.beans.factory.BeanFactory#getBean(java.lang.Class<T>, java.lang.Object...)
org.springframework.beans.factory.BeanFactory#getBeanProvider(java.lang.Class<T>)
org.springframework.beans.factory.BeanFactory#getBeanProvider(org.springframework.core.ResolvableType)
org.springframework.beans.factory.BeanFactory#containsBean
org.springframework.beans.factory.BeanFactory#isSingleton
org.springframework.beans.factory.BeanFactory#isPrototype
org.springframework.beans.factory.BeanFactory#isTypeMatch(java.lang.String, org.springframework.core.ResolvableType)
org.springframework.beans.factory.BeanFactory#isTypeMatch(java.lang.String, java.lang.Class<?>)
org.springframework.beans.factory.BeanFactory#getType(java.lang.String)
org.springframework.beans.factory.BeanFactory#getType(java.lang.String, boolean)
org.springframework.beans.factory.BeanFactory#getAliases
org.springframework.beans.factory.BeanFactory#FACTORY_BEAN_PREFIX
```

实现类： DefaultListableBeanFactory

Resource：
Interface for a resource descriptor that abstracts from the actual type of underlying resource, such as a file or class path resource.
对实际资源的一个抽象描述，比如文件 、class path下的资源。


### ClassPathResource
首先看一下ClassPathResource的构造器：
```
public ClassPathResource(String path) {
  this(path, (ClassLoader) null);
}

public ClassPathResource(String path, @Nullable ClassLoader classLoader) {
  Assert.notNull(path, "Path must not be null");
  //将windows下的路径分割标示替换为标准的路径分割、路径中存在"."的话要进行处理。
  String pathToUse = StringUtils.cleanPath(path);
  //以"/"开头的路径把"/"去掉
  if (pathToUse.startsWith("/")) {
    pathToUse = pathToUse.substring(1);
  }
  this.path = pathToUse;
  this.classLoader = (classLoader != null ? classLoader : ClassUtils.getDefaultClassLoader());
}

public static ClassLoader getDefaultClassLoader() {
  ClassLoader cl = null;
  try {
    //使用当前上下文类加载器
    cl = Thread.currentThread().getContextClassLoader();
  }
  catch (Throwable ex) {
    // Cannot access thread context ClassLoader - falling back...
  }
  //当前上下文类加载器为null则使用ClassUtils的类加载器
  if (cl == null) {
    // No thread context class loader -> use class loader of this class.
    cl = ClassUtils.class.getClassLoader();
    //ClassUtils的类加载器为空，意味着ClassUtils的类加载器是启动类加载器，那么使用系统类加载器加载
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
//提供类路径和class参数的构造器，有了class就可以使用class的类加载器
public ClassPathResource(String path, @Nullable Class<?> clazz) {
  Assert.notNull(path, "Path must not be null");
  this.path = StringUtils.cleanPath(path);
  this.clazz = clazz;
}
//不被推荐使用的构造器，因为即提供了类加载器又提供了class，造成了歧义和冗余
@Deprecated
protected ClassPathResource(String path, @Nullable ClassLoader classLoader, @Nullable Class<?> clazz) {
  this.path = StringUtils.cleanPath(path);
  this.classLoader = classLoader;
  this.clazz = clazz;
}
```

### DefaultListableBeanFactory
构造器：
```
public DefaultListableBeanFactory() {
  super();
}
```
DefaultListableBeanFactory的父接口AbstractAutowireCapableBeanFactory
```
  /**
	 * Dependency interfaces to ignore on dependency check and autowire, as Set of
	 * Class objects. By default, only the BeanFactory interface is ignored.
	 */
	private final Set<Class<?>> ignoredDependencyInterfaces = new HashSet<>();
public AbstractAutowireCapableBeanFactory() {
  super();
  ignoreDependencyInterface(BeanNameAware.class);
  ignoreDependencyInterface(BeanFactoryAware.class);
  ignoreDependencyInterface(BeanClassLoaderAware.class);
}
public void ignoreDependencyInterface(Class<?> ifc) {
  this.ignoredDependencyInterfaces.add(ifc);
}
````
ignoreDependencyInterface的作用是忽略掉ignoredDependencyInterfaces集合里边接口的实现的bean，这些bean不会进行依赖注入
AbstractAutowireCapableBeanFactory的父类AbstractBeanFactory
```
public AbstractBeanFactory() {
}
```

### XmlBeanDefinitionReader
BeanDefinitionReader beanDefinitionReader =  new XmlBeanDefinitionReader(defaultListableBeanFactory);
defaultListableBeanFactory实现了BeanDefinitionRegistry接口。
构造器：
```
public XmlBeanDefinitionReader(BeanDefinitionRegistry registry) {
  super(registry);
}
```
XmlBeanDefinitionReader继承了AbstractBeanDefinitionReader:
```
protected AbstractBeanDefinitionReader(BeanDefinitionRegistry registry) {
  Assert.notNull(registry, "BeanDefinitionRegistry must not be null");
  this.registry = registry;

  // Determine ResourceLoader to use.
  //判断defaultListableBeanFactory是否实现了ResourceLoader，如果实现了ResourceLoader，赋值给resourceLoader
  /ResourceLoader: Strategy interface for loading resources (e.. class path or file system resources)
  // ResourceLoader是用来加载文件，classpath下的文件的策略接口
  if (this.registry instanceof ResourceLoader) {
    this.resourceLoader = (ResourceLoader) this.registry;
  }
  else {
    //否则，创建一个PathMatchingResourcePatternResolver(内部封装了类加载器的逻辑，即ClassUtils.getDefaultClassLoader())
    this.resourceLoader = new PathMatchingResourcePatternResolver();
  }

  // Inherit Environment if possible
  //defaultListableBeanFactory实现了EnvironmentCapable，直接得到环境对象
  if (this.registry instanceof EnvironmentCapable) {
    this.environment = ((EnvironmentCapable) this.registry).getEnvironment();
  }
  else {
    //否则直接new 一个StandardEnvironment
    this.environment = new StandardEnvironment();
  }
}
```

#### Environment
Interface representing the environment in which the current application is running. Models two key aspects of the application environment: profiles and properties. Methods related to property access are exposed via the PropertyResolver superinterface.
代表当前应用运行的环境的接口，对2个方面的应用环境进行处理：profiles和properties。
属性的接入是通过暴露的PropertyResolver接口进行的。
profiles：决定应用运行在什么环境之下，dev，test，uat，pro etc。
properties: 应用当中运行的各种属性。
```
public interface Environment extends PropertyResolver {
  org.springframework.core.env.Environment#getActiveProfiles
  org.springframework.core.env.Environment#getDefaultProfiles
  org.springframework.core.env.Environment#acceptsProfiles(java.lang.String...)
  org.springframework.core.env.Environment#acceptsProfiles(org.springframework.core.env.Profiles)
}
```
Environment继承了PropertyResolver，得到了处理属性(properties)相关的功能。

### 加载BeanDefinition
beanDefinitionReader.loadBeanDefinitions(resource);
```
public int loadBeanDefinitions(Resource resource) throws BeanDefinitionStoreException {
  return loadBeanDefinitions(new EncodedResource(resource));
}
public int loadBeanDefinitions(EncodedResource encodedResource) throws BeanDefinitionStoreException {
  Assert.notNull(encodedResource, "EncodedResource must not be null");
  if (logger.isTraceEnabled()) {
    logger.trace("Loading XML bean definitions from " + encodedResource);
  }
  //resourcesCurrentlyBeingLoaded是一个ThreadLocal
  Set<EncodedResource> currentResources = this.resourcesCurrentlyBeingLoaded.get();
  if (currentResources == null) {
    currentResources = new HashSet<>(4);
    this.resourcesCurrentlyBeingLoaded.set(currentResources);
  }
  // 循环导入，即存在一个资源被导入2次，一般出现在嵌套循环依赖里边。
  if (!currentResources.add(encodedResource)) {
    throw new BeanDefinitionStoreException(
        "Detected cyclic loading of " + encodedResource + " - check your import definitions!");
  }
  //InputStream是Closeable的，不需要手动关闭流
  try (InputStream inputStream = encodedResource.getResource().getInputStream()) {
    //InputSource是对xml解析sax方式的封装，InputSource是通过流的方式进行解析的
    InputSource inputSource = new InputSource(inputStream);
    //编码设置
    if (encodedResource.getEncoding() != null) {
      inputSource.setEncoding(encodedResource.getEncoding());
    }
    return doLoadBeanDefinitions(inputSource, encodedResource.getResource());
  }
  catch (IOException ex) {
    //解析xml文档异常
    throw new BeanDefinitionStoreException(
        "IOException parsing XML document from " + encodedResource.getResource(), ex);
  }
  finally {
    //防止内存泄露
    currentResources.remove(encodedResource);
    if (currentResources.isEmpty()) {
      this.resourcesCurrentlyBeingLoaded.remove();
    }
  }
}
```
EncodedResource的底层构造器，将参数Resource赋值给resource，encoding和encoding是编码方式，
不能同时都设置。EncodedResource封装了待加载的资源以及资源的编码方式。
```
private EncodedResource(Resource resource, @Nullable String encoding, @Nullable Charset charset) {
  super();
  Assert.notNull(resource, "Resource must not be null");
  this.resource = resource;
  this.encoding = encoding;
  this.encoding = charset;
}
```

#### 从指定的文件里边加载bean
loadBeanDefinitions返回的int是加载的bean的数量，doLoadBeanDefinitions完成真正的加载
XmlBeanDefinitionReader:
```
private DocumentLoader documentLoader = new DefaultDocumentLoader();
private Class<? extends BeanDefinitionDocumentReader> documentReaderClass =
    DefaultBeanDefinitionDocumentReader.class;
protected int doLoadBeanDefinitions(InputSource inputSource, Resource resource)
    throws BeanDefinitionStoreException {

  try {
    //读取并解析，Document代表整个xml文档
    Document doc = doLoadDocument(inputSource, resource);
    //注册bean的定义
    int count = registerBeanDefinitions(doc, resource);
    if (logger.isDebugEnabled()) {
      logger.debug("Loaded " + count + " bean definitions from " + resource);
    }
    return count;
  }
  ......
}

public int registerBeanDefinitions(Document doc, Resource resource) throws BeanDefinitionStoreException {
  //创建一个读取xml文档BeanDefinition的读取器
  BeanDefinitionDocumentReader documentReader = createBeanDefinitionDocumentReader();
  //解析之前的bean的个数，
  int countBefore = getRegistry().getBeanDefinitionCount();
  documentReader.registerBeanDefinitions(doc, createReaderContext(resource));
  //解析之后bean的个数减去解析之前的bean的个数，这种出现不一致的情况往往是由于xml里边有import的情况导致的。
  return getRegistry().getBeanDefinitionCount() - countBefore;
}

protected BeanDefinitionDocumentReader createBeanDefinitionDocumentReader() {
  return BeanUtils.instantiateClass(this.documentReaderClass);
}
......
```

BeanUtils的相关方法：
```
public static <T> T instantiateClass(Class<T> clazz) throws BeanInstantiationException {
  Assert.notNull(clazz, "Class must not be null");
  if (clazz.isInterface()) {
    throw new BeanInstantiationException(clazz, "Specified class is an interface");
  }
  try {
    return instantiateClass(clazz.getDeclaredConstructor());
  }
  catch (NoSuchMethodException ex) {
    //找不到方法通过另外一种方式进行，findPrimaryConstructor使用的是kotlin的方式
    Constructor<T> ctor = findPrimaryConstructor(clazz);
    if (ctor != null) {
      //反射进行实例化
      return instantiateClass(ctor);
    }
    throw new BeanInstantiationException(clazz, "No default constructor found", ex);
  }
  catch (LinkageError err) {
    throw new BeanInstantiationException(clazz, "Unresolvable class definition", err);
  }
}

public static <T> T instantiateClass(Constructor<T> ctor, Object... args) throws BeanInstantiationException {
  Assert.notNull(ctor, "Constructor must not be null");
  try {
    //突破访问修饰符的限制
    ReflectionUtils.makeAccessible(ctor);
    //对kotlin的支持
    if (KotlinDetector.isKotlinReflectPresent() && KotlinDetector.isKotlinType(ctor.getDeclaringClass())) {
      return KotlinDelegate.instantiateClass(ctor, args);
    }
    else {
      //得到构造器的参数
      Class<?>[] parameterTypes = ctor.getParameterTypes();
      Assert.isTrue(args.length <= parameterTypes.length, "Can't specify more arguments than constructor parameters");
      Object[] argsWithDefaultValues = new Object[args.length];
      for (int i = 0 ; i < args.length; i++) {
        if (args[i] == null) {
          Class<?> parameterType = parameterTypes[i];
          argsWithDefaultValues[i] = (parameterType.isPrimitive() ? DEFAULT_TYPE_VALUES.get(parameterType) : null);
        }
        else {
          argsWithDefaultValues[i] = args[i];
        }
      }
      //反射得到实例
      return ctor.newInstance(argsWithDefaultValues);
    }
  }
......
}
```
BeanDefinitionDocumentReader构建完毕之后，接下来就是文档的解析和bean的注册。

回到XmlBeanDefinitionReader的registerBeanDefinitions方法，继续往下分析
【documentReader.registerBeanDefinitions(doc, createReaderContext(resource));】
DefaultBeanDefinitionDocumentReader:
```
public void registerBeanDefinitions(Document doc, XmlReaderContext readerContext) {
  this.readerContext = readerContext;
  doRegisterBeanDefinitions(doc.getDocumentElement());
}

//在给定的root元素下，注册每个bean的定义
protected void doRegisterBeanDefinitions(Element root) {
  // Any nested <beans> elements will cause recursion in this method. In
  // order to propagate and preserve <beans> default-* attributes correctly,
  // keep track of the current (parent) delegate, which may be null. Create
  // the new (child) delegate with a reference to the parent for fallback purposes,
  // then ultimately reset this.delegate back to its original (parent) reference.
  // this behavior emulates a stack of delegates without actually necessitating one.
  // 任何嵌套的元素都可能导致递归。

  //this.delegate是一种委托，这里使用了委托的设计模式
  BeanDefinitionParserDelegate parent = this.delegate;
  this.delegate = createDelegate(getReaderContext(), root, parent);

  if (this.delegate.isDefaultNamespace(root)) {
    String profileSpec = root.getAttribute(PROFILE_ATTRIBUTE);
    if (StringUtils.hasText(profileSpec)) {
      String[] specifiedProfiles = StringUtils.tokenizeToStringArray(
          profileSpec, BeanDefinitionParserDelegate.MULTI_VALUE_ATTRIBUTE_DELIMITERS);
      // We cannot use Profiles.of(...) since profile expressions are not supported
      // in XML config. See SPR-12458 for details.
      if (!getReaderContext().getEnvironment().acceptsProfiles(specifiedProfiles)) {
        if (logger.isDebugEnabled()) {
          logger.debug("Skipped XML bean definition file due to specified profiles [" + profileSpec +
              "] not matching: " + getReaderContext().getResource());
        }
        return;
      }
    }
  }
  //默认空实现，留给用户的扩展【模板方法模式】
  preProcessXml(root);
  //从root开始解析【模板方法模式】
  parseBeanDefinitions(root, this.delegate);
  //默认空实现，留给用户的扩展【模板方法模式】
  postProcessXml(root);

  this.delegate = parent;
}

protected void parseBeanDefinitions(Element root, BeanDefinitionParserDelegate delegate) {
  //根元素的解析
  if (delegate.isDefaultNamespace(root)) {
    NodeList nl = root.getChildNodes();
    for (int i = 0; i < nl.getLength(); i++) {
      Node node = nl.item(i);
      //xml当中的注释(<!-- -->)也会被加载，但是不是Element对象
      if (node instanceof Element) {
        Element ele = (Element) node;
        //默认命名空间
        if (delegate.isDefaultNamespace(ele)) {
          parseDefaultElement(ele, delegate);
        }
        else {
          delegate.parseCustomElement(ele);
        }
      }
    }
  }
  else {
    //默认命名空间之外的元素
    delegate.parseCustomElement(root);
  }
}
//某个元素的解析都是由委托对象完成的
private void parseDefaultElement(Element ele, BeanDefinitionParserDelegate delegate) {
  //impot是顶级元素
  if (delegate.nodeNameEquals(ele, IMPORT_ELEMENT)) {
    //读取另外一个xml文件进行加载
    importBeanDefinitionResource(ele);
  }
  //alias是顶级元素
  else if (delegate.nodeNameEquals(ele, ALIAS_ELEMENT)) {
    processAliasRegistration(ele);
  }
  //bean是顶级元素
  else if (delegate.nodeNameEquals(ele, BEAN_ELEMENT)) {
    processBeanDefinition(ele, delegate);
  }
  //嵌套的情况
  else if (delegate.nodeNameEquals(ele, NESTED_BEANS_ELEMENT)) {
    // recurse
    //递归调用
    doRegisterBeanDefinitions(ele);
  }
}
//bean元素的解析和注册
protected void processBeanDefinition(Element ele, BeanDefinitionParserDelegate delegate) {
  //解析bean的定义，构造成BeanDefinitionHolder，是bean的完整的定义
  BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);
  if (bdHolder != null) {
    //对bean的定义进行最终修饰
    bdHolder = delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);
    try {
      // Register the final decorated instance.
      //bdHolder是解析出来的bean的定义信息，getReaderContext().getRegistry()是工厂，即
      //将bean注册到工厂里边
      BeanDefinitionReaderUtils.registerBeanDefinition(bdHolder, getReaderContext().getRegistry());
    }
    catch (BeanDefinitionStoreException ex) {
      getReaderContext().error("Failed to register bean definition with name '" +
          bdHolder.getBeanName() + "'", ele, ex);
    }
    // Send registration event.
    getReaderContext().fireComponentRegistered(new BeanComponentDefinition(bdHolder));
  }
}
```
delegate.parseBeanDefinitionElement(ele)完成对Element的解析：
BeanDefinitionParserDelegate:
```
public BeanDefinitionHolder parseBeanDefinitionElement(Element ele) {
  return parseBeanDefinitionElement(ele, null);
}

public BeanDefinitionHolder parseBeanDefinitionElement(Element ele, @Nullable BeanDefinition containingBean) {
  //bean的id
  String id = ele.getAttribute(ID_ATTRIBUTE);
  //bean的name
  String nameAttr = ele.getAttribute(NAME_ATTRIBUTE);

  List<String> aliases = new ArrayList<>();
  if (StringUtils.hasLength(nameAttr)) {
    String[] nameArr = StringUtils.tokenizeToStringArray(nameAttr, MULTI_VALUE_ATTRIBUTE_DELIMITERS);
    aliases.addAll(Arrays.asList(nameArr));
  }

  String beanName = id;
  if (!StringUtils.hasText(beanName) && !aliases.isEmpty()) {
    beanName = aliases.remove(0);
    if (logger.isTraceEnabled()) {
      logger.trace("No XML 'id' specified - using '" + beanName +
          "' as bean name and " + aliases + " as aliases");
    }
  }

  if (containingBean == null) {
    //bean名称唯一性检查
    checkNameUniqueness(beanName, aliases, ele);
  }
  //parseBeanDefinitionElement里边会解析xml得到bean的class的名字
  AbstractBeanDefinition beanDefinition = parseBeanDefinitionElement(ele, beanName, containingBean);
  if (beanDefinition != null) {
    if (!StringUtils.hasText(beanName)) {
      try {
        if (containingBean != null) {
          //definition.getParentName() + "$child" + "#1" or
          //definition.getFactoryBeanName() + "$created" + "#1"
          beanName = BeanDefinitionReaderUtils.generateBeanName(
              beanDefinition, this.readerContext.getRegistry(), true);
        }
        else {
          beanName = this.readerContext.generateBeanName(beanDefinition);
          // Register an alias for the plain bean class name, if still possible,
          // if the generator returned the class name plus a suffix.
          // This is expected for Spring 1.2/2.0 backwards compatibility.
          //获取到bean的类的名字，类的全限定名
          String beanClassName = beanDefinition.getBeanClassName();
          if (beanClassName != null &&
              beanName.startsWith(beanClassName) && beanName.length() > beanClassName.length() &&
              !this.readerContext.getRegistry().isBeanNameInUse(beanClassName)) {
            aliases.add(beanClassName);
          }
        }
        if (logger.isTraceEnabled()) {
          logger.trace("Neither XML 'id' nor 'name' specified - " +
              "using generated bean name [" + beanName + "]");
        }
      }
      catch (Exception ex) {
        error(ex.getMessage(), ele);
        return null;
      }
    }
    String[] aliasesArray = StringUtils.toStringArray(aliases);
    //BeanDefinitionHolder持有beanDefinition、bean的名字，bean的别名数组
    return new BeanDefinitionHolder(beanDefinition, beanName, aliasesArray);
  }

  return null;
}
	public static final String CLASS_ATTRIBUTE = "class";
public AbstractBeanDefinition parseBeanDefinitionElement(
    Element ele, String beanName, @Nullable BeanDefinition containingBean) {

  this.parseState.push(new BeanEntry(beanName));
  //bean的类型解析
  String className = null;
  if (ele.hasAttribute(CLASS_ATTRIBUTE)) {
    className = ele.getAttribute(CLASS_ATTRIBUTE).trim();
  }
  String parent = null;
  if (ele.hasAttribute(PARENT_ATTRIBUTE)) {
    parent = ele.getAttribute(PARENT_ATTRIBUTE);
  }

  try {
    //创建AbstractBeanDefinition
    AbstractBeanDefinition bd = createBeanDefinition(className, parent);
    //bean的属性的解析
    parseBeanDefinitionAttributes(ele, beanName, containingBean, bd);
    //描述相关信息设置
    bd.setDescription(DomUtils.getChildElementValueByTagName(ele, DESCRIPTION_ELEMENT));
    //元数据信息配置
    parseMetaElements(ele, bd);
    parseLookupOverrideSubElements(ele, bd.getMethodOverrides());
    parseReplacedMethodSubElements(ele, bd.getMethodOverrides());
    //构造方法的参数的解析(bean的注入方式一种是set的方式注入(属性注入)，一种是构造器的注入)
    parseConstructorArgElements(ele, bd);
    //属性解析(属性注入)，包括ref属性，value属性等
    parsePropertyElements(ele, bd);
    //qualifier解析
    parseQualifierElements(ele, bd);

    bd.setResource(this.readerContext.getResource());
    bd.setSource(extractSource(ele));

    return bd;
  }
  catch (ClassNotFoundException ex) {
    error("Bean class [" + className + "] not found", ele, ex);
  }
  catch (NoClassDefFoundError err) {
    error("Class that bean class [" + className + "] depends on not found", ele, err);
  }
  catch (Throwable ex) {
    error("Unexpected failure during bean definition parsing", ele, ex);
  }
  finally {
    this.parseState.pop();
  }

  return null;
}

protected AbstractBeanDefinition createBeanDefinition(@Nullable String className, @Nullable String parentName)
    throws ClassNotFoundException {

  return BeanDefinitionReaderUtils.createBeanDefinition(
      parentName, className, this.readerContext.getBeanClassLoader());
}
```
BeanDefinitionReaderUtils根据类名和bean的父级名称封装为AbstractBeanDefinition.
BeanDefinitionReaderUtils:
```
public static AbstractBeanDefinition createBeanDefinition(
    @Nullable String parentName, @Nullable String className, @Nullable ClassLoader classLoader) throws ClassNotFoundException {

  GenericBeanDefinition bd = new GenericBeanDefinition();
  bd.setParentName(parentName);
  if (className != null) {
    if (classLoader != null) {
      //设置bean的class对象
      bd.setBeanClass(ClassUtils.forName(className, classLoader));
    }
    else {
      //classloader是空的情况，直接返回类对象的名字
      bd.setBeanClassName(className);
    }
  }
  return bd;
}
```
GenericBeanDefinition是AbstractBeanDefinition的子类。
AbstractBeanDefinition的setBeanClass和setBeanClassName都是对同一个成员变量的赋值：
```
private volatile Object beanClass;
public void setBeanClass(@Nullable Class<?> beanClass) {
  this.beanClass = beanClass;
}
public void setBeanClassName(@Nullable String beanClassName) {
  this.beanClass = beanClassName;
}

public String getBeanClassName() {
  Object beanClassObject = this.beanClass;
  if (beanClassObject instanceof Class) {
    return ((Class<?>) beanClassObject).getName();
  }
  else {
    return (String) beanClassObject;
  }
}
```

ClassUtils.forName是jdk的Class.forName的增强:
```
public static Class<?> forName(String name, @Nullable ClassLoader classLoader)
    throws ClassNotFoundException, LinkageError {

  Assert.notNull(name, "Name must not be null");
  //原生类型的解析
  Class<?> clazz = resolvePrimitiveClassName(name);
  if (clazz == null) {
    clazz = commonClassCache.get(name);
  }
  if (clazz != null) {
    return clazz;
  }
  //数组类型的解析
  // "java.lang.String[]" style arrays
  if (name.endsWith(ARRAY_SUFFIX)) {
    String elementClassName = name.substring(0, name.length() - ARRAY_SUFFIX.length());
    Class<?> elementClass = forName(elementClassName, classLoader);
    return Array.newInstance(elementClass, 0).getClass();
  }

  // "[Ljava.lang.String;" style arrays
  if (name.startsWith(NON_PRIMITIVE_ARRAY_PREFIX) && name.endsWith(";")) {
    String elementName = name.substring(NON_PRIMITIVE_ARRAY_PREFIX.length(), name.length() - 1);
    Class<?> elementClass = forName(elementName, classLoader);
    return Array.newInstance(elementClass, 0).getClass();
  }

  // "[[I" or "[[Ljava.lang.String;" style arrays
  if (name.startsWith(INTERNAL_ARRAY_PREFIX)) {
    String elementName = name.substring(INTERNAL_ARRAY_PREFIX.length());
    Class<?> elementClass = forName(elementName, classLoader);
    return Array.newInstance(elementClass, 0).getClass();
  }

  ClassLoader clToUse = classLoader;
  if (clToUse == null) {
    clToUse = getDefaultClassLoader();
  }
  try {
    //调用jdk的Class.forName返回class的对象
    return Class.forName(name, false, clToUse);
  }
  catch (ClassNotFoundException ex) {
    int lastDotIndex = name.lastIndexOf(PACKAGE_SEPARATOR);
    if (lastDotIndex != -1) {
      String innerClassName =
          name.substring(0, lastDotIndex) + INNER_CLASS_SEPARATOR + name.substring(lastDotIndex + 1);
      try {
        return Class.forName(innerClassName, false, clToUse);
      }
      catch (ClassNotFoundException ex2) {
        // Swallow - let original exception get through
      }
    }
    throw ex;
  }
}
```
回到BeanDefinitionParserDelegate的parseBeanDefinitionElement方法，【AbstractBeanDefinition bd = createBeanDefinition(className, parent);】创建完毕之后，接下里是parseBeanDefinitionAttributes()，完成bean的属性的解析:
```
private static final String SINGLETON_ATTRIBUTE = "singleton";
public AbstractBeanDefinition parseBeanDefinitionAttributes(Element ele, String beanName,
    @Nullable BeanDefinition containingBean, AbstractBeanDefinition bd) {
      //bean的作用域范围是singleton的时候不支持，报告错误【历史遗留问题】
      if (ele.hasAttribute(SINGLETON_ATTRIBUTE)) {
        error("Old 1.x 'singleton' attribute in use - upgrade to 'scope' declaration", ele);
      }
      else if (ele.hasAttribute(SCOPE_ATTRIBUTE)) {
        //将scope的值取出来，然后设置到AbstractBeanDefinition里边，默认是singleton。
        bd.setScope(ele.getAttribute(SCOPE_ATTRIBUTE));
      }
    }
```
parseBeanDefinitionAttributes方法会对很对属性进行解析和配置:
![bean-attribute.png](bean-attribute.png)

#### 将bean注册到工厂
回到DefaultBeanDefinitionDocumentReader的processBeanDefinition方法：
```
//bean元素的解析和注册
protected void processBeanDefinition(Element ele, BeanDefinitionParserDelegate delegate) {
  //解析bean的定义，构造成BeanDefinitionHolder，是bean的完整的定义
  BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);
  if (bdHolder != null) {
    //对bean的定义进行最终修饰
    bdHolder = delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);
    try {
      // Register the final decorated instance.
      //bdHolder是解析出来的bean的定义信息，getReaderContext().getRegistry()是工厂，即
      //将bean注册到工厂里边
      BeanDefinitionReaderUtils.registerBeanDefinition(bdHolder, getReaderContext().getRegistry());
    }
    catch (BeanDefinitionStoreException ex) {
      getReaderContext().error("Failed to register bean definition with name '" +
          bdHolder.getBeanName() + "'", ele, ex);
    }
    // Send registration event.
    getReaderContext().fireComponentRegistered(new BeanComponentDefinition(bdHolder));
  }
}
```
经过对bean的解析，我们得到了bean的定义BeanDefinitionHolder。
接下来时注册bean的定义到工厂里边，即【BeanDefinitionReaderUtils.registerBeanDefinition(bdHolder, getReaderContext().getRegistry());】
BeanDefinitionReaderUtils:
```
public static void registerBeanDefinition(
    BeanDefinitionHolder definitionHolder, BeanDefinitionRegistry registry)
    throws BeanDefinitionStoreException {

  // Register bean definition under primary name.
  //获取bean的名字
  String beanName = definitionHolder.getBeanName();
  //将bean的名字和bean的定义注册带工厂
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
工厂的注册方法registerBeanDefinition：
org.springframework.beans.factory.support.DefaultListableBeanFactory#registerBeanDefinition(String beanName, BeanDefinition beanDefinition);
```
/** Map of bean definition objects, keyed by bean name. */
private final Map<String, BeanDefinition> beanDefinitionMap = new ConcurrentHashMap<>(256);

public void registerBeanDefinition(String beanName, BeanDefinition beanDefinition)
    throws BeanDefinitionStoreException {

  Assert.hasText(beanName, "Bean name must not be empty");
  Assert.notNull(beanDefinition, "BeanDefinition must not be null");

  if (beanDefinition instanceof AbstractBeanDefinition) {
    try {
      //对bean进行验证
      ((AbstractBeanDefinition) beanDefinition).validate();
    }
    catch (BeanDefinitionValidationException ex) {
      throw new BeanDefinitionStoreException(beanDefinition.getResourceDescription(), beanName,
          "Validation of bean definition failed", ex);
    }
  }
  //根据bean的名字得到bean的定义对象，spring工厂最核心的容器就是一个ConcurrentHashMap
  BeanDefinition existingDefinition = this.beanDefinitionMap.get(beanName);
  //当前容器存在这个bean
  if (existingDefinition != null) {
    //不允许复写，直接抛异常
    if (!isAllowBeanDefinitionOverriding()) {
      throw new BeanDefinitionOverrideException(beanName, beanDefinition, existingDefinition);
    }
    else if (existingDefinition.getRole() < beanDefinition.getRole()) {
      // e.g. was ROLE_APPLICATION, now overriding with ROLE_SUPPORT or ROLE_INFRASTRUCTURE
      if (logger.isInfoEnabled()) {
        logger.info("Overriding user-defined bean definition for bean '" + beanName +
            "' with a framework-generated bean definition: replacing [" +
            existingDefinition + "] with [" + beanDefinition + "]");
      }
    }
    //当前bean和既有的bean不相同，打印日志
    else if (!beanDefinition.equals(existingDefinition)) {
      if (logger.isDebugEnabled()) {
        logger.debug("Overriding bean definition for bean '" + beanName +
            "' with a different definition: replacing [" + existingDefinition +
            "] with [" + beanDefinition + "]");
      }
    }
    else {
      if (logger.isTraceEnabled()) {
        logger.trace("Overriding bean definition for bean '" + beanName +
            "' with an equivalent definition: replacing [" + existingDefinition +
            "] with [" + beanDefinition + "]");
      }
    }
    //往集合里边塞入当前bean的定义
    this.beanDefinitionMap.put(beanName, beanDefinition);
  }
  else {
    //工厂中不存在当前参数的bean

    if (hasBeanCreationStarted()) {
      // Cannot modify startup-time collection elements anymore (for stable iteration)
      //不能修改启动阶段的集合元素，这里要进行同步
      synchronized (this.beanDefinitionMap) {
        this.beanDefinitionMap.put(beanName, beanDefinition);
        List<String> updatedDefinitions = new ArrayList<>(this.beanDefinitionNames.size() + 1);
        updatedDefinitions.addAll(this.beanDefinitionNames);
        updatedDefinitions.add(beanName);
        this.beanDefinitionNames = updatedDefinitions;
        removeManualSingletonName(beanName);
      }
    }
    else {
      // Still in startup registration phase
      //直接加入到集合
      this.beanDefinitionMap.put(beanName, beanDefinition);
      this.beanDefinitionNames.add(beanName);
      removeManualSingletonName(beanName);
    }
    this.frozenBeanDefinitionNames = null;
  }

  if (existingDefinition != null || containsSingleton(beanName)) {
    resetBeanDefinition(beanName);
  }
}
```
此时工厂的ConcurrentHashMap里边就会存在bean的定义的key-value对。
bean的定义注册完毕之后，回到DefaultBeanDefinitionDocumentReader的processBeanDefinition方法：
```
//Send registration event.
//观察者模式，bean的注册的时候会触发一些事件，通知观察者
getReaderContext().fireComponentRegistered(new BeanComponentDefinition(bdHolder));
```
回到org.springframework.beans.factory.xml.DefaultBeanDefinitionDocumentReader#parseDefaultElement方法，
此方法完成了bean的解析和注册。
流程再往回返，来到org.springframework.beans.factory.xml.DefaultBeanDefinitionDocumentReader#doRegisterBeanDefinitions
```
protected void doRegisterBeanDefinitions(Element root) {
  ......
  preProcessXml(root);
  //bean的解析和注册
  parseBeanDefinitions(root, this.delegate);
  postProcessXml(root);
  ......
}
```

###  总结
至此我们完成了如下四行代码:
```
Resource resource = new ClassPathResource("applicationContext.xml");
DefaultListableBeanFactory defaultListableBeanFactory
        = new DefaultListableBeanFactory();
BeanDefinitionReader beanDefinitionReader =
        new XmlBeanDefinitionReader(defaultListableBeanFactory);
beanDefinitionReader.loadBeanDefinitions(resource);
```
关于spring bean实例的注册流程
1. 定义好spring的配置文件
2. 通过Resource对象将spring配置文件进行抽象，抽象成一个具体的Resource对象(如ClassPathResource)
3. 定义好将要使用的bean工厂（各种BeanFactory）
4. 定义好XmlBeanDefinationReader对象，并将工厂对象作为参数传递进去，从而构建好二者之间的关联关系
5. 通过XmlBeanDefinationReader对象读取之前所抽取出的Rresource对象
6. 流程开始尽心解析
7. 针对XML文件进行各种元素属性的解析，这里面，真正的解析是通过BeanDefinationParserDelegate对象来完成的(委托模式)
8. 通过BeanDefinationParserDelegate对象在解析XML文件时，又使用了模板方法设计模式(pre,process,post)
9. 当所有的bean元素标签元素都解析完毕后，开始定义一个BeanDefination对象，该对象是一个非常重要的对象，里面容纳了一个bean相关的所有属性。
10. BeanDefination对象创建完毕后，Spring又会创建一个BeanDefinationHolder对象来持有这个BeanDefination对象。
11. BeanDefinationHolder对象主要包含两部分内容：beanName和BeanDefination。
12. 工厂将会解析出来的Bean信息存放到内部的一个ConcurrentHashMap中，该Map的键是beanName（唯一），值是beanDefination对象。
13. 调用bean解析完毕的触发动作，从而触发相应的监听器的方法的执行(使用到了观察者模式)
