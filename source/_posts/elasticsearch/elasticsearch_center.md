---
title: elasticsearch_center
date: 2019-07-16 14:05:45
tags: [elasticsearch]
categories: cloud
---

### 背景
  公司内部要对搜索中心进行改造，降低运维成本，leader让我负责整块的设计和编码以及前端展示，整个开发历时30个工作日，完成第一期，现在把一些当中的点做一次share，各位看官轻喷。

#### 现有系统的状态
  所在团队做的是跨境电商的服务，海量的商品存在mysql集群当中，当商品上架的时刻，需要将mysql的数据同步到elasticsearch集群当中，目的是为了给用户提供快速的搜索服务，同步的最小单元是表，即将一张表同步到es集群，老的系统的做法是当随着业务的增长，表结构会变化，或者增加，修改表等等一些DDL操作，之前的做法是每当这些变化发生的时候，需要在搜索中心的工程当中编写正对于变化的表的同步代码，适配mysql的变化，比如新增加了一张表，需要对这张表的数据同步到es，就需要写一个正对于此表的同步任务，修改表也是如此，需要制定开发周期，排工作量，测试计划等等。

##### 之前的架构设计
  针对于每一个mysql数据库实例都对接一个[canal](https://github.com/alibaba/canal)服务,canal监听mysql的binlog日志，然后将日志push到mq（canal支持kafka和rocketmq）里边，然后我们的app就是mq的消费者，消费mq的消息，消费的过程就是从mq的broker执行poll，拉取消息，然后将消息解析，得到消息里边的业务id，通过业务id去真实的mysql数据查询数据（重新查询一次mysql，这么做的原因是保证数据的强一致性），然后将数据刷新到es集群，完成消息的消费。
  ![old_structure.png](old_structure.png)

#### 现有系统存在的问题
  - 新增表需要进行针对性编码
  - 修改表需要进行针对性编码
  - 新增加数据库需要进行针对性编码
  - 索引的版本管理混乱
    - 需要手动掉es的http api切换别名(开发人员在使用es的搜索api查询的时候都是使用的别名，一个别名只能同时指向一个索引，如果发生索引升级，需要指向新的索引版本，别名的存在就是为了做无缝切换)
  ![remappinh_reindex.png](remappinh_reindex.png)
  - 数据类型映射管理刀工火种，人工做jdbc到es的数据类型映射太繁琐，还容易出错。
  ![dataTypeMapping.png](dataTypeMapping.png)

#### 现有轮子考察
  - Elasticsearch-jdbc
    - Not support Elasticsearch 5.0
    - Not support delete and unfriendly incremental update
    - https://github.com/jprante/elasticsearch-jdbc/issues/915
  - logstash-jdbc
    - Create new config need restart server
    - https://github.com/logstash-plugins/logstash-input-jdbc.git
  - elasticsearch-river-mysq
    - Stop maintain
  - go-mysql-elasticsearch
    - Unstable
    - Can not alter table format at runtime
    - Can not change too many rows at same time in one SQL
    - https://github.com/siddontang/go-mysql-elasticsearch

    现有轮子都存在各种各样的问题，阿里的dataX对增量是同步不太友好，而且对es的一些特性支持不友好,比如parent-child关系映射直接不支持。

#### 新改造支持的特性

  - 动态创建主题(mq topic)
    - 前提是预先创建canal实例
  - 动态创建数据库
  - 动态创建表
  - 支持es的[Parent-child](https://www.elastic.co/guide/cn/elasticsearch/guide/current/parent-child.html) 关系
  - 支持es映射的递归嵌套(支持nest嵌套)
  - 同步异常，支持断点续传
  - 表的一对多，一对一关联
  - 索引版本管理
  - 日常数据增量校验，保证每天的数据一致性（避免各类bug导致数据不一致，一个数据一致性保险检查程序）

### 功能演示

  - [es集群搭建](https://1156721874.github.io/2018/09/28/ELK-ElasticSearch-Logstash-Kibana%E6%90%AD%E5%BB%BA%E5%AE%9E%E6%97%B6%E6%97%A5%E5%BF%97%E5%88%86%E6%9E%90%E5%B9%B3%E5%8F%B0/)、[apollo配置中心部署](https://github.com/ctripcorp/apollo)此处不在熬述，参考官方和之前的博客。

  - 数据库脚本配置请使用工程里边的init.sql执行初始化.

  - 项目分为三个工程：
    - tdl-mysql-elasticsearch 核心引擎配合apollo
    - tdl-mysql-elasticsearch-api api层，为前端提供接口，配合apollo
    - tdl-mysql-elasticsearch-web vue前端展示工程

  - topic
    - topic 列表
    ![topic-list.png](topic-list.png)
    - topic 新增或者修改
    ![topic-insert-edit.png](topic-insert-edit.png)
  - 数据库操作
      - 数据库列表
      ![database-list.png](database-list.png)
      - 数据库新增和修改
      ![database-insert-edit.png](database-insert-edit.png)
  - 表
    - 表的列表
      ![table-list.png](table-list.png)
      一张表对应es里边的一个索引；

    - 表新增修改
      ![table-insert.png](table-insert.png)
      IndexName：表对应的索引名称
      IndexType：索引的type，一个索引有多个type
      IndexAlias：索引的别名，线上都是用的别名，如果索引发生了升级，只需要将别名指向新的索引版本即可，完成无缝切换
      DailyCheckColumn：日常检查的字段，一般是修改时间字段，用来对数据做校验，同步的时候也会用到这个字段，用时间戳做增量同步
      ParentIndexType：父子关系的时候，当前是child，ParentIndexType指向的是parent的index type，父子关系中父是一个type，child是一个type，2个type必须在同一个索引里边。
      ParentIndexColumnName：子表中父表的pid字段名称。
      ToCopy：参考es官网解释：https://www.elastic.co/guide/en/elasticsearch/reference/current/copy-to.html

    - 表字段添加
      ![table-column-insert.png](table-column-insert.png)
      ColumnName：字段名称
      ColumnType：字段的数据类型
      EsDataType：es的数据类型
      Analyzer：分析器（参考es官方doc：https://www.elastic.co/guide/en/elasticsearch/reference/current/search-analyzer.html）
      CopyTo：参考官方doc：https://www.elastic.co/guide/en/elasticsearch/reference/current/copy-to.html
      ExtendName：扩展对象名称，通过【AddRelation】按钮添加扩展对象的时候此名称可以被覆盖
      Keyword：参考官方doc：https://www.elastic.co/guide/en/elasticsearch/reference/current/keyword.html
      IsKey：标识当前字段是主键
      ExtendIsNest：扩展对象是否是嵌套的，可以被字段关系覆盖，参考官方doc：https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-nested-query.html
    - 字段关联(支持多级嵌套)
      ![table-column-relation.png](table-column-relation.png)
      SearchColumnName：当前要关联的字段名称。
      ExtendName：关联的对象在当前表里边的扩展名称，此处可以覆盖字段上的  ExtendName
      RelationTableName：关联的表
      RelationTableColumns：关联的表要加载它的那些字段
      RelationTableColumn：当前SearchColumnName和RelationTableName的RelationTableColumn发生关联，一般是id之类的。
      ExtendIsNest：是否是嵌套的，此处可以覆盖字段的ExtendIsNest
    - 表的状态和操作
      ![table-list-operation.png](table-list-operation.png)
      另外表的状态在history和avaiable状态的时候会有deleteAll操作权限，deleteAll会把抽闲和es当中的索引全部删除，危险操作；
      表的抽象创建完毕之后状态是unavailable状态，表在创建新的索引之后，首先是changing状态，标识正在创建新的索引版本，版本会自动加一，上一个版本的索引会置为history，新的索引的状态是available状态，标识正在同步mysql。

### 架构设计

#### 整体架构图
  ![structure.png](structure.png)
  首先解释下searchContext，searchContext是这个上下文，里边存储了当前可以同步的主题，数据库，表，以及正在changing的tableId，还有同步线程的引用等等，ListenTopicTask会每隔三分钟刷新一次上下文；
  整个轮子有2条主线，以searchContext为中心，searchContext下面是索引创建流程，上面是消息监听流程（索引已经创建完毕，mysql数据变化监听，然后将变化推送到es集群）；
  索引创建流程将索引创建完毕之后，会更新上下文，然后消息监听流程会使用更新之后的上下文。
#### 索引创建流程
  索引创建流程就是在页面发起【createIndex】操作，后端会进行5个步骤的操作：
  - 创建索引请求的发起，这个过程会做一些表和字段的校验，以及一些判重操作，比如当前表已经同步过，或者正在同步，又或者在同步任务比价多，同步任务被放到任务队列里边也是会被发现的，这些数据是不允许往下执行的。
  - 将当前表抽象为一个同步任务，在DB层面就是在tnp_search_job里边插入一条数据，任务状态status是init，之后syn_cursor步长初始化时间是将要同步的表的最小时间, 即，select min(DailyCheckColumn) from table,注意：tnp_search_job表里边的数据只有三种状态，init、running、done，如果一个任务同步失败，那么这条同步任务会从tnp_search_job里边删除。
  - 通知同步线程去消费本次的同步任务：
    同步线程SynchronizeJobTask内部有一把锁，我们可以将SynchronizeJobTask理解为消费者，页面的创建索引请求是生产者，当消费者没有任务可以消费的时候，就会在lock上wait，当页面发起请求，插入了一条同步任务，就会notify一下消费线程去消费，这是一个经典的wait/notify模型，生产者消费者问题，lock就是用来做生产和消费协调的。我们可以看到消费者消费任务的时候，获取任务的sql：select * from from tnp_search_job where status in ('init','running'),即，初始化的任务和正在进行中的任务都会进入到同步线程的管理，running状态的也会加载出来的原因是为了在同步的过程中突然断电，下次启动的时候仍然可以从之前断掉的时间继续同步，也就是断点续传。
  - 异步执行同步任务
    SynchronizeJobTask右侧的代码是SynchronizeJobTask的核心逻辑，在死循环当中，使用了CompletableFuture，而且是完全异步的，同步过程是异步，同步完毕（成功后者失败）之后也是异步的，一张表由于使用了CompletableFuture，就会对应使用2个线程分别去同步和处理同步结果。在supplyAsync当中做的工作有：
      - 将当前表的同步任务状态从init置为running状态
      - 表的状态置为changing状态
    supplyAsync占用一个线程去处理。  
    thenAcceptAsync是对同步完毕之后的后置处理：
      - 同步成功
        - 记录日志
        - 表的同步任务状态置为完毕
        - 将当前同步表的状态置为可用
        - 将上一个版本的索引状态置为history
        - 将索引别名指向新的索引版本
        - 刷新上下文（为消息监听流程流程提供上下文支持）
        - 将在同步期间修改或者新增的数据（类似于jvm垃圾收集里边的浮动垃圾）刷新到新的索引里边，和这个步骤在图片中没有画出。
      - 同步失败
        - 记录日志
        - 删除同步任务
        - 将当前同步表的状态置为不可用

  - 刷新数据到es集群
      当同步任务被执行的时候，内部就会将数据从mysql的一张表按照步长同步到es集群当中，主要是由SynchronizeFactory来做的，SynchronizeFactory是一个同步工厂的抽象，他的实现类是EsSynchronizeFactoryImpl，同步过程如下：
      - 获取jdbc驱动，jdbc驱动使用的c3p0数据库连接池，并且设置了不会让链接空闲失效，在SynchronizeFactory层面是模板模式。
      - 组装存储到es的JSON对象，这个对象是按照建立的mapping格式组装的，我们设置的父子关系，嵌套等设置，这个JSON对象都要遵守。
      - 检查索引和索引type，如果没有的话就会创建。
      - 父子关系的检查，es当中规定parent type和child type必须在同一个es分片，否则就会产生查询混乱，当我们修改了一个child的pid的时候，这个时候pid对应的parent可能不和child在同一个分片，这个时候我们要将child删除，重新插入child，确保child和parent在同一个分片，[parent-child扩展阅读](https://www.elastic.co/guide/cn/elasticsearch/guide/current/indexing-parent-child.html)
      - 调用es的java api刷新数据到es集群。
#### 消息监听流程
  当一个索引创建成功处于available状态的时候，就会被消息监听流程使用，当mysql产生binlog，会被canal收到，然后canal将binlog推送到mq里边，然后我们的应用就是mq的消费者，我们的消费者是可以在界面上配置的，配置完毕之后就会在程序里边创建一个消费者实例，进入到监听，监听到消息之后消费的流程如下：
    - 拿到应用的上下文
    - 解析消息
    - 数据库和消息匹配检查
    - table和消息匹配检查
    - 过滤不感兴趣的操作，只对插入，修改，删除感兴趣
    - 获取jdbc驱动，jdbc驱动使用的c3p0数据库连接池，并且设置了不会让链接空闲失效，在SynchronizeFactory层面是模板模式。
    - 组装存储到es的JSON对象，这个对象是按照建立的mapping格式组装的，我们设置的父子关系，嵌套等设置，这个JSON对象都要遵守。
    - 检查索引和索引type，如果没有的话就会创建。
    - 父子关系的检查，es当中规定parent type和child type必须在同一个es分片，否则就会产生查询混乱，当我们修改了一个child的pid的时候，这个时候pid对应的parent可能不和child在同一个分片，这个时候我们要将child删除，重新插入child，确保child和parent在同一个分片，[parent-child扩展阅读](https://www.elastic.co/guide/cn/elasticsearch/guide/current/indexing-parent-child.html)
    - 调用es的java api刷新数据到es集群。

#### 类图
  ![SearchCenterCLassDiagram.jpg](SearchCenterCLassDiagram.jpg)
#### 启动流程图
  ![boot-sequence.png](boot-sequence.png)
#### 索引创建流程图
  ![SerarchCenterJobSequenceDiagram.jpg](SerarchCenterJobSequenceDiagram.jpg)
#### 消息消费流程图
  ![SerarchCenterConsumerSequenceDiagram.jpg](SerarchCenterConsumerSequenceDiagram.jpg)

### 结束
  代码正在脱敏。。。。稍后即来。。。。
