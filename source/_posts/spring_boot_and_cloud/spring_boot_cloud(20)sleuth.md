---
title: spring_boot_cloud(20)sleuth
date: 2020-06-25 13:33:30
tags: [config]
categories: spring_boot_cloud
---

### sleuth
- 警犬、监视、追踪的意思
- 服务链路分布式追踪
- 微服务架构是一个分布式架构 ，他按业务划分服务单元，一个分布式系统往往有很多个服务单元，由于服务单元数量众多，业务的复杂性，如果出现了错误和异常，很难去定位。主要体现在一个请求可能需要调用很多个服务，而内部服务的调用复杂性决定了问题难以定位，所以微服务架构中，必须实现分布式链路追踪，去跟进一个请求到底有哪些服务参与，参与的顺序又是怎样的，从而达到每个请求的步骤清晰可见，除了问题很快定位。
- 举个例子，在服务系统中，一个来自用户的请求，想达到前端A（如前端界面），然后通过远程调用，到达系统的中间件B、C（如负载均衡、网关），最后到达后端服务D、E，后端经过一系列的业务逻辑计算后将数据返回给用户，对于这样一个请求，经历了这么多服务，怎样将它的请求过程的数据记录下来呢？这就需要用到服务链路追踪。
- 目前，链路追踪组件有google的Dapper，Twitter的ziplin等，他们都是非常优秀的链路追踪开源组件。
- spring cloud sleuth采用的是google的开源项目Dapper的专业术语。

#### sleuth重要概念
- span：基本工作单元，发送一个远程调度任务就会产生一个span，span是一个64位id唯一标示的，，trace是用另一个64位id唯一标示的，span还有其他数据信息，比如摘要、时间戳时间、span的id、以及进度id。
- trace：一系列span组成的一个树状结构，请求一个微服务系统的api接口，这个api接口需要调用多个微服务，调用每个微服务都会产生一个新的span，所有由这个请求产生的span组成了这个trace
- annotation：用来及时记录一个事件，一些核心注解用来定义一个请求的开始和结束
Annotation: is used to record existence of an event in time. Some of the core annotations used to define the start and stop of a request are:

  - cs - Client Sent - The client has made a request. This annotation depicts the start of the span.

  - sr - Server Received - The server side got the request and will start processing it. If one subtracts the cs timestamp from this timestamp one will receive the network latency.

  - ss - Server Sent - Annotated upon completion of request processing (when the response got sent back to the client). If one subtracts the sr timestamp from this timestamp one will receive the time needed by the server side to process the request.

  - cr - Client Received - Signifies the end of the span. The client has successfully received the response from the server side. If one subtracts the cs timestamp from this timestamp one will receive the whole time needed by the client to receive the response from the server.

#### 配置依赖
spring-cloud-eureka-client\spring-cloud-feign 增加依赖
org.springframework.cloud:spring-cloud-starter-sleuth

#### spring-cloud-eureka-client配置日志级别
```
logging:
  level:
    root: trace
```

启动spring-cloud-eureka、spring-cloud-eureka-client、spring-cloud-feign
在spring-cloud-feign查看日志：
2020-06-25 14:27:48.041 DEBUG [feign-client,e095ccf4d53b7992,e095ccf4d53b7992,true] 87068 --- [  XNIO-1 task-1] c.s.feign.client.EurekaClientFeign       : [EurekaClientFeign#infoByFeign] ---> GET http://eureka-client/info HTTP/1.1
feign-client是客户端id。
e095ccf4d53b7992是traceid。
e095ccf4d53b7992是spanid
true 指的是生成的请求日志是否是转发到日志服务器上。

### 采样器
#### RateLimitingSampler
```
class RateLimitingSampler extends Sampler {

	private final Sampler sampler;

	RateLimitingSampler(SamplerProperties configuration) {
		this.sampler = brave.sampler.RateLimitingSampler.create(rateLimit(configuration));
	}

	private Integer rateLimit(SamplerProperties configuration) {
		return configuration.getRate() != null ? configuration.getRate() : 0;
	}

	@Override
	public boolean isSampled(long traceId) {
		return this.sampler.isSampled(traceId);
	}

}
```
RateLimitingSampler是默认的采样器，继承了Sampler:
```
public abstract class Sampler {

  //永远采样
  public static final Sampler ALWAYS_SAMPLE = new Sampler() {
    @Override public boolean isSampled(long traceId) {
      return true;
    }

    @Override public String toString() {
      return "AlwaysSample";
    }
  };

  // 永远不采样
  public static final Sampler NEVER_SAMPLE = new Sampler() {
    @Override public boolean isSampled(long traceId) {
      return false;
    }

    @Override public String toString() {
      return "NeverSample";
    }
  };

  public abstract boolean isSampled(long traceId);

  public static Sampler create(float probability) {
    return CountingSampler.create(probability);
  }
}
```
Sampler属于brave.sampler包下边是org.springframework.cloud:spring-cloud-starter-zipkin依赖里边的。
##### 自定义采样器:
```
@Configuration
public class FeignClientConfig {

    @Bean
    public Retryer feignClientRetryer() {
        return new Retryer.Default(50, SECONDS.toMillis(2), 6);
    }

    @Bean
    public Logger.Level feignClientLogLevel() {
        return Logger.Level.FULL;
    }
    //配置采样器
    @Bean
    public Sampler mySampler() {
        return Sampler.NEVER_SAMPLE;
    }
}
```
##### 配置采样率
```
spring:
  application:
    name: feign-client
  sleuth:
    sampler:
      rate: 10
```

### 日志存储
- 目前。链路追踪组件有google的Dapper，Twitter的zipkin等，他们都是非常优秀的链路追踪开源组件。
- spring cloud sleuth采用的是google的开源项目Dapper的专业术语

#### zipKin
- 下载zipkin.jar：https://search.maven.org/remote_content?g=io.zipkin&a=zipkin-server&v=LATEST&c=exec
- 运行 java -jar zipkin.jar
- 访问: http://localhost:9411

#### 配置并将日志推到zipkin
spring-cloud-feign工程配置gradle依赖：org.springframework.cloud:spring-cloud-starter-zipkin
spring-cloud-eureka-client工程配置gradle依赖：org.springframework.cloud:spring-cloud-starter-zipkin
spring-cloud-feign、spring-cloud-eureka-client工程配置resources/application.yml:
```
zipkin:
  enabled: true
  base-url: http://localhost:9411
```
然后再次做一下请求http://localhost:8889/infoByFeign，产生一下日志。
默认zipkin是存储在内存里边的，当zipkin重启之后，日志会消息。
#### 存储
https://github.com/openzipkin/zipkin/tree/master/zipkin-storage
使用mysql存储：https://github.com/openzipkin/zipkin/tree/master/zipkin-storage/mysql-v1
需要建立zipkin数据库，然后执行提供的建表语句

重启zipkin，指定数据库：java -jar zipkin.jar --STORAGE_TYPE=mysql --MYSQL_HOST=localhost,--MYSQL_TCP_PORT=3306 --MYSQL_USER=root --MYSQL_PASS=root
然后再次做一下请求http://localhost:8889/infoByFeign，产生一下日志，这次生成的日志都会存储在mysql里边，es，cassandra都是同样的道理。



本章需要的代码：
https://github.com/1156721874/spring_cloud_projects/tree/master/spring-cloud-eureka
https://github.com/1156721874/spring_cloud_projects/tree/master/spring-cloud-eureka-client
https://github.com/1156721874/spring_cloud_projects/tree/master/spring-cloud-feign
