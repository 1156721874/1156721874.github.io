---
title: 3-docker-仓库
date: 2018-11-24 15:01:45
tags: [docker hub,Repository,仓库]
categories: docker
---

## 仓库和注册服务器的区别
  举例说明：
<!-- more -->
  tdlceaserwang/repository
  dl.dockerpool.com/ubuntu
  tdlceaserwang和dl.dockerpool.com都是注册服务器，repository和ubuntu都是仓库。

## Docker Hub基本操作

### 拉取镜像
  搜索：
  docker search  kafka
  过滤搜索：  docker search  kafka --filter=stars=N 【搜索star数量超过N的镜像】
  拉取：
  docker pull kafka

### 推送镜像
  1:>docker tag jdk8:v1 tdlceaserwang/jdk8:v1
  2:>docker push tdlceaserwang/jdk8:v1

  ```
  docker login
  #输入docker的用户id，注意，不是email
  #输入密码
  >docker tag jdk8:v1 tdlceaserwang/jdk8:v1
  >docker push tdlceaserwang/jdk8:v1
  ```
  ![3-1](3-1.png)
  ![3-2](3-2.png)
