---
title: spring_core(3)AOP剖析
date: 2020-07-11 18:31:00
tags: [spring aop]
categories: spring_core
---

### 理论部分
#### Spring AOP目标
- 将分散在程序各处的横切关注点剥离出来并以集中的方式进行表达
- 使得开发人员能够专注于业务逻辑的实现而非繁杂的非功能代码，简化了程序编写与单元测试
- 应用场景
  - 日志
  - 安全
  - 事物
<!-- more -->
#### AOP VS 继承
- AOP重点考虑的是程序的横切逻辑
- 继承重点考虑的是纵向的职责分派(面向对象推荐组合的方式，而不是滥用继承)

#### AOP核心概念
- Advice(通知)
  - 定义在连接点处的行为，围绕方法调用而进行注入
- Pointcut(切点)
  - 确定在哪些连接点处应用通知
- Advisor(通知器)
  - 组合Advice与Pointcut

#### spring aop实现
ProxyFactory
  - FactoryBean implemention that builds an aop Proxy based on beans in spring BeanFactory
  - Spring AOP的底层实现与源头
  - FactoryBean可以理解为对BeanFactory中的bean的一个代理。

#### ProxyFactoryBean的构成
- target
  - 目标对象，需要对齐进行切面增强
- proxyInterfaces
  - 代理对象所实现的接口
- interceptorNames
  - 通知器(Advisor)列表，通知器中包含了通知(Advice)与切点(Pointcut)

#### ProxyFactoryBean的作用
- 总的来说，ProxyFactoryBean的作用可用下面这句话概括
  - 针对目标对象创建代理对象，将对目标对象方法的调用转到对应代理对象方法的调用，并且可以在代理对象方法调用前后执行与之匹配的各个通知器中定义好的方法

#### 目标代理对象的创建
- spring通过3种方式创建目标代理对象
  - jdk动态代理
  - cglib
  - objenessCglibAopProxy

#### 代理模式
- 代理模式的作用是：为其他对象提供一种代理以控制对这个对象的访问
- 在某些情况下，一个客户端或者不能直接引用另一个对象，而代理对象可以在客户端和目标对象之间起到中介的作用

##### jdk动态代理
- 如果目标对象实现了接口，那么spring就会通过jdk动态代理为目标对象生成代理
![proxy.png](proxy.png)
- java动态代理类似于java.lang.reflect包下，一般主要涉及到以下2个接口：
  - interface InvocationHandler：该接口仅仅定义一个方法:public object invoke(Object obj, Method method,Object[] args)
    - 在实际使用时，第一个参数obj一般是指代理类，method是被代理的方法，args为该方法的参数数组，这个抽象方法在代理类中动态实现。
  - Proxy：该类即为动态代理类，其中主要包含以下内容
    - static Object newProxyInstance(classLoader loader,Class[] interfaces,InvocationHandler h)
    - 返回代理类的一个实例，返回后的代理类可以被代理类使用
- 动态代理是这样一种class：
  - 在运行时生成class，在生成它时你必须提供一组interface给他，，然后该class就会声明它实现了这些interface。因此我们可以将该class的实例当做这些interface中的任何一个来用，当然，这个动态代理其实就是一个Proxy，他不会替你作实质的工作，在生成他的实例时你必须提供一个handler，由他接管实际的工作

#### jdk动态代理的实现
1. 创建一个接口InvocationHandler的类，他必须实现invoke方法
2. 创建被代理的类以及接口
3. 通过Proxy的静态以及接口
newProxyInstance(classLoader loader,Class[] iterfaces,InvocationHandler h)创建一个被代理
4. 通过代理调用方法
参考之前的文章：
[jvm原理（36）透过字节码生成审视Java动态代理运作机制](https://ceaser.wang/2018/10/05/jvm%E5%8E%9F%E7%90%86%EF%BC%8836%EF%BC%89%E9%80%8F%E8%BF%87%E5%AD%97%E8%8A%82%E7%A0%81%E7%94%9F%E6%88%90%E5%AE%A1%E8%A7%86Java%E5%8A%A8%E6%80%81%E4%BB%A3%E7%90%86%E8%BF%90%E4%BD%9C%E6%9C%BA%E5%88%B6/)

#### CGLIB代理
- 如果目标类未实现接口，那么spring就会使用cglib库为其创建代理

#### spring aop的应用场景：事物
- 事务是任何一个应用都要仔细考虑的问题
- 事务代理经常是一些程式化代码
- 手工处理程序事务较易出错
- 事务是spring aop非常好的一个应用场景
  - 极大减轻了程序员的工作量
  - 将事务传播属性等内容交给spring来做
  - 开发人员只需要考虑业务逻辑
  - 程序代码中将见不到事务相关代码(声明式事务)

#### spring事务的创建
- spring提供了一个统一的父类来表示不同的事务处理器
  - PlatformTransactionManager
- 事务的开启、提交、回滚等则由具体的事务管理器来实现

#### 总结
- spring核心ioc与aop是整个审判日那个的基石
- spring aop实现方式有3种
  - 动态代理
  - cglib库
  - ObjenessCgibAopProxy
- 事务是spring aop应用的最佳范例

### aop流程实现
#### 定义目标类的接口
```
public interface MyService {
    void myMethod();
}
```
#### 定义目标类的接口的实现类
```
public class MyServiceImpl implements MyService {
    @Override
    public void myMethod() {
        System.out.println("my method invoke");
    }
}
```

#### 定义通知器MyAdvisor
```
import org.aopalliance.intercept.MethodInterceptor;
import org.aopalliance.intercept.MethodInvocation;

public class MyAdvisor implements MethodInterceptor {

    @Override
    public Object invoke(MethodInvocation invocation) throws Throwable {
        System.out.println("befor MyAdvisor invoke!");
        Object result =  invocation.proceed();
        System.out.println("after MyAdvisor invoke!");
        return result;
    }
}
```
#### 配置ProxyFactoryBean
```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd">

    <bean id="myService" class="com.tdl.spring.aop.service.impl.MyServiceImpl">
    </bean>

    <bean id="myAdvisor" class="com.tdl.spring.aop.advisor.MyAdvisor">
    </bean>

    <bean id="myAop" class="org.springframework.aop.framework.ProxyFactoryBean">
        <property name="proxyInterfaces">
            <value>com.tdl.spring.aop.service.MyService</value>
        </property>
        <property name="interceptorNames">
            <list>
                <value>myAdvisor</value>
            </list>
        </property>
        <property name="target">
            <ref bean="myService"></ref>
        </property>
    </bean>

</beans>
```
#### 启动Example
```
public class SpringClientAop {
    public static void main(String[] args) {
        Resource resource = new ClassPathResource("applicationContext2.xml");
        DefaultListableBeanFactory defaultListableBeanFactory
                = new DefaultListableBeanFactory();
        BeanDefinitionReader beanDefinitionReader =
                new XmlBeanDefinitionReader(defaultListableBeanFactory);
        beanDefinitionReader.loadBeanDefinitions(resource);

        MyService myService = (MyService)defaultListableBeanFactory.getBean("myAop");
        myService.myMethod();
        System.out.println(myService.getClass());
        System.out.println(myService.getClass().getSuperclass());
        System.out.println(myService.getClass().getInterfaces().length);
        for( Class tclass : myService.getClass().getInterfaces()){
            System.out.println(tclass.getName());
        }
    }
}
```
打印：
befor MyAdvisor invoke!
my method invoke
after MyAdvisor invoke!
class com.sun.proxy.$Proxy4
class java.lang.reflect.Proxy
4
com.tdl.spring.aop.service.MyService
org.springframework.aop.SpringProxy
org.springframework.aop.framework.Advised
org.springframework.core.DecoratingProxy

从打印的接口可以看出，MyServiceImpl实现了MyService、SpringProxy、Advised、DecoratingProxy四个接口。

### aop实现方式源码解析
####  ProxyFactoryBean
ProxyFactoryBean构建出一个aop的代理，基于spring ioc管理的bean创建的代理对象。
ProxyFactoryBean代理了我们的业务类，内部粘合和接口列表，拦截器名字的集合，以及通知器。
ProxyFactoryBean实现了FactoryBean。
FactoryBean是BeanFactory内部的bean需要去实现的接口，而且，FactoryBean往外暴露的不是bean本身，而是以bean的工厂的方式暴露出来。

org.springframework.beans.factory.FactoryBean:
```
org.springframework.beans.factory.FactoryBean#getObject
org.springframework.beans.factory.FactoryBean#getObjectType
org.springframework.beans.factory.FactoryBean#isSingleton
org.springframework.beans.factory.FactoryBean#OBJECT_TYPE_ATTRIBUTE
```
FactoryBean和BeanFactory的区别：
BeanFactory是一个factory，即是一个工厂，这个工厂是用来管理bean的。
FactoryBean也是受到beanfactory的管理，FactoryBean和普通的bean在创建的时候并没有什么区别，也是使用反射，也会进入到缓存的管理，不同的是，当一个class是一个FactoryBean的时候(实现了FactoryBean接口)，那么在创建完毕之后，返回之前加了一些逻辑，在返回之前会调用FactoryBean的getObject()方法，getObject()方法会根据FactoryBean的一些属性和定义执行一些逻辑，就拿ProxyFactoryBean举例，ProxyFactoryBean会根据proxyInterfaces、interceptorNames、target等属性动态生成另外一个类(代理类)的对象，然后将这个动态生成的对象返回。
beanfactory是spring ioc的工厂，它里面管理着spring所创建出来的各种bean对象，当我们在配置文件（注解）中声明了某个bean的id后，通过这个id就可以获取到与该id所对应的class对象的实例（可能新建，也可能从缓存中获取）

FactoryBean本质上也是一个bean，它同其他bean一样，也是由BeanFactory所管理和维护的，当然它的实例也会缓存到spring的工厂中（如果是单例），它与普通的bean的唯一区别在于，当spring创建另一个FactoryBean的实例后，他接下来会判断当前所创建的bean是否是一个FactoryBean实例，如果不是，那么就直接将创建出来的bean返回给客户端；如果是，那么它会对其进行进一步的处理，根据配置文件所配置的target，advisor与interface等信息，在运行期间动态构建出一个类，并生成该类的一个实例，最后将该实例返回给客户端；因此，我们在声明一个FactoryBean时，通过id获取到的并非这个FactoryBean的实例，而是它的动态代理生成出来的一个代理对象（通过三种方式来进行生成）

AopProxy：
Delegate interface for a configured AOP proxy, allowing for the creation of actual proxy objects.
Out-of-the-box implementations are available for JDK dynamic proxies and for CGLIB proxies, as applied by DefaultAopProxyFactory。
针对于可配置的aop代理的接口，允许创建真实的代理对象。
开箱即用的DefaultAopProxyFactory实现有jdk的动态代理和cglib的代理。
```
public class DefaultAopProxyFactory implements AopProxyFactory, Serializable {

	@Override
	public AopProxy createAopProxy(AdvisedSupport config) throws AopConfigException {
		if (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config)) {
			Class<?> targetClass = config.getTargetClass();
			if (targetClass == null) {
				throw new AopConfigException("TargetSource cannot determine target class: " +
						"Either an interface or a target is required for proxy creation.");
			}
			if (targetClass.isInterface() || Proxy.isProxyClass(targetClass)) {
				return new JdkDynamicAopProxy(config);
			}
			return new ObjenesisCglibAopProxy(config);
		}
		else {
			return new JdkDynamicAopProxy(config);
		}
	}
  ......
}
```
CglibAopProxy\JdkDynamicAopProxy\ObjenesisCglibAopProxy这三个是AopProxy的三种实现方式，
ObjenesisCglibAopProxy是基于CglibAopProxy实现的，ObjenesisCglibAopProxy是基于字节码创建的代理，可以不使用构造器，spring4默认的代理方式。

#### 微观解析
我们的事例里边【MyService myService = (MyService)defaultListableBeanFactory.getBean("myAop");】返回了我们想要的aop事例。
我们只要来到具体的特化的创建aop的代理分支就可以，因为bean的创建和普通bean没有区别。

org.springframework.beans.factory.support.AbstractBeanFactory
getBean(String name)
=>
doGetBean(final String name, @Nullable final Class<T> requiredType,	@Nullable final Object[] args, boolean typeCheckOnly)
=>
getObjectForBeanInstance(Object beanInstance, String name, String beanName, @Nullable RootBeanDefinition mbd)
```
//返回bean，要么是bean自身，要么是FactoryBean创建出来的对象
protected Object getObjectForBeanInstance(
    Object beanInstance, String name, String beanName, @Nullable RootBeanDefinition mbd) {

  // Don't let calling code try to dereference the factory if the bean isn't a factory.
  if (BeanFactoryUtils.isFactoryDereference(name)) {
    if (beanInstance instanceof NullBean) {
      return beanInstance;
    }
    if (!(beanInstance instanceof FactoryBean)) {
      throw new BeanIsNotAFactoryException(beanName, beanInstance.getClass());
    }
    if (mbd != null) {
      mbd.isFactoryBean = true;
    }
    return beanInstance;
  }

  // Now we have the bean instance, which may be a normal bean or a FactoryBean.
  // If it's a FactoryBean, we use it to create a bean instance, unless the
  // caller actually wants a reference to the factory.
    //判断创建出来的bean是不是FactoryBean
  if (!(beanInstance instanceof FactoryBean)) {
    return beanInstance;
  }
  //以下逻辑是FactoryBean的流程
  Object object = null;
  if (mbd != null) {
    mbd.isFactoryBean = true;
  }
  else {
    //缓存可能得到为null
    object = getCachedObjectForFactoryBean(beanName);
  }
  if (object == null) {
    // Return bean instance from factory.
    //将ProxyFactoryBean转换为接口的类型
    FactoryBean<?> factory = (FactoryBean<?>) beanInstance;
    // Caches object obtained from FactoryBean if it is a singleton.
    //判断bean的定义在缓存是否存在
    if (mbd == null && containsBeanDefinition(beanName)) {
      mbd = getMergedLocalBeanDefinition(beanName);
    }
    boolean synthetic = (mbd != null && mbd.isSynthetic());
    //从工厂bean返回代理对象
    object = getObjectFromFactoryBean(factory, beanName, !synthetic);
  }
  return object;
}

//factory：org.springframework.aop.framework.ProxyFactoryBean
//beanName：myAop
//shouldPostProcess: true
protected Object getObjectFromFactoryBean(FactoryBean<?> factory, String beanName, boolean shouldPostProcess) {
  if (factory.isSingleton() && containsSingleton(beanName)) {
    synchronized (getSingletonMutex()) {
      Object object = this.factoryBeanObjectCache.get(beanName);
      if (object == null) {
        //真正工厂获取的动作
        object = doGetObjectFromFactoryBean(factory, beanName);
        // Only post-process and store if not put there already during getObject() call above
        // (e.g. because of circular reference processing triggered by custom getBean calls)
        Object alreadyThere = this.factoryBeanObjectCache.get(beanName);
        if (alreadyThere != null) {
          object = alreadyThere;
        }
        else {
          if (shouldPostProcess) {
            if (isSingletonCurrentlyInCreation(beanName)) {
              // Temporarily return non-post-processed object, not storing it yet..
              return object;
            }
            beforeSingletonCreation(beanName);
            try {
              object = postProcessObjectFromFactoryBean(object, beanName);
            }
            catch (Throwable ex) {
              throw new BeanCreationException(beanName,
                  "Post-processing of FactoryBean's singleton object failed", ex);
            }
            finally {
              afterSingletonCreation(beanName);
            }
          }
          if (containsSingleton(beanName)) {
            this.factoryBeanObjectCache.put(beanName, object);
          }
        }
      }
      return object;
    }
  }
  else {
    Object object = doGetObjectFromFactoryBean(factory, beanName);
    if (shouldPostProcess) {
      try {
        object = postProcessObjectFromFactoryBean(object, beanName);
      }
      catch (Throwable ex) {
        throw new BeanCreationException(beanName, "Post-processing of FactoryBean's object failed", ex);
      }
    }
    return object;
  }
}

//真正工厂获取的动作
private Object doGetObjectFromFactoryBean(final FactoryBean<?> factory, final String beanName)
    throws BeanCreationException {

  Object object;
  try {
    if (System.getSecurityManager() != null) {
      AccessControlContext acc = getAccessControlContext();
      try {
        object = AccessController.doPrivileged((PrivilegedExceptionAction<Object>) factory::getObject, acc);
      }
      catch (PrivilegedActionException pae) {
        throw pae.getException();
      }
    }
    else {
      //调用FactoryBean的getObject方法，获取对象
      object = factory.getObject();
    }
  }
  catch (FactoryBeanNotInitializedException ex) {
    throw new BeanCurrentlyInCreationException(beanName, ex.toString());
  }
  catch (Throwable ex) {
    throw new BeanCreationException(beanName, "FactoryBean threw exception on object creation", ex);
  }

  // Do not accept a null value for a FactoryBean that's not fully
  // initialized yet: Many FactoryBeans just return null then.
  if (object == null) {
    if (isSingletonCurrentlyInCreation(beanName)) {
      throw new BeanCurrentlyInCreationException(
          beanName, "FactoryBean which is currently in creation returned null from getObject");
    }
    object = new NullBean();
  }
  return object;
}
```
FactoryBean的getObject()方法具体实现:
org.springframework.aop.framework.ProxyFactoryBean:
```
//获取对象
public Object getObject() throws BeansException {
  initializeAdvisorChain();
  if (isSingleton()) {
    //返回代理对象的单例的实例
    return getSingletonInstance();
  }
  else {
    if (this.targetName == null) {
      logger.info("Using non-singleton proxies with singleton targets is often undesirable. " +
          "Enable prototype proxies by setting the 'targetName' property.");
    }
    return newPrototypeInstance();
  }
}
//创建单例的实例
private synchronized Object getSingletonInstance() {
  if (this.singletonInstance == null) {
    //targetSource内部引用了com.tdl.spring.aop.service.impl.MyServiceImpl
    //即得到目标增强的目标对象
    this.targetSource = freshTargetSource();
    if (this.autodetectInterfaces && getProxiedInterfaces().length == 0 && !isProxyTargetClass()) {
      // Rely on AOP infrastructure to tell us what interfaces to proxy.
      Class<?> targetClass = getTargetClass();
      if (targetClass == null) {
        throw new FactoryBeanNotInitializedException("Cannot determine target class for proxy");
      }
      setInterfaces(ClassUtils.getAllInterfacesForClass(targetClass, this.proxyClassLoader));
    }
    // Initialize the shared singleton instance.
    super.setFrozen(this.freezeProxy);
    //getProxy得到代理
    //createAopProxy方法在org.springframework.aop.framework.ProxyCreatorSupport内部实现
    this.singletonInstance = getProxy(createAopProxy());
  }
  return this.singletonInstance;
}

//初始化通知器链
private synchronized void initializeAdvisorChain() throws AopConfigException, BeansException {
  if (this.advisorChainInitialized) {
    return;
  }
  //检查interceptorNames（myAop配置了interceptorNames字符串数组）
  if (!ObjectUtils.isEmpty(this.interceptorNames)) {
    if (this.beanFactory == null) {
      throw new IllegalStateException("No BeanFactory available anymore (probably due to serialization) " +
          "- cannot resolve interceptor names " + Arrays.asList(this.interceptorNames));
    }

    // Globals can't be last unless we specified a targetSource using the property...
    if (this.interceptorNames[this.interceptorNames.length - 1].endsWith(GLOBAL_SUFFIX) &&
        this.targetName == null && this.targetSource == EMPTY_TARGET_SOURCE) {
      throw new AopConfigException("Target required after globals");
    }

    // Materialize interceptor chain from bean names.
    for (String name : this.interceptorNames) {
      if (name.endsWith(GLOBAL_SUFFIX)) {
        if (!(this.beanFactory instanceof ListableBeanFactory)) {
          throw new AopConfigException(
              "Can only use global advisors or interceptors with a ListableBeanFactory");
        }
        addGlobalAdvisors((ListableBeanFactory) this.beanFactory,
            name.substring(0, name.length() - GLOBAL_SUFFIX.length()));
      }

      else {
        // If we get here, we need to add a named interceptor.
        // We must check if it's a singleton or prototype.
        Object advice;
        if (this.singleton || this.beanFactory.isSingleton(name)) {
          // Add the real Advisor/Advice to the chain.
          //从beanFactoy获取bean(beanFactory是DefaultListableBeanFactory)
          //这里又会执行getBean的流程。
          //获取通知器/通知
          advice = this.beanFactory.getBean(name);
        }
        else {
          // It's a prototype Advice or Advisor: replace with a prototype.
          // Avoid unnecessary creation of prototype bean just for advisor chain initialization.
          advice = new PrototypePlaceholderAdvisor(name);
        }
        //把Advisor添加到链表当中
        addAdvisorOnChainCreation(advice);
      }
    }
  }

  this.advisorChainInitialized = true;
}
//aopProxy是JdkDynamicAopProxy
protected Object getProxy(AopProxy aopProxy) {
  return aopProxy.getProxy(this.proxyClassLoader);
}
```
addAdvisorOnChainCreation将通知器包装成Advisor，添加到通知器列表当中
org.springframework.aop.framework.AdvisedSupport:
```
	private List<Advisor> advisors = new ArrayList<>();
```
org.springframework.aop.framework.ProxyCreatorSupport:
```
//DefaultAopFactory
private AopProxyFactory aopProxyFactory;
public ProxyCreatorSupport() {
  this.aopProxyFactory = new DefaultAopProxyFactory();
}

protected final synchronized AopProxy createAopProxy() {
  if (!this.active) {
    //监听器的触发
    activate();
  }
  return getAopProxyFactory().createAopProxy(this);
}
public AopProxyFactory getAopProxyFactory() {
  //aopProxyFactory是DefaultAopFactory，其在ProxyCreatorSupport构造器里边被初始的。
  return this.aopProxyFactory;
}
```
getAopProxyFactory().createAopProxy(this)会来到DefaultAopFactory的createAopProxy方法：
```
//spring4开始。使用ObjenesisCglibAopProxy代替CglibAopProxy，因此此处没有CglibAopProxy
public class DefaultAopProxyFactory implements AopProxyFactory, Serializable {

	@Override
	public AopProxy createAopProxy(AdvisedSupport config) throws AopConfigException {
		if (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config)) {
			Class<?> targetClass = config.getTargetClass();
			if (targetClass == null) {
				throw new AopConfigException("TargetSource cannot determine target class: " +
						"Either an interface or a target is required for proxy creation.");
			}
			if (targetClass.isInterface() || Proxy.isProxyClass(targetClass)) {
				return new JdkDynamicAopProxy(config);
			}
			return new ObjenesisCglibAopProxy(config);
		}
		else {
			return new JdkDynamicAopProxy(config);
		}
	}
  ......
}
```
myAop实现了接口，这里会使用JdkDynamicAopProxy。
JdkDynamicAopProxy:
```
final class JdkDynamicAopProxy implements AopProxy, InvocationHandler, Serializable {
  public JdkDynamicAopProxy(AdvisedSupport config) throws AopConfigException {
    Assert.notNull(config, "AdvisedSupport must not be null");
    if (config.getAdvisors().length == 0 && config.getTargetSource() == AdvisedSupport.EMPTY_TARGET_SOURCE) {
      throw new AopConfigException("No advisors and no TargetSource specified");
    }
    this.advised = config;
  }

  public Object getProxy(@Nullable ClassLoader classLoader) {
    if (logger.isTraceEnabled()) {
      logger.trace("Creating JDK dynamic proxy: " + this.advised.getTargetSource());
    }
    //interface com.tdl.spring.aop.service.MyService
    //interface org.springframework.aop.SpringProxy
    //interface org.springframework.aop.framework.Advised
    //interface org.springframework.core.DecoratingProxy
    Class<?>[] proxiedInterfaces = AopProxyUtils.completeProxiedInterfaces(this.advised, true);
    //对equals和hashcode方法的特殊处理
    findDefinedEqualsAndHashCodeMethods(proxiedInterfaces);
    //调用jdk的api创建代理，完成真正的代理类和对象的创建
    return Proxy.newProxyInstance(classLoader, proxiedInterfaces, this);
  }
}
```
org.springframework.aop.framework.AopProxyUtils:
```
//得到目标代理对象需要的接口数组
static Class<?>[] completeProxiedInterfaces(AdvisedSupport advised, boolean decoratingProxy) {
  Class<?>[] specifiedInterfaces = advised.getProxiedInterfaces();
  if (specifiedInterfaces.length == 0) {
    // No user-specified interfaces: check whether target class is an interface.
    //interface com.tdl.spring.aop.service.MyService
    Class<?> targetClass = advised.getTargetClass();
    if (targetClass != null) {
      if (targetClass.isInterface()) {
        advised.setInterfaces(targetClass);
      }
      else if (Proxy.isProxyClass(targetClass)) {
        advised.setInterfaces(targetClass.getInterfaces());
      }
      specifiedInterfaces = advised.getProxiedInterfaces();
    }
  }
  boolean addSpringProxy = !advised.isInterfaceProxied(SpringProxy.class);
  boolean addAdvised = !advised.isOpaque() && !advised.isInterfaceProxied(Advised.class);
  boolean addDecoratingProxy = (decoratingProxy && !advised.isInterfaceProxied(DecoratingProxy.class));
  //非用户添加的接口数量
  int nonUserIfcCount = 0;
  if (addSpringProxy) {
    nonUserIfcCount++;
  }
  if (addAdvised) {
    nonUserIfcCount++;
  }
  if (addDecoratingProxy) {
    nonUserIfcCount++;
  }
  //长度为4的数组
  Class<?>[] proxiedInterfaces = new Class<?>[specifiedInterfaces.length + nonUserIfcCount];
  System.arraycopy(specifiedInterfaces, 0, proxiedInterfaces, 0, specifiedInterfaces.length);
  int index = specifiedInterfaces.length;
  if (addSpringProxy) {
    proxiedInterfaces[index] = SpringProxy.class;
    index++;
  }
  if (addAdvised) {
    proxiedInterfaces[index] = Advised.class;
    index++;
  }
  if (addDecoratingProxy) {
    proxiedInterfaces[index] = DecoratingProxy.class;
  }
  return proxiedInterfaces;
}
```

#### 关于Spring AOP代理的生成过程小结
1. 通过ProxyFactoryBean[FactoryBean接口的实现]来去配置相应的代理对象相关的信息。
即如下的信息:
```
<bean id="myAop" class="org.springframework.aop.framework.ProxyFactoryBean">
    <property name="proxyInterfaces">
        <value>com.tdl.spring.aop.service.MyService</value>
    </property>
    <property name="interceptorNames">
        <list>
            <value>myAdvisor</value>
        </list>
    </property>
    <property name="target">
        <ref bean="myService"></ref>
    </property>
</bean>
```
2. 在获取ProxyFactoryBean实例时，本质上并不是获取ProxyFactoryBean的对象，而是获取到了ProxyFactoryBean所返回(getObject方法)的那个对象实例。
3. 在ProxyFactoryBean实例的构建与缓存的过程中，其流程与普通的bean对象完全一致
4. 差别在于，当创建了ProxyFactoryBean对象后，spring会判断当前所创建的对象是否是一个FactoryBean实例。
5. 如果不是，那么spring就直接将所创建的对象返回。
6. 如果是，spring则会进入到一个新的流程分支当中
7. spring会根据我们在配置信息中所指定的各种元素，如目标对象是否实现了接口以及Advisor等信息，使用动态代理或是cglib等方式为目标对象创建相应的代理对象。
8. 当相应的代理对象创建完毕后，spring就会通过ProxyFactoryBean的getObject方法，将所创建的对象返回
9. 对象返回到调用端(客户端)，它本质上是一个代理对象，可以代理对目标对象的访问与调用；这个代理对象对用户来说，就好像一个目标对象一样。
10. 客户在使用代理对象时，可以正常调用目标对象的方法，同时在执行过程中，会根据我们在配置文件中所配置的信息在调用前后执行额外的附加逻辑

注意：我们在使用idea调试动态代理的时候，动态代理对象的toString会被idea持续不断的调用，来更新调试窗口变量的名字，因此就会在控制台出现动态代理类invoke方法的内部的一些打印。


### aop动态代理方法的执行
先看下之前的实例代码:
```
MyService myService = (MyService)defaultListableBeanFactory.getBean("myAop");
myService.myMethod();
```
myService是返回的一个代理对象。
myMethod调用的时候，会来到org.springframework.aop.framework.JdkDynamicAopProxy的invoke方法:
```
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
  Object oldProxy = null;
  boolean setProxyContext = false;
  //目标对象SingletonTargetSource：包装了com.tdl.spring.aop.service.impl.MyServiceImpl
  TargetSource targetSource = this.advised.targetSource;
  Object target = null;

  try {
    if (!this.equalsDefined && AopUtils.isEqualsMethod(method)) {
      // The target does not implement the equals(Object) method itself.
      return equals(args[0]);
    }
    else if (!this.hashCodeDefined && AopUtils.isHashCodeMethod(method)) {
      // The target does not implement the hashCode() method itself.
      return hashCode();
    }
    else if (method.getDeclaringClass() == DecoratingProxy.class) {
      // There is only getDecoratedClass() declared -> dispatch to proxy config.
      return AopProxyUtils.ultimateTargetClass(this.advised);
    }
    else if (!this.advised.opaque && method.getDeclaringClass().isInterface() &&
        method.getDeclaringClass().isAssignableFrom(Advised.class)) {
      // Service invocations on ProxyConfig with the proxy config...
      return AopUtils.invokeJoinpointUsingReflection(this.advised, method, args);
    }

    Object retVal;

    if (this.advised.exposeProxy) {
      // Make invocation available if necessary.
      oldProxy = AopContext.setCurrentProxy(proxy);
      setProxyContext = true;
    }

    // Get as late as possible to minimize the time we "own" the target,
    // in case it comes from a pool.
    //目标对象：com.tdl.spring.aop.service.impl.MyServiceImpl
    target = targetSource.getTarget();
    Class<?> targetClass = (target != null ? target.getClass() : null);

    // Get the interception chain for this method.
    //获取方法的拦截器链，我们只配置了一个：myAdvisor
    List<Object> chain = this.advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);

    // Check whether we have any advice. If we don't, we can fallback on direct
    // reflective invocation of the target, and avoid creating a MethodInvocation.
    if (chain.isEmpty()) {
      // We can skip creating a MethodInvocation: just invoke the target directly
      // Note that the final invoker must be an InvokerInterceptor so we know it does
      // nothing but a reflective operation on the target, and no hot swapping or fancy proxying.
      Object[] argsToUse = AopProxyUtils.adaptArgumentsIfNecessary(method, args);
      retVal = AopUtils.invokeJoinpointUsingReflection(target, method, argsToUse);
    }
    else {
      // We need to create a method invocation...
      封装一个方法调用
      MethodInvocation invocation =
          new ReflectiveMethodInvocation(proxy, target, method, args, targetClass, chain);
      // Proceed to the joinpoint through the interceptor chain.
      //执行方法调用
      retVal = invocation.proceed();
    }

    // Massage return value if necessary.
    Class<?> returnType = method.getReturnType();
    if (retVal != null && retVal == target &&
        returnType != Object.class && returnType.isInstance(proxy) &&
        !RawTargetAccess.class.isAssignableFrom(method.getDeclaringClass())) {
      // Special case: it returned "this" and the return type of the method
      // is type-compatible. Note that we can't help if the target sets
      // a reference to itself in another returned object.
      retVal = proxy;
    }
    else if (retVal == null && returnType != Void.TYPE && returnType.isPrimitive()) {
      throw new AopInvocationException(
          "Null return value from advice does not match primitive return type for: " + method);
    }
    return retVal;
  }
  finally {
    if (target != null && !targetSource.isStatic()) {
      // Must have come from TargetSource.
      targetSource.releaseTarget(target);
    }
    if (setProxyContext) {
      // Restore old proxy.
      AopContext.setCurrentProxy(oldProxy);
    }
  }
}
```
![MethodInvocation.png](MethodInvocation.png)

org.springframework.aop.framework.ReflectiveMethodInvocation#proceed():
```
public Object proceed() throws Throwable {
  // We start with an index of -1 and increment early.
  if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
    return invokeJoinpoint();
  }

  Object interceptorOrInterceptionAdvice =
      this.interceptorsAndDynamicMethodMatchers.get(++this.currentInterceptorIndex);
  if (interceptorOrInterceptionAdvice instanceof InterceptorAndDynamicMethodMatcher) {
    // Evaluate dynamic method matcher here: static part will already have
    // been evaluated and found to match.
    InterceptorAndDynamicMethodMatcher dm =
        (InterceptorAndDynamicMethodMatcher) interceptorOrInterceptionAdvice;
    Class<?> targetClass = (this.targetClass != null ? this.targetClass : this.method.getDeclaringClass());
    if (dm.methodMatcher.matches(this.method, targetClass, this.arguments)) {
      return dm.interceptor.invoke(this);
    }
    else {
      // Dynamic matching failed.
      // Skip this interceptor and invoke the next in the chain.
      //可能的递归调用
      return proceed();
    }
  }
  else {
    // It's an interceptor, so we just invoke it: The pointcut will have
    // been evaluated statically before this object was constructed.
    //interceptorOrInterceptionAdvice是MyAdvisor,MyAdvisor实现了MethodInterceptor
    //这里会进入MyAdvisor的invoke方法。
    return ((MethodInterceptor) interceptorOrInterceptionAdvice).invoke(this);
  }
}
```
MyAdvisor的逻辑：
```
public class MyAdvisor implements MethodInterceptor {

    @Override
    public Object invoke(MethodInvocation invocation) throws Throwable {
        System.out.println("befor MyAdvisor invoke!");
        Object result =  invocation.proceed();
        System.out.println("after MyAdvisor invoke!");
        return result;
    }
}
```
invocation.proceed()会进入org.springframework.aop.framework.ReflectiveMethodInvocation的process()：
```
if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
  最后一个，即目标方法，会被调用，MyServiceImpl的myMethod方法被调用
  return invokeJoinpoint();
}
```
invokeJoinpoint方法逻辑：
```
protected Object invokeJoinpoint() throws Throwable {
  return AopUtils.invokeJoinpointUsingReflection(this.target, this.method, this.arguments);
}
```
![invokeJoinpointUsingReflection.png](invokeJoinpointUsingReflection.png)




【本章代码位置：https://github.com/1156721874/spring-kernel-lecture】
