---
title: linux下搭建RabbitMQ服务
date: 2018-09-28 21:55:04
tags: RabbitMQ linux
categories: MQ
---
**引言**
你是否遇到过两个（多个）系统间需要通过定时任务来同步某些数据？你是否在为异构系统的不同进程间相互调用、通讯的问题而苦恼、挣扎？如果是，那么恭喜你，消息服务让你可以很轻松地解决这些问题。
消息服务擅长于解决多系统、异构系统间的数据交换（消息通知/通讯）问题，你也可以把它用于系统间服务的相互调用（RPC）。本文将要介绍的RabbitMQ就是当前最主流的消息中间件之一。

**RabbitMQ简介**
AMQP，即Advanced Message Queuing Protocol，高级消息队列协议，是应用层协议的一个开放标准，为面向消息的中间件设计。消息中间件主要用于组件之间的解耦，消息的发送者无需知道消息使用者的存在，反之亦然。
AMQP的主要特征是面向消息、队列、路由（包括点对点和发布/订阅）、可靠性、安全。
RabbitMQ是一个开源的AMQP实现，服务器端用Erlang语言编写，支持多种客户端，如：Python、Ruby、.NET、Java、JMS、C、PHP、ActionScript、XMPP、STOMP等，支持AJAX。用于在分布式系统中存储转发消息，在易用性、扩展性、高可用性等方面表现不俗。
Rabbitmq试用业务范围：
**场景1：单发送单接收**
使用场景：简单的发送与接收，没有特别的处理。
**场景2：单发送多接收**
使用场景：一个发送端，多个接收端，如分布式的任务派发。为了保证消息发送的可靠性，不丢失消息，使消息持久化了。同时为了防止接收端在处理消息时down掉，只有在消息处理完成后才发送ack消息
**场景3：Publish/Subscribe**
使用场景：发布、订阅模式，发送端发送广播消息，多个接收端接收。
**场景4：Routing (按路线发送接收)**
使用场景：发送端按routing key发送消息，不同的接收端按不同的routing key接收消息。
**场景5：Topics (按topic发送接收)**
使用场景：发送端不只按固定的routing key发送消息，而是按字符串“匹配”发送，接收端同样如此。


1:下载所需的tar.gz包
 1)ncurses-5.2.tar(它是一个可以使应用程序直接控制终端屏幕显示的库,在安装rabbitmq-server中会报错缺少这个库)
 2)simplejson-3.8.0.tar(它是 Python解析JSON的程序库。)
 3)otp_src_R15B01.tar(RabbitMQ是基于Erlang的，所以首先必须配置Erlang环境,otp_src_R15B01是提供该环境的包)
 4)rabbitmq-server-3.5.4.tar


#########################搭建Erlang环境##############################
 2:登录到指定的一台linux服务器
   选择要创建一个文件夹，我选择的目录是(目录名称可随便)：
   /data/rabbitMQ
![这里写图片描述](20160802101807942.png)
3：进入到该目录,做以下操作
 cd  /data/rabbitMQ
 tar xvzf otp_src_R15B01.tar.gz
 cd otp_src_R15B01
 ./configure

最后一步执行完，可能会报一个错：
 No curses library functions found(这是缺少ncurses-5.2.tar包)
把ncurses-5.2.tar放到指定路径，我这里放到的是/data/ncurses 下，最好和之前放同一个路径
![这里写图片描述](20160802101839630.png)
执行以下操作：
tar zxvf ncurses-5.2.tar #解压缩并且释放 文件包
cd ncurses-5.2    #进入解压缩的目录（注意版本）
./configure #按照你的系统环境制作安装配置文件
make #编译源代码并且编译NCURSES库
su root #切换到root用户环境
make install #安装编译好的NCURSES库

等操作完以上命令，在重新执行搭建Erlang环境的 ./configure 命令：
编译后的输出如下图
![这里写图片描述](20160802101906459.png)
 提示没有wxWidgets和fop，但是问题不大。继续：
 make
 sudo make install

如果没报错，说明已经安装完Erlang，开始安装RabbitMQ-Server。



#########################搭建simplejson环境##############################
安装RabbitMQ-Server之前，必须先安装simplejson
主要参考官方文档：http://www.rabbitmq.com/build-server.html
需要安装simplejson。从此处下载最新的版本： http://pypi.python.org/pypi/simplejson#downloads 。我下载的版本是 simplejson-3.8.0.tar.gz
安装这个很简单，执行以下3个步骤即可：
进入到该目录：
![这里写图片描述](20160802101942194.png)
tar xvzf simplejson-3.8.0.tar.gz
cd simplejson-3.8.0
sudo python setup.py install

#########################安装RabbitMQ Server环境##############################


最后安装RabbitMQ Server。从此处下载源代码版本的RabbitMQ： http://www.rabbitmq.com/server.html。
我下载的版本是 rabbitmq-server-3.5.4.tar.gz

进入该目录：
![这里写图片描述](20160802102010282.png)
所需要的包
yum install xmlto

tar xvzf rabbitmq-server-3.5.4.tar.gz
 cd rabbitmq-server-3.5.4
 make
 TARGET_DIR=/usr/local SBIN_DIR=/usr/local/sbin MAN_DIR=/usr/local/man make install

安装成功。


运行
找到sbin/目录，默认目录在：/usr/local/sbin/下
运行程序：
rabbitmq-server –detached
停止程序：
rabbitmqctl stop


安装管理插件
mkdir /etc/rabbitmq
cd /usr/local/sbin/
./rabbitmq-plugins enable rabbitmq_management

./rabbitmq-server -detached

重新启动RabbitMQ，输入http://server-name:15672 就能够进入到监控页面。默认的用户名和密码是： guest 和 guest。
server-name:你指定的linux服务器ip，我的是10.1.100.67

浏览器输入：http://10.1.100.67:15672/ 则说明环境搭建成功
![这里写图片描述](20160802102045118.png)
输入默认用户名和密码：guest ，提示登陆失败
 翻看官方的release文档后，得知由于账号guest具有所有的操作权限，并且又是默认账号，出于安全因素的考虑，guest用户只能通过localhost登陆使用，并建议修改guest用户的密码以及新建其他账号管理使用rabbitmq(该功能是在3.3.0版本引入的)。


解决方法：
进入/data/rabbitMQ/rabbitmq-server/rabbitmq-server-3.5.4/ebin目录下rabbit.app中找到：loopback_users里的<<"guest">>删除。
 并重启rabbitmq，则可以用guest账号登陆管理控制台。成功界面如下：
![这里写图片描述](20160802102122048.png)


                 Java 代码与spring集成
1：发送者配置文件：

```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:context="http://www.springframework.org/schema/context"
	xmlns:rabbit="http://www.springframework.org/schema/rabbit" xmlns:p="http://www.springframework.org/schema/p" xmlns:c="http://www.springframework.org/schema/c"
	xsi:schemaLocation="
		http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans-3.2.xsd
		http://www.springframework.org/schema/context http://www.springframework.org/schema/context/spring-context-3.2.xsd
		http://www.springframework.org/schema/rabbit http://www.springframework.org/schema/rabbit/spring-rabbit-1.3.xsd">

	<!-- #################################################################### -->
	<!-- # RabbitMQ 消息转换器 -->
	<!-- #################################################################### -->
	<bean id="rabbitMessageConverter" class="org.springframework.amqp.support.converter.Jackson2JsonMessageConverter">
		<property name="classMapper">
			<bean class="org.springframework.amqp.support.converter.DefaultJackson2JavaTypeMapper" />
		</property>
	</bean>

	<!-- #################################################################### -->
	<!-- # RabbitMQ 异常处理程序 -->
	<!-- #################################################################### -->
	<bean id="logAndPropagateErrorHandler" class="org.springframework.beans.factory.config.FieldRetrievingFactoryBean">
		<property name="staticField">
			<value>org.springframework.scheduling.support.TaskUtils.LOG_AND_PROPAGATE_ERROR_HANDLER</value>
		</property>
	</bean>

	<!-- #################################################################### -->
	<!-- # rabbit 连接工厂 -->
	<!-- #################################################################### -->
	<rabbit:connection-factory id="rabbitConnectionFactory" addresses="10.1.100.67" username="guest" password="guest}" />

	<!-- #################################################################### -->
	<!-- # RabbitMQ 管理员 -->
	<!-- #################################################################### -->
	<rabbit:admin connection-factory="rabbitConnectionFactory" />

	<!-- #################################################################### -->
	<!-- # RabbitMQ 队列 -->
	<!-- #################################################################### -->

	<!-- 入库自动上架消息消息队列 -->
	<rabbit:queue id="queues.inbound.putway" name="queues.inbound.putway">
		<rabbit:queue-arguments>
			<!-- 开启集群环境镜像队列 -->
			<entry key="x-ha-policy" value="all" />
		</rabbit:queue-arguments>
	</rabbit:queue>

	<!-- #################################################################### -->
	<!-- # RabbitMQ Exchange -->
	<!-- # PS：RabbitMQ 中所有生产者提交的消息都由 Exchange 来接受，再由 Exchange 按照特定的策略转发到 Queue 进行存储/处理 -->
	<!-- # 策略规则：pattern 表达式中 # 表示0个或若干个关键字， * 表示一个关键字 -->
	<!-- # 示例A：queues.# 能匹配 queues.sample 也能匹配 queues.sample.one -->
	<!-- # 示例B：queues.* 能匹配 queues.sample 不能匹配 queues.sample.one -->
	<!-- #################################################################### -->
	<rabbit:topic-exchange name="amq.topic">
		<rabbit:bindings>
			<rabbit:binding queue="queues.inbound.putway" pattern="queues.inbound.#"/>
		</rabbit:bindings>
	</rabbit:topic-exchange>

	<!-- #################################################################### -->
	<!-- # RabbitMQ 模板（生产者） -->
	<!-- #################################################################### -->
	<rabbit:template id="rabbitTemplate" connection-factory="rabbitConnectionFactory" channel-transacted="true" message-converter="rabbitMessageConverter" />
</beans>

```
首先导入jar：spring-rabbit-1.2.2.RELEASE.jar
引入jar：

```
@Autowired
private RabbitTemplate rabbitTemplate;
发送者java代码：
rabbitTemplate.convertAndSend("queues.inbound.putway",productPutaway);

Queues.inbound.putway :xml 里面定义的id
productPutaway:要发送的消息，可以为字符串对象，集合，map等形式

```
2：消费者配置文件

```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:context="http://www.springframework.org/schema/context"
	xmlns:rabbit="http://www.springframework.org/schema/rabbit" xmlns:p="http://www.springframework.org/schema/p" xmlns:c="http://www.springframework.org/schema/c"
	xsi:schemaLocation="
		http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans-3.2.xsd
		http://www.springframework.org/schema/context http://www.springframework.org/schema/context/spring-context-3.2.xsd
		http://www.springframework.org/schema/rabbit http://www.springframework.org/schema/rabbit/spring-rabbit-1.3.xsd">

	<!-- #################################################################### -->
	<!-- # RabbitMQ 消息转换器 -->
	<!-- #################################################################### -->
	<bean id="rabbitMessageConverter" class="org.springframework.amqp.support.converter.Jackson2JsonMessageConverter">
		<property name="classMapper">
			<bean class="org.springframework.amqp.support.converter.DefaultJackson2JavaTypeMapper" />
		</property>
	</bean>

	<!-- #################################################################### -->
	<!-- # RabbitMQ 异常处理程序 -->
	<!-- #################################################################### -->
	<bean id="logAndPropagateErrorHandler" class="org.springframework.beans.factory.config.FieldRetrievingFactoryBean">
		<property name="staticField">
			<value>org.springframework.scheduling.support.TaskUtils.LOG_AND_PROPAGATE_ERROR_HANDLER</value>
		</property>
	</bean>

	<!-- #################################################################### -->
	<!-- # rabbit 连接工厂 -->
	<!-- #################################################################### -->
	<rabbit:connection-factory id="rabbitConnectionFactory" addresses="10.1.100.67" username="guest" password="guest}" />

	<!-- #################################################################### -->
	<!-- # RabbitMQ 管理员 -->
	<!-- #################################################################### -->
	<rabbit:admin connection-factory="rabbitConnectionFactory" />

	<!-- #################################################################### -->
	<!-- # RabbitMQ 队列 -->
	<!-- #################################################################### -->


	<!-- #################################################################### -->
	<!-- # RabbitMQ 模板（生产者） -->
	<!-- #################################################################### -->
	<rabbit:template id="rabbitTemplate" connection-factory="rabbitConnectionFactory" channel-transacted="true" message-converter="rabbitMessageConverter" />

	<!-- #################################################################### -->
	<!-- # RabbitMQ 监听容器（消费者） -->
	<!-- #################################################################### -->
	<rabbit:listener-container connection-factory="rabbitConnectionFactory" message-converter="rabbitMessageConverter" channel-transacted="true" error-handler="logAndPropagateErrorHandler">
		<!-- 货品上架单消费者 -->
		<rabbit:listener queues="queues.inbound.putway" ref="productPutAwayMessageConsumer" method="saveProductPutaway" />
	</rabbit:listener-container>

</beans>

```
接收者Java代码：

```

/**
 * 收货入库单插入上架单消息对象介绍处理类
 * @author Min.Wang
 *
 */
@Component
public class ProductPutAwayMessageConsumer {
	 @Autowired
	 private ProductPutawayService productPutawayService;

	 /**
     * 保存上架单/给收货完成是调用
     * @author Min.Wang
     */
    public void saveProductPutaway(ProductPutaway productPutaway){
    	//根据收到的消息数据，处理对应的业务逻辑
    }
}
更多扩展请了解rabbitmq官网：http://www.rabbitmq.com/




```
