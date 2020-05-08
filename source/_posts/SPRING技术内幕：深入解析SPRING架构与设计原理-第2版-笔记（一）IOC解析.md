---
title: SPRING技术内幕：深入解析SPRING架构与设计原理(第2版)-笔记（一）IOC解析
date: 2018-09-28 18:58:43
tags: spring
categories: spring
---
开始之前先说一下Beanfactory的结构原理：

![这里写图片描述](20150610213912663.png)
<!-- more -->

下图是springIOC解析的整个过程：
![这里写图片描述](20150518222648397)![这里写图片描述](20150518222843084.png)![这里写图片描述](20150518223322309.png)

IOC容器分为3个步骤：     
1、定位               
(1)Resource resource = resourceLoader.getResource(location);
int loadCount = loadBeanDefinitions(resource);
(2)loadBeanDefinitions委派为子类XmlBeanDefinitionReader的重写方法
(3)定位：在方法loadBeanDefinitions(String location, Set<Resource> actualResources)中语句：
Resource resource = resourceLoader.getResource(location)，resourceLoader调用其实现类DefaultResourceLoader的getResource(String location)方法的getResourceByPath(location)定位加载资源，getResourceByPath(location)在FileSystemXmlApplicationContext已经重写，即，调用的FileSystemXmlApplicationContext的实现方法。这也解释了FileSystemXmlApplicationContext有一个getResourceByPath方法的原因（委派机制）。                
2、载入      
主要实现类：
BeanDefinitionParserDelegate.parseBeanDefinitionElement(
			Element ele, String beanName, BeanDefinition containingBean):

```
/**
	 * Parse the bean definition itself, without regard to name or aliases. May return
	 * <code>null</code> if problems occured during the parse of the bean definition.
	 */
	public AbstractBeanDefinition parseBeanDefinitionElement(
			Element ele, String beanName, BeanDefinition containingBean) {

		this.parseState.push(new BeanEntry(beanName));

		String className = null;
		if (ele.hasAttribute(CLASS_ATTRIBUTE)) {
			className = ele.getAttribute(CLASS_ATTRIBUTE).trim();
		}

		try {
			String parent = null;
			if (ele.hasAttribute(PARENT_ATTRIBUTE)) {
				parent = ele.getAttribute(PARENT_ATTRIBUTE);
			}
			AbstractBeanDefinition bd = createBeanDefinition(className, parent);

			parseBeanDefinitionAttributes(ele, beanName, containingBean, bd);
			bd.setDescription(DomUtils.getChildElementValueByTagName(ele, DESCRIPTION_ELEMENT));

			parseMetaElements(ele, bd);
			parseLookupOverrideSubElements(ele, bd.getMethodOverrides());
			parseReplacedMethodSubElements(ele, bd.getMethodOverrides());

			parseConstructorArgElements(ele, bd);
			parsePropertyElements(ele, bd);
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

```


3、注册   
主要实现类：
DefaultListableBeanFactory.registerBeanDefinition(String beanName, BeanDefinition beanDefinition)

```
//---------------------------------------------------------------------
	// Implementation of BeanDefinitionRegistry interface
	//---------------------------------------------------------------------

	public void registerBeanDefinition(String beanName, BeanDefinition beanDefinition)
			throws BeanDefinitionStoreException {

		Assert.hasText(beanName, "Bean name must not be empty");
		Assert.notNull(beanDefinition, "BeanDefinition must not be null");

		if (beanDefinition instanceof AbstractBeanDefinition) {
			try {
				((AbstractBeanDefinition) beanDefinition).validate();
			}
			catch (BeanDefinitionValidationException ex) {
				throw new BeanDefinitionStoreException(beanDefinition.getResourceDescription(), beanName,
						"Validation of bean definition failed", ex);
			}
		}

		synchronized (this.beanDefinitionMap) {
			Object oldBeanDefinition = this.beanDefinitionMap.get(beanName);
			if (oldBeanDefinition != null) {
				if (!this.allowBeanDefinitionOverriding) {
					throw new BeanDefinitionStoreException(beanDefinition.getResourceDescription(), beanName,
							"Cannot register bean definition [" + beanDefinition + "] for bean '" + beanName +
							"': There is already [" + oldBeanDefinition + "] bound.");
				}
				else {
					if (this.logger.isInfoEnabled()) {
						this.logger.info("Overriding bean definition for bean '" + beanName +
								"': replacing [" + oldBeanDefinition + "] with [" + beanDefinition + "]");
					}
				}
			}
			else {
				this.beanDefinitionNames.add(beanName);
				this.frozenBeanDefinitionNames = null;
			}
			this.beanDefinitionMap.put(beanName, beanDefinition);

			resetBeanDefinition(beanName);
		}
	}
```
