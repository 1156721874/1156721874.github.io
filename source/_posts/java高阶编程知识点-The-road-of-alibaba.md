---
title: java高阶编程知识点---The road of alibaba
date: 2018-09-27 20:54:54
tags:
categories: 技术之路
---


第一部分   面试初级

阿里面试题目总结：

第一轮面试电话（5月6号）：

1.自我介绍，包括做过项目。

2.有看过哪些JDK源码，了解哪些常用库。

3.集合框架HashMap的扩容机制，ConcurrnetHashMap的原理

java集合框架图：http://blog.csdn.net/stefanie860624/article/details/7245873

4.jvm内存模型与gc内存回收机制

5.classloader结构，是否可以自己定义一个java.lang.String类，为什么？ 双亲代理机制。

6.了解哪些设计模式，6个设计原则分别是什么？每种设计原则体现的设计模式是哪个？

7.关于设计模式看了哪些书？书名是什么？

8.uml模型图画过哪些？ 类图中类之间的关系有哪些，区别分别是什么？

9.画uml中类图时候用过一种虚线么？做什么用的？

10.做过应用相关性能测试的，举个例子，实际项目中怎么使用的。

用过并发框架相关的哪些内容

11.了解哪些osgi的框架？

12有没有做过jvm内存调优，如何做的，举例子，用过哪些工具？

//一些不记得了



第二轮面试视频

1.自我介绍

2.看过哪些源码

3.java的io库的类结构图所用到的设计模式如何体现

4.画出自己设计过的设计模式如何体现，画出结构图，并进行讲解。

5.画出自己做的架构的项目架构图 如何扩展等

6.数据库设计中主键id设计的原则

7.jvm内存调优用过哪些工具，jstate做什么用的？如何dump出当前线程状态？

8.并发框架是否有了解

9.classloader的双亲代理机制

10.应用服务器的jvm调优实际经验，如何做的，在哪里用到的

11.在哪里获取最新资讯，逛什么论坛。最新的Swift语言有什么看法

12.设计原则与设计模式对应

13.servlet/filter作用原理配置

14.ibatis in操作 以及一个属性的作用

15.spring aop 用了什么设计原则，自动注入配置是做什么用的

16.jboss的类加载器

17.session共享机制

18.做过最成功的一件事情是什么？

19.最大的争执是什么？

20.为什么想要离职去阿里

//问题很多，一些不记得了



第三轮面试电话：

1.现在公司负责什么？

2.项目主要目的是做什么的？

3.公司管理方式、项目问题反馈机制是什么？

4.Java 的序列化做什么用的 序列化id会出现哪些问题？

5.OSGi用过哪些？类加载器结构如何，如何在一个bundle中加载另外一个bundle中的一个类？

6.nio是否了解 阻塞之后通知机制是怎样的？

7.uml设计类图如何画，类之间关系以及区别

8.spring如何不许要配置文件加载bean定义，可能是问自动注解或者是properties文件定义bean

9.ibatis等框架是不是都是实际在使用的,技术细节

10.为什么想离职去阿里

//一些不记得了



第四轮总监面电话面试：

1.自我介绍

2.公司做什么，业务， 负责内容，汇报机制等

3.企业级应用安全相关

4.http协议，返回码，301与302区别

5.多线程并发用过哪些

6.应用服务器相关，谈最熟悉的

7.为什么离职

//这个太多不记得了，很多不太会。

第二部分   面试升级

http://lvwenwen.iteye.com/blog/1495707

第三部分  Java集合框架、IO框架、虚拟机相关、线程

l  JAVA IO 设计模式彻底分析：http://blog.csdn.net/oracle_microsoft/article/details/2444947

l  JVM类加载机制：http://blog.csdn.net/nysyxxg/article/details/41978019?ref=myread

l  Java虚拟机学习分享：http://bbs.csdn.net/topics/390251794

l  JDK动态代理实现原理：http://rejoy.iteye.com/blog/1627405
l  java容器类源码分析——LinkedHashMap：http://www.iteye.com/topic/1131321
l  ConcurrentHashMap：http://iwebcode.iteye.com/blog/1306640
l  解读ClassLoader：http://www.iteye.com/topic/83978
l  Java并发编程：线程池的使用：http://www.cnblogs.com/dolphin0520/p/3932921.html
l  深入理解HashMap: http://www.iteye.com/topic/539465
l  需要完全掌握的集合（走读源代码）：
Map m1 = newHashMap();

Map m2 = newHashtable();

Map m3 = newTreeMap();

Mapm4 = new  ConcurrentHashMap();

Map m5 = new  LinkedHashMap();



Set s1 = newHashSet();

Set s2 = newTreeSet();

Set s3 = newLinkedHashSet();





List l1 = newArrayList();

List l2 = new  LinkedList();

Deque<String> deque = newLinkedList<String>();//栈

Queue<String> queue = newLinkedList<String>();//队列
第四部分   Tomcat以及其他项目源码

java类加载器-Tomcat类加载器：http://www.cnblogs.com/metoy/p/3917535.html
Tomcat源码分析：http://www.cnblogs.com/metoy/p/3855875.html
Spring源码走读：
《Spring_IOC_.pdf》、
《spring源码解析.pdf》、
《Spring技术内幕：深入解析Spring架构与设计原理第2版》
第五部分  理论

设计模式六大原则：http://fyd222.iteye.com/blog/1443150
计算机网络的基础诸如TCP、IP、三次握手。
第六部       推荐书籍（重点）

《阿里Java Web技术内幕（修订版）试读样章》

《深入理解_Java_虚拟机_(JVM_高级特性与最佳实践)》

此博客全部看完：http://blog.csdn.net/chjttony/article/list/

《淘宝技术这十年，完整最终确认版》

第七部分    提高（云计算方向）

《大型分布式网站架构设计与实践》

《Storm 实战：构建大数据实时计算试读样章》

《重构大数据统计试读样章》

JDK源码视频300集（讲师是尚学堂讲师高级高琪，此视频看完绝对走火入魔，慎入。。。哈哈）：

链接：http://pan.baidu.com/s/1mg1JaiO密码：t21s



第八部分    算法

1、  递归、冒泡排序、归并排序、插入排序、快速排序以及他们的平均复杂度。

2、  平衡二叉树、满二叉树、红黑树。

3、  链表、数组。

4、  B树、B+数。



未完待续…..

你要想得到你从未有过的东西，就必须做你从未做过的事！
