---
title: spring_boot_cloud(1)微服务宏观把控与深入剖析
date: 2019-05-19 20:03:32
tags: [微服务]
categories: spring_boot_cloud
---

### 什么是微服务
- Martin Fowler:简而言之，微服务架构风格这种开发方法，是以开发一组小型服务的方式来开发一个独立的应用系统。其中每个小型服务都运行在自己的进程中，并经常采用http资源api这样轻量级的机制来互相通信。这些服务围绕业务功能进行构建，并能通过全量自动的部署机制来进行独立部署。这些微服务可以使用不同的语言来编写，并且可以使用不同的数据存储技术。对于这些微服务我们仅做最低限度的集中管理。

[Martin Fowler关于微服务的解读](https://martinfowler.com/articles/microservices.html)
此处为了读者理解和阅读，引用二龙湖 [@Jerry xu](https://github.com/BladeCode)对此文的翻译给各位吃瓜群众，[【译】• 微服务](https://incoder.org/2019/06/01/microservices/)


- 微服务是一种架构模式，她提倡将单一应用程序划分成一组小的服务，服务之间相互协调、相互配合，为用户提供最终价值。
每个服务运行在其独立的进程中，服务于服务间采用轻量级的通信机制相互通信（通常是基于http的restfull api）每个服务都围绕着具体业务构建、并且能够独立的部署到生产环境、类生产环境等。另外，应尽量避免统一的、集中式的服务器管理机制，对具体的一个服务而言，应根据业务上下文，选择合适的语言、工具对其进行构建。
- 微服务是一种架构风格，一个大型复杂软件应用由一个或多个微服务组成，系统中的各个微服务可被独立部署，各个微服务之间是松耦合的。每个微服务仅关注于完成一件任务并很好的完成该任务，在所有情况下，每个任务代表着一个小的业务能力。

- 微服务的优点
  - 易于开发和维护
  - 启动较快
  - 局部修改容易部署
  - 技术栈不受限
  - 按需伸缩
  - DevOps

- 微服务带来的挑战
  - 运维要求较高
  - 分布式的复杂性
  - 接口调整成本高
  - 重复劳动

- 微服务设计原则
  - 单一职责原则
  - 服务自治原则
  - 轻量级通信原则
  - 接口明确原则

### 什么是SOA
- soa的概念和介绍
[Service-oriented_architecture](https://en.wikipedia.org/wiki/Service-oriented_architecture)
此处为了读者理解和阅读，引用二龙湖 [@Jerry xu](https://github.com/BladeCode)对此文的翻译给各位吃瓜群众，[【译】• 面向服务的架构](https://incoder.org/2019/06/19/soa/)


### SOA和microservices的区别
[soa-versus-microservices](https://www.ibm.com/blogs/cloud-computing/2018/09/06/soa-versus-microservices/)
这篇文章主要的点时soa是在应用(application)上的架构模式，而微服务是在服务(service)上的架构模式

[microservices-vs-soa-is-there-any-difference-at-al](https://dzone.com/articles/microservices-vs-soa-is-there-any-difference-at-al)
