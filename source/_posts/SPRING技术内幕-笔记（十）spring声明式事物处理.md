---
title: SPRING技术内幕-笔记（十）spring声明式事物处理
date: 2018-09-28 19:55:57
tags: spring
categories: spring
---
**10.1事物处理拦截器的配置**
首先看一下建立事物处理对象的时序图：
![这里写图片描述](20150714170841112.png)
<!-- more -->

首先从TransactionProxyFactoryBean 的createMainInterceptor()方法开始：

```
//TransactionInterceptor 封装了AOP的事物处理的实现，通过依赖注入设置进来
	private final TransactionInterceptor transactionInterceptor = new TransactionInterceptor();

	private Pointcut pointcut;
		public void setTransactionAttributes(Properties transactionAttributes) {
		this.transactionInterceptor.setTransactionAttributes(transactionAttributes);
	}
//通过依赖注入的PlatformTransactionManager
		public void setTransactionManager(PlatformTransactionManager transactionManager) {
		this.transactionInterceptor.setTransactionManager(transactionManager);
	}
//创建SPringAOP处理的advisor
	protected Object createMainInterceptor() {
		this.transactionInterceptor.afterPropertiesSet();
		if (this.pointcut != null) {
		//使用默认的DefaultPointcutAdvisor作为默认的通知器，并设置拦截器
			return new DefaultPointcutAdvisor(this.pointcut, this.transactionInterceptor);
		}
		else {
			// Rely on default pointcut.如果没有配置pointcut 就用TransactionAttributeSourceAdvisor作为通知器，并设置transactionInterceptor为拦截器
			return new TransactionAttributeSourceAdvisor(this.transactionInterceptor);
		}
	}
```
值得注意的是createMainInterceptor()是在bean完成依赖注入的时候通过InitializingBean方法调用的。
TransactionProxyFactoryBean继承了AbstractSingletonProxyFactoryBean，而AbstractSingletonProxyFactoryBean实现了InitializingBean，于是就会重写InitializingBean的afterPropertiesSet()方法，这个方法实例化了一个proxyFactory，建立起 SPringAOP的应用，在这里，会为这个proxyfactory设置通知，目标对象，并最终返回proxy代理对象 。
AbstractSingletonProxyFactoryBean的afterPropertiesSet方法：

```
public void afterPropertiesSet() {
		if (this.target == null) {
			throw new IllegalArgumentException("Property 'target' is required");
		}
		if (this.target instanceof String) {
			throw new IllegalArgumentException("'target' needs to be a bean reference, not a bean name as value");
		}
		if (this.proxyClassLoader == null) {
			this.proxyClassLoader = ClassUtils.getDefaultClassLoader();
		}
		//TransactionProxyFactoryBean使用ProxyFactory 完成AOP的年基本功能，ProxyFactory 提供代理对象，并将transactionInterceptor设置为target的拦截器
		ProxyFactory proxyFactory = new ProxyFactory();

		if (this.preInterceptors != null) {
			for (Object interceptor : this.preInterceptors) {
				proxyFactory.addAdvisor(this.advisorAdapterRegistry.wrap(interceptor));
			}
		}

		// Add the main interceptor (typically an Advisor).
		spring加入通知器的地方，可以加入2种通知器，分别是DefaultPointcutAdvisor、TransactionAttributeSourceAdvisor，Proxyfactory的基类，ADvisedSupport中，维护了一个用来持有advice的linkedList，通过对这个list的增删改等操作，用来管理配置给Proxyfactory的通知器
		proxyFactory.addAdvisor(this.advisorAdapterRegistry.wrap(createMainInterceptor()));

		if (this.postInterceptors != null) {
			for (Object interceptor : this.postInterceptors) {
				proxyFactory.addAdvisor(this.advisorAdapterRegistry.wrap(interceptor));
			}
		}

		proxyFactory.copyFrom(this);
 //创建AOP的目标源
		TargetSource targetSource = createTargetSource(this.target);
		proxyFactory.setTargetSource(targetSource);

		if (this.proxyInterfaces != null) {
		//设置使用哪个接口作为代理
			proxyFactory.setInterfaces(this.proxyInterfaces);
		}
		else if (!isProxyTargetClass()) {
			// Rely on AOP infrastructure to tell us what interfaces to proxy.
			proxyFactory.setInterfaces(
					ClassUtils.getAllInterfacesForClass(targetSource.getTargetClass(), this.proxyClassLoader));
		}
//设置代理对象
		this.proxy = proxyFactory.getProxy(this.proxyClassLoader);
	}

//至于怎创建的代理对象要到proxyFactory看看：
	public Object getProxy(ClassLoader classLoader) {
		return createAopProxy().getProxy(classLoader);
	}
	createAopProxy（）在其基类ProxyCreatorSupport中实现
createAopProxy():
	protected final synchronized AopProxy createAopProxy() {
		if (!this.active) {
			activate();
		}
		//使用 DefaultAopProxyfactory来创建AopProxy对象，proxyFactory本身是ProxyConfig的子类，所以使用this
		return getAopProxyFactory().createAopProxy(this);
	}
```
**10.2事物处理配置的读入**
在AOP配置完成的基础上，从TransactionAttributeSourceAdvisor的实现为入口，了解具体的事物配置属性是如何读取的。

```
//Interceptor使用之前介绍的transactionInterceptor
	private TransactionInterceptor transactionInterceptor;
//对于pointcut ，使用其内部类TransactionAttributeSourcePointcut，
	private final TransactionAttributeSourcePointcut pointcut = new TransactionAttributeSourcePointcut() {
		@Override
		//使用transactionInterceptor得到事物配置的属性，在对proxy的方法进行调用时，会用到这些属性
		protected TransactionAttributeSource getTransactionAttributeSource() {
			return (transactionInterceptor != null ? transactionInterceptor.getTransactionAttributeSource() : null);
		}
	};
```
TransactionAttributeSourcePointcut这个切点实现了StaticMethodMatcherPointcut，有一个matches(Method method, Class targetClass)函数，在此函数中调用getTransactionAttributeSource得到配置属性，并且判断是否当前方法被拦截：
TransactionAttributeSourcePointcut的matches

```
	public boolean matches(Method method, Class targetClass) {
	//调用transactionInterceptor的getTransactionAttributeSource()，见TransactionAttributeSourcePointcut 得内部类TransactionAttributeSourcePointcut的匿名实现。
		TransactionAttributeSource tas = getTransactionAttributeSource();
		//判断是否是被拦截的方法
		return (tas == null || tas.getTransactionAttribute(method, targetClass) != null);
	}
```
这个TransactionAttributeSource是在完成依赖注入的时候配置的，在transactionInterceptor的基类TransactionAspectSupport中注入实现：

```
	public void setTransactionAttributes(Properties transactionAttributes) {
	//实际使用的是NameMatchTransactionAttributeSource，然后将事物配置属性设置到     
	//NameMatchTransactionAttributeSource。
		NameMatchTransactionAttributeSource tas = new NameMatchTransactionAttributeSource();
		tas.setProperties(transactionAttributes);
		this.transactionAttributeSource = tas;
	}
```
我们可以看到读取和匹配事物配置属性的是NameMatchTransactionAttributeSource ，这个类将transactionAttributes通过调用setProperties方法把调用的方法名为key，放到namemap中，在应用调用目标方法的时候，因为目标方法已经被TransactionProxyFactoryBean代理，所以TransactionProxyFactoryBean需要判断这个调用方法是否是事物方法，这个判断的实现是通过NameMatchTransactionAttributeSource 中能否为这个调用返回事物属性来完成的，具体的实现是这样的：首先，以调用方法名为索引在namemap中查找相应的事物处理属性值，如果能够找到，那么就说明该调用方法和事物方法是直接对应的，如果你找不到，就用正则表达式的方式模糊匹配。意味着，可以使用通配符的方式指定要拦截的方法。返回的属性封装在TransactionAttribute 中。

```
 //配置事物属性的方法
	public void setProperties(Properties transactionAttributes) {
		TransactionAttributeEditor tae = new TransactionAttributeEditor();
		Enumeration propNames = transactionAttributes.propertyNames();
		while (propNames.hasMoreElements()) {
			String methodName = (String) propNames.nextElement();
			String value = transactionAttributes.getProperty(methodName);
			tae.setAsText(value);
			TransactionAttribute attr = (TransactionAttribute) tae.getValue();
			addTransactionalMethod(methodName, attr);
		}
	}
//将被拦截的方法的名字为key，配置的属性为value放入到nameMap中去。
	public void addTransactionalMethod(String methodName, TransactionAttribute attr) {
		if (logger.isDebugEnabled()) {
			logger.debug("Adding transactional method [" + methodName + "] with attribute [" + attr + "]");
		}
		this.nameMap.put(methodName, attr);
	}

//根据方法名字活模式取配置的事物属性
	public TransactionAttribute getTransactionAttribute(Method method, Class<?> targetClass) {
		// look for direct name match
		String methodName = method.getName();
		//以名字为key
		TransactionAttribute attr = this.nameMap.get(methodName);

		if (attr == null) {
			// Look for most specific name match.
			String bestNameMatch = null;
			for (String mappedName : this.nameMap.keySet()) {
			//isMatch使用模糊或者通配符的方式匹配
				if (isMatch(methodName, mappedName) &&
						(bestNameMatch == null || bestNameMatch.length() <= mappedName.length())) {
					attr = this.nameMap.get(mappedName);
					bestNameMatch = mappedName;
				}
			}
		}
//返回取得的属性值
		return attr;
	}

```
10.3事物处理拦截器的设计与实现
TransactionProxyFactoryBean代理得到代理对象，通过调用getObject()得到，对目标方法的调用，TransactionProxyFactoryBean不会直接调用而是经过拦截器的拦截：
getObject方法：

```
	public Object getObject() {
		if (this.proxy == null) {
			throw new FactoryBeanNotInitializedException();
		}
		 //proxy已经配置好事物拦截器配置
		return this.proxy;
	}
```
对AOP代理起到作用，是用到TransactionInterceptor的回调方法，invoke方法：

```
	public Object invoke(final MethodInvocation invocation) throws Throwable {
		// Work out the target class: may be <code>null</code>.
		// The TransactionAttributeSource should be passed the target class
		// as well as the method, which may be from an interface.
		 //目标对象
		Class<?> targetClass = (invocation.getThis() != null ? AopUtils.getTargetClass(invocation.getThis()) : null);

		// If the transaction attribute is null, the method is non-transactional.
		//取得事物的配置属性，通过TransactionAttributeSource得到
		final TransactionAttribute txAttr =
				getTransactionAttributeSource().getTransactionAttribute(invocation.getMethod(), targetClass);
//根据TransactionProxyFactoryBean的配置信息获取具体的事物处理器
		final PlatformTransactionManager tm = determineTransactionManager(txAttr);
		final String joinpointIdentification = methodIdentification(invocation.getMethod(), targetClass);

// 这里获取不同的PlatformTransactionManager ，因为回调方式不同，CallbackPreferringPlatformTransactionManager的需要回调函数实现事物的回调与提交，而非CallbackPreferringPlatformTransactionManager不需要，DatasourceTransactionManager就不是CallbackPreferringPlatformTransactionManager
		if (txAttr == null || !(tm instanceof CallbackPreferringPlatformTransactionManager)) {
			// Standard transaction demarcation with getTransaction and commit/rollback calls.
			 //创建事物，并且把创建过程得到的信息放到TransactionInfo 中去，TransactionInfo 是封装事物状态的类
			TransactionInfo txInfo = createTransactionIfNecessary(tm, txAttr, joinpointIdentification);
			Object retVal = null;
			try {
				// This is an around advice: Invoke the next interceptor in the chain.
				// This will normally result in a target object being invoked.
				//继续走拦截器链，知道目标方法被调用。
				retVal = invocation.proceed();
			}
			catch (Throwable ex) {
				// target invocation exception
				//如果调用过程出现异常需要根据具体情况判断是提交或者回滚。
				completeTransactionAfterThrowing(txInfo, ex);
				throw ex;
			}
			finally {
			 //把线程绑定的TransactionInfo 置为oldTransactionInfo
				cleanupTransactionInfo(txInfo);
			}
			 //使用事物处理器对事物进行提交
			commitTransactionAfterReturning(txInfo);
			return retVal;
		}

		else {
			// It's a CallbackPreferringPlatformTransactionManager: pass a TransactionCallback in.
			//使用回调的方式
			try {
				Object result = ((CallbackPreferringPlatformTransactionManager) tm).execute(txAttr,
						new TransactionCallback<Object>() {
							public Object doInTransaction(TransactionStatus status) {
								TransactionInfo txInfo = prepareTransactionInfo(tm, txAttr, joinpointIdentification, status);
								try {
									return invocation.proceed();
								}
								catch (Throwable ex) {
									if (txAttr.rollbackOn(ex)) {
										// A RuntimeException: will lead to a rollback.
										//导致事物回滚
										if (ex instanceof RuntimeException) {
											throw (RuntimeException) ex;
										}
										else {
											throw new ThrowableHolderException(ex);
										}
									}
									else {
										// A normal return value: will lead to a commit.
										//正常的处理，进行事物提交
										return new ThrowableHolder(ex);
									}
								}
								finally {
									cleanupTransactionInfo(txInfo);
								}
							}
						});

				// Check result: It might indicate a Throwable to rethrow.
				if (result instanceof ThrowableHolder) {
					throw ((ThrowableHolder) result).getThrowable();
				}
				else {
					return result;
				}
			}
			catch (ThrowableHolderException ex) {
				throw ex.getCause();
			}
		}
	}
```
事物提交时序图：
![这里写图片描述](20150715155836118.png)
invoke方法是AOP和spring事物处理的桥梁，接下来就是事物处理的实现。
