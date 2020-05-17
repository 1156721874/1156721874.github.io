---
title: spring_boot_cloud(15)eureka架构剖析与服务注册详解
date: 2020-05-16 16:45:32
tags: [Condition]
categories: spring_boot_cloud
---

### eureka架构
![eureka-construct.png](eureka-construct.png)

### DiscoveryClient
The class that is instrumental for interactions with Eureka Server.
Eureka Client is responsible for a) Registering the instance with Eureka Server b) Renewalof the lease with Eureka Server c) Cancellation of the lease from Eureka Server during shutdown
d) Querying the list of services/instances registered with Eureka Server
DiscoveryClient是和Eureka服务通信的类的实现
a)注册到Eureka server
b)租约，续约
c)服务下线
d)拉取服务列表
<!-- more -->
#### 初始化

DiscoveryClient的主要方法:
```
/**
 * Initializes all scheduled tasks.
 * 初始化所有的调度任务
 */
private void initScheduledTasks() {
  //返回true拉取所有的信息
    if (clientConfig.shouldFetchRegistry()) {
        // registry cache refresh timer
        int registryFetchIntervalSeconds = clientConfig.getRegistryFetchIntervalSeconds();
        int expBackOffBound = clientConfig.getCacheRefreshExecutorExponentialBackOffBound();
        //启动定时服务
        cacheRefreshTask = new TimedSupervisorTask(
                "cacheRefresh",
                scheduler,
                cacheRefreshExecutor,
                registryFetchIntervalSeconds,
                TimeUnit.SECONDS,
                expBackOffBound,
                new CacheRefreshThread()
        );
        scheduler.schedule(
                cacheRefreshTask,
                registryFetchIntervalSeconds, TimeUnit.SECONDS);
    }
    //需要注册到Eureka server
    if (clientConfig.shouldRegisterWithEureka()) {
        int renewalIntervalInSecs = instanceInfo.getLeaseInfo().getRenewalIntervalInSecs();
        int expBackOffBound = clientConfig.getHeartbeatExecutorExponentialBackOffBound();
        logger.info("Starting heartbeat executor: " + "renew interval is: {}", renewalIntervalInSecs);

        // Heartbeat timer
        heartbeatTask = new TimedSupervisorTask(
                "heartbeat",
                scheduler,
                heartbeatExecutor,
                renewalIntervalInSecs,
                TimeUnit.SECONDS,
                expBackOffBound,
                new HeartbeatThread()
        );
        scheduler.schedule(
                heartbeatTask,
                renewalIntervalInSecs, TimeUnit.SECONDS);

        // InstanceInfo replicator
        instanceInfoReplicator = new InstanceInfoReplicator(
                this,
                instanceInfo,
                clientConfig.getInstanceInfoReplicationIntervalSeconds(),
                2); // burstSize

        statusChangeListener = new ApplicationInfoManager.StatusChangeListener() {
            @Override
            public String getId() {
                return "statusChangeListener";
            }

            @Override
            public void notify(StatusChangeEvent statusChangeEvent) {
                if (InstanceStatus.DOWN == statusChangeEvent.getStatus() ||
                        InstanceStatus.DOWN == statusChangeEvent.getPreviousStatus()) {
                    // log at warn level if DOWN was involved
                    logger.warn("Saw local status change event {}", statusChangeEvent);
                } else {
                    logger.info("Saw local status change event {}", statusChangeEvent);
                }
                instanceInfoReplicator.onDemandUpdate();
            }
        };

        if (clientConfig.shouldOnDemandUpdateStatusChange()) {
            applicationInfoManager.registerStatusChangeListener(statusChangeListener);
        }
        // 主要的注册实现在 instanceInfoReplicator的run方法里边实现的
        instanceInfoReplicator.start(clientConfig.getInitialInstanceInfoReplicationIntervalSeconds());
    } else {
        logger.info("Not registering with Eureka server per configuration");
    }
}


#### 注册

```
instanceInfoReplicator的run方法：
```
public void run() {
    try {
        discoveryClient.refreshInstanceInfo();

        Long dirtyTimestamp = instanceInfo.isDirtyWithTime();
        if (dirtyTimestamp != null) {
          // 注册的核心实现
            discoveryClient.register();
            instanceInfo.unsetIsDirty(dirtyTimestamp);
        }
    } catch (Throwable t) {
        logger.warn("There was a problem with the instance info replicator", t);
    } finally {
        Future next = scheduler.schedule(this, replicationIntervalSeconds, TimeUnit.SECONDS);
        scheduledPeriodicRef.set(next);
    }
}
```
discoveryClient.register()的实现:
```
/**
 * Register with the eureka service by making the appropriate REST call.
 */
boolean register() throws Throwable {
    logger.info(PREFIX + "{}: registering service...", appPathIdentifier);
    EurekaHttpResponse<Void> httpResponse;
    try {
      //使用http的方式去注册
        httpResponse = eurekaTransport.registrationClient.register(instanceInfo);
    } catch (Exception e) {
        logger.warn(PREFIX + "{} - registration failed {}", appPathIdentifier, e.getMessage(), e);
        throw e;
    }
    if (logger.isInfoEnabled()) {
        logger.info(PREFIX + "{} - registration status: {}", appPathIdentifier, httpResponse.getStatusCode());
    }
    return httpResponse.getStatusCode() == Status.NO_CONTENT.getStatusCode();
}
```
eurekaTransport.registrationClient.register的实现:
```
public EurekaHttpResponse<Void> register(InstanceInfo info) {
  String urlPath = serviceUrl + "apps/" + info.getAppName();
  //组装http的header
  HttpHeaders headers = new HttpHeaders();
  headers.add(HttpHeaders.ACCEPT_ENCODING, "gzip");
  headers.add(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE);

  ResponseEntity<Void> response = restTemplate.exchange(urlPath, HttpMethod.POST,
      new HttpEntity<>(info, headers), Void.class);

  return anEurekaHttpResponse(response.getStatusCodeValue())
      .headers(headersOf(response)).build();
}
```
eureka最终是http的方式去注册的。

#### 续约
```
/**
 * Renew with the eureka service by making the appropriate REST call
 */
 续约到eureka servver，通过REST的方式
boolean renew() {
    EurekaHttpResponse<InstanceInfo> httpResponse;
    try {
      //发送心跳
        httpResponse = eurekaTransport.registrationClient.sendHeartBeat(instanceInfo.getAppName(), instanceInfo.getId(), instanceInfo, null);
        logger.debug(PREFIX + "{} - Heartbeat status: {}", appPathIdentifier, httpResponse.getStatusCode());
        if (httpResponse.getStatusCode() == Status.NOT_FOUND.getStatusCode()) {
            REREGISTER_COUNTER.increment();
            logger.info(PREFIX + "{} - Re-registering apps/{}", appPathIdentifier, instanceInfo.getAppName());
            long timestamp = instanceInfo.setIsDirtyWithTime();
            boolean success = register();
            if (success) {
                instanceInfo.unsetIsDirty(timestamp);
            }
            return success;
        }
        return httpResponse.getStatusCode() == Status.OK.getStatusCode();
    } catch (Throwable e) {
        logger.error(PREFIX + "{} - was unable to send heartbeat!", appPathIdentifier, e);
        return false;
    }
}
```
sendHeartBeat的主要实现:
org.springframework.cloud.netflix.eureka.http.RestTemplateEurekaHttpClient
```
public EurekaHttpResponse<InstanceInfo> sendHeartBeat(String appName, String id,
    InstanceInfo info, InstanceStatus overriddenStatus) {
  String urlPath = serviceUrl + "apps/" + appName + '/' + id + "?status="
      + info.getStatus().toString() + "&lastDirtyTimestamp="
      + info.getLastDirtyTimestamp().toString() + (overriddenStatus != null
          ? "&overriddenstatus=" + overriddenStatus.name() : "");

  ResponseEntity<InstanceInfo> response = restTemplate.exchange(urlPath,
      HttpMethod.PUT, null, InstanceInfo.class);

  EurekaHttpResponseBuilder<InstanceInfo> eurekaResponseBuilder = anEurekaHttpResponse(
      response.getStatusCodeValue(), InstanceInfo.class)
          .headers(headersOf(response));

  if (response.hasBody()) {
    eurekaResponseBuilder.entity(response.getBody());
  }

  return eurekaResponseBuilder.build();
}
```
即续约也是使用http的方式.


### EurekaClientConfigBean
```
eureka:
  client:
    registerWithEureka: true
    fetchRegistry: true
    service-url:
      defaultZone: http://node1:10097/eureka/,http://node2:10098/eureka/,http://node3:10099/eureka/
```
这个eureka配置主要的实现类是EurekaClientConfigBean,service-url的获取:
```
	public static final String DEFAULT_ZONE = "defaultZone";
  public static final String DEFAULT_URL = "http://localhost:8761" + DEFAULT_PREFIX+ "/";
  private Map<String, String> serviceUrl = new HashMap<>();

  {
    this.serviceUrl.put(DEFAULT_ZONE, DEFAULT_URL);
  }	private Map<String, String> serviceUrl = new HashMap<>();

  	{
  		this.serviceUrl.put(DEFAULT_ZONE, DEFAULT_URL);
  	}
```
