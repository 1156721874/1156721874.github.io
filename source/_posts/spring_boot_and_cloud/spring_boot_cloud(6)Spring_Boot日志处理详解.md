---
title: spring_boot_cloud(6)Spring_Boot日志处理详解
date: 2019-07-28 09:00:32
tags: [SpringBootApplication]
categories: spring_boot_cloud
---

### spring-boot官方简介
https://github.com/spring-projects/spring-boot
<!-- more -->

### Spring Boot日志处理详解

Spring Boot有一套自己的日志继承体系，我们在项目工程里边看到的logback-spring.xml文件就是它的体现，我们可以打开maven的依赖包下的
spring-boot-2.1.3.RELEASE.jar!/org/springframework/boot/logging/logback/base.xml文件，里边是一些基础的log配置:
```
<?xml version="1.0" encoding="UTF-8"?>

<!--
Base logback configuration provided for compatibility with Spring Boot 1.1
-->

<included>
	<include resource="org/springframework/boot/logging/logback/defaults.xml" />
	<property name="LOG_FILE" value="${LOG_FILE:-${LOG_PATH:-${LOG_TEMP:-${java.io.tmpdir:-/tmp}}}/spring.log}"/>
	<include resource="org/springframework/boot/logging/logback/console-appender.xml" />
	<include resource="org/springframework/boot/logging/logback/file-appender.xml" />
	<root level="INFO">
		<appender-ref ref="CONSOLE" />
		<appender-ref ref="FILE" />
	</root>
</included>
```

根据这个配置我们可以新建自己的logback-spring.xml：
- 在工程的resources目录下边新建文件logback-spring.xml
- 内容如下：
```
<?xml version="1.0" encoding="utf-8" ?>

<configuration >
<!-- 讲base.xml的日志配置引入 -->
    <include resource="org/springframework/boot/logging/logback/base.xml"/>
    <!-- com.twodragonlake.boot包下的日志级别是DEBUG -->
    <logger name="com.twodragonlake.boot" level="DEBUG"/>
</configuration>
```
- 打印所有级别的日志
  在MyApplication里边增加变量：
  private static  final Logger logger = LoggerFactory.getLogger(MyApplication.class);
  增加方法：
  ```
  //PostConstruct意味着当bean构建完毕的时候执行这个方法。
  @PostConstruct
  public void myLog(){
      logger.trace("Trace Message");
      logger.debug("Debug Message");
      logger.info("Info Message");
      logger.warn("Warn Message");
      logger.error("Error Message");
  }
  ```
- 打印结果
  2019-07-28 10:13:49.343 DEBUG 2740 --- [           main] com.twodragonlake.boot.MyApplication     : Debug Message
  2019-07-28 10:13:49.343  INFO 2740 --- [           main] com.twodragonlake.boot.MyApplication     : Info Message
  2019-07-28 10:13:49.343  WARN 2740 --- [           main] com.twodragonlake.boot.MyApplication     : Warn Message
  2019-07-28 10:13:49.344 ERROR 2740 --- [           main] com.twodragonlake.boot.MyApplication     : Error Message

  Trace Message没有打印出来是因为我们的日志级别是【<logger name="com.twodragonlake.boot" level="DEBUG"/>】

### springProfile
有时候我们需要在开发环境、测试环境部、正式环境进行不同级别的日志打印。
为此就需要springProfile，我们在logback-spring.xml增加新的配置：
```
<springProfile name="test">
    <logger  name="com.twodragonlake.boot"  level="INFO" />
</springProfile>
```
输出：
2019-07-28 10:20:42.747 DEBUG 14372 --- [           main] com.twodragonlake.boot.MyApplication     : Debug Message
2019-07-28 10:20:42.747  INFO 14372 --- [           main] com.twodragonlake.boot.MyApplication     : Info Message
2019-07-28 10:20:42.747  WARN 14372 --- [           main] com.twodragonlake.boot.MyApplication     : Warn Message
2019-07-28 10:20:42.748 ERROR 14372 --- [           main] com.twodragonlake.boot.MyApplication     : Error Message
我们可以看到日志打印没有发生变化，为什么呢，看一下启动日志有一句：
2019-07-28 10:20:41.489  INFO 14372 --- [           main] com.twodragonlake.boot.MyApplication     : No active profile set, falling back to default profiles: default

当用户没有设置profile的时候，springboot就会使用默认的profiles，名字是“default”，
所以我们将springProfile的name改为default：
```
<springProfile name="default">
    <logger  name="com.twodragonlake.boot"  level="INFO" />
</springProfile>
```
重新启动打印如下：
2019-07-28 10:24:26.552  INFO 10260 --- [           main] com.twodragonlake.boot.MyApplication     : Info Message
2019-07-28 10:24:26.553  WARN 10260 --- [           main] com.twodragonlake.boot.MyApplication     : Warn Message
2019-07-28 10:24:26.553 ERROR 10260 --- [           main] com.twodragonlake.boot.MyApplication     : Error Message

### 小结
- 如果我们logback-spring.xml里边的springProfile的name设置为default，而且logback-spring.xml里面存在单独的logger配置，诸如
【 `<logger name="com.twodragonlake.boot" level="DEBUG"/>`】，那么springProfile name为default的级别要高；
如果我们把springProfile的name改为非default的，那么单独的logger配置的优先级要高。

- 可以在application.yml里边指定profile，比如指定当前环境为test，相应的把springProfile的name也为test：
```
spring:
  application:
    name: mytest
  http:
    encoding:
      enabled: true
      charset: UTF-8
  profiles:
    active: test

server:
  port: 9090

myConfig:
  myObject:
    myName: zhangsan
    myAge: 20
```

### spring logging profile配置
为了演示去掉小结里边的application.yml如下配置
```
#  profiles:
#    active: test
```
springProfile的name改为default
增加：
```
logging:
  level:
    root: debug
```
启动信息会非常的多，不在罗列。

#### 指定日志文件
application.yml配置如下：
```
logging:
  level:
    root: debug
  path: logs/mylog
```
