---
title: SPRING技术内幕-笔记（十二）spring驱动ibatis的设计与实现
date: 2018-09-28 20:04:12
tags: spring
categories: spring
---
**12.1设计原理**
对ibatis的使用相对来说比较简单，在spring的封装中，有几个基本过程，首先需要创建sqlmapclient，这个sqlmapclient类似于在hibernate中的session，对于它的创建，在spring中设计sqlmapclientfactorybean，通过这个factorybean；哎读取sqlmapclient的配置和具体创建。在配置和创建好sqlmapclient之后，在spring中同样为sqlmapclient的使用封装了sqlmapclienttemplate，他同样作为一个模板，封装了通过sqlmapclient完成的主要操作。

<!-- more -->
**12.2创建sqlmapclient**
在springIOC容器中，ibatis实例通常通过sqlmapclientfactorybean来设置，在sqlmapfactorybean中完成sqlmapclient的创建，sqlmapclient是用户使用ibatis操作数据库的主要类，这个创建过程包括一些对sqlmapclient的配置过程（比如对数据源打他source的配置），以及对参数的配置，宰割创建过程是在afterpropertiesset中完成，他在依赖注入完成以后被ioc容器回调。
IOC调用回顾：

```
	protected void invokeInitMethods(String beanName, final Object bean, RootBeanDefinition mbd)
			throws Throwable {

		boolean isInitializingBean = (bean instanceof InitializingBean);
		if (isInitializingBean && (mbd == null || !mbd.isExternallyManagedInitMethod("afterPropertiesSet"))) {
			if (logger.isDebugEnabled()) {
				logger.debug("Invoking afterPropertiesSet() on bean with name '" + beanName + "'");
			}
			if (System.getSecurityManager() != null) {
				try {
					AccessController.doPrivileged(new PrivilegedExceptionAction<Object>() {
						public Object run() throws Exception {
							((InitializingBean) bean).afterPropertiesSet();
							return null;
						}
					}, getAccessControlContext());
				}
				catch (PrivilegedActionException pae) {
					throw pae.getException();
				}
			}				
			else {
			//对bean注入之后进行初始化
				((InitializingBean) bean).afterPropertiesSet();
			}
		}

		if (mbd != null) {
			String initMethodName = mbd.getInitMethodName();
			if (initMethodName != null && !(isInitializingBean && "afterPropertiesSet".equals(initMethodName)) &&
					!mbd.isExternallyManagedInitMethod(initMethodName)) {
				invokeCustomInitMethod(beanName, bean, mbd);
			}
		}
	}
```
SqlMapClientFactoryBean的getObject以及afterPropertiesSet方法：
	public SqlMapClient getObject() {
		return this.sqlMapClient;
	}
```
	public void afterPropertiesSet() throws Exception {
		if (this.lobHandler != null) {
			// Make given LobHandler available for SqlMapClient configuration.
			// Do early because because mapping resource might refer to custom types.
			configTimeLobHandlerHolder.set(this.lobHandler);
		}

		try {
		//开始创建sqlMapClient
			this.sqlMapClient = buildSqlMapClient(this.configLocations, this.mappingLocations, this.sqlMapClientProperties);

			// Tell the SqlMapClient to use the given DataSource, if any.
			//为sqlMapClient 设置数据源
			if (this.dataSource != null) {
				TransactionConfig transactionConfig = (TransactionConfig) this.transactionConfigClass.newInstance();
				DataSource dataSourceToUse = this.dataSource;
				if (this.useTransactionAwareDataSource && !(this.dataSource instanceof TransactionAwareDataSourceProxy)) {
					dataSourceToUse = new TransactionAwareDataSourceProxy(this.dataSource);
				}
				transactionConfig.setDataSource(dataSourceToUse);
				transactionConfig.initialize(this.transactionConfigProperties);
				applyTransactionConfig(this.sqlMapClient, transactionConfig);
			}
		}

		finally {
			if (this.lobHandler != null) {
				// Reset LobHandler holder.
				configTimeLobHandlerHolder.remove();
			}
		}
	}
```
buildSqlMapClient方法的实现：

```
	protected SqlMapClient buildSqlMapClient(
			Resource[] configLocations, Resource[] mappingLocations, Properties properties)
			throws IOException {

		if (ObjectUtils.isEmpty(configLocations)) {
			throw new IllegalArgumentException("At least 1 'configLocation' entry is required");
		}

		SqlMapClient client = null;
		//对应对数据源以及数据源附属参数的设置
		SqlMapConfigParser configParser = new SqlMapConfigParser();
		for (Resource configLocation : configLocations) {
			InputStream is = configLocation.getInputStream();
			try {
				client = configParser.parse(is, properties);
			}
			catch (RuntimeException ex) {
				throw new NestedIOException("Failed to parse config resource: " + configLocation, ex.getCause());
			}
		}
//对映射文件的初始化。
		if (mappingLocations != null) {
			SqlMapParser mapParser = SqlMapParserFactory.createSqlMapParser(configParser);
			for (Resource mappingLocation : mappingLocations) {
				try {
					mapParser.parse(mappingLocation.getInputStream());
				}
				catch (NodeletException ex) {
					throw new NestedIOException("Failed to parse mapping resource: " + mappingLocation, ex);
				}
			}
		}

		return client;
	}
```

**12.3 sqlmapclienttemplate的实现**

sqlmapclienttemplate封装了对ibatis的操作，其继承关系如下：
![这里写图片描述](2018/09/28/SPRING技术内幕-笔记（十二）spring驱动ibatis的设计与实现/20150726132920921.png)

sqlmapclienttemplate是一个核心，这个类持有一个sqlmapclient，这个类是ibatis的类，是直接使用ibatis时调用的，它提供了使用ibatis的API，类似于hibernate的session，同时，sqlmapclientdaosupport中持有一个salmapclienttemplate，尽管对ibatis的操作是由sqlmapclienttemplate来完成，但应用可以通过扩展sqlmapclientdaosupport来对ibatis进行操作。spring封装ibatis操作基本上封装在sqlmapclienttemplate的设计和实现中。其设计时序图：
![这里写图片描述](2018/09/28/SPRING技术内幕-笔记（十二）spring驱动ibatis的设计与实现/20150726142033632.png)

在这个时序过程中，template会从sqlmapclient中得到session和datasource，并进行一系列的初始化过程，然后回调sqlmapclientcallback的doinsqlmapclient方法执行具体的动作，最后释放数据库连接和关闭session。
代码实现：

```
/**
	 * Execute the given data access action on a SqlMapExecutor.
	 * @param action callback object that specifies the data access action
	 * @return a result object returned by the action, or <code>null</code>
	 * @throws DataAccessException in case of SQL Maps errors
	 */
	 //使用SqlMapExecutor完成数据的操作
	public <T> T execute(SqlMapClientCallback<T> action) throws DataAccessException {
		Assert.notNull(action, "Callback object must not be null");
		Assert.notNull(this.sqlMapClient, "No SqlMapClient specified");

		// We always need to use a SqlMapSession, as we need to pass a Spring-managed
		// Connection (potentially transactional) in. This shouldn't be necessary if
		// we run against a TransactionAwareDataSourceProxy underneath, but unfortunately
		// we still need it to make iBATIS batch execution work properly: If iBATIS
		// doesn't recognize an existing transaction, it automatically executes the
		// batch for every single statement...
         //通过sqlMapClient完成sqlmapsession
		SqlMapSession session = this.sqlMapClient.openSession();
		if (logger.isDebugEnabled()) {
			logger.debug("Opened SqlMapSession [" + session + "] for iBATIS operation");
		}
		Connection ibatisCon = null;
        //得到数据源
		try {
			Connection springCon = null;
			DataSource dataSource = getDataSource();
			boolean transactionAware = (dataSource instanceof TransactionAwareDataSourceProxy);

			// Obtain JDBC Connection to operate on...
			try {
				ibatisCon = session.getCurrentConnection();
				if (ibatisCon == null) {
				//此处将要获取connection，如果已经在spring的事物管理之下，数据源直接拿过来使用，否则就是用
				//DataSourceUtils生成一个connection，并将得到的connnection放在spring的事物管理之下。
					springCon = (transactionAware ?
							dataSource.getConnection() : DataSourceUtils.doGetConnection(dataSource));
					session.setUserConnection(springCon);
					if (logger.isDebugEnabled()) {
						logger.debug("Obtained JDBC Connection [" + springCon + "] for iBATIS operation");
					}
				}
				else {
					if (logger.isDebugEnabled()) {
						logger.debug("Reusing JDBC Connection [" + ibatisCon + "] for iBATIS operation");
					}
				}
			}
			catch (SQLException ex) {
				throw new CannotGetJdbcConnectionException("Could not get JDBC Connection", ex);
			}

			// Execute given callback...
			try {
			 //执行SqlMapClientCallback的回调函数
				return action.doInSqlMapClient(session);
			}
			catch (SQLException ex) {
				throw getExceptionTranslator().translate("SqlMapClient operation", null, ex);
			}
			finally {
				try {
					if (springCon != null) {
						if (transactionAware) {
							springCon.close();
						}
						else {
							DataSourceUtils.doReleaseConnection(springCon, dataSource);
						}
					}
				}
				catch (Throwable ex) {
					logger.debug("Could not close JDBC Connection", ex);
				}
			}

			// Processing finished - potentially session still to be closed.
		}
		//释放datasource
		finally {
			// Only close SqlMapSession if we know we've actually opened it
			// at the present level.
			if (ibatisCon == null) {
				session.close();
			}
		}
	}
```
sqlmapclienttemplate的其他方法也是调用exector方法提供回调函数实现的。
比如：
```
	public Object queryForObject(final String statementName, final Object parameterObject)
			throws DataAccessException {

		return execute(new SqlMapClientCallback<Object>() {
			public Object doInSqlMapClient(SqlMapExecutor executor) throws SQLException {
				return executor.queryForObject(statementName, parameterObject);
			}
		});
	}
```
关于datasource的关闭以及事物的绑定都已经做好了封装。
