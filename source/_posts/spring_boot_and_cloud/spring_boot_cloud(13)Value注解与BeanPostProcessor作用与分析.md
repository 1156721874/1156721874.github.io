---
title: spring_boot_cloud(13)Value注解与BeanPostProcessor作用与分析
date: 2019-11-21 21:14:32
tags: [Value注解 SpringBoot BeanPostProcessor]
categories: spring_boot_cloud
---

### @Value注解的使用方式

<!-- more -->
```
@RestController
@RequestMapping(value = "/person", produces = MediaType.APPLICATION_JSON_UTF8_VALUE)
public class MyController {
    @Value("${myConfig.myObject.myName}")
    private  String myName;
    @Value("${myConfig.myObject.myAge}")
    private int myAge;
}
```
myConfig.myObject.myName和myConfig.myObject.myAge都是配置里边的属性。

那么 `@Value`注解是怎样把其表达式的值赋值给它所作用的变量的呢？
接下来看一下它的doc说明：
Annotation at the field or method/constructor parameter level that indicates a default value expression for the affected argument.
Typically used for expression-driven dependency injection. Also supported for dynamic resolution of handler method parameters, e.g. in Spring MVC.
A common use case is to assign default field values using #{systemProperties.myProp} style expressions.
Note that actual processing of the @Value annotation is performed by a BeanPostProcessor which in turn means that you cannot use @Value within BeanPostProcessor or BeanFactoryPostProcessor types. Please consult the javadoc for the AutowiredAnnotationBeanPostProcessor class (which, by default, checks for the presence of this annotation).

作用在方法/构造方法/字段等上面，用于受影响的参数一个值表达式。
通常用于表达式驱动依赖注入的场景上边，此外还支持处理器方法的动态解析，比如spring mvc得到了大量使用。
一种常用的使用场景是使用#{systemProperties.myProp}风格的表达式赋值一个字段的值。
注意，对于`@Value`注解的处理是使用BeanPostProcessor来去完成的，表示不能在BeanPostProcessor或者BeanFactoryPostProcessor类型上使用注解，请参考AutowiredAnnotationBeanPostProcessor类（默认情况下会检查`@Value`这个注解是否存在）

### BeanPostProcessor
```
Factory hook that allows for custom modification of new bean instances, e.g. checking for marker interfaces or wrapping them with proxies.
ApplicationContexts can autodetect BeanPostProcessor beans in their bean definitions and apply them to any beans subsequently created. Plain bean factories allow for programmatic registration of post-processors, applying to all beans created through this factory.
Typically, post-processors that populate beans via marker interfaces or the like will implement postProcessBeforeInitialization, while post-processors that wrap beans with proxies will normally implement postProcessAfterInitialization.
BeanPostProcessor是一个工厂的钩子，对于新的bean的实例进行一种定制化的修改，比如，会检查marker interface或者将其包装成一个代理。
ApplicationContexts可以在bean的定义当中自动探测到BeanPostProcessor，然后将BeanPostProcessor应用到随后创建出来的bean上面，
普通的bean工厂允许post-processors进行一种编程式注册，将其应用到经过这个工厂创建的所有的bean上面。
典型的，post-processors 或者类似的bean，通过marker interfaces或者类型的组件，都会实现postProcessBeforeInitialization，其他的包装了post-processors的代理通常实现postProcessAfterInitialization。
public interface BeanPostProcessor {
  /**
    Apply this BeanPostProcessor to the given new bean instance before any bean initialization callbacks (like InitializingBean's afterPropertiesSet or a custom init-method). The bean will already be populated with property values. The returned bean instance may be a wrapper around the original.
    The default implementation returns the given bean as-is.
    在任何的bean实例初始化回调(比如说InitializingBean的afterPropertiesSet，或者自定义的初始化方法)之前应用这个BeanPostProcessor，这些bean已经使用给定的属性值进行了装配，返回的bean的实例可能是一个原始实例的一个包装，
    默认的实现是返回给定的bean的自身。
  **/
  default Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
    return bean;
  }

  /**
    Apply this BeanPostProcessor to the given new bean instance after any bean initialization callbacks (like InitializingBean's afterPropertiesSet or a custom init-method). The bean will already be populated with property values. The returned bean instance may be a wrapper around the original.
    In case of a FactoryBean, this callback will be invoked for both the FactoryBean instance and the objects created by the FactoryBean (as of Spring 2.0). The post-processor can decide whether to apply to either the FactoryBean or created objects or both through corresponding bean instanceof FactoryBean checks.
    This callback will also be invoked after a short-circuiting triggered by a InstantiationAwareBeanPostProcessor.postProcessBeforeInstantiation method, in contrast to all other BeanPostProcessor callbacks.
    The default implementation returns the given bean as-is.
    在任何的bean实例初始化回调(比如说InitializingBean的afterPropertiesSet，或者自定义的初始化方法)之后应用这个BeanPostProcessor，这些bean已经使用给定的属性值进行了装配，返回的bean的实例可能是一个原始实例的一个包装，
    默认的实现是返回给定的bean的自身。
    对于FactoryBean来说，针对于FactoryBean实例和通过FactoryBean创建的对象都会得到回调，post-processor可以决定是否应用到FactoryBean上边，或者说FactoryBean创建的对象上边，或者2者之上，都是可以通过FactoryBean的检查来决定。
    当一个短路操作被触发对的时候，这个方法也会被调用，通过InstantiationAwareBeanPostProcessor.postProcessBeforeInstantiation方法的调用触发，这和其他的BeanPostProcessor回调是相反的。
    默认的实现是返回给定的bean的自身。
  **/
  default Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
    return bean;
  }
}
```
postProcessBeforeInitialization和postProcessAfterInitialization为什么到了jdk1.8改成默认方法了，是因为在1.7里边如果实现一个接口，就必须去实现它的所有方法，有些时候我们只需要实现其中的一个方法，只不过另一个方法返回原来的bean，而使用default method可以不去实现所有的方法，用到那个就重写那个即可。
![desc.png](desc.png)

上面说到 `@Value`不能在BeanPostProcessor或者BeanFactoryPostProcessor上使用，那么BeanFactoryPostProcessor是做啥的呢？
### BeanFactoryPostProcessor
```
/**
Allows for custom modification of an application context's bean definitions, adapting the bean property values of the context's underlying bean factory.
Application contexts can auto-detect BeanFactoryPostProcessor beans in their bean definitions and apply them before any other beans get created.
Useful for custom config files targeted at system administrators that override bean properties configured in the application context.
See PropertyResourceConfigurer and its concrete implementations for out-of-the-box solutions that address such configuration needs.
A BeanFactoryPostProcessor may interact with and modify bean definitions, but never bean instances. Doing so may cause premature bean instantiation, violating the container and causing unintended side-effects. If bean instance interaction is required, consider implementing BeanPostProcessor instead.
允许对于应用上下文的bean定义进行定制化修改，适配上下文底层bean工厂的属性值。
在其他任何的bean创建之前，应用上下文可以在bean的定义当中自动检测BeanFactoryPostProcessor，
主要作用于定制化的配置文件，目标是系统管理员，用于覆盖应用上下文当中的属性。
参考PropertyResourceConfigurer和具体的实现，针对于这种配置需要的开箱即用的解决方案。
一个BeanFactoryPostProcessor可能和修改bean的定义或者和bean的定义进行交互相关，但是从来不会和 bean的实例进行交互和修改，如果是面向bean的实例，会导致一个不成熟的bean的实例化，违背了容器的一些约定，并且会导致一些意想不到的副作用，如果需要和bean的实例进行交互，可以考虑使用BeanPostProcessor的实现代替。
*/
@FunctionalInterface
public interface BeanFactoryPostProcessor {
  /**
  Modify the application context's internal bean factory after its standard initialization. All bean definitions will have been loaded, but no beans will have been instantiated yet. This allows for overriding or adding properties even to eager-initializing beans.
  在bean工厂初始化完毕之后，修改应用上下文里边的bean工厂，所有的bean的定义将会被加载，但是还没有bean的实例，这样就允许我们覆盖甚至添加一些属性，甚至于对于非延迟初始化的bean的属性进行覆盖。
  **/
  void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException;
}
```
BeanFactoryPostProcessor是在bena的定义已经加载，但是bean的实例还没有初始化这个间隙，加入一些逻辑。

上面提到检查`Value`是否存在，用的是AutowiredAnnotationBeanPostProcessor，那么看一下这个类的介绍：

### AutowiredAnnotationBeanPostProcessor
org.springframework.beans.factory.config.BeanPostProcessor implementation that autowires annotated fields, setter methods and arbitrary config methods. Such members to be injected are detected through a Java 5 annotation: by default, Spring's `@Autowired` and `@Value` annotations.
Also supports JSR-330's `@Inject` annotation, if available, as a direct alternative to Spring's own `@Autowired`.
Only one constructor (at max) of any given bean class may declare this annotation with the 'required' parameter set to true, indicating the constructor to autowire when used as a Spring bean. If multiple non-required constructors declare the annotation, they will be considered as candidates for autowiring. The constructor with the greatest number of dependencies that can be satisfied by matching beans in the Spring container will be chosen. If none of the candidates can be satisfied, then a primary/default constructor (if present) will be used. If a class only declares a single constructor to begin with, it will always be used, even if not annotated. An annotated constructor does not have to be public.
Fields are injected right after construction of a bean, before any config methods are invoked. Such a config field does not have to be public.
Config methods may have an arbitrary name and any number of arguments; each of those arguments will be autowired with a matching bean in the Spring container. Bean property setter methods are effectively just a special case of such a general config method. Config methods do not have to be public.
Note: A default AutowiredAnnotationBeanPostProcessor will be registered by the "context:annotation-config" and "context:component-scan" XML tags. Remove or turn off the default annotation configuration there if you intend to specify a custom AutowiredAnnotationBeanPostProcessor bean definition.
NOTE: Annotation injection will be performed before XML injection; thus the latter configuration will override the former for properties wired through both approaches.
In addition to regular injection points as discussed above, this post-processor also handles Spring's `@Lookup` annotation which identifies lookup methods to be replaced by the container at runtime. This is essentially a type-safe version of getBean(Class, args) and getBean(String, args), See `@Lookup's` javadoc for details.
AutowiredAnnotationBeanPostProcessor是BeanPostProcessor的实现（AutowiredAnnotationBeanPostProcessor面向bena的实例），她会自动装配被注解的fields，setter方法，被配置好的方法，这些被用于注入的方法，是通过java 5的一个注解进行检测，默认是通过 `@Autowired` and `@Value` 注解。
当然也支持JSR-330标准的 `@Inject`注解，如果有的话可以作为spring  `@Autowired`的替代方案，给定的bean的class只有一个构造器(最多一个)，并且声明了`@Autowired`这个注解的参数required是true，这个构造方法会自动的进行装配，当用做一个spring bean的时候，
如果有多个没有声明require的`@Autowired`注解的构造器，他们会被认为是自动注入的备选，如果一个拥有最多依赖的构造器将会作为满足spring容器的选择，如果没有候选的依赖，那么主构造器或者默认构造器，如果有的话，将会被使用，如果一个class只有一个单个构造器，那么这个构造器将会永远被使用，一个构造器不必是一个public的构造器，既是她没有被`@Autowired`注解。
 成员变量的注入是在bean的构造之后进行的，在所有的配置方法执行之前，这样的成员变量没有必要是public的。
配置方法拥有一些自由的名称和一些参数；每个方法的参数都会自动匹配一个spring容器里边的一个bean，bean的属性的setter方法就是一个配置方法，配置方法没有必要是public的。
注意：默认的AutowiredAnnotationBeanPostProcessor将会被"context:annotation-config" 和 "context:component-scan" XML 标签注册，如果你倾向于移除或者关闭默认注解配置，那么可以使用定制化的AutowiredAnnotationBeanPostProcessor 的bean定义。
注意：注解的注入比xml的注入的优先级比较高，如果使用这两种方式，这样后来的配置将会覆盖之前的属性配置。
除了常规的注入点之外，post-processor后置处理器可以处理spring的lookup注解，lookup注解是用来标示或者指定一个lookup方法，可以被容器在 运行时的时候别替换，这本质上是一个类替换的安全的getBean的版本，有兴趣参考`@Lookup`java 文档。
AutowiredAnnotationBeanPostProcessor的构造器：
```
public class AutowiredAnnotationBeanPostProcessor extends InstantiationAwareBeanPostProcessorAdapter
		implements MergedBeanDefinitionPostProcessor, PriorityOrdered, BeanFactoryAware{
        public AutowiredAnnotationBeanPostProcessor() {
            this.autowiredAnnotationTypes.add(Autowired.class);
            this.autowiredAnnotationTypes.add(Value.class);
            //try catch的作用是检测JSR-330的Inject注解的防御性设计。
            try {
              this.autowiredAnnotationTypes.add((Class<? extends Annotation>)
                  ClassUtils.forName("javax.inject.Inject", AutowiredAnnotationBeanPostProcessor.class.getClassLoader()));
              logger.trace("JSR-330 'javax.inject.Inject' annotation found and supported for autowiring");
            }
            catch (ClassNotFoundException ex) {
              // JSR-330 API not available - simply skip.
            }
         }

    }
```

### Autowired注解
Marks a constructor, field, setter method or config method as to be autowired by Spring's dependency injection facilities. This is an alternative to the JSR-330 javax.inject.Inject annotation, adding required-vs-optional semantics.
Only one constructor (at max) of any given bean class may declare this annotation with the 'required' parameter set to true, indicating the constructor to autowire when used as a Spring bean. If multiple non-required constructors declare the annotation, they will be considered as candidates for autowiring. The constructor with the greatest number of dependencies that can be satisfied by matching beans in the Spring container will be chosen. If none of the candidates can be satisfied, then a primary/default constructor (if present) will be used. If a class only declares a single constructor to begin with, it will always be used, even if not annotated. An annotated constructor does not have to be public.
Fields are injected right after construction of a bean, before any config methods are invoked. Such a config field does not have to be public.
Config methods may have an arbitrary name and any number of arguments; each of those arguments will be autowired with a matching bean in the Spring container. Bean property setter methods are effectively just a special case of such a general config method. Such config methods do not have to be public.
In the case of a multi-arg constructor or method, the 'required' parameter is applicable to all arguments. Individual parameters may be declared as Java-8-style java.util.Optional or, as of Spring Framework 5.0, also as @Nullable or a not-null parameter type in Kotlin, overriding the base required semantics.
In case of a java.util.Collection or java.util.Map dependency type, the container autowires all beans matching the declared value type. For such purposes, the map keys must be declared as type String which will be resolved to the corresponding bean names. Such a container-provided collection will be ordered, taking into account org.springframework.core.Ordered/org.springframework.core.annotation.Order values of the target components, otherwise following their registration order in the container. Alternatively, a single matching target bean may also be a generally typed Collection or Map itself, getting injected as such.
Note that actual injection is performed through a BeanPostProcessor which in turn means that you cannot use @Autowired to inject references into BeanPostProcessor or BeanFactoryPostProcessor types. Please consult the javadoc for the AutowiredAnnotationBeanPostProcessor class (which, by default, checks for the presence of this annotation).
标记一个构造器，成员变量，setter方法，配置方法，作为spring依赖管理自动注入的标示。 是JSR-330的javax.inject.Inject的替代方案，添加了require和optional的语义。
给定的类只有一个构造器可能声明这个注解，并且声明了require参数为true，标示这个构造去器会进行自动装配，如果有多个没有require参数的构造器被注解，他们都会被作为注入的候选者，拥有最多的依赖的构造会被spring容器作为满足注入的依赖最佳选择，如果没有一个候选，会使用默认的构造器，如果一个class只有一个构造器，那么这个构造器会被永远使用，甚至是没有被注解的构造器，一个被注解的构造器没有必要是public的。
成员变量的注入是在bean的构造之后进行的，在所有的配置方法执行之前，这样的成员变量没有必要是public的。
配置方法拥有一些自由的名称和一些参数；每个方法的参数都会自动匹配一个spring容器里边的一个bean，bean的属性的setter方法就是一个配置方法，配置方法没有必要是public的。
有多个参数的构造器或者方法，require参数是针对于所有的方法参数。单个参数的可以声明为java8风格的java.util.Optional 或者是说从spring5.0开始作为一个@Nullable，或者kotlin当中一个非空参数，可以覆盖一些基础的语义。
对于java.util.Collection和java.util.Map依赖的类型，spring容器可以匹配与其值类型匹配的所有的bean，假设一下，如果是map的key是String类型，它会被解析成与之对应的bean的名字，这样容器提供的集合将会被排序，，，，
略。。。

### Configuration注解
Indicates that a class declares one or more @Bean methods and may be processed by the Spring container to generate bean definitions and service requests for those beans at runtime, for example:
   @Configuration
   public class AppConfig {

       @Bean
       public MyBean myBean() {
           // instantiate, configure and return bean ...
       }
   }
Bootstrapping @Configuration classes
  Via AnnotationConfigApplicationContext
   @Configuration classes are typically bootstrapped using either AnnotationConfigApplicationContext or its web-capable variant, AnnotationConfigWebApplicationContext. A simple example with the former follows:
      AnnotationConfigApplicationContext ctx = new AnnotationConfigApplicationContext();
      ctx.register(AppConfig.class);
      ctx.refresh();
      MyBean myBean = ctx.getBean(MyBean.class);
      // use myBean ...

   See the AnnotationConfigApplicationContext javadocs for further details, and see AnnotationConfigWebApplicationContext for web configuration instructions in a Servlet container.
 Via Spring <beans> XML
   As an alternative to registering @Configuration classes directly against an AnnotationConfigApplicationContext, @Configuration classes may be declared as normal <bean> definitions within Spring XML files:
      <beans>
         <context:annotation-config/>
         <bean class="com.acme.AppConfig"/>
      </beans>

   In the example above, <context:annotation-config/> is required in order to enable ConfigurationClassPostProcessor and other annotation-related post processors that facilitate handling @Configuration classes.
 Via component scanning
   @Configuration is meta-annotated with @Component, therefore @Configuration classes are candidates for component scanning (typically using Spring XML's <context:component-scan/> element) and therefore may also take advantage of @Autowired/@Inject like any regular @Component. In particular, if a single constructor is present autowiring semantics will be applied transparently for that constructor:
      @Configuration
      public class AppConfig {

          private final SomeBean someBean;

          public AppConfig(SomeBean someBean) {
              this.someBean = someBean;
          }

          // @Bean definition using "SomeBean"

      }
   @Configuration classes may not only be bootstrapped using component scanning, but may also themselves configure component scanning using the @ComponentScan annotation:
      @Configuration
      @ComponentScan("com.acme.app.services")
      public class AppConfig {
          // various @Bean definitions ...
      }
   See the @ComponentScan javadocs for details.

 Working with externalized values
   Using the Environment API
   Externalized values may be looked up by injecting the Spring org.springframework.core.env.Environment into a @Configuration class — for example, using the @Autowired annotation:
      @Configuration
      public class AppConfig {

          @Autowired Environment env;

          @Bean
          public MyBean myBean() {
              MyBean myBean = new MyBean();
              myBean.setName(env.getProperty("bean.name"));
              return myBean;
          }
      }
   Properties resolved through the Environment reside in one or more "property source" objects, and @Configuration classes may contribute property sources to the Environment object using the @PropertySource annotation:
      @Configuration
      @PropertySource("classpath:/com/acme/app.properties")
      public class AppConfig {

          @Inject Environment env;

          @Bean
          public MyBean myBean() {
              return new MyBean(env.getProperty("bean.name"));
          }
      }
   See the Environment and @PropertySource javadocs for further details.
 Using the @Value annotation

Composing @Configuration classes
With the @Import annotation
@Configuration classes may be composed using the @Import annotation, similar to the way that <import> works in Spring XML. Because @Configuration objects are managed as Spring beans within the container, imported configurations may be injected — for example, via constructor injection:
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
Now both AppConfig and the imported DatabaseConfig can be bootstrapped by registering only AppConfig against the Spring context:
   new AnnotationConfigApplicationContext(AppConfig.class);
With the @Profile annotation
@Configuration classes may be marked with the @Profile annotation to indicate they should be processed only if a given profile or profiles are active:
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
Alternatively, you may also declare profile conditions at the @Bean method level — for example, for alternative bean variants within the same configuration class:
   @Configuration
   public class ProfileDatabaseConfig {

       @Bean("dataSource")
       @Profile("development")
       public DataSource embeddedDatabase() { ... }

       @Bean("dataSource")
       @Profile("production")
       public DataSource productionDatabase() { ... }
   }
See the @Profile and org.springframework.core.env.Environment javadocs for further details.
With Spring XML using the @ImportResource annotation
As mentioned above, @Configuration classes may be declared as regular Spring <bean> definitions within Spring XML files. It is also possible to import Spring XML configuration files into @Configuration classes using the @ImportResource annotation. Bean definitions imported from XML can be injected — for example, using the @Inject annotation:
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
With nested @Configuration classes
@Configuration classes may be nested within one another as follows:
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
When bootstrapping such an arrangement, only AppConfig need be registered against the application context. By virtue of being a nested @Configuration class, DatabaseConfig will be registered automatically. This avoids the need to use an @Import annotation when the relationship between AppConfig and DatabaseConfig is already implicitly clear.
Note also that nested @Configuration classes can be used to good effect with the @Profile annotation to provide two options of the same bean to the enclosing @Configuration class.
Configuring lazy initialization
By default, @Bean methods will be eagerly instantiated at container bootstrap time. To avoid this, @Configuration may be used in conjunction with the @Lazy annotation to indicate that all @Bean methods declared within the class are by default lazily initialized. Note that @Lazy may be used on individual @Bean methods as well.


标示声明有多个@Bean的方法的类，可以被spring的容器处理，用来生成bean的定义和针对于bean在运行期间你的服务请求，举例：
```
@Configuration
public class AppConfig {
    @Bean
    public MyBean myBean() {
        // instantiate, configure and return bean ...
    }
}
```
#### 启动Configuration
##### 通过 AnnotationConfigApplicationContext
@Configuration的启动通常有AnnotationConfigApplicationContext和 web-capable的变种AnnotationConfigWebApplicationContext，举例：
```
AnnotationConfigApplicationContext ctx = new AnnotationConfigApplicationContext();
ctx.register(AppConfig.class);
ctx.refresh();
MyBean myBean = ctx.getBean(MyBean.class);
// use myBean ...
```
参考AnnotationConfigApplicationContext 文档和AnnotationConfigWebApplicationContext 了解详情。
##### 通过Spring XML方式
作为Configuration注解的替代方案，直接使用AnnotationConfigApplicationContext的方式注册，@Configuration可以声明成spring xml的方式定义bean。
```
<beans>
   <context:annotation-config/>
   <bean class="com.acme.AppConfig"/>
</beans>
```
在上面的实例当中呢，<context:annotation-config/>是被要求的，用来启用ConfigurationClassPostProcessor和其他的和注解相关的后置处理器，处理@Configuration。

##### 组件扫描的方式
@Configuration是由元注解@Component修饰的，所以@Configuration也是可以被认为是组件（通常使用<context:component-scan/>的元素），因此可以使用@Autowired/@Inject 就像常规的组件一样，如果出现单个的构造方法，那么自动装配的语义会被透明的应用到这个构造方法。
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
@Configuration不仅可以使用组件扫描启动，他自己也可以配置组件扫描使用 @ComponentScan注解
```
@Configuration
@ComponentScan("com.acme.app.services")
public class AppConfig {
    // various @Bean definitions ...
}
```
#### 以外部的值去工作
##### 使用环境变量
外部的值可以通过spring的 org.springframework.core.env.Environment 注入到被@Configuration接的类里边， 举例，使用 @Autowired 注解：
```
@Configuration
public class AppConfig {

    @Autowired Environment env;

    @Bean
    public MyBean myBean() {
        MyBean myBean = new MyBean();
        myBean.setName(env.getProperty("bean.name"));
        return myBean;
    }
}
```
通过Environment可以解析属性源对象，并且 @Configuration 可以通过@PropertySource 注解给Environment提供属性源。
```
@Configuration
@PropertySource("classpath:/com/acme/app.properties")
public class AppConfig {

    @Value("${bean.name}") String beanName;

    @Bean
    public MyBean myBean() {
        return new MyBean(beanName);
    }
}
```
#####  通过@Value注解
外部的值的注入到@Configuration 注解的class，可以通过@Value 注解。
```
@Configuration
@PropertySource("classpath:/com/acme/app.properties")
public class AppConfig {

    @Value("${bean.name}") String beanName;

    @Bean
    public MyBean myBean() {
        return new MyBean(beanName);
    }
}
```
#### 组合 @Configuration 类
##### 使用 @Import 注解
@Configuration注解可以使用 @Import 注解进行组合，有点像xml方式里边的 <import> 标签，因为被 @Configuration 注解的对象是作为spring 容器的bean被管理的，导入配置可以被注入的，举例，使用构造器注入：
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
现在，可以通过仅在Spring上下文中注册AppConfig来引导AppConfig和导入的DatabaseConfig：
```
 new AnnotationConfigApplicationContext(AppConfig.class);
```
##### 通过@Profile 注解
@Configuration注解可以被@Profile 注解标记，暗示它们在指定的profile或者活动profile需要被处理。
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
也可以在 @Bean 方法层面声明profile条件，举例，以下方式可以替代上面的@Profile的方式：
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
#### 和spring xml配合使用@ImportResource 注解
前边提过，@Configuration 类可以在spring的 xml里边按照spring的bean定义声明，同样可以使用@ImportResource 注解导入 Spring XML配置到 @Configuration 的类里边。bean的xml定义被注入---举例，使用 @Inject注解：
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

#### 使用嵌套的 @Configuration 类
 @Configuration可以被嵌套到其他的 @Configuration类里边:
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
 这种写法启动的时候，只需要将AppConfig注册到spring的上下文，通过虚拟的嵌套的@Configuration类，DatabaseConfig将会被自动注册，避免了在AppConfig和DatabaseConfig存在联系的时候使用 @Import 注解，这样比较清晰。

### AnnotationConfigApplicationContext
Standalone application context, accepting annotated classes as input - in particular @Configuration-annotated classes, but also plain @Component types and JSR-330 compliant classes using javax.inject annotations. Allows for registering classes one by one using register(Class...) as well as for classpath scanning using scan(String...).
In case of multiple @Configuration classes,@Bean  methods defined in later classes will override those defined in earlier classes. This can be leveraged to deliberately override certain bean definitions via an extra @Configuration class.
See @Configuration's javadoc for usage examples.
独立应用上下文，以被注解的类作为参数输入，特别是 @Configuration注解的类，同时也是一个@Component组件类型，兼容JSR-330的javax.inject注解。允许通过register(Class...)方法一个一个的注册class，或者使用 scan(String...)方法扫描classPath下的，
当存在多个 @Configuration 的时候，后面的类的 @Bean注解的方法的定义将会覆盖前边的定义，这个可以用来故意覆盖一些bena的定义，通过外部的@Configuration 类。

### AnnotationConfigWebApplicationContext
是AnnotationConfigApplicationContext在web环境下的实现

### 注解解析的流程
我们打开AutowiredAnnotationBeanPostProcessor，这里面有AutowiredMethodElement、AutowiredFieldElement看上去分别是为了解析被注解的方法和字段的，我们拿AutowiredFieldElement的inject方法进行断点调试，启动我们的app。
![debug1.png](debug1.png)
断点到了inject方法里边，可以看到inject的beanname参数是我们的controller，controller的结构：
![debug2.png](debug2.png)
最终到了关键性的代码：
![debug3.png](debug3.png)
makeAccessible是为了打开访问设置：
```
public static void makeAccessible(Field field) {
    if ((!Modifier.isPublic(field.getModifiers()) || !Modifier.isPublic(field.getDeclaringClass().getModifiers()) || Modifier.isFinal(field.getModifiers())) && !field.isAccessible()) {
        field.setAccessible(true);
    }
}
```
field.set(bean, value);
是java的反射appi，field是controller的myName字段，bean是MyController对象，value是从yml里边读取的值。
PS：其实MyController里边的getter和setter是无需提供的，而是spring通过反射设置的。
