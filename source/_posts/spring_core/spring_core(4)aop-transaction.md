---
title: spring_core(4)aop-transaction
date: 2020-07-13 20:17:00
tags: [spring aop transaction]
categories: spring_core
---

### 事物实例
1. 配置数据库驱动
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
            "org.apache.tomcat:tomcat-jdbc:9.0.34" 数据库连接池
    )
}
```
<!-- more -->
2. DAO配置
```
import com.tdl.spring.bean.Student;

public interface StudentDao {
    void saveStudent(Student student);
}
```
实现：
```
import com.tdl.spring.bean.Student;
import com.tdl.spring.dao.StudentDao;
import org.springframework.jdbc.core.JdbcTemplate;

public class StudentDaoImpl implements StudentDao {
    private JdbcTemplate jdbcTemplate;

    public void setJdbcTemplate(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void saveStudent(Student student) {
        String sql = "insert into student(name,age) values (?,?)";
        this.jdbcTemplate.update(sql,student.getName(),student.getAge());
    }
}
```

3. Service
接口：
```
public interface StudentService {
    void saveStudent(Student student);
}
```
实现：
```
import com.tdl.spring.bean.Student;
import com.tdl.spring.dao.StudentDao;
import com.tdl.spring.service.StudentService;

public class StudentServiceImpl implements StudentService {

    private StudentDao studentDao;

    public void setStudentDao(StudentDao studentDao) {
        this.studentDao = studentDao;
    }

    @Override
    public void saveStudent(Student student) {
        this.studentDao.saveStudent(student);
    }
}
```
4. 配置事物文件
```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:tx="http://www.springframework.org/schema/tx"
       xmlns:aop="http://www.springframework.org/schema/aop"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
       http://www.springframework.org/schema/tx http://www.springframework.org/schema/tx/spring-tx.xsd">

    <bean id="dataSource" class="org.apache.tomcat.jdbc.pool.DataSource" destroy-method="close" autowire="no">
        <property name="url" value="jdbc:mysql://localhost:3306/mytest"></property>
        <property name="username" value="root"></property>
        <property name="password" value="operater"></property>
        <property name="driverClassName" value="com.mysql.cj.jdbc.Driver"></property>
        <property name="minIdle" value="1"/>
        <property name="maxIdle" value="5"/>
        <property name="maxActive" value="100"/>
        <property name="initialSize" value="1"/>
        <property name="testOnBorrow" value="true"/>
        <property name="validationQuery" value="select 1"/>
        <property name="testOnReturn" value="true"/>
        <property name="validationInterval" value="500000"/>
        <property name="removeAbandoned" value="true"/>
        <property name="removeAbandonedTimeout" value="30"/>
        <property name="fairQueue" value="false"/>
        <property name="defaultAutoCommit" value="false"/> <!-- 关闭自动提交 -->
    </bean>
     <!-- 事物管理器 -->
    <bean id="transactionManager" class="org.springframework.jdbc.datasource.DataSourceTransactionManager">
        <property name="dataSource" ref="dataSource"/>
    </bean>

    <bean id="jdbcTemplate" class="org.springframework.jdbc.core.JdbcTemplate">
        <property name="dataSource" ref="dataSource"></property>
    </bean>

    <bean id="studentDao" class="com.tdl.spring.dao.impl.StudentDaoImpl">
        <property name="jdbcTemplate" ref="jdbcTemplate"/>
    </bean>

    <bean id="studentService" class="com.tdl.spring.service.impl.StudentServiceImpl">
        <property name="studentDao" ref="studentDao"/>
    </bean>

    <bean id="studentServiceProxy" class="org.springframework.transaction.interceptor.TransactionProxyFactoryBean">
        <property name="transactionManager" ref="transactionManager" />
        <property name="target" ref="studentService"/>
        <property name="transactionAttributes">
            <props>
                <prop key="save*">PROPAGATION_REQUIRED</prop>
                <prop key="update*">PROPAGATION_REQUIRED</prop>
                <prop key="remove*">PROPAGATION_REQUIRED</prop>
                <prop key="get*">PROPAGATION_REQUIRED,readOnly</prop>
            </props>
        </property>
    </bean>

</beans>
```
5. 启动测试类
```

public class SpringClientTransaction {
    public static void main(String[] args) {
        Resource resource = new ClassPathResource("applicationContext3.xml");
        DefaultListableBeanFactory defaultListableBeanFactory
                = new DefaultListableBeanFactory();
        BeanDefinitionReader beanDefinitionReader =
                new XmlBeanDefinitionReader(defaultListableBeanFactory);
        beanDefinitionReader.loadBeanDefinitions(resource);

        StudentService studentService = (StudentService)defaultListableBeanFactory.
                getBean("studentServiceProxy");
        Student student  = new Student();
        student.setName("zhangsan");
        student.setAge(23);
        studentService.saveStudent(student);
    }
}
```

### 事物开启流程
【StudentService studentService = (StudentService)defaultListableBeanFactory.getBean("studentServiceProxy");】
这行代码的执行过程会伴随事物的开启，接下来开始看一下。
bean的实例化和普通 的bean没啥区别，不做过多介绍，最后 程序会来到org.springframework.beans.factory.support.AbstractBeanFactory#getObjectForBeanInstance()
```
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
  if (!(beanInstance instanceof FactoryBean)) {
    return beanInstance;
  }

  Object object = null;
  if (mbd != null) {
    mbd.isFactoryBean = true;
  }
  else {
    object = getCachedObjectForFactoryBean(beanName);
  }
  if (object == null) {
    // Return bean instance from factory.
    FactoryBean<?> factory = (FactoryBean<?>) beanInstance;
    // Caches object obtained from FactoryBean if it is a singleton.
    if (mbd == null && containsBeanDefinition(beanName)) {
      mbd = getMergedLocalBeanDefinition(beanName);
    }
    boolean synthetic = (mbd != null && mbd.isSynthetic());
    object = getObjectFromFactoryBean(factory, beanName, !synthetic);
  }
  return object;
}

protected Object getObjectFromFactoryBean(FactoryBean<?> factory, String beanName, boolean shouldPostProcess) {
  if (factory.isSingleton() && containsSingleton(beanName)) {
    synchronized (getSingletonMutex()) {
      Object object = this.factoryBeanObjectCache.get(beanName);
      if (object == null) {
        object = doGetObjectFromFactoryBean(factory, beanName);
        .......略
      }
      return object;
    }
  }
  else {
    ......略
  }
}

private Object doGetObjectFromFactoryBean(final FactoryBean<?> factory, final String beanName)
    throws BeanCreationException {

  Object object;
    ......略
    //TransactionProxyFactoryBean是TransactionProxyFactoryBean，
      object = factory.getObject();
  ......
  return object;
}
```
factory.getObject()的实现是：
org.springframework.aop.framework.AbstractSingletonProxyFactoryBean#getObject():
```
public Object getObject() {
  if (this.proxy == null) {
    throw new FactoryBeanNotInitializedException();
  }
  return this.proxy;
}
```
proxy是生成的代理，代理的目标是com.tdl.spring.service.impl.StudentServiceImpl
![proxy4.png](proxy4.png)
因此【StudentService studentService = (StudentService)defaultListableBeanFactory.getBean("studentServiceProxy");】中的
studentService是proxy4，是一个代理，studentService.saveStudent()会调用动态代理对象的invoke方法，完成代理。

### 事务管理器层次体系分析与执行逻辑
#### TransactionProxyFactoryBean
TransactionProxyFactoryBean 继承了AbstractSingletonProxyFactoryBean，AbstractSingletonProxyFactoryBean实现了FactoryBean，同时在AbstractSingletonProxyFactoryBean里边维护了target(别代理的对象)。
TransactionProxyFactoryBean有三个重要属性需要配置：
1. "transactionManager": the PlatformTransactionManager implementation to use (for example, a org.springframework.transaction.jta.JtaTransactionManager instance)
2. "target": the target object that a transactional proxy should be created for
3. "transactionAttributes": the transaction attributes (for example, propagation behavior and "readOnly" flag) per target method name (or method name pattern

#### PlatformTransactionManager
```
public interface PlatformTransactionManager extends TransactionManager {
org.springframework.transaction.PlatformTransactionManager#commit
org.springframework.transaction.PlatformTransactionManager#rollback
}
```
This is the central interface in Spring's transaction infrastructure. Applications can use this directly, but it is not primarily meant as API: Typically, applications will work with either TransactionTemplate or declarative transaction demarcation through AOP.
For implementors, it is recommended to derive from the provided org.springframework.transaction.support.AbstractPlatformTransactionManager class, which pre-implements the defined propagation behavior and takes care of transaction synchronization handling. Subclasses have to implement template methods for specific states of the underlying transaction, for example: begin, suspend, resume, commit.
The default implementations of this strategy interface are org.springframework.transaction.jta.JtaTransactionManager and org.springframework.jdbc.datasource.DataSourceTransactionManager, which can serve as an implementation guide for other transaction strategies.
PlatformTransactionManager是spring事物基础设施中心化的一个接口，应用可以直接使用它，一般应用会使用TransactionTemplate，或者声明式的事物去实现。
推荐具体的实现使用AbstractPlatformTransactionManager去驱动，它预实现了一些传播行为，以及事物的一些同步的处理，子类只需要根据具体的事物实现去实现一些模板的方法，比如事物开始，挂起，回滚，提交
PlatformTransactionManager的默认实现策略有org.springframework.transaction.jta.JtaTransactionManager 和 org.springframework.jdbc.datasource.DataSourceTransactionManager，他们可以作为一种其他事物管理器实现的一个指导。
PlatformTransactionManager的一些实现有：
```
AbstractPlatformTransactionManager
CallbackPreferringPlatformTransactionManager
CciLocalTransactionManager
DataSourceTransactionManager
HibernateTransactionManager
JpaTransactionManager
JtaTransactionManager
ResourceTransactionManager
WebLogicJtaTransactionManager
WebSphereUowTransactionManager
```
AbstractPlatformTransactionManager作为一个模板，让其他的事物管理器去继承AbstractPlatformTransactionManager。
- PlatformTransactionManager
  - AbstractPlatformTransactionManager
    - CciLocalTransactionManager
    - DataSourceTransactionManager
    - HibernateTransactionManager
    - JpaTransactionManager
    - JtaTransactionManager
    - WebLogicJtaTransactionManager
    - WebSphereUowTransactionManager

#### 执行逻辑-事物的执行
```
public class SpringClientTransaction {
    public static void main(String[] args) {
        Resource resource = new ClassPathResource("applicationContext3.xml");
        DefaultListableBeanFactory defaultListableBeanFactory
                = new DefaultListableBeanFactory();
        BeanDefinitionReader beanDefinitionReader =
                new XmlBeanDefinitionReader(defaultListableBeanFactory);
        beanDefinitionReader.loadBeanDefinitions(resource);

        StudentService studentService = (StudentService)defaultListableBeanFactory.
                getBean("studentServiceProxy");
        Student student  = new Student();
        student.setName("zhangsan");
        student.setAge(23);
        studentService.saveStudent(student);
    }
}
```
我们在【studentService.saveStudent(student)】debug往下跟进流程，注意studentService是一个代理对象，因此方法进入JdkDynamicAopProxy。
org.springframework.aop.framework.JdkDynamicAopProxy：
```
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
		Object oldProxy = null;
		boolean setProxyContext = false;
    //TargetSource的实现是SingletonTargetSource，SingletonTargetSource里面注入了StudentServiceImpl
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
      //target等于StudentServiceImpl
			target = targetSource.getTarget();
      //StudentServiceImpl的class对象
			Class<?> targetClass = (target != null ? target.getClass() : null);

			// Get the interception chain for this method.
      //method等于StudentService.saveStudent，即StudentServiceImpl类里边的saveStudent方法对应的拦截器链
      //chain只有一个对象是TransactionInterceptor
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
        //ReflectiveMethodInvocation是比较重要的一个类，封装了代理，目标对象，目标对象的方法调用，参数，以及
        //拦截器链的引用
				MethodInvocation invocation =
						new ReflectiveMethodInvocation(proxy, target, method, args, targetClass, chain);
				// Proceed to the joinpoint through the interceptor chain.
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
ReflectiveMethodInvocation#proceed()：
```
//List of MethodInterceptor and InterceptorAndDynamicMethodMatcher that need dynamic checks
protected final List<?> interceptorsAndDynamicMethodMatchers;
public Object proceed() throws Throwable {
  // We start with an index of -1 and increment early.
  if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
    return invokeJoinpoint();
  }
  //interceptorsAndDynamicMethodMatchers缓存了我们配置的拦截器，每次currentInterceptorIndex都会往前走伴随着下一个拦截器的到来
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
      return proceed();
    }
  }
  else {
    // It's an interceptor, so we just invoke it: The pointcut will have
    // been evaluated statically before this object was constructed.
    //调用MethodInterceptor的invoke方法。
    return ((MethodInterceptor) interceptorOrInterceptionAdvice).invoke(this);
  }
}
```
MethodInterceptor的invoke实现在TransactionInterceptor里边。
org.springframework.transaction.interceptor.TransactionInterceptor#invoke()方法
```
public Object invoke(MethodInvocation invocation) throws Throwable {
  // Work out the target class: may be {@code null}.
  // The TransactionAttributeSource should be passed the target class
  // as well as the method, which may be from an interface.
  //targetClass是StudentServiceImpl。
  Class<?> targetClass = (invocation.getThis() != null ? AopUtils.getTargetClass(invocation.getThis()) : null);

  // Adapt to TransactionAspectSupport's invokeWithinTransaction...
  //在事物当中去进行调用
  return invokeWithinTransaction(invocation.getMethod(), targetClass, invocation::proceed);
}
```
invokeWithinTransaction的实现在【org.springframework.transaction.interceptor.TransactionAspectSupport】里边:
```
protected Object invokeWithinTransaction(Method method, @Nullable Class<?> targetClass,
    final InvocationCallback invocation) throws Throwable {

  // If the transaction attribute is null, the method is non-transactional.
  //tas的内容是我们在配置文件里边配置的一些属性：
  //"save*" -> {RuleBasedTransactionAttribute@1914} "PROPAGATION_REQUIRED,ISOLATION_DEFAULT"
  //"update*" -> {RuleBasedTransactionAttribute@1912} "PROPAGATION_REQUIRED,ISOLATION_DEFAULT"
  //"get*" -> {RuleBasedTransactionAttribute@1910} "PROPAGATION_REQUIRED,ISOLATION_DEFAULT,readOnly"
  //"remove*" -> {RuleBasedTransactionAttribute@1908} "PROPAGATION_REQUIRED,ISOLATION_DEFAULT"
  TransactionAttributeSource tas = getTransactionAttributeSource();
  //txAttr内容是事物的一些属性(针对于targetClass的method方法)：
  //rollbackRules = null
  //qualifier = null
  //descriptor = null
  //propagationBehavior = 0
  //isolationLevel = -1
  //timeout = -1
  //readOnly = false
  //name = null
  final TransactionAttribute txAttr = (tas != null ? tas.getTransactionAttribute(method, targetClass) : null);
  //根据事物属性构建事物管理器
  final TransactionManager tm = determineTransactionManager(txAttr);
  ......略
  //转换为PlatformTransactionManager，因为PlatformTransactionManager是事物管理最基础的事物管理集权。
  PlatformTransactionManager ptm = asPlatformTransactionManager(tm);
  //com.tdl.spring.service.impl.StudentServiceImpl.saveStudent
  final String joinpointIdentification = methodIdentification(method, targetClass, txAttr);

  //真正开始创建事物，参数：事物管理器、事物属性、目标对象的实际方
  //法(com.tdl.spring.service.impl.StudentServiceImpl.saveStudent)
  TransactionInfo txInfo = createTransactionIfNecessary(ptm, txAttr, joinpointIdentification);

  Object retVal;
  try{}
    //环绕通知，调用拦截器链中的下一个拦截器，如果没有拦截器会调用目标对象的方法
    retVal = invocation.proceedWithInvocation();
  }catch(Throwable e){
    completeTransactionAfterThrowing(txInfo, ex);
    throw ex;
  }finally{
    cleanupTransactionInfo(txInfo);
  }
    if (vavrPresent && VavrDelegate.isVavrTry(retVal)) {
    // Set rollback-only in case of Vavr failure matching our rollback rules...
    TransactionStatus status = txInfo.getTransactionStatus();
    if (status != null && txAttr != null) {
      retVal = VavrDelegate.evaluateTryFailure(retVal, txAttr, status);
    }
  }

  commitTransactionAfterReturning(txInfo);
  return retVal;
}

//创建事物管理器
protected TransactionManager determineTransactionManager(@Nullable TransactionAttribute txAttr) {
  // Do not attempt to lookup tx manager if no tx attributes are set
  if (txAttr == null || this.beanFactory == null) {
    return getTransactionManager();
  }

  String qualifier = txAttr.getQualifier();
  if (StringUtils.hasText(qualifier)) {
    return determineQualifiedTransactionManager(this.beanFactory, qualifier);
  }
  else if (StringUtils.hasText(this.transactionManagerBeanName)) {
    return determineQualifiedTransactionManager(this.beanFactory, this.transactionManagerBeanName);
  }
  else {
    //获取默认的事物管理器
    TransactionManager defaultTransactionManager = getTransactionManager();
    if (defaultTransactionManager == null) {
      defaultTransactionManager = this.transactionManagerCache.get(DEFAULT_TRANSACTION_MANAGER_KEY);
      if (defaultTransactionManager == null) {
        defaultTransactionManager = this.beanFactory.getBean(TransactionManager.class);
        this.transactionManagerCache.putIfAbsent(
            DEFAULT_TRANSACTION_MANAGER_KEY, defaultTransactionManager);
      }
    }
    //返回事物管理器
    return defaultTransactionManager;
  }
}

//直接返回事物管理器(XML已经配置过)
public TransactionManager getTransactionManager() {
  return this.transactionManager;
}
//将transactionManager转换为PlatformTransactionManager，因为PlatformTransactionManager是transactionManager的一个实现
private PlatformTransactionManager asPlatformTransactionManager(@Nullable Object transactionManager) {
  if (transactionManager == null || transactionManager instanceof PlatformTransactionManager) {
    return (PlatformTransactionManager) transactionManager;
  }
  else {
    //spring中的所有的事物管理器必须是实现PlatformTransactionManager接口
    throw new IllegalStateException(
        "Specified transaction manager is not a PlatformTransactionManager: " + transactionManager);
  }
}

protected TransactionInfo createTransactionIfNecessary(@Nullable PlatformTransactionManager tm,
    @Nullable TransactionAttribute txAttr, final String joinpointIdentification) {

  TransactionStatus status = status = tm.getTransaction(txAttr);
  return prepareTransactionInfo(tm, txAttr, joinpointIdentification, status);
}
```
TransactionInfo的结构如下
![TransactionInfo.png](TransactionInfo.png)
tm.getTransaction的实现在
org.springframework.transaction.support.AbstractPlatformTransactionManager:
```
public final TransactionStatus getTransaction(@Nullable TransactionDefinition definition)
    throws TransactionException {

  // Use defaults if no transaction definition given.
  //表示事物的属性
  TransactionDefinition def = (definition != null ? definition : TransactionDefinition.withDefaults());
  //执行创建事物，transaction等于DataSourceTransactionObject，每次来一个事物就会创建一个DataSourceTransactionObject
  //DataSourceTransactionObject是DataSourceTransaction的内部类
  Object transaction = doGetTransaction();
  boolean debugEnabled = logger.isDebugEnabled();
  //是不是一个既有的事物（嵌套事物）
  if (isExistingTransaction(transaction)) {
    // Existing transaction found -> check propagation behavior to find out how to behave.
    return handleExistingTransaction(def, transaction, debugEnabled);
  }

  // Check definition settings for new transaction.
  if (def.getTimeout() < TransactionDefinition.TIMEOUT_DEFAULT) {
    throw new InvalidTimeoutException("Invalid transaction timeout", def.getTimeout());
  }
  //事物传播行为的一些操作
  // No existing transaction found -> check propagation behavior to find out how to proceed.
  if (def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_MANDATORY) {
    throw new IllegalTransactionStateException(
        "No existing transaction found for transaction marked with propagation 'mandatory'");
  }
  else if (def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRED ||
      def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRES_NEW ||
      def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_NESTED) {
    SuspendedResourcesHolder suspendedResources = suspend(null);
    if (debugEnabled) {
      logger.debug("Creating new transaction with name [" + def.getName() + "]: " + def);
    }
    try {
      //开启事物，参数：事物的定义、事物对象、
      return startTransaction(def, transaction, debugEnabled, suspendedResources);
    }
    catch (RuntimeException | Error ex) {
      resume(null, suspendedResources);
      throw ex;
    }
  }
  else {
    // Create "empty" transaction: no actual transaction, but potentially synchronization.
    if (def.getIsolationLevel() != TransactionDefinition.ISOLATION_DEFAULT && logger.isWarnEnabled()) {
      logger.warn("Custom isolation level specified but no actual transaction initiated; " +
          "isolation level will effectively be ignored: " + def);
    }
    boolean newSynchronization = (getTransactionSynchronization() == SYNCHRONIZATION_ALWAYS);
    //设置事物状态
    return prepareTransactionStatus(def, null, true, newSynchronization, debugEnabled, null);
  }
}
```
doGetTransaction()的实现在org.springframework.jdbc.datasource.DataSourceTransactionManager：
```
protected Object doGetTransaction() {
  //DataSourceTransactionObject是一个事物对象
  DataSourceTransactionObject txObject = new DataSourceTransactionObject();
  txObject.setSavepointAllowed(isNestedTransactionAllowed());
  ConnectionHolder conHolder =
      (ConnectionHolder) TransactionSynchronizationManager.getResource(obtainDataSource());
  txObject.setConnectionHolder(conHolder, false);
  return txObject;
}
```
startTransaction()返回一个事物状态对象，又回到了org.springframework.transaction.support.AbstractPlatformTransactionManager:
```
private TransactionStatus startTransaction(TransactionDefinition definition, Object transaction,
    boolean debugEnabled, @Nullable SuspendedResourcesHolder suspendedResources) {

  boolean newSynchronization = (getTransactionSynchronization() != SYNCHRONIZATION_NEVER);
  DefaultTransactionStatus status = newTransactionStatus(
      definition, transaction, true, newSynchronization, debugEnabled, suspendedResources);
  doBegin(transaction, definition);
  prepareSynchronization(status, definition);
  return status;
}
```
doBegin的实现在org.springframework.jdbc.datasource.DataSourceTransactionManager：
```
/**
 * This implementation sets the isolation level but ignores the timeout.
 * 实现一些隔离级别，但是忽略超时
 */
@Override
protected void doBegin(Object transaction, TransactionDefinition definition) {
  DataSourceTransactionObject txObject = (DataSourceTransactionObject) transaction;
  Connection con = null;

  try {
    if (!txObject.hasConnectionHolder() ||
        txObject.getConnectionHolder().isSynchronizedWithTransaction()) {
          //获取到数据源，即一个DataSource对象，xml有配置。然后获取数据库连接
      Connection newCon = obtainDataSource().getConnection();
      if (logger.isDebugEnabled()) {
        logger.debug("Acquired Connection [" + newCon + "] for JDBC transaction");
      }
      txObject.setConnectionHolder(new ConnectionHolder(newCon), true);
    }

    txObject.getConnectionHolder().setSynchronizedWithTransaction(true);
    con = txObject.getConnectionHolder().getConnection();

    Integer previousIsolationLevel = DataSourceUtils.prepareConnectionForTransaction(con, definition);
    txObject.setPreviousIsolationLevel(previousIsolationLevel);
    //是否设置成只读操作
    txObject.setReadOnly(definition.isReadOnly());

    // Switch to manual commit if necessary. This is very expensive in some JDBC drivers,
    // so we don't want to do it unnecessarily (for example if we've explicitly
    // configured the connection pool to set it already).
    //如果是自动提交，设置成非自动提交(如果是自动提交的话，事物的配置是没有意义的)
    if (con.getAutoCommit()) {
      txObject.setMustRestoreAutoCommit(true);
      if (logger.isDebugEnabled()) {
        logger.debug("Switching JDBC Connection [" + con + "] to manual commit");
      }
      con.setAutoCommit(false);
    }
    //只读事物
    prepareTransactionalConnection(con, definition);
    txObject.getConnectionHolder().setTransactionActive(true);

    int timeout = determineTimeout(definition);
    if (timeout != TransactionDefinition.TIMEOUT_DEFAULT) {
      txObject.getConnectionHolder().setTimeoutInSeconds(timeout);
    }

    // Bind the connection holder to the thread.
    if (txObject.isNewConnectionHolder()) {
      TransactionSynchronizationManager.bindResource(obtainDataSource(), txObject.getConnectionHolder());
    }
  }

  catch (Throwable ex) {
    if (txObject.isNewConnectionHolder()) {
      DataSourceUtils.releaseConnection(con, obtainDataSource());
      txObject.setConnectionHolder(null, false);
    }
    throw new CannotCreateTransactionException("Could not open JDBC Connection for transaction", ex);
  }
}

//如果xml文件配置了readonly，这里会把事物设置成只读事物
protected void prepareTransactionalConnection(Connection con, TransactionDefinition definition)
    throws SQLException {

  if (isEnforceReadOnly() && definition.isReadOnly()) {
    try (Statement stmt = con.createStatement()) {
      stmt.executeUpdate("SET TRANSACTION READ ONLY");
    }
  }
}
```

我们回到TransactionAspectSupport的invokeWithinTransaction方法，得到TransactionInfo之后，会调用InvocationCallback的proceedWithInvocation方法，这个方法会执行拦截器链，如果没有拦截器链会执行目标方法。
proceedWithInvocation的实现上文已经介绍过：
org.springframework.aop.framework.ReflectiveMethodInvocation：
```
public Object proceed() throws Throwable {
  // We start with an index of -1 and increment early.
  if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
    //进入invokeJoinpoint方法
    return invokeJoinpoint();
  }
  ......略
}
//使用反射调用连接点
protected Object invokeJoinpoint() throws Throwable {
  //target是目标对象，method是目标对象的方法，arguments是目标方法的参数
  return AopUtils.invokeJoinpointUsingReflection(this.target, this.method, this.arguments);
}
```
invokeJoinpointUsingReflection方法实现：
org.springframework.aop.support.AopUtils
```
public static Object invokeJoinpointUsingReflection(@Nullable Object target, Method method, Object[] args)
    throws Throwable {

  // Use reflection to invoke the method.
  try {
    //突破访问限制
    ReflectionUtils.makeAccessible(method);
    //调用目标方法，即StudentServiceImpl.saveStudent()
    return method.invoke(target, args);
  }
  catch (InvocationTargetException ex) {
    // Invoked method threw a checked exception.
    // We must rethrow it. The client won't see the interceptor.
    throw ex.getTargetException();
  }
  catch (IllegalArgumentException ex) {
    throw new AopInvocationException("AOP configuration seems to be invalid: tried calling method [" +
        method + "] on target [" + target + "]", ex);
  }
  catch (IllegalAccessException ex) {
    throw new AopInvocationException("Could not access method [" + method + "]", ex);
  }
}
```

#### 执行逻辑-事物的提交/回滚
我们回到TransactionAspectSupport的invokeWithinTransaction方法，环绕事物InvocationCallback.proceedWithInvocation()
执行完毕之后，紧接着执行commitTransactionAfterReturning()方法对事物进行提交：
org.springframework.transaction.interceptor.TransactionAspectSupport
```
protected void commitTransactionAfterReturning(@Nullable TransactionInfo txInfo) {
  if (txInfo != null && txInfo.getTransactionStatus() != null) {
    if (logger.isTraceEnabled()) {
      logger.trace("Completing transaction for [" + txInfo.getJoinpointIdentification() + "]");
    }
    txInfo.getTransactionManager().commit(txInfo.getTransactionStatus());
  }
}
```
commit方法的实现：
org.springframework.transaction.support.AbstractPlatformTransactionManager
```
public final void commit(TransactionStatus status) throws TransactionException {
  ......略
  //事物处理逻辑
  processCommit(defStatus);
}
//处理一个实际的提交
private void processCommit(DefaultTransactionStatus status) throws TransactionException {
  try {
    boolean beforeCompletionInvoked = false;

    try {
      boolean unexpectedRollback = false;
      prepareForCommit(status);
      triggerBeforeCommit(status);
      triggerBeforeCompletion(status);
      beforeCompletionInvoked = true;

      if (status.hasSavepoint()) {
        if (status.isDebug()) {
          logger.debug("Releasing transaction savepoint");
        }
        unexpectedRollback = status.isGlobalRollbackOnly();
        status.releaseHeldSavepoint();
      }
      else if (status.isNewTransaction()) {
        if (status.isDebug()) {
          logger.debug("Initiating transaction commit");
        }
        unexpectedRollback = status.isGlobalRollbackOnly();
        //事物提交
        doCommit(status);
      }
      else if (isFailEarlyOnGlobalRollbackOnly()) {
        unexpectedRollback = status.isGlobalRollbackOnly();
      }

      // Throw UnexpectedRollbackException if we have a global rollback-only
      // marker but still didn't get a corresponding exception from commit.
      if (unexpectedRollback) {
        throw new UnexpectedRollbackException(
            "Transaction silently rolled back because it has been marked as rollback-only");
      }
    }
    catch (UnexpectedRollbackException ex) {
      // can only be caused by doCommit
      triggerAfterCompletion(status, TransactionSynchronization.STATUS_ROLLED_BACK);
      throw ex;
    }
    catch (TransactionException ex) {
      // can only be caused by doCommit
      if (isRollbackOnCommitFailure()) {
        doRollbackOnCommitException(status, ex);
      }
      else {
        triggerAfterCompletion(status, TransactionSynchronization.STATUS_UNKNOWN);
      }
      throw ex;
    }
    catch (RuntimeException | Error ex) {
      if (!beforeCompletionInvoked) {
        triggerBeforeCompletion(status);
      }
      doRollbackOnCommitException(status, ex);
      throw ex;
    }

    // Trigger afterCommit callbacks, with an exception thrown there
    // propagated to callers but the transaction still considered as committed.
    try {
      triggerAfterCommit(status);
    }
    finally {
      triggerAfterCompletion(status, TransactionSynchronization.STATUS_COMMITTED);
    }

  }
  finally {
    cleanupAfterCompletion(status);
  }
}

执行提交
protected void doCommit(DefaultTransactionStatus status) {
  //事物对象，每一次事物都会存在一个事物对象
  DataSourceTransactionObject txObject = (DataSourceTransactionObject) status.getTransaction();
  //得到一个数据库连接，ConnectionHolder持有当前数据库的连接
  Connection con = txObject.getConnectionHolder().getConnection();
  if (status.isDebug()) {
    logger.debug("Committing JDBC transaction on Connection [" + con + "]");
  }
  try {
    //使用数据库连接执行事物的提交
    con.commit();
  }
  catch (SQLException ex) {
    throw new TransactionSystemException("Could not commit JDBC transaction", ex);
  }
}
```

至此事物执行结束。

##### 针对于数据库事物的操作
setAutoCommit();

target.methods();

conn.commit();
or
conn.rollback();

##### 回滚
org.springframework.transaction.interceptor.TransactionAspectSupport
```
protected Object invokeWithinTransaction(Method method, @Nullable Class<?> targetClass,
    final InvocationCallback invocation) throws Throwable {

      Object retVal;
			try {
				// This is an around advice: Invoke the next interceptor in the chain.
				// This will normally result in a target object being invoked.
        //环绕通知，调用拦截器链中的下一个拦截器，如果没有拦截器会调用目标对象的方法
				retVal = invocation.proceedWithInvocation();
			}
			catch (Throwable ex) {
				// target invocation exception
        //如果目标方法出现异常，completeTransactionAfterThrowing执行回滚
				completeTransactionAfterThrowing(txInfo, ex);
				throw ex;
			}
			finally {
				cleanupTransactionInfo(txInfo);
			}
}

protected void completeTransactionAfterThrowing(@Nullable TransactionInfo txInfo, Throwable ex) {
  ......略
        txInfo.getTransactionManager().rollback(txInfo.getTransactionStatus());
          ......略
}
```
org.springframework.transaction.support.AbstractPlatformTransactionManager
```
public final void rollback(TransactionStatus status) throws TransactionException {
  if (status.isCompleted()) {
    throw new IllegalTransactionStateException(
        "Transaction is already completed - do not call commit or rollback more than once per transaction");
  }

  DefaultTransactionStatus defStatus = (DefaultTransactionStatus) status;
  //处理回滚
  processRollback(defStatus, false);
}

private void processRollback(DefaultTransactionStatus status, boolean unexpected) {
            ......略
	doRollback(status);
            ......略
}

protected void doRollback(DefaultTransactionStatus status) {
  DataSourceTransactionObject txObject = (DataSourceTransactionObject) status.getTransaction();
  Connection con = txObject.getConnectionHolder().getConnection();
  if (status.isDebug()) {
    logger.debug("Rolling back JDBC transaction on Connection [" + con + "]");
  }
  try {
    //使用数据库连接执行回滚
    con.rollback();
  }
  catch (SQLException ex) {
    throw new TransactionSystemException("Could not roll back JDBC transaction", ex);
  }
}
```

【本章代码位置：https://github.com/1156721874/spring-kernel-lecture】
