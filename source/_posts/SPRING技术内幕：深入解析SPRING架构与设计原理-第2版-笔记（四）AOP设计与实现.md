---
title: SPRING技术内幕：深入解析SPRING架构与设计原理(第2版)-笔记（四）AOP设计与实现
date: 2018-09-28 19:20:41
tags: spring
categories: spring
---
proxyConfig是一个数据基类，这个数据基类为proxyFactoryBean这样的子类提供配置属性，在另一个基类advisesupport的实现中，封装了AOP对通知和通知其的相关操作，这些操作对于不同AOP的代理对象的生成都是一样的，但对于具体的AOP代理对象的创建，advisedSupport把它交给他的子类们去完成，对于proxyCreatorsupport,可以将它看成是其子类创建AOP代理对象的一个辅助类。aspectJProxyBean起到集成Spring和AspectJ的作用；对于使用SpringAOP的应用，ProxyFactoryBean和ProxyFactory都提供了AOP功能的封装，只是使用ProxyFactory,可以在IOC容器中完成声明式配置，而使用ProxyFactory，则需要编程式的使用spring AOP
![这里写图片描述](2018/09/28/SPRING技术内幕：深入解析SPRING架构与设计原理-第2版-笔记（四）AOP设计与实现/20150519215523554.png)
