---
title: Redis 在Centos7下配置开机自启动
date: 2018-10-04 15:06:58
tags: redis 启动脚本
categories: redis
---

来源：http://www.jianshu.com/p/20b761ae993c
设置Redis开机启动需要如下几个步骤：
<!-- more -->

编写配置脚本 [ vim /etc/init.d/redis ]

```
#!/bin/sh
#
# Simple Redis init.d script conceived to work on Linux systems
# as it does use of the /proc filesystem.
#chkconfig: 2345 80 90
#description:auto_run
REDISPORT=6379
EXEC=/usr/local/bin/redis/src/redis-server
CLIEXEC=/usr/local/bin/redis/src/redis-cli

PIDFILE=/var/run/redis_${REDISPORT}.pid
CONF="/usr/local/bin/redis/redis.conf"

case "$1" in
    start)
        if [ -f $PIDFILE ]
        then
                echo "$PIDFILE exists, process is already running or crashed"
        else
                echo "Starting Redis server..."
                $EXEC $CONF
        fi
        ;;
    stop)
        if [ ! -f $PIDFILE ]
        then
                echo "$PIDFILE does not exist, process is not running"
        else
                PID=$(cat $PIDFILE)
                echo "Stopping ..."
                $CLIEXEC -p $REDISPORT shutdown
                while [ -x /proc/${PID} ]
                do
                    echo "Waiting for Redis to shutdown ..."
                    sleep 1
                done
                echo "Redis stopped"
        fi
        ;;
    *)
        echo "Please use start or stop as first argument"
        ;;
esac
```

修改redis.conf,打开后台运行选项

```
# By default Redis does not run as a daemon. Use 'yes' if you need it.
# Note that Redis will write a pid file in /var/run/redis.pid when daemonized.
daemonize yes
```

修改文件执行权限

```
chmod +x /etc/init.d/redis
```

设置开机启动
# 尝试启动或停止 redis

```
service redis start
service redis stop
```

# 开启服务自启动

```
chkconfig redis on
```

5.异常处理
A. 执行 [ service redis start ] 提示服务不支持 chkconfig，在开机脚本前添加如下内容:

```
#chkconfig: 2345 80 90
#description:auto_run
```

B. 如果在Windows下编辑的开机脚本，由于Windows中的换行符为CRLF, 而Unix(或Linux)换行符为LF，会导致开机脚本执行报错,把脚本通过notepad++转化为Unix格式。

作者：_LiuWei
链接：http://www.jianshu.com/p/20b761ae993c
來源：简书
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
