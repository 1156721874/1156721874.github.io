---
title: spring_boot_cloud(14)Condition条件注解
date: 2020-05-16 14:14:32
tags: [Condition]
categories: spring_boot_cloud
---

###  Condition
A single condition that must be matched in order for a component to be registered.
用来标示一个组件是否可以被注册。
<!-- more -->
#### Conditional
Condition和Conditional成对出现
```
@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface Conditional {

	/**
	 * All {@link Condition Conditions} that must {@linkplain Condition#matches match}
	 * in order for the component to be registered.
	 */
   //所有Condition都匹配才可以被注册进来
	Class<? extends Condition>[] value();

}
```
#### 实例
我们在application.yml里边添加一个配置：
```
person:
  address:
    city: dalian
````
创建一个实现了Condition的类：
```
public class TestCondition implements Condition {
    @Override
    public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
        String city = context.getEnvironment().getProperty("person.address.city");
        if("tianjin".equals(city)){
            return true;
        }
        return false;
    }
}
```
如果城市是天津就返回true，表示加载。
接着创建一个Config:
```
@Configuration
public class TestConditionConfig {

    //Conditional的参数TestCondition规定了是否可以加载这个bean，中间会调TestCondition的matches方法
    @Bean
    @Conditional(TestCondition.class)
    public String getConfig(){
        return "hello";
    }

    //没有配置Conditional条件加载
    @Bean
    public String getConfig2(){
        return "world";
    }


    @Bean
    @Conditional(TestCondition.class)
    public String getConfig3(){
        return "welcome";
    }
}
```

最后在MyApplication里边启动测试：
```
@SpringBootApplication
public class MyApplication {
  private static  final Logger logger = LoggerFactory.getLogger(MyApplication.class);
  public static void main(String[] args) {
    ConfigurableApplicationContext configurableApplicationContext =  SpringApplication.run(MyApplication.class,args);
    String [] names =  configurableApplicationContext.getBeanNamesForType(String.class);
    System.out.println(names);
  }
}
```
输出：
[getConfig2]


因为我们配置的大连，所以getConfig和getConfig3不会被加载。

修改application.yml为:
```
person:
  address:
    city: dalian
  name:
    firstNamme: zhangsan
```
创建新的Condition：
```
public class TestCondition2 implements Condition {
    @Override
    public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
        String city = context.getEnvironment().getProperty("person.name.firstNamme");
        if ("lisi".equals(city)) {
            return true;
        }
        return false;
    }
}
```
修改TestConditionConfig的getConfig3
```
@Bean
@Conditional({TestCondition.class, TestCondition2.class})
public String getConfig3(){
    return "welcome";
}
```
运行MyApplication输出：
[getConfig, getConfig2]

#### 小结
Conditional要求Conditional.value()返回的值都返回true，才会加载。

#### Conditional在spring框架内部的使用
ConditionalOnBean Bean存在的条件加载
ConditionalOnClass Class存在的条件加载
ConditionalOnCloudPlatform
ConditionalOnExpression
ConditionalOnJava
ConditionalOnJndi
ConditionalOnMissingBean  当Bean不存在的条件加载
ConditionalOnMissingClass 当Class不存在的条件加载
ConditionalOnNotWebApplication
ConditionalOnProperty
ConditionalOnResource
ConditionalOnSingleCandidate
ConditionalOnWebApplication
ConditionEvaluationReport

这些注解实现了springboot的按需加载。
