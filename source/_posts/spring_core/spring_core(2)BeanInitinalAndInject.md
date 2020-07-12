---
title: spring_core(2)Bean的初始化和注入
date: 2020-07-05 16:25:00
tags: [spring bean load init inject]
categories: spring_core
---

上一章节bean只是从xml加载出来，放到map里边，但是bean的class并没有创建实例。
```
Student student = defaultListableBeanFactory.getBean("student", Student.class);
```
当执行上述代码的时候才会实例化一个bean。
<!-- more -->
### Bean的创建缓存过程
org.springframework.beans.factory.support.AbstractBeanFactory#getBean:
```
public <T> T getBean(String name, Class<T> requiredType) throws BeansException {
  return doGetBean(name, requiredType, null, false);
}

//返回一个单利或者一个独立的bean
protected <T> T doGetBean(final String name, @Nullable final Class<T> requiredType,
    @Nullable final Object[] args, boolean typeCheckOnly) throws BeansException {

  final String beanName = transformedBeanName(name);
  Object bean;

  // Eagerly check singleton cache for manually registered singletons.
  //提早检查bean是否在缓存中存在
  Object sharedInstance = getSingleton(beanName);
	if (sharedInstance != null && args == null) {
      ......
  }else{
    ......
    //多线程创建bean会抛出异常
    if (isPrototypeCurrentlyInCreation(beanName)) {
      throw new BeanCurrentlyInCreationException(beanName);
    }
    BeanFactory parentBeanFactory = getParentBeanFactory();
    //检查bean的定义是否存在【默认是空的】
    if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
      ......
    }
    //不仅仅是类型检查，还有其他的检查
    if (!typeCheckOnly) {
      //将所指定的bean标记为已经创建或者正在创建，防止bean重复创建
      //标记放在ConcurrentHashMap里边
      markBeanAsCreated(beanName);
    }
    ......
    //RootBeanDefinition是一个汇总的bean信息，里边的信息是已经解析完毕的beanDefination的信息
    final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
    //检查，如果一个bean的定义是抽象的是不能实例化的。
		checkMergedBeanDefinition(mbd, beanName, args);
    // Guarantee initialization of beans that the current bean depends on.
    //mbd依赖的其他的bean
    String[] dependsOn = mbd.getDependsOn();
    if (dependsOn != null) {
      for (String dep : dependsOn) {
        //循环依赖引用，抛出异常
        if (isDependent(beanName, dep)) {
          throw new BeanCreationException(mbd.getResourceDescription(), beanName,
              "Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
        }
        registerDependentBean(dep, beanName);
        try {
          getBean(dep);
        }
        catch (NoSuchBeanDefinitionException ex) {
          throw new BeanCreationException(mbd.getResourceDescription(), beanName,
              "'" + beanName + "' depends on missing bean '" + dep + "'", ex);
        }
      }
    }

    // Create bean instance.
    //判断是否是singleton的作用域
    if (mbd.isSingleton()) {
      //获取单例的bean，不存在就执行lambda表达式执行创建
      sharedInstance = getSingleton(beanName, () -> {
        try {
          //创建bean，并且缓存到singletonObjects
          return createBean(beanName, mbd, args);
        }
        catch (BeansException ex) {
          // Explicitly remove instance from singleton cache: It might have been put there
          // eagerly by the creation process, to allow for circular reference resolution.
          // Also remove any beans that received a temporary reference to the bean.
          destroySingleton(beanName);
          throw ex;
        }
      });
      bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
    }	else if (mbd.isPrototype()) {
					// It's a prototype -> create a new instance.
					Object prototypeInstance = null;
					try {
						beforePrototypeCreation(beanName);
						prototypeInstance = createBean(beanName, mbd, args);
					}
					finally {
						afterPrototypeCreation(beanName);
					}
					bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
		}

  }

  return (T) bean;
}

public Object getSingleton(String beanName) {
  return getSingleton(beanName, true);
}
/** Cache of singleton objects: bean name to bean instance. */
//singletonObjects单例对象的缓存器，spring工厂单例的对象的存储集合，bean的name映射到bean的实例
private final Map<String, Object> singletonObjects = new ConcurrentHashMap<>(256);

protected Object getSingleton(String beanName, boolean allowEarlyReference) {
  Object singletonObject = this.singletonObjects.get(beanName);
  if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
    synchronized (this.singletonObjects) {
      singletonObject = this.earlySingletonObjects.get(beanName);
      if (singletonObject == null && allowEarlyReference) {
        ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
        if (singletonFactory != null) {
          singletonObject = singletonFactory.getObject();
          this.earlySingletonObjects.put(beanName, singletonObject);
          this.singletonFactories.remove(beanName);
        }
      }
    }
  }
  return singletonObject;
}

//返回给定名字的bean对象，有的话返回，没有的话创建并返回
public Object getSingleton(String beanName, ObjectFactory<?> singletonFactory) {
  ......
  synchronized (this.singletonObjects) {
    Object singletonObject = this.singletonObjects.get(beanName);
    if (singletonObject == null) {
        ......
      boolean newSingleton = false;
			try {
        //执行lambda表达式【创建bean】
        singletonObject = singletonFactory.getObject();
        newSingleton = true;
      }
      ......
      finally {
        if (recordSuppressedExceptions) {
          this.suppressedExceptions = null;
        }
        //并发的一些检查
        afterSingletonCreation(beanName);
      }
    }
      ......
    if (newSingleton) {
      addSingleton(beanName, singletonObject);
    }
    ......
  }
  return singletonObject;
}
//缓存操作
protected void addSingleton(String beanName, Object singletonObject) {
  synchronized (this.singletonObjects) {
    //将bean的(name-实例)映射塞入到singletonObjects(工厂的容器ConcurrentHashMap)当中
    this.singletonObjects.put(beanName, singletonObject);
    this.singletonFactories.remove(beanName);
    this.earlySingletonObjects.remove(beanName);
    this.registeredSingletons.add(beanName);
  }
}
//创建bean
protected Object createBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
    throws BeanCreationException {

  if (logger.isTraceEnabled()) {
    logger.trace("Creating instance of bean '" + beanName + "'");
  }
  RootBeanDefinition mbdToUse = mbd;

  // Make sure bean class is actually resolved at this point, and
  // clone the bean definition in case of a dynamically resolved Class
  // which cannot be stored in the shared merged bean definition.
  //拿到bean定义的class对象，后期用反射来实例化对象
  //底层：Class<?> resolvedClass = ClassUtils.forName(className, classLoader);
  Class<?> resolvedClass = resolveBeanClass(mbd, beanName);
  if (resolvedClass != null && !mbd.hasBeanClass() && mbd.getBeanClassName() != null) {
    mbdToUse = new RootBeanDefinition(mbd);
    mbdToUse.setBeanClass(resolvedClass);
  }

  ......
  // Give BeanPostProcessors a chance to return a proxy instead of the target bean instance.
  //bean的后置处理器，bean可以配置返回bean的代理对象【bean实例化之前处理】
  Object bean = resolveBeforeInstantiation(beanName, mbdToUse);
  if (bean != null) {
    return bean;
  }
  ......
  try {
    //执行真正创建bean实例
    Object beanInstance = doCreateBean(beanName, mbdToUse, args);
    if (logger.isTraceEnabled()) {
      logger.trace("Finished creating instance of bean '" + beanName + "'");
    }
    //返回
    return beanInstance;
  }
  catch (BeanCreationException | ImplicitlyAppearedSingletonException ex) {
    // A previously detected exception with proper bean creation context already,
    // or illegal singleton state to be communicated up to DefaultSingletonBeanRegistry.
    throw ex;
  }
  catch (Throwable ex) {
    throw new BeanCreationException(
        mbdToUse.getResourceDescription(), beanName, "Unexpected exception during bean creation", ex);
  }
}

```
doCreateBean位于org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory:
```
/** Cache of unfinished FactoryBean instances: FactoryBean name to BeanWrapper. */
//未创建的FactoryBean实例
private final ConcurrentMap<String, BeanWrapper> factoryBeanInstanceCache = new ConcurrentHashMap<>();

//执行真正创建bean实例
protected Object doCreateBean(final String beanName, final RootBeanDefinition mbd, final @Nullable Object[] args)
    throws BeanCreationException {

  // Instantiate the bean.
  //bean的包装器
  BeanWrapper instanceWrapper = null;
  if (mbd.isSingleton()) {
    //为创建的bean的缓存，当前是创建过程，需要从缓冲里边删除
    instanceWrapper = this.factoryBeanInstanceCache.remove(beanName);
  }
  if (instanceWrapper == null) {
    //创建包裹bean实例的BeanWrapper
    instanceWrapper = createBeanInstance(beanName, mbd, args);
  }
  //返回被包裹的对象，即业务对象，Student对象
  final Object bean = instanceWrapper.getWrappedInstance();
  //返回包裹的bean的class对象
  Class<?> beanType = instanceWrapper.getWrappedClass();
  if (beanType != NullBean.class) {
    mbd.resolvedTargetType = beanType;
  }

  // Allow post-processors to modify the merged bean definition.
  synchronized (mbd.postProcessingLock) {
    if (!mbd.postProcessed) {
      try {
        //应用后置处理器
        applyMergedBeanDefinitionPostProcessors(mbd, beanType, beanName);
      }
      catch (Throwable ex) {
        throw new BeanCreationException(mbd.getResourceDescription(), beanName,
            "Post-processing of merged bean definition failed", ex);
      }
      mbd.postProcessed = true;
    }
  }

  // Eagerly cache singletons to be able to resolve circular references
  // even when triggered by lifecycle interfaces like BeanFactoryAware.
  //尽早缓存bena的实例，以防止bean的循环引用问题
  boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences &&
      isSingletonCurrentlyInCreation(beanName));
  if (earlySingletonExposure) {
    if (logger.isTraceEnabled()) {
      logger.trace("Eagerly caching bean '" + beanName +
          "' to allow for resolving potential circular references");
    }
    //一些缓存的操作
    addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
  }

  // Initialize the bean instance.
  //初始化bean的实例，实例有了，但是bean里边的属性还没有初始化和赋值
  Object exposedObject = bean;
  try {
    //对bean实例的属性进行赋值，不做详细展开。
    populateBean(beanName, mbd, instanceWrapper);
    //bean创建完毕之后的一些初始化工作，比如用户自定义的初始化方法之类的。
    exposedObject = initializeBean(beanName, exposedObject, mbd);
  }
  catch (Throwable ex) {
    if (ex instanceof BeanCreationException && beanName.equals(((BeanCreationException) ex).getBeanName())) {
      throw (BeanCreationException) ex;
    }
    else {
      throw new BeanCreationException(
          mbd.getResourceDescription(), beanName, "Initialization of bean failed", ex);
    }
  }

  if (earlySingletonExposure) {
    Object earlySingletonReference = getSingleton(beanName, false);
    if (earlySingletonReference != null) {
      if (exposedObject == bean) {
        exposedObject = earlySingletonReference;
      }
      else if (!this.allowRawInjectionDespiteWrapping && hasDependentBean(beanName)) {
        String[] dependentBeans = getDependentBeans(beanName);
        Set<String> actualDependentBeans = new LinkedHashSet<>(dependentBeans.length);
        for (String dependentBean : dependentBeans) {
          if (!removeSingletonIfCreatedForTypeCheckOnly(dependentBean)) {
            actualDependentBeans.add(dependentBean);
          }
        }
        if (!actualDependentBeans.isEmpty()) {
          throw new BeanCurrentlyInCreationException(beanName,
              "Bean with name '" + beanName + "' has been injected into other beans [" +
              StringUtils.collectionToCommaDelimitedString(actualDependentBeans) +
              "] in its raw version as part of a circular reference, but has eventually been " +
              "wrapped. This means that said other beans do not use the final version of the " +
              "bean. This is often the result of over-eager type matching - consider using " +
              "'getBeanNamesOfType' with the 'allowEagerInit' flag turned off, for example.");
        }
      }
    }
  }

  // Register bean as disposable.
  try {
    registerDisposableBeanIfNecessary(beanName, bean, mbd);
  }
  catch (BeanDefinitionValidationException ex) {
    throw new BeanCreationException(
        mbd.getResourceDescription(), beanName, "Invalid destruction signature", ex);
  }

  return exposedObject;
}
//创建bean的实例
protected BeanWrapper createBeanInstance(String beanName, RootBeanDefinition mbd, @Nullable Object[] args) {
  // Make sure bean class is actually resolved at this point.
  //确认bean已经被解析过
  Class<?> beanClass = resolveBeanClass(mbd, beanName);
  //不允许创建的情况检查：不是public修饰、并且设置不允许公共访问接入
  if (beanClass != null && !Modifier.isPublic(beanClass.getModifiers()) && !mbd.isNonPublicAccessAllowed()) {
    throw new BeanCreationException(mbd.getResourceDescription(), beanName,
        "Bean class isn't public, and non-public access not allowed: " + beanClass.getName());
  }

  Supplier<?> instanceSupplier = mbd.getInstanceSupplier();
  if (instanceSupplier != null) {
    return obtainFromSupplier(instanceSupplier, beanName);
  }

  if (mbd.getFactoryMethodName() != null) {
    return instantiateUsingFactoryMethod(beanName, mbd, args);
  }

  // Shortcut when re-creating the same bean...
  boolean resolved = false;
  boolean autowireNecessary = false;
  if (args == null) {
    synchronized (mbd.constructorArgumentLock) {
      if (mbd.resolvedConstructorOrFactoryMethod != null) {
        resolved = true;
        autowireNecessary = mbd.constructorArgumentsResolved;
      }
    }
  }
  if (resolved) {
    if (autowireNecessary) {
      return autowireConstructor(beanName, mbd, null, null);
    }
    else {
      return instantiateBean(beanName, mbd);
    }
  }

  // Candidate constructors for autowiring?
  //候选的构造器进行装备
  Constructor<?>[] ctors = determineConstructorsFromBeanPostProcessors(beanClass, beanName);
  if (ctors != null || mbd.getResolvedAutowireMode() == AUTOWIRE_CONSTRUCTOR ||
      mbd.hasConstructorArgumentValues() || !ObjectUtils.isEmpty(args)) {
    return autowireConstructor(beanName, mbd, ctors, args);
  }

  // Preferred constructors for default construction?
  //获取优先的构造器
  ctors = mbd.getPreferredConstructors();
  if (ctors != null) {
    return autowireConstructor(beanName, mbd, ctors, null);
  }

  // No special handling: simply use no-arg constructor.
  //没有特殊的情况需要处理，使用无参的构造器进行创建
  return instantiateBean(beanName, mbd);
}
//使用默认的构造器来去实例化所给定的bean
protected BeanWrapper instantiateBean(final String beanName, final RootBeanDefinition mbd) {
  try {
    Object beanInstance;
    final BeanFactory parent = this;
    if (System.getSecurityManager() != null) {
      beanInstance = AccessController.doPrivileged((PrivilegedAction<Object>) () ->
          getInstantiationStrategy().instantiate(mbd, beanName, parent),
          getAccessControlContext());
    }
    else {
      //调用一个实例化策略，返回对应的实例
      beanInstance = getInstantiationStrategy().instantiate(mbd, beanName, parent);
    }
    //BeanWrapper实现类BeanWrapperImpl创建，BeanWrapperImpl持有bean的实例对象
    BeanWrapper bw = new BeanWrapperImpl(beanInstance);
    //BeanWrapper的初始化工作
    initBeanWrapper(bw);
    return bw;
  }
  catch (Throwable ex) {
    throw new BeanCreationException(
        mbd.getResourceDescription(), beanName, "Instantiation of bean failed", ex);
  }
}
```
InstantiationStrategy是创建策略的封装
org.springframework.beans.factory.support.InstantiationStrategy#instantiate(RootBeanDefinition bd, @Nullable String beanName, BeanFactory owner)
instantiate方法的实现在【org.springframework.beans.factory.support.SimpleInstantiationStrategy】当中:
```
public Object instantiate(RootBeanDefinition bd, @Nullable String beanName, BeanFactory owner) {
  // Don't override the class with CGLIB if no overrides.
  if (!bd.hasMethodOverrides()) {
    Constructor<?> constructorToUse;
    //同步锁
    synchronized (bd.constructorArgumentLock) {
      constructorToUse = (Constructor<?>) bd.resolvedConstructorOrFactoryMethod;
      if (constructorToUse == null) {
        //获取对象
        final Class<?> clazz = bd.getBeanClass();
        //是不是接口
        if (clazz.isInterface()) {
          throw new BeanInstantiationException(clazz, "Specified class is an interface");
        }
        try {
          if (System.getSecurityManager() != null) {
            constructorToUse = AccessController.doPrivileged(
                (PrivilegedExceptionAction<Constructor<?>>) clazz::getDeclaredConstructor);
          }
          else {
            //待使用的构造器，即，默认的无参构造器
            constructorToUse = clazz.getDeclaredConstructor();
          }
          bd.resolvedConstructorOrFactoryMethod = constructorToUse;
        }
        catch (Throwable ex) {
          throw new BeanInstantiationException(clazz, "No default constructor found", ex);
        }
      }
    }
    //使用spring的BeanUtils实例化
    return BeanUtils.instantiateClass(constructorToUse);
  }
  else {
    // Must generate CGLIB subclass.
    //CGLB的方式生成bean的实例
    return instantiateWithMethodInjection(bd, beanName, owner);
  }
}
```
根据构造器实例化对象在BeanUtils#instantiateClass中,这里不再列举，参考上一节的介绍。
到此实例才算真正的创建出来！


### 对象属性赋值与作用域
修改在applicationContext.xml当中配置bean

```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd">

    <bean id="student" class="com.tdl.spring.bean.Student">
        <property name="name2" value="zhangsan"/>
        <property name="age" value="20"/>
    </bean>

</beans>
```
即将name改为name2.
那么如下程序在执行【defaultListableBeanFactory.getBean("student", Student.class)】之前不会抛出异常:
```
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
只有执行defaultListableBeanFactory.getBean的时候才会抛出异常。

属性的赋值在org.springframework.beans.BeanWrapperImpl.setValue(final Object value)throws Exception执行:
```
public void setValue(final @Nullable Object value) throws Exception {
  //得到写方法
  final Method writeMethod = (this.pd instanceof GenericTypeAwarePropertyDescriptor ?
      ((GenericTypeAwarePropertyDescriptor) this.pd).getWriteMethodForActualAccess() :
      this.pd.getWriteMethod());
  if (System.getSecurityManager() != null) {
    AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
      ReflectionUtils.makeAccessible(writeMethod);
      return null;
    });
    try {
      AccessController.doPrivileged((PrivilegedExceptionAction<Object>) () ->
          writeMethod.invoke(getWrappedInstance(), value), acc);
    }
    catch (PrivilegedActionException ex) {
      throw ex.getException();
    }
  }
  else {
    ReflectionUtils.makeAccessible(writeMethod);
    //反射调用
    writeMethod.invoke(getWrappedInstance(), value);
  }
}
```
GenericTypeAwarePropertyDescriptor初始化的时候，写方法的定义是以"set"开头的方法。

### 从已有缓存获取对象
bean的默认scope是单例的，如果将scope设置为prototype类型的，那么每次获取的bean的实例都是不一样的，二期也不会缓存bean实例。
```
单例的bean会在getSingleton方法里边进行缓存
if (mbd.isSingleton()) {
  sharedInstance = getSingleton(beanName, () -> {
    try {
      return createBean(beanName, mbd, args);
    }
    catch (BeansException ex) {
      // Explicitly remove instance from singleton cache: It might have been put there
      // eagerly by the creation process, to allow for circular reference resolution.
      // Also remove any beans that received a temporary reference to the bean.
      destroySingleton(beanName);
      throw ex;
    }
  });
  bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
}

else if (mbd.isPrototype()) {
  // It's a prototype -> create a new instance.
  Object prototypeInstance = null;
  try {
    //Prototype类型的bean不会进行缓存。
    beforePrototypeCreation(beanName);
    prototypeInstance = createBean(beanName, mbd, args);
  }
  finally {
    afterPrototypeCreation(beanName);
  }
  bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
}
```

关于spring Bean的创建流程
1. Spring 所管理的Bean实际上是缓存在一个ConcurrentHashMap中的(singletonFactory对象中)
2. 该对象本质上是一个key-value对的形式，key指的是bean的名字（id），value是一个Object对象，就是所创建的bean对象
3. 在创建Bean之前，首先需要将该Bean的创建标示指定好，标示该Bean已经或是即将创建，目的是增强缓存的效率。
4. 根据bean的scope属性来确定当前这个bean是一个singleton还是prototype的bean，然后创建相应的对象
5. 无论是singleton还是prototype的bean，其创建的过程是一致的。
6. 通过java反射机制来创建bean的实例，在创建之前需要检查构造方法的访问修饰符，如果不是public的，则会调用setAccessible(true)方法
来突破java语法限制，使得可以通过非public构造方法来完成对象实例的创建。
7. 当对象创建完毕后，开始进行对象属性的注入。
8. 在对象属性注入的过程中，spring除去使用之前通过BeanDefination对象获取的bean信息外，还会通过反射的方式获取到上面所创建的bean中的真实属性信息(还包括一个class属性，表示该Bean所对应的class类型)
9. 完成bean属性的注入(或者抛出异常)
10. 如果bean是一个单例的，那么将所创建出来的bean添加到singleton对象中(缓存中)，供程序后续再次使用。

【本章代码位置：https://github.com/1156721874/spring-kernel-lecture】
