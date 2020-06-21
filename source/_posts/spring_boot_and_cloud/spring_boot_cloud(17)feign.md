---
title: spring_boot_cloud(17)feign
date: 2020-06-20 16:05:32
tags: [feign]
categories: spring_boot_cloud
---

### feign
feign是一个声明式的伪http客户端，它使得编写http客户端变的简单。使用Feign，只需要创建一个接口并注解。它具有可插拔的注解特性，可使用Feign注解和JAX_RS注解。Feign支持可插拔的编码器和解码器。Feign整合了Ribbon与Hystrix，并和Eureka结合，能够实现负载均衡和断路器等效果。
简而言之:
- feign采用的基于接口的注解
- feign整合Ribbon、Hystrix
<!-- more -->
####feign提供的主要功能
- 可插拔的http客户端实现
- 可插拔的编解码器
- 可对http请求与响应进行gzip压缩
- 可设定压缩的阈值
- 自带负载均衡实现
- 自带熔断器
- 请求日志详细信息展示
- 自带重试处理器

#### Feign的实现流程
- 首先通过@EnableFeignClients注解开启FeignClient的功能，只有这个注解存在，才会在程序启动时开启对@FeignClient注解的包扫描
- 根据Feign的规则实现接口，并在接口上加上@FeignClient注解
- 程序启动后，会进行包扫描，扫描所有的@FeignClient注解的类，并将这些信息注入到IOC容器中。
- 当接口中的方法被调用时，通过JDK的动态代理生成具体的RequestTemplate模板对象
- 根据RequestTemplate再生成Http的request对象
- Request对象交给Client处理，其中Client网络请求框架可以是HttpURLConnection，HttpClient与OkHttp（主要看依赖什么）
- 最后，client被封装到LoadBalanceClient类，该类结合Ribbon做到了负载均衡。


#### 重拾器
```
//针对于所有Feign客户端生效
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
}
```
Retryer.Default(50, SECONDS.toMillis(2), 6):
50: 间隔50秒重试一次。
SECONDS.toMillis(2): 最大重试间隔时间。
6：重试次数

充实逻辑：
```
long nextMaxInterval() {
  long interval = (long) (period * Math.pow(1.5, attempt - 1));
  return interval > maxPeriod ? maxPeriod : interval;
}
```
第一次的重试间隔是10秒，那么距离第二次的时间间隔是10*1.5，距离第三次的时间间隔是10*1.5*1.5。

如果重试器要想针对某一个客户端生效：
```
@FeignClient(value = "eureka-client", configuration = {FeignClientConfig.class})
public interface EurekaClientFeign {
  ....
}
```

#### 日志配置
```
@Configuration
public class FeignClientConfig {

    @Bean
    public Retryer feignClientRetryer() {
        return new Retryer.Default(50, SECONDS.toMillis(2), 6);
    }

    @Bean
    public Logger.Level feignClientLogLevel() {
      //配置http访问日志级别
        return Logger.Level.FULL;
    }
}

```
http日志级别，枚举：
```
/**
 * Controls the level of logging.
 */
public enum Level {
  /**
   * No logging.
   */
  NONE,
  /**
   * Log only the request method and URL and the response status code and execution time.
   */
  BASIC,
  /**
   * Log the basic information along with request and response headers.
   */
  HEADERS,
  /**
   * Log the headers, body, and metadata for both requests and responses.
   */
  FULL
}
```

另外需要配置application.yml:
```
logging:
  level:
    com.shengsiyuan.feign.client.EurekaClientFeign: debug
```

其他使用方式参考github的实例代码。

### Feign的底层实现逻辑分析
先从app的启动开始：
```
@SpringBootApplication
@EnableEurekaClient
@EnableFeignClients
public class EurekaFeignClientApplication {

    public static void main(String[] args) {
        SpringApplication.run(EurekaFeignClientApplication.class, args);
    }
}
```
#### EnableFeignClients注解
EnableFeignClients主要是用来表示扫描Feign的一些组件的注册
```
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@Documented
@Import(FeignClientsRegistrar.class)
public @interface EnableFeignClients {

}
```
注册的实现在FeignClientsRegistrar里边：
FeignClientsRegistrar实现了spring的一些接口
```
class FeignClientsRegistrar 	implements ImportBeanDefinitionRegistrar, ResourceLoaderAware, EnvironmentAware {
  //主要方法
  public void registerBeanDefinitions(AnnotationMetadata metadata,BeanDefinitionRegistry registry) {
    //注册默认的配置信息
    registerDefaultConfiguration(metadata, registry);
    //注册客户端接口
    registerFeignClients(metadata, registry);
  }
}
```

跟进registerFeignClients(),最后来到registerFeignClient()方法:
```
private void registerFeignClient(BeanDefinitionRegistry registry,
    AnnotationMetadata annotationMetadata, Map<String, Object> attributes) {
  String className = annotationMetadata.getClassName();
  BeanDefinitionBuilder definition = BeanDefinitionBuilder
      .genericBeanDefinition(FeignClientFactoryBean.class);
  validate(attributes);
  definition.addPropertyValue("url", getUrl(attributes));
  definition.addPropertyValue("path", getPath(attributes));
  String name = getName(attributes);
  definition.addPropertyValue("name", name);
  String contextId = getContextId(attributes);
  definition.addPropertyValue("contextId", contextId);
  definition.addPropertyValue("type", className);
  definition.addPropertyValue("decode404", attributes.get("decode404"));
  definition.addPropertyValue("fallback", attributes.get("fallback"));
  definition.addPropertyValue("fallbackFactory", attributes.get("fallbackFactory"));
  definition.setAutowireMode(AbstractBeanDefinition.AUTOWIRE_BY_TYPE);
  ....
```
这里一个重要的工厂类FeignClientFactoryBean:
```
class FeignClientFactoryBean implements FactoryBean<Object>, InitializingBean, ApplicationContextAware {
      ...
      protected <T> T loadBalance(Feign.Builder builder, FeignContext context,HardCodedTarget<T> target) {
        Client client = getOptional(context, Client.class);
        if (client != null) {
          builder.client(client);
          Targeter targeter = get(context, Targeter.class);
          return targeter.target(this, builder, context, target);
        }

        throw new IllegalStateException(
            "No Feign Client for loadBalancing defined. Did you forget to include spring-cloud-starter-netflix-ribbon?");
      }
      ...
}
```
重点看loadBalance方法,方法的功能是得到客户端的代理对象
![jdk-feign-proxy.png](jdk-feign-proxy.png)

#### debug验证
##### 启动
我们首选在生成动态代理的地方加一个断点，然后debug启动:
![jdk-feign-proxy-app-start.png](jdk-feign-proxy-app-start.png)
##### 调用
我们在ReflectiveFeign的invoke处打一个断点：
浏览器访问http://localhost:8889/getStudentByFeign
![jdk-feign-proxy-app-invoke.png](jdk-feign-proxy-app-invoke.png)


【本期代码：https://github.com/1156721874/spring_cloud_projects】
