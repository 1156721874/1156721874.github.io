---
title: spring_boot_cloud(3)JDWP远程调试详解以及调试spring-boot-loader的启动与加载全流程
date: 2019-06-08 21:05:32
tags: [JDWP远程调试，调试spring-boot-loader]
categories: spring_boot_cloud
---

# JDWP
Java Debug Wire Protocol, Java调试协议
<!-- more -->

命令： java -agentlib:jdwp=help
```
Java Debugger JDWP Agent Library
--------------------------------

(see http://java.sun.com/products/jpda for more information)

jdwp usage: java -agentlib:jdwp=[help]|[<option>=<value>, ...]

Option Name and Value            Description                       Default  
---------------------            -----------                       -------
suspend=y|n                      wait on startup?                  y          启动的时候是否等待建立远程的调试的socket连接
transport=<name>                 transport spec                    none       传输协议
address=<listen/attach address>  transport spec                    ""         监听地址
server=y|n                       listen for debugger?              n          是否监听调试
launch=<command line>            run debugger on event             none       时间发生的时候进入调试
onthrow=<exception name>         debug on throw                    none       
onuncaught=y|n                   debug on any uncaught?            n
timeout=<timeout value>          for listen/attach in milliseconds n
mutf8=y|n                        output modified utf-8             n
quiet=y|n

examples

Using socket connect to a debugger at a specific address[客户端]:
java -agentlib:jdwp=transport=dt_socket,address=localhost:8080

Using sockets listen for a debugger t attach[服务器]:
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=y
```

接下来我们使用监听的方式启动我们的应用:
运行命令：java -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5050  -jar spring_lecture-1.0-SNAPSHOT.jar
服务端打印：Listening for transport dt_socket at address: 5050
idea的设置：
![jdwp1.png](jdwp1.png)
然后debug此设置，此时在JarLaunche（gradle要导入io.spring.gradle:dependency-management-plugin:1.0.7.RELEASE）r的main方法的断点就会进入debug模式。
![jdwp2.png](jdwp2.png)

我们debug到加载archives的地方可以看到spring的加载器加载的是那些东西，就是archives里边的jar包
![jdwp3.png](jdwp3.png)
