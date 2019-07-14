---
title: 1-docker-使用镜像
date: 2018-11-18 21:19:47
tags: [docker,docer image]
categories: docker
---

# 获取docker 镜像
## docker pull
docker hub：https://hub.docker.com/explore/
  从 Docker 镜像仓库获取镜像的命令是 docker pull：
  docker pull [选项] [Docker Registry 地址[:端口号]/]仓库名[:标签]
  example：
  ```
  docker pull myregistry.local:5000/testing/test-image
  docker pull centos:7
  docker pull tdlceaserwang/repository/jdk8DoclerFile:v1
  ```
## 运行
  example：
  ```
  docker run -it --rm \
  ubuntu:16.04 \
  bash
  ```
  -it ：这是两个参数，一个是 -i ：交互式操作，一个是 -t 终端。我们这里打算进入
  bash 执行一些命令并查看返回结果，因此我们需要交互式终端。
  --rm ：这个参数是说容器退出后随之将其删除。默认情况下，为了排障需求，退出的容
  器并不会立即删除，除非手动 docker rm 。我们这里只是随便执行个命令，看看结果，
  不需要排障和保留结果，因此使用 --rm 可以避免浪费空间。
  ubuntu:16.04 ：这是指用 ubuntu:16.04 镜像为基础来启动容器。
  bash ：放在镜像名后的是命令，这里我们希望有个交互式 Shell，因此用的是 bash

## 列出镜像

  ```
  docker image ls
  ```

  ![1-1](1-1.png)
  查看镜像、容器、数据卷所占用的空间:
  ```
  docker system df
  ```
  ![1-2](1-2.png)

## 虚悬镜像
  定义：镜像既没有仓库名，也没有标签，均为 <none>
  列出虚悬镜像：
  ```
  docker image ls -f dangling=true
  ```
  删除虚悬镜像(dangling image)：
  ```
  docker image prune
  ```

## 中间层镜像
  为了加速镜像构建、重复利用资源，Docker 会利用 中间层镜像。所以在使用一段时间后，可
  能会看到一些依赖的中间层镜像。默认的 docker image ls 列表中只会显示顶层镜像，如果
  希望显示包括中间层镜像在内的所有镜像的话，需要加 -a 参:
  ```
  docker image ls -a
  ```
  ps:删除那些依赖它们的镜像后，这些依赖的中间层镜像也会被连带删除.
### 过滤器参数
  example:
  ```
  docker image ls -f since=mongo:3.2
  # 想查看某个位置之前的镜像也可以，只需要把 since 换成 before 即可
  ```
## 以特定格式显示
  ```
  docker image ls -q
  ```
  结果：
  ```
  75835a67d134
  cae870735e91
  ```
  --filter 配合 -q 产生出指定范围的 ID 列表，然后送给另一个 docker 命令作为参数
###  Go 的模板语法
  ```
  docker image ls --format "{{.ID}}: {{.Repository}}"
  ```

  结果：
  75835a67d134: centos
  cae870735e91: docker4w/nsenter-dockerd

## 删除本地镜像
  docker image rm [选项] <镜像1> [<镜像2> ...]

  其中， <镜像> 可以是 镜像短 ID 、 镜像长 ID 、 镜像名 或者 镜像摘要

  example：
  ```
  docker image rm 501
  # 或者
  docker image rm centos
  ```

  结果：
  ```
  Untagged: centos:latest
  Untagged: centos@sha256:b2f9d1c0ff5f87a4743104d099a3d561002ac500db1b9bfa02a783a46e0d366c
  Deleted: sha256:0584b3d2cf6d235ee310cf14b54667d889887b838d3f3d3033acd70fc3c48b8a
  Deleted: sha256:97ca462ad9eeae25941546209454496e1d66749d53dfa2ee32bf1faabd239d38
  ```

### Untagged 和 Deleted
  上边的删除分了Untagged 和 Deleted2步，镜像的唯一标识是其 ID 和摘要，而一个镜像可以有多个标签。Untagged是删除镜像的标签，当该镜像所有的标签都被取消了，该镜像很可能会失去了存在的意义，因此会触发删除行为。镜像是多层存储结构，因此在删除的时候也是从上层向基础层方向依次进行判断删除，如果某个层其他镜像有依赖，或者某个容器有依赖（不论容器是否运行）都不会删除本层。

### 用 docker image ls 命令来配合
    ```
    docker image rm $(docker image ls -q redis)
    docker image rm $(docker image ls -q -f before=mongo:3.2)
    ```

## 使用 Dockerfile 定制镜像

### 构建镜像
  ```
  docker build -t nginx:v3 .
  ```

### RUN 执行命令
  shell 格式:
  ```
  RUN echo '<h1>Hello, Docker!</h1>' > /usr/share/nginx/html/index.html
  ```

  exec 格式: RUN ["可执行文件", "参数1", "参数2"] ，这更像是函数调用中的格式
### COPY 复制文件
  格式：COPY <源路径>... <目标路径>
  example：
  ```
  COPY package.json /usr/src/app/
  ```
  <源路径> 可以是多个，甚至可以是通配符:
  ```
  COPY hom* /mydir/
  COPY hom?.txt /mydir/
  ```
  ps:使用 COPY 指令，源文件的各种元数据都会保留。比如读、写、执行权限、文件变更时间等

### ADD 更高级的复制文件
  ADD 指令和 COPY 的格式和性质基本一致。但是在 COPY 基础上增加了一些功能.
  比如 <源路径> 可以是一个 URL,这种情况下，Docker 引擎会试图去下载这个链接的文件放到 <目标路径> 去。下载后的文件权限自动设置为 600 ，如果这并不是想要的权限，那么还需要增加额外的一层 RUN 进行权限调整，另外，如果下载的是个压缩包，需要解压缩，也一样还需要额外的一层 RUN 指令进行解压缩。所以不如直接使用 RUN 指令，然后使用 wget 或者 curl 工具下载，处理权限、解压缩、然后清理无用文件更合理。因此，这个功能其实并不实用，而且不推荐使用。

  **
  如果 <源路径> 为一个 tar 压缩文件的话，压缩格式为 gzip , bzip2 以及 xz 的情况
  下， ADD 指令将会自动解压缩这个压缩文件到 <目标路径> 去。
  **

  因此在 COPY 和 ADD 指令中选择的时候，可以遵循这样的原则，所有的文件复制均使用COPY 指令，仅在需要自动解压缩的场合使用 ADD 。

### CMD 容器启动命令
  格式:
  shell 格式： CMD <命令>
  exec 格式： CMD ["可执行文件", "参数1", "参数2"...]
  参数列表格式： CMD ["参数1", "参数2"...] 。在指定了 ENTRYPOINT 指令后，用 CMD 指定具体的参数。
  在指令格式上，一般推荐使用 exec 格式，这类格式在解析时会被解析为 JSON 数组，因此 一定要使用双引号 " ，而不要使用单引号。
  如果使用 shell 格式的话，实际的命令会被包装为 sh -c 的参数的形式进行执行。比如：
  ```
  CMD echo $HOME
  ```

  在实际执行中，会将其变更为：
  ```
  CMD [ "sh", "-c", "echo $HOME" ]
  ```

  **sh -c：**
  c string
  If the -c option is present, then commands are read from string. If there are arguments after the string, they are assigned to the positional parameters, starting with $0.
  翻译一下就是： 如果-c 选项存在，命令就从字符串中读取。如果字符串后有参数，他们将会被分配到参数的位置上，从$0开始。
  /bin/sh -c 命令
  可以用shell执行指定的命令
  这里
  /bin/sh -c ls
  会执行ls命令（列出文件）

  Docker 不是虚拟机，容器就是进程。既然是进程，那么在启动容器的时候，需要指定所运行的程序及参数。 CMD 指令就是用于指定默认的容器主进程的启动命令的。

  错误事例：
  ```
  CMD service nginx start
  ```

  CMD service nginx start 会被理解为 CMD [ "sh", "-c", "service nginxstart"] ，因此主进程实际上是 sh 。那么当 service nginx start 命令结束后， sh 也就结束了， sh 作为主进程退出了，自然就会令容器退出。

  正确的做法是直接执行 nginx 可执行文件，并且要求以前台形式运行。比如：
  ```
  CMD ["nginx", "-g", "daemon off;"]
  ```

### ENTRYPOINT 入口点
  ENTRYPOINT 的格式和 RUN 指令格式一样，分为 exec 格式和 shell 格式。
  两种格式：

    ENTRYPOINT ["executable", "param1", "param2"]
    ENTRYPOINT command param1 param2（shell中执行）。

  当指定了 ENTRYPOINT 后， CMD 的含义就发生了改变，不再是直接的运行其命令，而是将
  CMD 的内容作为参数传给 ENTRYPOINT 指令，换句话说实际执行时，将变为：
  ```
  <ENTRYPOINT> "<CMD>"
  ```
  ENTRYPOINT和CMD配置，让容器像命令一样使用：
#### example A：
  Dockerfile:
  ```
  FROM ubuntu:16.04
  RUN apt-get update \
  && apt-get install -y curl \
  && rm -rf /var/lib/apt/lists/*
  ENTRYPOINT [ "curl", "-s", "http://ip.cn" ]
  ```
  运行：
  ```
  $ docker run myip
  当前 IP：61.148.226.66 来自：北京市 联通
  $ docker run myip -i
  HTTP/1.1 200 OK
  Server: nginx/1.8.0
  Date: Tue, 22 Nov 2016 05:12:40 GMT
  Content-Type: text/html; charset=UTF-8
  Vary: Accept-Encoding
  X-Powered-By: PHP/5.6.24-1~dotdeb+7.1
  X-Cache: MISS from cache-2
  X-Cache-Lookup: MISS from cache-2:80
  X-Cache: MISS from proxy-2_6
  Transfer-Encoding: chunked
  Via: 1.1 cache-2:80, 1.1 proxy-2_6:8006
  Connection: keep-alive
  当前 IP：61.148.226.66 来自：北京市 联通
  ```
####  example B：
  启动容器之前要做一些准备工作，我们可以写一个脚本，然后ENTRYPOINT 脚本，脚本的参数就是CMD，我们可以在脚本中前边执行初始化，然后在最后执行cmd里边的命令。
  example:
  redis的镜像：
  ```
  FROM alpine:3.4
  ...
  创建redis用户
  RUN addgroup -S redis && adduser -S -G redis redis
  ...
  ENTRYPOINT ["docker-entrypoint.sh"]
  EXPOSE 6379
  #redis-server会作为docker-entrypoint.sh的参数
  CMD [ "redis-server" ]
  ```

  docker-entrypoint.sh：
  ```
  #!/bin/sh
  # allow the container to be started with `--user`
  #判断CMD的是不是redis-server，是的切换到redis用户，执行第一个参数，即，  CMD [ "redis-server" ]里边的redis-server
  if [ "$1" = 'redis-server' -a "$(id -u)" = '0' ]; then
  chown -R redis .
  exec su-exec redis "$0" "$@"
  fi
  exec "$@"
  ```

## ENV 设置环境变量
  格式有两种：
  - `ENV <key> <value>`
  - `ENV <key1>=<value1> <key2>=<value2>...`

  换行、有空格的情况，加引号：
  ```
  ENV VERSION=1.0 DEBUG=on \
  NAME="Happy Feet"
  ```

  可以使用环境变量的指令：
  ADD 、 COPY 、 ENV 、 EXPOSE 、 LABEL 、 USER 、 WORKDIR 、 VOLUME 、 STOPSIGNAL 、 ONBU、ILD 。

  ```
  ENV NODE_VERSION 7.2.0
  RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.ta  r.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs
  ```

## ARG 构建参数
  和ENV一样，差别是ARG只能在容器build的时候能用，容器启动之后是不可见的，但是依然会存在容器的历史当中(dcker history)，所以不要ARG保存密码等敏感信息。
  ARG一般用来占位，用做默认值写在Dockfile里边。但是ARG可以被--build-arg覆盖，--build-arg里边的参数，不强制要求必须要在Dockerfile里边定义。

## VOLUME 定义匿名卷
  格式为：
  - VOLUME ["<路径1>", "<路径2>"...]
  - VOLUME <路径>

  容器运行时，尽量保持容器存储层不发生写操作，对于数据库这类应用，存在动态数据，数据文件不应该写在容器的存储层，而是应该写在juan里边，
  比如VOLUME /data ，容器运行的时候，任何向/data写入的数据都不会存到容器的存储层。
  VOLUME可以被覆盖：
  ```
  docker run -d -v mydata:/data xxxx
  ```
  在这行命令中，就使用了 mydata 这个命名卷挂载到了 /data 这个位置，替代了 Dockerfile 中定义的匿名卷的挂载配置。

## EXPOSE 声明端口
  格式为 EXPOSE <端口1> [<端口2>...] 。
  EXPOSE 指令是声明运行时容器提供服务端口，这只是一个声明，在运行时并不会因为这个声明应用就会开启这个端口的服务。
  docker run -P 时，会自动随机映射 EXPOSE 的端口,要将 EXPOSE 和在运行时使用 -p <宿主端口>:<容器端口> 区分开来。 -p ，是映射宿主端口和
  容器端口，换句话说，就是将容器的对应端口服务公开给外界访问，而 EXPOSE 仅仅是声明, 容器打算使用什么端口而已，并不会自动在宿主进行端口映射。

## WORKDIR 指定工作目录
  格式为 WORKDIR <工作目录路径> 。
  WORKDIR用来指定工作目录，或者当前目录，指定之后，以后各层的工作目录  都是这个WORKDIR指定的目录，我们知道每个Dockerfile 里边的命令都是一层，层与层之间的内存执行环境是不可见的，他们的执行环境不一样，错误实例：
  ```
  RUN cd /app
  RUN echo "hello" > world.txt
  ```
  第一层  RUN cd /app只是在内存中修改一些，当执行RUN echo "hello" > world.txt时，就会找不到world.txt这个文件。第二层的时候，启动的是一个全新的容器，跟第一层的容器更完全没关
  系，自然不可能继承前一层构建过程中的内存变化。
  WORKDIR可以指定以后各层都在一个目录下工作。

## USER 指定当前用户
  格式： USER <用户名>
  USER 指令和 WORKDIR 相似，都是改变环境状态并影响以后的层。 WORKDIR 是改变工作目录， USER 则是改变之后层的执行 RUN , CMD 以及 ENTRYPOINT 这类命令的身份。
  比如我们希望执行一个命令使用另外一个已经存在的用户去执行，不要使用 su或者sudo，这写需要很麻烦的配置，我们可以使用gosu；
  example：
  ```
  # 建立 redis 用户，并使用 gosu 换另一个用户执行命令
  RUN groupadd -r redis && useradd -r -g redis redis
  # 下载 gosu
  RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64" \
  && chmod +x /usr/local/bin/gosu \
  && gosu nobody true
  # 设置 CMD，并以另外的用户执行
  CMD [ "exec", "gosu", "redis", "redis-server" ]
  USER 指定当前用户
  ```

## ONBUILD
  格式： ONBUILD <其它指令> 。
  ONBUILD 是一个特殊的指令，它后面跟的是其它指令，比如 RUN , COPY 等，而这些指令，在当前镜像构建时并不会被执行。只有当以当前镜像为基础镜像，去构建下一级镜像的时候才会被执行。
  因此我们可以使用ONBUILD用在基础镜像里边，example：
  基础镜像文件A：
  ```
  FROM node:slim
  RUN mkdir /app
  WORKDIR /app
  ONBUILD COPY ./package.json /app
  ONBUILD RUN [ "npm", "install" ]
  ONBUILD COPY . /app/
  CMD [ "npm", "start" ]
  ```
  前缀带有ONBUILD的在构建基础镜像A本身的时候，并不会执行，只有在其他 镜像from A的时候，ONBUILD的命令才会执行。
  其他镜像可以如些写法：
  ```
  FROM my-node
  ```
  只需要一行指令，就可以将当前的一个前端项目启动起来。

## 多阶段构建
  在 Docker 17.05 版本之前docker支持多阶段构建, 比如我们要在一个容器中使用go语言的一个软件，我们使用源码编译，首先需要在容器里边安装go的编译器，然后将软件拷贝到容器，执行编译，最后拿到编译结果；编译器和最终编译出来的结果都在一个容器里边，其实我们只需要的是最终的编译结果，中间的编译器是不需要在最终保留的，那么这就可是使用docker的最新的特性---多阶段编译，只需要一个dockerfile，里边可以包含多个from指令，多个 FROM 指令并不是为了生成多根的层关系，最后生成的镜像，仍以最后一条 FROM 为准，之前的 FROM 会被抛弃，那么之前的FROM 又有什么意义呢？
  每一条 FROM 指令都是一个构建阶段，多条 FROM 就是多阶段构建，虽然最后生成的镜像只能是最后一个阶段的结果，但是，能够将前置阶段中的文件拷贝到后边的阶段中，这就是多阶段构建的最大意义。
  最大的使用场景是将编译环境和运行环境分离，比如，我们需要构建一个Go语言程序，那么就需要用到go命令等编译环境，我们的Dockerfile是这样的：

  ```
    # 编译阶段
    FROM golang:1.10.3
    
    COPY server.go /build/

    WORKDIR /build

    RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOARM=6 go build -ldflags '-w -s' -o server

    # 运行阶段
     FROM scratch

    # 从编译阶段的中拷贝编译结果到当前镜像中
    COPY --from=0 /build/server /

    ENTRYPOINT ["/server"]
  ```
