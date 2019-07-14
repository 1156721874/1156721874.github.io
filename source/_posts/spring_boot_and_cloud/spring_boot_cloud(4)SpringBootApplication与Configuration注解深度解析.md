---
title: spring_boot_cloud(4)SpringBootApplication与Configuration注解深度解析
date: 2019-06-23 21:03:32
tags: [SpringBootApplication]
categories: spring_boot_cloud
---

### @SpringBootApplication
有三个注解组成：
@SpringBootConfiguration
@EnableAutoConfiguration
@ComponentScan

#### @SpringBootConfiguration
```
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Configuration
public @interface SpringBootConfiguration {
}
```
首先@SpringBootConfiguration是一个@Configuration，@SpringBootConfiguration可以作为@Configuration的替换方法，应用的配置会自动找到并且配置，应用的项目应该只使用一次在@SpringBootApplication里边。
`@Configuration`是 context 包里边，表示一个类声明了多个bean和方法，用来生成bean。
使用事例：
```
@Configuration
   public class AppConfig {

       @Bean
       public MyBean myBean() {
           // instantiate, configure and return bean ...
       }
   }
```

### 引导 @Configuration 类：
@Configuration通常通过AnnotationConfigApplicationContext 或者 具有web功能的contextAnnotationConfigWebApplicationContext引导，下面是一个实例：
```
AnnotationConfigApplicationContext ctx = new AnnotationConfigApplicationContext();
 ctx.register(AppConfig.class);
 ctx.refresh();
 MyBean myBean = ctx.getBean(MyBean.class);
 // use myBean ...
```

查看AnnotationConfigApplicationContext、AnnotationConfigWebApplicationContext的官方文档获得更多信息。

#### 通过XML的方式：
<beans>
     <context:annotation-config/>
     <bean class="com.acme.AppConfig"/>
</beans>



#### 通过组件扫描的方式：
 @Configuration是一种元注解，可以通过组件扫描。

```
@Configuration
public class AppConfig {

       private final SomeBean someBean;

       public AppConfig(SomeBean someBean) {
           this.someBean = someBean;
       }

       // @Bean definition using "SomeBean"

   }
```

#### 通过ComponentScan的方式：
```
@Configuration
@ComponentScan("com.acme.app.services")
public class AppConfig {
    // various @Bean definitions ...
}

```

#### 通过环境API：
```
   @Configuration
   @PropertySource("classpath:/com/acme/app.properties")
   public class AppConfig {

       @Inject Environment env;

       @Bean
       public MyBean myBean() {
           return new MyBean(env.getProperty("bean.name"));
       }
   }
```

#### 通过 @Value annotation
Externalized values may be injected into `@Configuration` classes using the `@Value` annotation:
   @Configuration
   @PropertySource("classpath:/com/acme/app.properties")
   public class AppConfig {

       @Value("${bean.name}") String beanName;

       @Bean
       public MyBean myBean() {
           return new MyBean(beanName);
       }
   }

#### 组合Configuration

使用@import对配置类进行组合。相当于<import>标签，@Configuration是被spring容器进行管理的，@Configuration类也会被注入(通过构造器)
```
@Configuration
public class DatabaseConfig {

       @Bean
       public DataSource dataSource() {
           // instantiate, configure and return DataSource
       }
   }

   @Configuration
   @Import(DatabaseConfig.class)
   public class AppConfig {

       private final DatabaseConfig dataConfig;

       public AppConfig(DatabaseConfig dataConfig) {
           this.dataConfig = dataConfig;
       }

       @Bean
       public MyBean myBean() {
           // reference the dataSource() bean method
           return new MyBean(dataConfig.dataSource());
       }
   }
```
这样不管是AppConfig还是被注入的DatabaseConfig都可以注册的AppConfig来从spring context引导启动：
```
 new AnnotationConfigApplicationContext(AppConfig.class);
```

#### 使用@Profile 注解
`@Configuration` 可以被@Profile 注解标记
```
   @Profile("development")
   @Configuration
   public class EmbeddedDatabaseConfig {

       @Bean
       public DataSource dataSource() {
           // instantiate, configure and return embedded DataSource
       }
   }

   @Profile("production")
   @Configuration
   public class ProductionDatabaseConfig {

       @Bean
       public DataSource dataSource() {
           // instantiate, configure and return production DataSource
       }
   }
```
或者
```
   @Configuration
   public class ProfileDatabaseConfig {

       @Bean("dataSource")
       @Profile("development")
       public DataSource embeddedDatabase() { ... }

       @Bean("dataSource")
       @Profile("production")
       public DataSource productionDatabase() { ... }
   }
  ```
这种方式如果用apollo的中心化，Profile是用不上的，如果是spring cloud可能还能用到。

#### 使用 @ImportResource annotation 加载spring xml配置文件
```
@Configuration
 @ImportResource("classpath:/com/acme/database-config.xml")
 public class AppConfig {

     @Inject DataSource dataSource; // from XML

     @Bean
     public MyBean myBean() {
         // inject the XML-defined dataSource bean
         return new MyBean(this.dataSource);
     }
 }
```

####  嵌套的@Configuration classes
```
@Configuration
   public class AppConfig {

       @Inject DataSource dataSource;

       @Bean
       public MyBean myBean() {
           return new MyBean(dataSource);
       }

       @Configuration
       static class DatabaseConfig {
           @Bean
           DataSource dataSource() {
               return new EmbeddedDatabaseBuilder().build();
           }
       }
   }
```
这种方式避免了使用@Import ，当使用dataSource的时候 就会去寻找DataSource的配置。

#### 配置延迟加载

被 @Bean修饰的方法，会在容器启动的时候就会实例化。@Configuration 也可以和 @Lazy搭配使用，而且单个的bean也可以和 @Lazy 搭配使用，表示@Configuration修饰的类里边所有被 @Bean 修饰的方法都会被延迟加载。


####  @Configuration对测试支持

```
@RunWith(SpringRunner.class)
@ContextConfiguration(classes = {AppConfig.class, DatabaseConfig.class})
public class MyTests {

    @Autowired MyBean myBean;

    @Autowired DataSource dataSource;

    @Test
    public void test() {
        // assertions against myBean ...
    }
}
```


####  @Configuratione的一些约束

-  @Configuratione必须被提供作为一个类（可以子类增强）
-  @Configuratione 修饰的类 不能是final的
-  @Configuratione 不能声明在一个方法的内部
-  嵌套的 @Configuratione 必须是静态的 static


###  @EnableAutoConfiguration 作用和分析
我们知道 @Configuration是对配置的一种抽象，而SpringBootConfiguration又是的 @Configuration一种实现，那SpringBootConfiguration肯定是对spring boot配置的特殊的抽象实现

```
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Configuration
public @interface SpringBootConfiguration {

}
```

然后我们看一下SpringBootApplication的结构：
```
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@SpringBootConfiguration
@EnableAutoConfiguration
@ComponentScan(excludeFilters = {
		@Filter(type = FilterType.CUSTOM, classes = TypeExcludeFilter.class),
		@Filter(type = FilterType.CUSTOM, classes = AutoConfigurationExcludeFilter.class) })
public @interface SpringBootApplication {

}
```
前边的四个是jdk的注解，第五个是@SpringBootConfiguration，刚刚提到了，是SpringBoot的特化配置的实现，最后是个@EnableAutoConfiguration我们看一下doc：

org.springframework.boot.autoconfigure @Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
`@Documented`
`@Inherited`
`@AutoConfigurationPackage`
@Import(AutoConfigurationImportSelector.class)
public interface EnableAutoConfiguration
extends annotation.Annotation
Enable auto-configuration of the Spring Application Context, attempting to guess and configure beans that you are likely to need. Auto-configuration classes are usually applied based on your classpath and what beans you have defined. For example, if you have tomcat-embedded.jar on your classpath you are likely to want a TomcatServletWebServerFactory (unless you have defined your own ServletWebServerFactory bean).
When using SpringBootApplication, the auto-configuration of the context is automatically enabled and adding this annotation has therefore no additional effect.
Auto-configuration tries to be as intelligent as possible and will back-away as you define more of your own configuration. You can always manually exclude() any configuration that you never want to apply (use excludeName() if you don't have access to them). You can also exclude them via the spring.autoconfigure.exclude property. Auto-configuration is always applied after user-defined beans have been registered.
The package of the class that is annotated with `@EnableAutoConfiguration`, usually via `@SpringBootApplication`, has specific significance and is often used as a 'default'. For example, it will be used when scanning for @Entity classes. It is generally recommended that you place `@EnableAutoConfiguration` (if you're not using `@SpringBootApplication`) in a root package so that all sub-packages and classes can be searched.
Auto-configuration classes are regular Spring Configuration beans. They are located using the SpringFactoriesLoader mechanism (keyed against this class). Generally auto-configuration beans are `@Conditional` beans (most often using `@ConditionalOnClass` and `@ConditionalOnMissingBean` annotations).
See Also:
ConditionalOnBean, ConditionalOnMissingBean, ConditionalOnClass, AutoConfigureAfter, SpringBootApplication

`@EnableAutoConfiguration让spring` 的上下文的自动配置成为 可能，尝试或者猜测去配置你可能需要的bean。自动化配置往往基于classpath和你已经定义的bean去加载。
比如你有一个tomcat-embedded.jar在你的classpath下边，你可能想要TomcatServletWebServerFactory这个bean（除非已经定义了你自己的ServletWebServerFactory bean）。
当使用SpringBootApplication 自动化配置就已经开启了，再去添加`@EnableAutoConfiguration让spring`也不会有影响。
自动阿虎配置尽可能智能的，也可以使用 exclude()排除掉你不想加载的配置，也可以以使用spring.autoconfigure.exclude property（yml里边配置）排除掉不想加载的配置。自动化配置总是在用户已经注册好了自定义的bean才能去应用上。

被 `@EnableAutoConfiguration`修饰的类所在的路径，通常通过 `@SpringBootApplication`，其指定了一个签名，通常是一个默认值，通常我们将 `@EnableAutoConfiguration`修饰的类放在根路径root package下（没有使用`@SpringBootApplication`的情况下）,这样所有的包和子包都会扫描到。

自动配置类就是一个普通的spring 配置bean，通过SpringFactoriesLoader的机制定位的，通常自动化配置bean是一个 `@Conditional` bean
（大部分都是`@ConditionalOnClass` and `@ConditionalOnMissingBean`注解）

总之：`@EnableAutoConfiguration让spring`会完成自动化的注入。最佳实践是将`@EnableAutoConfiguration让spring`修饰的类放在root package下，对应的实现就是 `@SpringBootApplication`。

```
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@AutoConfigurationPackage
@Import(AutoConfigurationImportSelector.class)
public @interface EnableAutoConfiguration {
}
```
#### AutoConfigurationPackage
修饰EnableAutoConfiguration当中有一个AutoConfigurationPackage，意味着被AutoConfigurationPackage注解的类所在的包应该注册到AutoConfigurationPackages里边去。

#### @ComponentScan 组件扫描
修饰SpringBootApplication的最后一个注解ComponentScan；
```
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@Documented
@Repeatable(ComponentScans.class)
public @interface ComponentScan
```
配置组件扫描的指令，通常用于Configuration类，提供了使用 Spring XML（<context:component-scan>）也可以通过basePackageClasses或者basePackages指定特定的包去扫描。如果定义的package不存在，默认就会从@ComponentScan注解的类所在的package去扫描。

注意<context:component-scan>有一个annotation-config属性，但是@ComponentScan注解没有

### SpringApplication
SpringApplicatio用来在main方法里边启动和引导spring 应用，默认会执行一下的步骤：
- 创建一个合适的SpringApplication实例(在classpath下面)
- 注册CommandLinePropertySource来暴露命令行参数作为 Spring properties
- 刷新application context，加载所有单利的bean
- 触发CommandLineRunner bean

默认静态的main方法里边启动应用。

```
@Configuration
@EnableAutoConfiguration
public class MyApplication  {

  // ... Bean definitions

  public static void main(String[] args) {
    SpringApplication.run(MyApplication.class, args);
  }
}
```


对于更加高级的配置，SpringApplication实例可以在启动之前做一些定制化。
```
public static void main(String[] args) {
  SpringApplication application = new SpringApplication(MyApplication.class);
  // ... customize application settings here
  application.run(args)
}
```

SpringApplication可以从不同的源读取bean，通常推荐一个单个的 @Configuration 用于启动你的应用，然后你可以设置源从以下方面：
- 完全限定的类名通过 AnnotatedBeanDefinitionReader加载。
- 本地的xml资源，通过 XmlBeanDefinitionReader加载 或者通过groovy 脚本，通过GroovyBeanDefinitionReader加载。
- 包名扫描通过 ClassPathBeanDefinitionScanner
