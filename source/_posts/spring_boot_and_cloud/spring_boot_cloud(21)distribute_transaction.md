---
title: spring_boot_cloud(21)distribute_transaction
date: 2020-06-25 16:04:30
tags: [distribute_transaction]
categories: spring_boot_cloud
---

### 分布式事物
- 2pc
- 3pc
- tcc
- 事物的最终一致性
<!-- more -->
#### 2pc 2阶段提交
![2pc.png](2pc.png)
- 角色：Transaction Manager、Resource Manager
- 预提交阶段
  Transaction Manager给Resource Manager发信息，进行预提交，然后Resource Manager会把预提交的结果反馈给Transaction Manager
- 提交阶段
  如果预提交阶段所有的Resource Manager都是返回OK，那么进行真正的提交，Transaction Manager给所有的Resource Manager发信息，全部提交，然后所有的Resource Manager都会给Transaction Manager返回提交结果。
- 异常处理，如果预提交阶段其中任何一个Resource Manager返回失败，那么Transaction Manager都会给所有Resource Manager发送回滚。
  同样的道理如果是提交阶段任何一个Resource Manager返回失败，那么Transaction Manager也会给所有Resource Manager发送回滚信息。
- Resource Manager里边是一个jvm实例，可以使用spring的事物管理器管理提交和回滚。
- 不完美处：在预提交处会对所有涉及的资源资源进行锁定，第二是Transaction Manager存在单点故障，导致整个轮子不可用

####  3pc三阶段提交
 3pc其实是对2pc的第一阶段 一分为二。同时针对Transaction Manager、Resource Manager都设置里的超时，如果超时了不会进行提交。
 - can commit
  我能提交吗
 - 预提交
 - 提交

####  TCC
try confirm cancel
![tcc.png](tcc.png)
- try
  main发起者对每个依赖的服务ABCD执行try，try的内容是，比如：下单，对A减100，对B加100，对C减库存，对D积分加20.
  ABCD每个服务在try阶段都是对自己业务表的一个备用字段进行加减，不是对真正的业务字段进行操作，只是尝试，try一下。
- confirm
    如果try阶段都是返回成功，那么执行confirm阶段，这个阶段main会给ABCD发送真正提交的命令，然后ABCD收到命令之后执行真正的业务字段的加减操作和提交。
- cancel
  如果在try或者confirm阶段，ABCD任何一个返回失败，那么main会给ABCD发送cancel的命令，撤销操作。

tcc是同步的模式。

#### 最终一致性
异步的事物一致性
