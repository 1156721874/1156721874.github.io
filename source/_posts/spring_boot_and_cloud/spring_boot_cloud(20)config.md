---
title: spring_boot_cloud(19)config
date: 2020-06-21 21:23:30
tags: [config]
categories: spring_boot_cloud
---

### spring cloud config
- 用来为分布式系统中的基础设置和微服务应用提供集中化的外部配置支持，它分为服务端与客户端两个部分，其中服务端也称为分布式配置中心，他是一个独立的微服务应用，用来连接配置仓库并为客户端提供获取配置信息，加密/解密信息等访问接口；而客户端则是微服务架构中的各个微服务应用或基础设施，他们通过指定的配置中心来管理应用资源与业务相关的配置内容，并在启动的时候从配置中心获取和加载配置信息。
![config1.png](config1.png)

- spring cloud config实现了对服务端和客户端中环境变量和属性配置的抽象映射，他是除了适用于spring构建的应用程序之外，也可以在任何其他语言运行的应用程序中使用，由于spring cloud config实现的配置中心默认采用git来存储配置信息，所以使用spring cloud config构建的配置服务器，天然就支持对微服务应用配置信息的版本管理，并且可以通过git客户端工具来方便的管理和访问配置内容。当然他也提供了对其他存储方式的支持，比如svn仓库，本地化文件系统。

spring cloud config 文件与访问方式剖析
- 仓库中的配置文件会被转换为web接口，访问请参考以下的规则
  - {application}/{profile}/{label}
  - {application}-{profile}.yml
  - {label}/{application}-{profile}.yml
  - {application}/{profile}.preperties
  - {label}/{application}-{profile}.properties
- 以config-client-dev为例，它的application是config-client（这里的application是存储配置的应用程序名字），profile是dev。
client会根据填写的参数来选择读取对应的配置。

spring cloud config的高可用
![config2.png](config2.png)

【本期代码：https://github.com/1156721874/spring_cloud_projects】
