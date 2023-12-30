---
title: 2-docker-容器
date: 2018-11-20 22:05:41
tags: [docker,container,容器]
categories: docker
---

## 新建并启动
  ```
<!-- more -->
  docker run ubuntu:14.04 /bin/echo 'Hello world'
  Hello world

  docker run -t -i ubuntu:14.04 /bin/bash
  root@af8bae53bdd3:/#
  ```
  -t:打开终端,让Docker分配一个伪终端（pseudo-tty）并绑定到容器的标准输入上
  -i:交互式,让容器的标准输入保持打开。在这种模式下，用户可以输入ls、pwd这类命令和os进行交互

## 启动已终止容器
  可以利用 docker container start 命令，直接将一个已经终止的容器启动运行。

## 后台运行
  更多的时候，需要让 Docker 在后台运行而不是直接把执行命令的结果输出在当前宿主机下。
  此时，可以通过添加 -d 参数来实现。
  example:不使用-d：
  ```
  docker run ubuntu:17.10 /bin/sh -c "while true; do echo hello world; sleep 1; done"
  hello world
  hello world
  hello world
  hello world
  ```

  使用了 -d 参数运行容器:
  ```
  $ docker run -d ubuntu:17.10 /bin/sh -c "while true; do echo hello world; sleep 1; done"
  77b2dc01fe0f3f1265df143181e7b9af5e05279a884f4776ee75350ea9d8017a
  ```
  此时容器会在后台运行并不会把输出的结果 (STDOUT) 打印到宿主机上面(输出结果可以用docker logs/docker container logs 查看)。
  注： 容器是否会长久运行，是和 docker run 指定的命令有关，和 -d 参数无关。
  使用 -d 参数启动后会返回一个唯一的 id，也可以通过 docker container ls 命令来查看容
  器信息。
### docker container logs
  ```
  $ docker container logs [container ID or NAMES]
  hello world
  hello world
  hello world
  . . .
  ```

## 终止容器

  docker container stop用来终止一个正在运行的容器，如果容器指定的app终止，那么容器也会立刻终止。
  可以使用  docker container ls -a查看到终止的容器。
  docker container start：将终止的容器重新运行。
  docker container restart：将运行的容器终止，然后再重启。

## 进入容器
  使用-d启动容器后，容器会在后台运行，这时候，我们想再次进入容器操作，就需要一些方式，下面介绍2种命令。

### attach 命令
  ```
  >docker run -dit  jdk8:v1
  bba6e1a848711fd046a4a6d934ac9de0f58736bcade81e42d30ce05aa620ee30
  >docker container ls
  CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
  bba6e1a84871        jdk8:v1             "/bin/bash"         43 seconds ago      Up 40 seconds                           suspicious_blackwell
  >docker attach bba
  [root@bba6e1a84871 /]# ls /
  anaconda-post.log  bin  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
  ```
  ![2-1](2018/11/20/2-docker-容器/2-1.png)
  PS：使用attach退出终端后，容器也会终止，退出。
### exec 命令

  ![2-2](2018/11/20/2-docker-容器/2-2.png)

  ```
  >docker run -dit jdk8:v1
  15febd290b57ea968d233096e701b8f73bf11ca90db6692da33e185e8a016103

  >docker container ls
  CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
  15febd290b57        jdk8:v1             "/bin/bash"         12 seconds ago      Up 9 seconds                            goofy_banach
  >docker exec -it 15f bash
  [root@15febd290b57 /]# ls
  anaconda-post.log  bin  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
  [root@15febd290b57 /]# exit
  exit

  >docker container ls
  CONTAINER ID        IMAGE               COMMAND             CREATED              STATUS              PORTS               NAMES
  15febd290b57        jdk8:v1             "/bin/bash"         About a minute ago   Up About a minute                       goofy_banach
  ```

  可以看到使用exec进入容器操作，然后退出终端后，容器并没有终止。这个是和attach的主要区别，也是推荐使用的。
  docker exec -it 15f bash：bash指的是运行bash，exec要求至少2个参数，一个是容器的id，一个是运行的方式。

## 删除容器
    可以使用 docker container rm 来删除一个处于终止状态的容器。例如
    ```
    $ docker container rm trusting_newton
    trusting_newton
    ```

## 清理所有处于终止状态的容器
  用 docker container ls -a 命令可以查看所有已经创建的包括终止状态的容器，如果数量太多要一个个删除可能会很麻烦，用下面的命令可以清理掉所有处于终止状态的容器。
  ![2-3](2018/11/20/2-docker-容器/2-3.png)
  同样的道理也可以清理镜像：
  ![2-4](2018/11/20/2-docker-容器/2-4.png)
