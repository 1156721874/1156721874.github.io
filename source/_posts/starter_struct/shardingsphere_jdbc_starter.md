---
title: shardingsphere_jdbc_starter
date: 2021-07-18 22:01:45
tags: [shardingsphere,jdbc,starter]
categories: starter_struct
---

### Sharding-JDBC简介
定位为轻量级Java框架，在Java的JDBC层提供的额外服务。 它使用客户端直连数据库，以jar包形式提供服务，无需额外部署和依赖，可理解为增强版的JDBC驱动，完全兼容JDBC和各种ORM框架。

- 适用于任何基于JDBC的ORM框架，如：JPA, Hibernate, Mybatis, Spring JDBC Template或直接使用JDBC。
- 支持任何第三方的数据库连接池，如：DBCP, C3P0, BoneCP, Druid, HikariCP等。
 支持任意实现JDBC规范的数据库。目前支持MySQL，Oracle，SQLServer，PostgreSQL以及任何遵循SQL92标准的数据库。

 ![image.png](https://shardingsphere.apache.org/document/legacy/4.x/document/img/sharding-jdbc-brief.png)
<!-- more -->
官方提供了数据分片、读写分离、数据脱敏的三种配置:
[SPRING BOOT配置](https://shardingsphere.apache.org/document/legacy/4.x/document/cn/manual/sharding-jdbc/configuration/config-spring-boot/)

### Sharding-JDBC在使用上的问题
Sharding-JDBC 在启动的时候需要加载分片、脱敏、读写分离等这些配置，加载时候只认识以spring.shardingsphere开头的配置信息，并且不支持加载多次，什么意思呢，加入我的app使用了2套数据库系统，订单系统使用了oracle，商品系统使用了mysql，但是他们的代码逻辑存在耦合，放在一个app里边，在一个jvm里边启动app，同时呢，订单和商品都是分库分表的，并且订单数据有些字段需要加密，这就使用到了Sharding-jdbc的数据分片，数据脱敏，而且分别应用到2套数据库分片系统，需要加载好多datasource，一个逻辑库，对应n个实体库，每个实体库都是一个datasource对象，如果使用Sharding-jdbc原来的加载机制，是无法完成这个工作的，因为shardingsphere对的配置都是spring.shardingsphere开头的，但是我的多个不同的逻辑数据库使用了不同的分片策略，需要另外一套spring.shardingsphere前缀开头的配置，因此需要进行一次Sharding-jdbc的封装，做一个springboot的starter。

### twodragonlake-sharding-jdbc-starter设计
假如我们有一个逻辑数据库：cs，然后分了三个实体数据库cs1、cs2、cs3.
然后有一个ds逻辑数据库，他有三个实体数据库:ds1、ds2、ds3.
然后我们还设置了一个默认实体数据库cs1.
我们先用我们自己的定义规范定义这些数据库:
```
#默认实体数据库cs1
jdbc.datasource.defaultDS=ds

# 独立的一个数据源
jdbc.datasource.tnp_product.url = jdbc:mysql://192.168.120.17:3306/tnp_product?serverTimezone=UTC&useSSL=false&useUnicode=true&characterEncoding=UTF-8
jdbc.datasource.tnp_product.username = tnp_dev
jdbc.datasource.tnp_product.password = tnp_dev
jdbc.datasource.tnp_product.pool = druid
jdbc.datasource.tnp_product.driverClass = com.mysql.jdbc.Driver

jdbc.datasource.ds.names = ds1,ds2,ds3

# ds1的数据源配置
jdbc.datasource.ds.ds1.url = jdbc:mysql://192.168.120.17:3306/ds1?serverTimezone=UTC&useSSL=false&useUnicode=true&characterEncoding=UTF-8
jdbc.datasource.ds.ds1.username = ds1
jdbc.datasource.ds.ds1.password = ds1
jdbc.datasource.ds.ds1.pool = druid
jdbc.datasource.ds.ds1.driverClass = com.mysql.jdbc.Driver

# ds2的数据源配置
jdbc.datasource.ds.ds2.url = jdbc:mysql://192.168.120.17:3306/ds2?serverTimezone=UTC&useSSL=false&useUnicode=true&characterEncoding=UTF-8
jdbc.datasource.ds.ds2.username = tnp_dev
jdbc.datasource.ds.ds2.password = tnp_dev
jdbc.datasource.ds.ds2.pool = druid
jdbc.datasource.ds.ds2.driverClass = com.mysql.jdbc.Driver

# ds3的数据源配置
jdbc.datasource.ds.ds3.url = jdbc:mysql://192.168.120.17:3306/ds3?serverTimezone=UTC&useSSL=false&useUnicode=true&characterEncoding=UTF-8
jdbc.datasource.ds.ds3.username = tnp_dev
jdbc.datasource.ds.ds3.password = tnp_dev
jdbc.datasource.ds.ds3.pool = druid
jdbc.datasource.ds.ds3.driverClass = com.mysql.jdbc.Driver

#对ds逻辑数据库进行分片+数据脱敏配置，没有ds前缀意味着ds是一个默认数据源
spring.shardingsphere.sharding.default-database-strategy.inline.sharding-column = user_id
spring.shardingsphere.sharding.default-database-strategy.inline.algorithm-expression = ds$->{user_id % 3 + 3}
spring.shardingsphere.sharding.binding-tables = health_record,health_task
spring.shardingsphere.sharding.broadcast-tables = health_level
spring.shardingsphere.sharding.tables.health_record.actual-data-nodes = ds$->{1..3}.health_record$->{0..2}
spring.shardingsphere.sharding.tables.health_record.table-strategy.inline.sharding-column = record_id
spring.shardingsphere.sharding.tables.health_record.table-strategy.inline.algorithm-expression = health_record$->{record_id % 3}
spring.shardingsphere.sharding.tables.health_record.key-generator.column = record_id
spring.shardingsphere.sharding.tables.health_record.key-generator.type = SNOWFLAKE
spring.shardingsphere.sharding.tables.health_record.key-generator.props.worker.id = 33
spring.shardingsphere.sharding.tables.health_task.actual-data-nodes = ds$->{1..3}.health_task$->{0..2}
spring.shardingsphere.sharding.tables.health_task.table-strategy.inline.sharding-column = record_id
spring.shardingsphere.sharding.tables.health_task.table-strategy.inline.algorithm-expression = health_task$->{record_id % 3}
spring.shardingsphere.sharding.tables.health_task.key-generator.column = task_id
spring.shardingsphere.sharding.tables.health_task.key-generator.type = SNOWFLAKE
spring.shardingsphere.sharding.tables.health_task.key-generator.props.worker.id = 33
spring.shardingsphere.sharding.tables.encrypt_user.actual-data-nodes = ds$->{1..3}.encrypt_user$->{0..2}
spring.shardingsphere.sharding.tables.encrypt_user.table-strategy.inline.sharding-column = user_id
spring.shardingsphere.sharding.tables.encrypt_user.table-strategy.inline.algorithm-expression = encrypt_user$->{user_id % 3}
spring.shardingsphere.sharding.tables.encrypt_user.key-generator.column = user_id
spring.shardingsphere.sharding.tables.encrypt_user.key-generator.type = SNOWFLAKE
spring.shardingsphere.sharding.tables.encrypt_user.key-generator.props.worker.id = 33
spring.shardingsphere.sharding.encrypt-rule.encryptors.encryptor_aes.type = LLPayAES
spring.shardingsphere.sharding.encrypt-rule.encryptors.encryptor_aes.props.aes.key.value = 123456
spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.user_name.plain-column = user_name_plain
spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.user_name.cipher-column = user_name
spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.user_name.encryptor = encryptor_aes
spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.pwd.cipher-column = pwd
spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.pwd.encryptor = encryptor_aes
spring.shardingsphere.sharding.props.sql.show = true

#cs逻辑数据库有三个实体数据库分片
jdbc.datasource.cs.names = cs1,cs2,cs3

# cs1的数据源配置
jdbc.datasource.cs.cs1.url = jdbc:mysql://192.168.120.17:3306/cs1?serverTimezone=UTC&useSSL=false&useUnicode=true&characterEncoding=UTF-8
jdbc.datasource.cs.cs1.username = tnp_dev
jdbc.datasource.cs.cs1.password = tnp_dev
jdbc.datasource.cs.cs1.pool = druid
jdbc.datasource.cs.cs1.driverClass = com.mysql.jdbc.Driver

# cs2的数据源配置
jdbc.datasource.cs.cs2.url = jdbc:mysql://192.168.120.17:3306/cs2?serverTimezone=UTC&useSSL=false&useUnicode=true&characterEncoding=UTF-8
jdbc.datasource.cs.cs2.username = tnp_dev
jdbc.datasource.cs.cs2.password = tnp_dev
jdbc.datasource.cs.cs2.pool = druid
jdbc.datasource.cs.cs2.driverClass = com.mysql.jdbc.Driver

# cs3的数据源配置
jdbc.datasource.cs.cs3.url = jdbc:mysql://192.168.120.17:3306/cs3?serverTimezone=UTC&useSSL=false&useUnicode=true&characterEncoding=UTF-8
jdbc.datasource.cs.cs3.username = tnp_dev
jdbc.datasource.cs.cs3.password = tnp_dev
jdbc.datasource.cs.cs3.pool = druid
jdbc.datasource.cs.cs3.driverClass = com.mysql.jdbc.Driver

#对cs逻辑数据库进行分片+数据脱敏配置
cs.spring.shardingsphere.sharding.default-database-strategy.inline.sharding-column = user_id
cs.spring.shardingsphere.sharding.default-database-strategy.inline.algorithm-expression = cs$->{user_id % 3 + 3}
cs.spring.shardingsphere.sharding.binding-tables = health_record,health_task
cs.spring.shardingsphere.sharding.broadcast-tables = health_level
cs.spring.shardingsphere.sharding.tables.health_record.actual-data-nodes = cs$->{1..3}.health_record$->{0..2}
cs.spring.shardingsphere.sharding.tables.health_record.table-strategy.inline.sharding-column = record_id
cs.spring.shardingsphere.sharding.tables.health_record.table-strategy.inline.algorithm-expression = health_record$->{record_id % 3}
cs.spring.shardingsphere.sharding.tables.health_record.key-generator.column = record_id
cs.spring.shardingsphere.sharding.tables.health_record.key-generator.type = SNOWFLAKE
cs.spring.shardingsphere.sharding.tables.health_record.key-generator.props.worker.id = 33
cs.spring.shardingsphere.sharding.tables.health_task.actual-data-nodes = cs$->{1..3}.health_task$->{0..2}
cs.spring.shardingsphere.sharding.tables.health_task.table-strategy.inline.sharding-column = record_id
cs.spring.shardingsphere.sharding.tables.health_task.table-strategy.inline.algorithm-expression = health_task$->{record_id % 3}
cs.spring.shardingsphere.sharding.tables.health_task.key-generator.column = task_id
cs.spring.shardingsphere.sharding.tables.health_task.key-generator.type = SNOWFLAKE
cs.spring.shardingsphere.sharding.tables.health_task.key-generator.props.worker.id = 33
cs.spring.shardingsphere.sharding.tables.encrypt_user.actual-data-nodes = cs$->{1..3}.encrypt_user$->{0..2}
cs.spring.shardingsphere.sharding.tables.encrypt_user.table-strategy.inline.sharding-column = user_id
cs.spring.shardingsphere.sharding.tables.encrypt_user.table-strategy.inline.algorithm-expression = encrypt_user$->{user_id % 3}
cs.spring.shardingsphere.sharding.tables.encrypt_user.key-generator.column = user_id
cs.spring.shardingsphere.sharding.tables.encrypt_user.key-generator.type = SNOWFLAKE
cs.spring.shardingsphere.sharding.tables.encrypt_user.key-generator.props.worker.id = 33
cs.spring.shardingsphere.sharding.encrypt-rule.encryptors.encryptor_aes.type = LLPayAES
cs.spring.shardingsphere.sharding.encrypt-rule.encryptors.encryptor_aes.props.aes.key.value = 123456
cs.spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.user_name.plain-column = user_name_plain
cs.spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.user_name.cipher-column = user_name
cs.spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.user_name.encryptor = encryptor_aes
cs.spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.pwd.cipher-column = pwd
cs.spring.shardingsphere.sharding.encrypt-rule.tables.encrypt_user.columns.pwd.encryptor = encryptor_aes
cs.spring.shardingsphere.sharding.props.sql.show = true
```

#### 加载配置，生成datasource
我们定义DataSourceConfiger类，是一个数据源配置管理器，它实现了EnvironmentAware、BeanFactoryPostProcessor。
##### DataSourceConfiger的成员
- PropertiesReader、Environment，PropertiesReader用来读取Environment当中的配置。
- String defaultLogicDsName：默认的逻辑数据源，这里是ds。
- Map<String, Map<String, DataSource>> originalDataSourceMaps：
    - key:logicDsName;value:{key:realDsName,value:DataSource}，即一个逻辑数据源对应多个真实的实体数据源。
- Map<String,ShardingspherePropertiesConfig> logicDsNameToshardingspherePropertiesConfigs：
  - shardingsphere的逻辑数据源和数据源配置的映射。

##### EnvironmentAware
EnvironmentAware的作用主要是用来配置DataSourceConfiger的环境，为DataSourceConfiger提供配置环境管理的能力，DataSourceConfiger需要实现EnvironmentAware的setEnvironment
方法：
```
@Override
public void setEnvironment(Environment environment) {
    this.environment = environment;
    this.propertiesReader = new PropertiesReader() {
        @Override
        public String getString(String propertyName) {
            return environment.getProperty(propertyName);
        }
    };
    // 初始化所有的实体数据源，设置默认数据源
    initDataSourceMap(environment);
    //加载所有逻辑数据源的shardingsphere配置，包括默认逻辑数据源的配置
    initPropertiesAndDataSource(environment);
}
```

##### 初始化所有的实体数据源，设置默认数据源
```
private void initDataSourceMap(Environment environment) throws Throwable {
    StandardEnvironment standardEnv = (StandardEnvironment) environment;
    defaultLogicDsName = standardEnv.getProperty("jdbc.datasource.defaultDS");
    // 默认数据源没有配置启动异常
    if(StringUtils.isBlank(defaultLogicDsName)){
        logger.error("you should point jdbc.datasource.defaultDS key.");
        throw new Throwable("you should point jdbc.datasource.defaultDS key.");
    }
    //实例化所有逻辑数据源的实体数据源
    List<String> logicNames = new InlineExpressionParser(environment.getProperty("jdbc.datasource.names")).splitAndEvaluate();
    for(String logicDsName : logicNames){
        List<String> realDsNames = new InlineExpressionParser(environment.getProperty("jdbc.datasource." + logicDsName.trim()+".names")).splitAndEvaluate();
        //加载shardingsphere的sharding配置的数据源
        if(!CollectionUtils.isEmpty(realDsNames)){
            Map<String, DataSource> oneLogicDataSources = new HashMap<>();
            for(String realDsName: realDsNames){
                DataSource dataSource = DataSourceFactory.createDataSource(new DataSourceConfig(logicDsName,realDsName,
                        DataSourcesEnum.getDataSourcesEnumByName(standardEnv.getProperty("jdbc.datasource."+logicDsName+"."+realDsName+".pool")),propertiesReader));
                oneLogicDataSources.put(realDsName,dataSource);
            }
            originalDataSourceMaps.put(logicDsName, oneLogicDataSources);
        }else {
            // single ds
            /**
            加载如下形式的数据源配置，这种数据源不使用shardingsphere
            jdbc.datasource.tnp_product.url = jdbc:mysql://192.168.120.17:3306/tnp_product?serverTimezone=UTC&useSSL=false&useUnicode=true&characterEncoding=UTF-8
            jdbc.datasource.tnp_product.username = tnp_dev
            jdbc.datasource.tnp_product.password = tnp_dev
            jdbc.datasource.tnp_product.pool = druid
            jdbc.datasource.tnp_product.driverClass = com.mysql.jdbc.Driver
            **/
            if(environment.containsProperty("jdbc.datasource."+logicDsName+".url")){
                Map<String, DataSource> oneSingleLogicDataSources = new HashMap<>();
                DataSource dataSource =  DataSourceFactory.createDataSource(new DataSourceConfig(null,logicDsName,
                        DataSourcesEnum.getDataSourcesEnumByName(standardEnv.getProperty("jdbc.datasource."+logicDsName+".pool")), propertiesReader));
                oneSingleLogicDataSources.put(logicDsName, dataSource);
                originalDataSourceMaps.put(logicDsName, oneSingleLogicDataSources);
            }
        }
    }
}
```

##### 加载所有逻辑数据源的shardingsphere配置，包括默认逻辑数据源的配置
```
private void initPropertiesAndDataSource(Environment environment) {
   //定义分库分片、读写分离、数据脱敏、影子库的Sharding配置
    ShardingRuleConfigurationProperties defaultShardingProperties = new ShardingRuleConfigurationProperties();
    MasterSlaveRuleConfigurationProperties defaultMasterSlaveProperties = new MasterSlaveRuleConfigurationProperties();
    EncryptRuleConfigurationProperties defaultEncryptProperties = new EncryptRuleConfigurationProperties();
    PropertiesConfigurationProperties defaultPropMapProperties = new PropertiesConfigurationProperties();
    ShadowRuleConfigurationProperties defaultShadowProperties = new ShadowRuleConfigurationProperties();
    try {
       //默认配置
        PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere.sharding", defaultShardingProperties, environment);
        PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere.masterslave", defaultMasterSlaveProperties, environment);
        PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere.encrypt", defaultEncryptProperties, environment);
        PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere.shadow", defaultShadowProperties, environment);
        PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere", defaultPropMapProperties, environment);
        ShardingspherePropertiesConfig defaultShardingspherePropertiesConfig = new ShardingspherePropertiesConfig(defaultShardingProperties,defaultEncryptProperties,defaultMasterSlaveProperties,defaultShadowProperties,defaultPropMapProperties);
        logicDsNameToshardingspherePropertiesConfigs.put(defaultLogicDsName, defaultShardingspherePropertiesConfig);

        //加载逻辑库的Sharding配置
        List<String> logicNames = new InlineExpressionParser(environment.getProperty("jdbc.datasource.names")).splitAndEvaluate();
        for(String logicDsName : logicNames){
            //datasource have specific sharding configs，比如以cs开头的配置
            if(PropertyUtil.containPropertyPrefix(environment, logicDsName )){
               // 得到逻辑库名称后边的配置字符串，比如cs.spring.shardingsphere.sharding.props.sql.show = true
               //经过handle会得到spring.shardingsphere.sharding.props.sql.show = true
                Map<String,Object> kvs =  PropertyUtil.handle(environment, logicDsName , Map.class);
                Environment transferEnv = new StandardEnvironment();
                ConfigurableEnvironment configurableEnvironment = (ConfigurableEnvironment)transferEnv;
                MapPropertySource  propertiesPropertySource = new MapPropertySource("spring.shardingsphere", kvs);
                configurableEnvironment.getPropertySources().addLast(propertiesPropertySource);

                ShardingRuleConfigurationProperties shardingProperties = new ShardingRuleConfigurationProperties();
                MasterSlaveRuleConfigurationProperties masterSlaveProperties = new MasterSlaveRuleConfigurationProperties();
                EncryptRuleConfigurationProperties encryptProperties = new EncryptRuleConfigurationProperties();
                PropertiesConfigurationProperties propMapProperties = new PropertiesConfigurationProperties();
                ShadowRuleConfigurationProperties shadowProperties = new ShadowRuleConfigurationProperties();
                PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere.sharding", shardingProperties, transferEnv);
                PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere.masterslave", masterSlaveProperties, transferEnv);
                PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere.encrypt", encryptProperties, transferEnv);
                PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere.shadow", shadowProperties, transferEnv);
                PropertiesConfigurationUtils.bindPropertiesToTarget("spring.shardingsphere", propMapProperties, transferEnv);
                // 每一个逻辑数据库都有可能存在四种可能的shardingsphere的配置，不管有没有，到放到一个ShardingspherePropertiesConfig对象当中
                logicDsNameToshardingspherePropertiesConfigs.put(logicDsName, new ShardingspherePropertiesConfig(shardingProperties,encryptProperties,
                        masterSlaveProperties,shadowProperties,propMapProperties));
            }
        }
    } catch (Exception e) {
        throw new RuntimeException(e.getMessage(), e);
    }
}
```

以上是对实体数据源和逻辑数据源的准备工作，实体化了所有的实体数据源，以及加载了逻辑数据源的shardingsphere配置到logicDsNameToshardingspherePropertiesConfigs当中。
由于DataSourceConfiger实现了BeanFactoryPostProcessor，因此DataSourceConfiger需要override BeanFactoryPostProcessor的postProcessBeanFactory方法，即在BeanFactory就绪完毕执行的逻辑。

### 创建Shardingsphere逻辑数据源实例对象，配置事物管理器

```
@Override
public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
    BeanDefinitionRegistry registry = (BeanDefinitionRegistry)beanFactory;
    // key:logicDsName;value:{key:realDsName,value:DataSource}
    for(Map.Entry<String, Map<String, DataSource>> oneLogicDs: originalDataSourceMaps.entrySet()){
        // 在环境配置当中寻找，是否存在一种Shardingsphere配置。
        // 而且一个逻辑数据源只能配置为一种模式（ps:分片策略可以和数据脱敏同时配置，不冲突，参考cs逻辑数据源的配置）
        List<ShardingType> shardingTypes = RuleCondition.getShardingTypes(environment,oneLogicDs.getKey());
        if(1 != shardingTypes.size()){
            throw new Throwable("only setting one mode in shardingDataSource,masterSlaveDataSource,encryptDataSource,shadowDataSource options");
        }
        //sharding逻辑数据源的shardingsphere实例化，根据配置不同，分化为分片、脱敏、读写分离、影子库模式其中一个策略。
        //create and register sharding dataSource
        if(logicDsNameToshardingspherePropertiesConfigs.containsKey(oneLogicDs.getKey())){
            ShardingsphereDataSourceRegisterFactory.newInstance(shardingTypes.get(0),oneLogicDs.getKey(), oneLogicDs.getValue(),
                    logicDsNameToshardingspherePropertiesConfigs.get(oneLogicDs.getKey()), registry);
        }else if(defaultLogicDsName.equals(oneLogicDs.getKey())){
            // 默认数据源的shardingsphere实例化
            ShardingsphereDataSourceRegisterFactory.newInstance(shardingTypes.get(0),oneLogicDs.getKey(), oneLogicDs.getValue(),
                    logicDsNameToshardingspherePropertiesConfigs.get(defaultLogicDsName), registry);
        }else{
            //独立数据源的shardingsphere实例化（独立数据源在shardingsphere也是支持的，即没有任何分库分表配置）
            ShardingsphereDataSourceRegisterFactory.newInstance(ShardingType.EMPTY,oneLogicDs.getKey(), oneLogicDs.getValue(),
                    logicDsNameToshardingspherePropertiesConfigs.get(defaultLogicDsName), registry);
        }
        // 为每个shardingsphere逻辑数据源配置事物管理器
        //create and register sharding dataSource`s transactionManager
        String eachTxManagerBeanName = oneLogicDs.getKey()+"TXManager";
        GenericBeanDefinition eachTxDefinition = new GenericBeanDefinition();
        eachTxDefinition.setBeanClass(DataSourceTransactionManager.class);
        eachTxDefinition.setScope(BeanDefinition.SCOPE_SINGLETON);
        eachTxDefinition.getPropertyValues().addPropertyValue("dataSource", new RuntimeBeanReference(oneLogicDs.getKey()));
        eachTxDefinition.addQualifier(new AutowireCandidateQualifier(Qualifier.class, oneLogicDs.getKey()));
        registry.registerBeanDefinition(eachTxManagerBeanName, eachTxDefinition);
    }
    // 事物管理器扫描
    //register sharding transaction scanner
    String shardingTransactionTypeScanner = "shardingTransactionTypeScanner";
    BeanDefinitionBuilder factory = BeanDefinitionBuilder.rootBeanDefinition(ShardingTransactionTypeScanner.class);
    registry.registerBeanDefinition(shardingTransactionTypeScanner, factory.getBeanDefinition());
}
```

#### 小结
DataSourceConfiger实现了将所有的分库数据源和单库数据源全部同一位shardingsphere的数据源的形式，为后续mybatis的初始化提供了参数。

### MybatisConfigure实例化mybatis的配置
MybatisConfigure实现了 EnvironmentAware, BeanFactoryPostProcessor, ApplicationContextAware三个接口，分别具有了环境配置拉取、bean配置后置处理、以及获取spring上下文的能力。
内部有三个成员:
```
// 从environment读取配置
private PropertiesReader propertiesReader;
//spring上下文
private ApplicationContext applicationContext;
//环境元数据
private Environment environment;
```

成员变量的初始化:
```
@Override
public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
    this.applicationContext = applicationContext;
}

@Override
public void setEnvironment(Environment environment) {
    this.environment = environment;
    this.propertiesReader = new PropertiesReader() {
        @Override
        public String getString(String propertyName) {
            return environment.getProperty(propertyName);
        }
    };
}
```

接下来是BeanFactoryPostProcessor接口的能力，借助实现postProcessBeanFactory方法初始化mybatis的配置:
```
@Override
public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
    BeanDefinitionRegistry registry = (BeanDefinitionRegistry)beanFactory;
    //把DataSourceConfiger加载完毕的数据源信息拿过来
    //key:logicDsName;value:{key:realDsName,value:DataSource}，即一个逻辑数据源对应多个真实的实体数据源。
    for(Map.Entry<String, Map<String, DataSource>> entity: DataSourceConfiger.originalDataSourceMaps.entrySet()){
        // register  SqlSessionFactoryBean，即构建SqlSessionFactoryBean，SqlSessionFactoryBean封装了mybatis-config.xml的位置、mapper的xml位置信息等
        GenericBeanDefinition definition =  buildSessionFactoryBeanDefinition(entity.getKey());
        //将SqlSessionFactoryBean注册到spring容器
        registry.registerBeanDefinition(entity.getKey() + "sqlSessionFactoryBean", definition);
        // register  sqlTemplate
        // SqlSessionTemplate是给mapper类使用的，mapper 的java类在访问数据源的时候是通过 SqlSessionTemplate去访问的。
        GenericBeanDefinition eachSqlTemplatedefinition = new GenericBeanDefinition();
        eachSqlTemplatedefinition.setBeanClass(SqlSessionTemplate.class);
        eachSqlTemplatedefinition.setScope(BeanDefinition.SCOPE_SINGLETON);
        eachSqlTemplatedefinition.getConstructorArgumentValues().addIndexedArgumentValue(0, new RuntimeBeanReference(entity.getKey()+"sqlSessionFactoryBean"));
        registry.registerBeanDefinition(entity.getKey()+"sqlTemplate", eachSqlTemplatedefinition);
    }
    //配置mapper 的java类的扫描（根据mapper上的注解实现扫描的）
    Set<String> basePackages = this.resolveBasePackages();
    MapperScannerConfigurer mapperScannerConfigurer = new MapperScannerConfigurer();
    mapperScannerConfigurer.setApplicationContext(applicationContext);
    mapperScannerConfigurer.setMarkerInterface(Mapper.class);
    //mapper类被注解了@Mapper 会被认为是一个mubatis的mapper
    mapperScannerConfigurer.setAnnotationClass(com.twodragonlake.sharding.jdbc.mapper.annotation.Mapper.class);
    //扫描的根目录
    mapperScannerConfigurer.setBasePackage(com.twodragonlake.sharding.jdbc.common.utils.StringUtils.join(basePackages, ","));
    //mapper默认使用默认的数据源的sqlTemplate
    mapperScannerConfigurer.setSqlSessionTemplateBeanName(DataSourceConfiger.defaultLogicDsName + "sqlTemplate");
    //配置为自动扫描生效，mapperScannerConfigurer会根据mapper上的DBSwitch注解，切换为实际的sqlTemplate，稍后讲解mapperScannerConfigurer的逻辑
    int mapperCount = mapperScannerConfigurer.autoConfigure(registry);
    logger.info("{} mappers have been found and been added to spring container.", mapperCount);
}

//创建SqlSessionFactoryBean
//SqlSessionFactoryBean封装了mybatis-config.xml的位置、mapper的xml位置信息等
private GenericBeanDefinition buildSessionFactoryBeanDefinition(String dataBaseName) {
    GenericBeanDefinition definition = new GenericBeanDefinition();
    definition.setBeanClass(SqlSessionFactoryBean.class);
    definition.setScope(BeanDefinition.SCOPE_SINGLETON);
    definition.getPropertyValues().addPropertyValue("dataSource", new RuntimeBeanReference(dataBaseName));
    Resource mybatisResource;
    try {
        Resource[] mybatisResources  = this.applicationContext.getResources("classpath*:/mybatis-config.xml");
        mybatisResource = mybatisResources[0];
    } catch (IllegalConfigException e) {
        throw e;
    } catch (Exception e) {
        throw new IllegalConfigException("no mybatis-config.xml file exists in classpath.");
    }
    definition.getPropertyValues().addPropertyValue("configLocation", mybatisResource);

    String typeAliasesPackage = propertiesReader.getString("spring.shardingsphere.datasource.typeAliasesPackage", "");
    if (!StringUtils.isEmpty(typeAliasesPackage)) {
        definition.getPropertyValues().addPropertyValue("typeAliasesPackage", typeAliasesPackage);
    }
    String typeHandlersPackage = propertiesReader.getString("spring.shardingsphere.datasource.typeHandlersPackage", "");
    if (!StringUtils.isEmpty(typeHandlersPackage)) {
        definition.getPropertyValues().addPropertyValue("typeHandlersPackage", typeHandlersPackage);
    }

    try {
        definition.getPropertyValues().addPropertyValue("mapperLocations", this.applicationContext.getResources("classpath*:/mybatis/**/*.xml"));
    } catch (IOException e) {
        throw new IllegalStateException("IOException when loading mapper resource under classpath*:/mybatis/**/*.xml");
    }
    return definition;
}

// 获取扫描的package根路径
private Set<String> resolveBasePackages() {
    // 获取main方法启动的类(使用异常取巧的编程方式)
    Class<?> main = CommonUtils.findMainClass();
    Set<String> scanPackages = new HashSet<>();
    List<Class<?>> scanPackageClasses = new ArrayList<>();
    String basePackages = this.propertiesReader.getString(" ");
    if(StringUtils.isEmpty(basePackages)) {
        //兼容starter，MapperComponentScan 可以配置扫描的路径
        MapperComponentScan mapperComponentScan = main.getAnnotation(MapperComponentScan.class);
        if(mapperComponentScan != null) {
            scanPackages.addAll(Arrays.asList(mapperComponentScan.basePackage()));
            scanPackageClasses.addAll(Arrays.asList(mapperComponentScan.basePackageClasses()));
        } else {
            // MapperScan也可以配置扫描的路径
            MapperScan mapperScan = main.getAnnotation(MapperScan.class);
            if(mapperScan != null) {
                scanPackages.addAll(Arrays.asList(mapperScan.basePackages()));
                scanPackageClasses.addAll(Arrays.asList(mapperScan.basePackageClasses()));
            } else {
                scanPackageClasses.add(main);
            }
        }
        if(scanPackageClasses != null) {
            for(Class<?> packageClass : scanPackageClasses){
                scanPackages.add(packageClass.getPackage().getName());
            }
        }
    } else {
        scanPackages.add(basePackages);
    }
    return scanPackages;
}
```

#### MapperScannerConfigurer切换mapper的sqlTemplate为实际需要的sqlTemplate
 这里不对mybatis的一些组件细化讲解，有兴趣可以参考这个课程深化了解mybatis:
 ![image.png](https://i.loli.net/2021/07/18/5bMpSuartDmW2L7.png)
```
public class MapperScannerConfigurer extends org.mybatis.spring.mapper.MapperScannerConfigurer {

    private static final Logger logger = LoggerFactory.getLogger(MapperScannerConfigurer.class);

    private MapperHelper mapperHelper = new MapperHelper();

    @Override
    public void setMarkerInterface(Class<?> superClass) {
        super.setMarkerInterface(superClass);
        if (Marker.class.isAssignableFrom(superClass)) {
            mapperHelper.registerMapper(superClass);
        }
    }

    public MapperHelper getMapperHelper() {
        return mapperHelper;
    }

    public void setMapperHelper(MapperHelper mapperHelper) {
        this.mapperHelper = mapperHelper;
    }

    /**
     * 属性注入
     *
     * @param properties
     */
    public void setProperties(Properties properties) {
        mapperHelper.setProperties(properties);
    }

    public int autoConfigure( BeanDefinitionRegistry registry) {
        super.postProcessBeanDefinitionRegistry(registry);
        //如果没有注册过接口，就注册默认的Mapper接口
        this.mapperHelper.ifEmptyRegisterDefaultInterface();
        String[] names = registry.getBeanDefinitionNames();
        GenericBeanDefinition definition;
        int mapperCount = 0;
        for (String name : names) {
            BeanDefinition beanDefinition = registry.getBeanDefinition(name);
            if (beanDefinition instanceof GenericBeanDefinition) {
                definition = (GenericBeanDefinition) beanDefinition;
                //MapperFactoryBean 是mybatis对mapper在spring当中的抽象，适配了springbean的规范，是一个FactoryBean，FactoryBean其实是一个代理，getObject才是正真的对象
                //这里的意思是如果是一个mybatis的mapper的封装，那么进行一波逻辑操作
                if (StringUtil.isNotEmpty(definition.getBeanClassName()) && definition.getBeanClassName().equals("org.mybatis.spring.mapper.MapperFactoryBean")) {
                    try {
                        //definition.getPropertyValues().add("sqlSessionTemplate", new RuntimeBeanReference("sqlTemplate"));
                        //得到mapper类的元信息
                        String value = ((ScannedGenericBeanDefinition) definition).getMetadata().getClassName();
                        //得到mapper类对象
                        Class<?> valueClass = Class.forName(value);
                        //尝试得到DBSwitch注解
                        DBSwitch dbSwitch = valueClass.getAnnotation(DBSwitch.class);
                        if(dbSwitch == null || StringUtils.isEmpty(dbSwitch.value())){
                            // mapper没有配置DBSwitch，则使用默认的sqlTemplate
                            definition.getPropertyValues().add("sqlSessionTemplate", new RuntimeBeanReference(DataSourceConfiger.defaultLogicDsName + "sqlTemplate"));
                        }else{
                            //mapper配置了DBSwitch，则使用DBSwitch配置的数据源名称对应的sqlTemplate
                            definition.getPropertyValues().add("sqlSessionTemplate", new RuntimeBeanReference(dbSwitch.value()+"sqlTemplate"));
                        }
                        mapperCount++;
                    } catch (Exception e) {
                        e.printStackTrace();
                        throw new IllegalStateException(e);
                    }
                    definition.setBeanClass(tk.mybatis.spring.mapper.MapperFactoryBean.class);
                    definition.getPropertyValues().add("mapperHelper", this.mapperHelper);
                }
            }
        }
        return mapperCount;
    }
}
```

#### 小结
MybatisConfigure 使用DataSourceConfiger里边初始化的数据源，创建了mybatis访问数据源用的SqlSessionTemplate，之后使用SqlSessionTemplate作为参数创建mapper，
加载了mapper到spring容器。


### 使用Encryptor实现定制化脱敏编解码器
关于shardingsphere的实现方案，参考官方的介绍，[数据脱敏](https://shardingsphere.apache.org/document/legacy/4.x/document/cn/features/orchestration/encrypt/)
次数不再单独讲解。
Encryptor的加载，shardingsphere使用了java的spi机制，首先我们先介绍些 怎么实现一个定制化的Encryptor:
#### 实现Encryptor接口定制一个脱敏编解码器
```

public class LLPayAESEncryptor implements Encryptor {
    // Encryptor的配置信息
    private Properties properties = new Properties();
    // IAESCryptService是一个rpc服务，对外提供了信息加密解密的能力
    private static IAESCryptService aESCryptService;

    @Override
    public void init() {
        //初始化
    }

    // 使用aESCryptService加密
    @Override
    public String encrypt(Object plaintext) {
        try {
            if (null != plaintext && !StringUtils.isEmpty(plaintext)) {
                return aESCryptService.encrypt(plaintext.toString().getBytes(StandardCharsets.UTF_8));
            }
        }catch (AESException aesException){
            throw new RuntimeException(aesException);
        }
        return null;
    }

    //使用aESCryptService解密
    @Override
    public Object decrypt(String ciphertext) {
        try {
            if (null != ciphertext && !StringUtils.isEmpty(ciphertext)) {
                return new String (aESCryptService.decrypt(ciphertext),StandardCharsets.UTF_8);
            }
        }catch (AESException aesException){
            throw new RuntimeException(aesException);
        }
        return null;
    }

    // 编解码器的类型，EncryptorServiceLoader加载器会根据这个类型字符串加载当前的LLPayAESEncryptor实现
    @Override
    public String getType() {
        return EncryptConstants.LLPAYENCRYPT_AES;
    }

    @Override
    public Properties getProperties() {
        return properties;
    }

    @Override
    public void setProperties(Properties properties) {
        this.properties = properties;
    }

    //初始化aESCryptService（如果是dubbo服务，要提前将服务注册到spring容器当中）
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
        if (null ==  aESCryptService) {
            aESCryptService = beanFactory.getBean(IAESCryptService.class);
        }
    }
}
```

### 加载Encryptor
shardingsphere使用java的spi机制加载脱敏编解码器，shardingsphere有自己封装的loader：
```
import com.twodragonlake.sharding.jdbc.encrypt.constants.EncryptConstants;
import com.twodragonlake.sharding.jdbc.encrypt.llaes.LLPayAESEncryptor;
import org.apache.shardingsphere.encrypt.strategy.spi.loader.EncryptorServiceLoader;
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.beans.factory.config.ConfigurableListableBeanFactory;

import java.util.Properties;

public class EncryptConfigurer implements  BeanFactoryPostProcessor {
    //EncryptorServiceLoaders相当于jdk当中的ServiceLoader，shardingsphere实现了一套适合自己的EncryptorServiceLoader，换汤不换药
    private EncryptorServiceLoader serviceLoader = new EncryptorServiceLoader();

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
        // 使用EncryptorServiceLoader加载指定类型的Encryptor
        LLPayAESEncryptor llPayEncryptor = (LLPayAESEncryptor) serviceLoader.newService(EncryptConstants.LLPAYENCRYPT_AES, new Properties());
        //注册到spring容器当中
        llPayEncryptor.postProcessBeanFactory(beanFactory);
    }
}
```

#### 引导
最后需要配置入口，让EncryptorServiceLoader可以加载到LLPayAESEncryptor，我们把上述EncryptConfigurer和LLPayAESEncryptor可以封装到一个jar当中，业务系统可以直接用maven引入，当业务app启动的时候要想加载LLPayAESEncryptor生效需要遵守java的spi规范，因此需要在我们的jar包当中的resources目录下创建如下结构的文件：
-resources
  -META-INF.services
    org.apache.shardingsphere.encrypt.strategy.spi.Encryptor

org.apache.shardingsphere.encrypt.strategy.spi.Encryptor文件内容：
```
com.twodragonlake.sharding.jdbc.encrypt.llaes.LLPayAESEncryptor
```
即Encryptor的实现LLPayAESEncryptor。

#### 小结
shardingsphere提供了一套脱敏方案，并且暴露了接口给开发者，可以实现定制化的数据脱敏实现，在我们的例子当中，IAESCryptService的实现可以是阿里云、aws等服务上提供的加密服务，这样就能灵活的配置数据脱敏。


### 总结
本章主要介绍了 shardin-jdbc在不同的数据库，使用不同的策略的封装和实现，配合mybatis去做了mapper上的兼容，最后介绍了sharding-jdbc脱敏的定制化实现。
源码目前还在内部优化，开源之后会放到[TwoDragonLake](https://github.com/TwoDragonLake) Organization当中。
