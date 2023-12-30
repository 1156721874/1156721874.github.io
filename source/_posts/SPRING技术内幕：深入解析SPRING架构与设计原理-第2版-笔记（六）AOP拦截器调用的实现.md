---
title: SPRING技术内幕：深入解析SPRING架构与设计原理(第2版)-笔记（六）AOP拦截器调用的实现
date: 2018-09-28 19:28:58
tags: spring
categories: spring
---
**JdkDynamicAopProxy**
JdkDynamicAopProxy代理对象的回调：
JdkDynamicAopProxy通过ReflectiveMethodInvocation完成拦截器链的调用，
<!-- more -->
```
/**
	 * Implementation of <code>InvocationHandler.invoke</code>.
	 * <p>Callers will see exactly the exception thrown by the target,
	 * unless a hook method throws an exception.
	 */
	public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
		MethodInvocation invocation;
		Object oldProxy = null;
		boolean setProxyContext = false;
		TargetSource targetSource = this.advised.targetSource;

		Class targetClass = null;
		Object target = null;

		try {
			if (!this.equalsDefined && AopUtils.isEqualsMethod(method)) {
				// The target does not implement the equals(Object) method itself.
				return equals(args[0]);
			}
			if (!this.hashCodeDefined && AopUtils.isHashCodeMethod(method)) {
				// The target does not implement the hashCode() method itself.
				return hashCode();
			}
			if (!this.advised.opaque && method.getDeclaringClass().isInterface() &&
					method.getDeclaringClass().isAssignableFrom(Advised.class)) {
				// Service invocations on ProxyConfig with the proxy config...没有拦截器直接调用目标对象的方法
				return AopUtils.invokeJoinpointUsingReflection(this.advised, method, args);
			}

			Object retVal;

			if (this.advised.exposeProxy) {
				// Make invocation available if necessary.
				oldProxy = AopContext.setCurrentProxy(proxy);
				setProxyContext = true;
			}

			// May be null. Get as late as possible to minimize the time we "own" the target,
			// in case it comes from a pool.
			/*targetSource.getTarget()可以从一个对象池或者对象工厂获得，target可以配置成热部署，可以随时切换目标对   
			*象，配置的时候可以将HotSwappableTargetSource作为ProxyFactoryBean的target属性即可。
		    */
			target = targetSource.getTarget();
			if (target != null) {
				targetClass = target.getClass();
			}

			// Get the interception chain for this method.
			List<Object> chain = this.advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);

			// Check whether we have any advice. If we don't, we can fallback on direct
			// reflective invocation of the target, and avoid creating a MethodInvocation.
			if (chain.isEmpty()) {
				// We can skip creating a MethodInvocation: just invoke the target directly
				// Note that the final invoker must be an InvokerInterceptor so we know it does
				// nothing but a reflective operation on the target, and no hot swapping or fancy proxying.
				retVal = AopUtils.invokeJoinpointUsingReflection(target, method, args);
			}
			else {
				// We need to create a method invocation...
				invocation = new ReflectiveMethodInvocation(proxy, target, method, args, targetClass, chain);
				// Proceed to the joinpoint through the interceptor chain.
				retVal = invocation.proceed();
			}

			// Massage return value if necessary.
			if (retVal != null && retVal == target && method.getReturnType().isInstance(proxy) &&
					!RawTargetAccess.class.isAssignableFrom(method.getDeclaringClass())) {
				// Special case: it returned "this" and the return type of the method
				// is type-compatible. Note that we can't help if the target sets
				// a reference to itself in another returned object.
				retVal = proxy;
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
**Cglib2AopProxy**
Cglib2AopProxy的intercept的回调：
其使用内部类DynamicAdvisedInterceptor 的intercept方法回调实现，使用CglibMethodInvocation完成拦截器链的调用。
```
	/**
	 * General purpose AOP callback. Used when the target is dynamic or when the
	 * proxy is not frozen.
	 */
	private static class DynamicAdvisedInterceptor implements MethodInterceptor, Serializable {

		private AdvisedSupport advised;

		public DynamicAdvisedInterceptor(AdvisedSupport advised) {
			this.advised = advised;
		}

		public Object intercept(Object proxy, Method method, Object[] args, MethodProxy methodProxy) throws Throwable {
			Object oldProxy = null;
			boolean setProxyContext = false;
			Class targetClass = null;
			Object target = null;
			try {
				if (this.advised.exposeProxy) {
					// Make invocation available if necessary.
					oldProxy = AopContext.setCurrentProxy(proxy);
					setProxyContext = true;
				}
				// May be <code>null</code>. Get as late as possible to minimize the time we
				// "own" the target, in case it comes from a pool.
				target = getTarget();
				if (target != null) {
					targetClass = target.getClass();
				}
				List<Object> chain = this.advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);
				Object retVal;
				// Check whether we only have one InvokerInterceptor: that is,
				// no real advice, but just reflective invocation of the target.
				if (chain.isEmpty() && Modifier.isPublic(method.getModifiers())) {
					// We can skip creating a MethodInvocation: just invoke the target directly.
					// Note that the final invoker must be an InvokerInterceptor, so we know
					// it does nothing but a reflective operation on the target, and no hot
					// swapping or fancy proxying.没有AOP通知配置，直接调用target对象的方法
					retVal = methodProxy.invoke(target, args);
				}
				else {
					// We need to create a method invocation...
					retVal = new CglibMethodInvocation(proxy, target, method, args, targetClass, chain, methodProxy).proceed();
				}
				retVal = massageReturnTypeIfNecessary(proxy, target, method, retVal);
				return retVal;
			}
			finally {
				if (target != null) {
					releaseTarget(target);
				}
				if (setProxyContext) {
					// Restore old proxy.
					AopContext.setCurrentProxy(oldProxy);
				}
			}
		}

		@Override
		public boolean equals(Object other) {
			return (this == other ||
					(other instanceof DynamicAdvisedInterceptor &&
							this.advised.equals(((DynamicAdvisedInterceptor) other).advised)));
		}

		/**
		 * CGLIB uses this to drive proxy creation.
		 */
		@Override
		public int hashCode() {
			return this.advised.hashCode();
		}

		protected Object getTarget() throws Exception {
			return this.advised.getTargetSource().getTarget();
		}

		protected void releaseTarget(Object target) throws Exception {
			this.advised.getTargetSource().releaseTarget(target);
		}
	}
```
**目标对象方法的调用**
JdkDynamicAopProxy目标对象方法的调用是通过AopUtils的invokeJoinpointUsingReflection方法实现的：

```
	/**
	 * Invoke the given target via reflection, as part of an AOP method invocation.
	 * @param target the target object
	 * @param method the method to invoke
	 * @param args the arguments for the method
	 * @return the invocation result, if any
	 * @throws Throwable if thrown by the target method
	 * @throws org.springframework.aop.AopInvocationException in case of a reflection error
	 */
	public static Object invokeJoinpointUsingReflection(Object target, Method method, Object[] args)
			throws Throwable {

		// Use reflection to invoke the method.
		try {
			ReflectionUtils.makeAccessible(method);
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

}
```
**拦截器链的调用**

不论是JdkDynamicAopProxy还是Cglib2AopProxy归根到底是通过ReflectiveMethodInvocation的proceed方法调用拦截器链的，
![这里写图片描述](2018/09/28/SPRING技术内幕：深入解析SPRING架构与设计原理-第2版-笔记（六）AOP拦截器调用的实现/20150521220420283.png)
advised（class：AdvisedSupport  ）持有拦截器链，getInterceptorsAndDynamicInterceptionAdvice方法的实现在其基类AdvisedSupport中：

```
	/**
	 * Determine a list of {@link org.aopalliance.intercept.MethodInterceptor} objects
	 * for the given method, based on this configuration.
	 * @param method the proxied method
	 * @param targetClass the target class
	 * @return List of MethodInterceptors (may also include InterceptorAndDynamicMethodMatchers)
	 */
	public List<Object> getInterceptorsAndDynamicInterceptionAdvice(Method method, Class targetClass) {
		MethodCacheKey cacheKey = new MethodCacheKey(method);
		List<Object> cached = this.methodCache.get(cacheKey);
		if (cached == null) {
			cached = this.advisorChainFactory.getInterceptorsAndDynamicInterceptionAdvice(
					this, method, targetClass);
			this.methodCache.put(cacheKey, cached);
		}
		return cached;
	}
```
工厂advisorChainFactory（impl:DefaultAdvisorChainFactory）完成拦截器链的获取过程，其中的AdvisorAdapterRegistry是完成ProxyFactoryBean从XML文件张得到的拦截器的注册工作，主要是放到之前设置好的List集合里边。list中的拦截器被JdkDynamicAopProxy的invoke或者Cglib2AopProxy的intercep对象使用得到拦截器。
DefaultAdvisorChainFactory的getInterceptorsAndDynamicInterceptionAdvice方法：

```
	public List<Object> getInterceptorsAndDynamicInterceptionAdvice(
			Advised config, Method method, Class targetClass) {

		// This is somewhat tricky... we have to process introductions first,
		// but we need to preserve order in the ultimate list.
		List<Object> interceptorList = new ArrayList<Object>(config.getAdvisors().length);
		boolean hasIntroductions = hasMatchingIntroductions(config, targetClass);
		AdvisorAdapterRegistry registry = GlobalAdvisorAdapterRegistry.getInstance();
		for (Advisor advisor : config.getAdvisors()) {
			if (advisor instanceof PointcutAdvisor) {
				// Add it conditionally.
				PointcutAdvisor pointcutAdvisor = (PointcutAdvisor) advisor;
				if (config.isPreFiltered() || pointcutAdvisor.getPointcut().getClassFilter().matches(targetClass)) {
					MethodInterceptor[] interceptors = registry.getInterceptors(advisor);
					MethodMatcher mm = pointcutAdvisor.getPointcut().getMethodMatcher();
					if (MethodMatchers.matches(mm, method, targetClass, hasIntroductions)) {
						if (mm.isRuntime()) {
							// Creating a new object instance in the getInterceptors() method
							// isn't a problem as we normally cache created chains.
							for (MethodInterceptor interceptor : interceptors) {
								interceptorList.add(new InterceptorAndDynamicMethodMatcher(interceptor, mm));
							}
						}
						else {
							interceptorList.addAll(Arrays.asList(interceptors));
						}
					}
				}
			}
			else if (advisor instanceof IntroductionAdvisor) {
				IntroductionAdvisor ia = (IntroductionAdvisor) advisor;
				if (config.isPreFiltered() || ia.getClassFilter().matches(targetClass)) {
					Interceptor[] interceptors = registry.getInterceptors(advisor);
					interceptorList.addAll(Arrays.asList(interceptors));
				}
			}
			else {
				Interceptor[] interceptors = registry.getInterceptors(advisor);
				interceptorList.addAll(Arrays.asList(interceptors));
			}
		}
		return interceptorList;
	}
```
事实上advisor通知其是在adviosrSupport得到并初始化的，再其子类ProxyFactoryBean中的实现如下：

```
/**
	 * Create the advisor (interceptor) chain. Aadvisors that are sourced
	 * from a BeanFactory will be refreshed each time a new prototype instance
	 * is added. Interceptors added programmatically through the factory API
	 * are unaffected by such changes.
	 */
	private synchronized void initializeAdvisorChain() throws AopConfigException, BeansException {
		if (this.advisorChainInitialized) {
			return;
		}

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
				if (logger.isTraceEnabled()) {
					logger.trace("Configuring advisor or advice '" + name + "'");
				}

				if (name.endsWith(GLOBAL_SUFFIX)) {
					if (!(this.beanFactory instanceof ListableBeanFactory)) {
						throw new AopConfigException(
								"Can only use global advisors or interceptors with a ListableBeanFactory");
					}
					addGlobalAdvisor((ListableBeanFactory) this.beanFactory,
							name.substring(0, name.length() - GLOBAL_SUFFIX.length()));
				}

				else {
					// If we get here, we need to add a named interceptor.
					// We must check if it's a singleton or prototype.
					Object advice;
					if (this.singleton || this.beanFactory.isSingleton(name)) {
						// Add the real Advisor/Advice to the chain.
						advice = this.beanFactory.getBean(name);
					}
					else {
						// It's a prototype Advice or Advisor: replace with a prototype.
						// Avoid unnecessary creation of prototype bean just for advisor chain initialization.
						advice = new PrototypePlaceholderAdvisor(name);
					}
					addAdvisorOnChainCreation(advice, name);
				}
			}
		}

		this.advisorChainInitialized = true;
	}
```

已配置在XML中的advisor是通过IOC容器（DefaultListableBeanFactory）的getbean得到的。

**advice通知的实现**
上边DefaultAdvisorChainFactory的getInterceptorsAndDynamicInterceptionAdvice得到拦截器链的时候，使用了一个注册器（AdvisorAdapterRegistry registry = GlobalAdvisorAdapterRegistry.getInstance();），这个registry包含了很多AOP的主要核心实现，这是个单件：

```
/**
 * Singleton to publish a shared DefaultAdvisorAdapterRegistry instance.
 *
 * @author Rod Johnson
 * @author Juergen Hoeller
 * @see DefaultAdvisorAdapterRegistry
 */
public abstract class GlobalAdvisorAdapterRegistry {

	/**
	 * Keep track of a single instance so we can return it to classes that request it.
	 */
	private static final AdvisorAdapterRegistry instance = new DefaultAdvisorAdapterRegistry();

	/**
	 * Return the singleton DefaultAdvisorAdapterRegistry instance.
	 */
	public static AdvisorAdapterRegistry getInstance() {
		return instance;
	}

}
```
DefaultAdvisorAdapterRegistry中设置了一个adapters成员变量，放的是一系列AdvisorAdapter适配器，spring的advice对应的是一个适配器，这些是适配器的作用是：一是调用adapter的support方法，通过这个方法来判断取得的advice属于什么类型的advice通知，从而根据不同的advice类型来注册不同的adviceinterceptor，也就是前面看到的哪些拦截器；第二，这些adviceinterceptor都是springAOP框架设计好的，是为了实现不同的advice功能提供服务，有了这些adviceinterceptor，就可以方便使用由spring提供的各种不同advice来设计AOP应用，也就是说，正是这些adviceinterceptor最终实现了advice通知在AOPProxy代理对象中的织入功能。
advisorAdaptor接口中类的设计层次与关系：
![这里写图片描述](2018/09/28/SPRING技术内幕：深入解析SPRING架构与设计原理-第2版-笔记（六）AOP拦截器调用的实现/20150524144221973.png)
DefaultAdvisorAdapterRegistry代码：
```
public class DefaultAdvisorAdapterRegistry implements AdvisorAdapterRegistry, Serializable {

	private final List<AdvisorAdapter> adapters = new ArrayList<AdvisorAdapter>(3);


	/**
	 * Create a new DefaultAdvisorAdapterRegistry, registering well-known adapters.
	 */
	public DefaultAdvisorAdapterRegistry() {
		registerAdvisorAdapter(new MethodBeforeAdviceAdapter());
		registerAdvisorAdapter(new AfterReturningAdviceAdapter());
		registerAdvisorAdapter(new ThrowsAdviceAdapter());
	}


	public Advisor wrap(Object adviceObject) throws UnknownAdviceTypeException {
		if (adviceObject instanceof Advisor) {
			return (Advisor) adviceObject;
		}
		if (!(adviceObject instanceof Advice)) {
			throw new UnknownAdviceTypeException(adviceObject);
		}
		Advice advice = (Advice) adviceObject;
		if (advice instanceof MethodInterceptor) {
			// So well-known it doesn't even need an adapter.
			return new DefaultPointcutAdvisor(advice);
		}
		for (AdvisorAdapter adapter : this.adapters) {
			// Check that it is supported.
			if (adapter.supportsAdvice(advice)) {
				return new DefaultPointcutAdvisor(advice);
			}
		}
		throw new UnknownAdviceTypeException(advice);
	}

	public MethodInterceptor[] getInterceptors(Advisor advisor) throws UnknownAdviceTypeException {
		List<MethodInterceptor> interceptors = new ArrayList<MethodInterceptor>(3);
		Advice advice = advisor.getAdvice();
		if (advice instanceof MethodInterceptor) {
			interceptors.add((MethodInterceptor) advice);
		}
		for (AdvisorAdapter adapter : this.adapters) {
			if (adapter.supportsAdvice(advice)) {
			//调用adapter的support方法，通过这个方法来判断取得的advice属于什么类型的advice通知，从而根据不同的advice
			//类型来注册不同的adviceinterceptor
				interceptors.add(adapter.getInterceptor(advisor));
			}
		}
		if (interceptors.isEmpty()) {
			throw new UnknownAdviceTypeException(advisor.getAdvice());
		}
		return interceptors.toArray(new MethodInterceptor[interceptors.size()]);
	}

	public void registerAdvisorAdapter(AdvisorAdapter adapter) {
		this.adapters.add(adapter);
	}

}

```

拿MethodBeforeAdviceAdapter来举例，其源代码如下：

```
class MethodBeforeAdviceAdapter implements AdvisorAdapter, Serializable {

	public boolean supportsAdvice(Advice advice) {
		return (advice instanceof MethodBeforeAdvice);
	}

	public MethodInterceptor getInterceptor(Advisor advisor) {
		MethodBeforeAdvice advice = (MethodBeforeAdvice) advisor.getAdvice();
		return new MethodBeforeAdviceInterceptor(advice);
	}

}
```
从代码可以看到supportsAdvice方法是判断是不是Advice 是不是MethodBeforeAdvice类型的，如果是就会在上边的DefaultAdvisorAdapterRegistry 的getInterceptors方法调用其getInterceptor方法返回一个MethodBeforeAdviceInterceptor，这个就是拦截器链里边放的interceptor，
其代码如下：

```
public class MethodBeforeAdviceInterceptor implements MethodInterceptor, Serializable {

	private MethodBeforeAdvice advice;


	/**
	 * Create a new MethodBeforeAdviceInterceptor for the given advice.
	 * @param advice the MethodBeforeAdvice to wrap
	 */
	public MethodBeforeAdviceInterceptor(MethodBeforeAdvice advice) {
		Assert.notNull(advice, "Advice must not be null");
		this.advice = advice;
	}
//这个invoke方法是把拦截器的回调方法，会在代理对象的方法被调用时触发回调
	public Object invoke(MethodInvocation mi) throws Throwable {
		this.advice.before(mi.getMethod(), mi.getArguments(), mi.getThis() );
		return mi.proceed();
	}

}
```
MethodBeforeAdviceInterceptor 封装了advice，可以在methodbeforeadviceinterceptor设计的invoke回调方法中，看到首先触发了advice的before回调，然后才是methodInvocation的process方法调用，看到这里，就已经和前面在reflectmethodInvocation的process分析中联系起来了，回忆一下，在AOpProxy代理对象触发ReflectiveMethodInvocation的process方法中，在取得拦截器以后，启动对拦截器invoke方法的调用，按照AOP的配置规则，reflectiveMethodInvocation触发的拦截器invoke方法，最会以根据不同的advice类型，触发spring对不同advice的拦截器封装，比如对MethodBeforAdvice。最终会触发MethodBeforAdviceInterceptor方法。在MethodBeforAdviceInterceptor方法中，会先调用advice的before方法，这就是MethodBeforAdvice所需要的对象的增强效果，在方法之前完成通知增强。AfterReturningAdviceAdapter、ThrowsAdviceAdapter按照同样的原理进行。
