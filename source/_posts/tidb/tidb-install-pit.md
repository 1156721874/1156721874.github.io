---
title: tidb-install-pit
date: 2019-07-25 14:05:45
tags: [tidb-install]
categories: cloud
---

<a name="df368884"></a>
### 前言

近期随着公司的业务发展，现有的mysql分库分表，无缝动态扩容，分布式事物，分布式id等等一些问题得不到满足，为此我们做了一次对tidb的考察，此文是记录tidb的安装遇到的坑进行记录,详情按照官方doc进行。

<a name="fa405f59"></a>
### 环境

集群规模：<br />node1 192.168.138.18  PD1, TiDB1   4c16G 200GHHD<br />node2 192.168.138.19  PD2, TiDB2   4c16G 200GHHD<br />node3 192.168.138.21  PD3              2c16G 200GHHD<br />node4 192.168.138.22  TiKV1           2c16G 200GHHD<br />node5 192.168.138.23  TiKV2           2c16G 200GHHD<br />node6 192.168.138.24  TiKV3           2c16G 200GHHD

当前os环境：

```
# cat /etc/redhat-release
CentOS Linux release 7.5.1804 (Core)
```

磁盘分布情况：

```
# lsblk -f
NAME            FSTYPE      LABEL UUID                                   MOUNTPOINT
sda                                                                      
├─sda1          xfs               70b07712-9842-4618-9680-a9e8f7617bf0   /boot
└─sda2          LVM2_member       etR92Z-w9Jt-Cxao-louw-Lgb2-hveD-knEFcQ
  ├─centos-root xfs               dda73e1e-afd7-4d76-9ac7-c30ed0ace8d4   /
  └─centos-swap swap              93faea67-8660-4c7d-85c1-a67ba4c4aad0   [SWAP]
sdb                                                                      
├─sdb1                                                                   
└─sdb5          ext4              055154ea-fafd-4ddf-8a8b-7d26de10f98f   /data
sr0
【sdb5是一块ext4文件系统格式的，这个是tidb要求的】
# fdisk -l

Disk /dev/sda: 107.4 GB, 107374182400 bytes, 209715200 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x000d73fc

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048      411647      204800   83  Linux
/dev/sda2          411648   209715199   104651776   8e  Linux LVM

Disk /dev/mapper/centos-root: 90.0 GB, 89980403712 bytes, 175742976 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/mapper/centos-swap: 17.2 GB, 17179869184 bytes, 33554432 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdb: 107.4 GB, 107374182400 bytes, 209715200 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x6ee43510

   Device Boot      Start         End      Blocks   Id  System
/dev/sdb1            2048   209715199   104856576    5  Extended
/dev/sdb5            4096   209715199   104855552   83  Linux
```

每台机器有2块硬盘，按照官方要求外挂的那块文件系统是ext4的。<br />然后机器需要安装git。

<a name="374d66be"></a>
### 官方安装doc

[https://pingcap.com/docs-cn/v3.0/how-to/deploy/orchestrated/ansible/](https://pingcap.com/docs-cn/v3.0/how-to/deploy/orchestrated/ansible/)

首先执行的是:

```
# yum -y install epel-release git curl sshpass
Loaded plugins: fastestmirror, langpacks
Loading mirror speeds from cached hostfile
No package epel-release available.【lib未找到】
Package git-1.8.3.1-13.el7.x86_64 already installed and latest version
Package curl-7.29.0-46.el7.x86_64 already installed and latest version
No package sshpass available.【lib未找到】
Nothing to do
```

<a name="34916830"></a>
#### [坑]No package epel-release available

根据[epel-repo-centos-7](https://www.shellhacks.com/epel-repo-centos-7-6-install/)指南需要执行:

```
# rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
```

然后在执行[yum -y install epel-release git curl sshpass]才会成功.

<a name="129fc895"></a>
#### [坑]提前配置Grafana Dashboard 上的 Report 按钮可用来生成 PDF 文件

在Grafana部署的机器上执行:

```
sudo yum install fontconfig open-sans-fonts
```

<a name="5c9f0649"></a>
#### [坑]PD 和 TiDB 同时部署的机器要求要有8个cpu core

异常如下：<br />[192.168.138.18]: Ansible FAILED! => playbook: bootstrap.yml; TASK: check_system_optional : Preflight check - Check TiDB server's CPU; message: {"changed": false, "msg": "This machine does not have sufficient CPU to run TiDB, at least 8 cores."}

[192.168.138.19]: Ansible FAILED! => playbook: bootstrap.yml; TASK: check_system_optional : Preflight check - Check TiDB server's CPU; message: {"changed": false, "msg": "This machine does not have sufficient CPU to run TiDB, at least 8 cores."}<br />解决方式：

- 找运维增加虚拟机的cpu core数量
- 修改参数：vi roles/check_system_optional/defaults/main.yml

```
tidb_min_cpu: 2
tikv_min_cpu: 2
pd_min_cpu: 2
monitor_min_cpu: 2
```

其他的内存和硬盘的检查参数也在这个文件配置。

- 参考： [https://github.com/pingcap/tidb/issues/6423](https://github.com/pingcap/tidb/issues/6423)

<a name="e1df35e7"></a>
#### [坑]磁盘检查异常

异常信息：<br />[192.168.138.22]: Ansible FAILED! => playbook: bootstrap.yml; TASK: machine_benchmark : Preflight check - Does fio randread iops of tikv_data_dir disk meet requirement; message: {"changed": false, "msg": "fio: randread iops of tikv_data_dir disk is too low: 7748 < 40000, it is strongly recommended to use SSD disks for TiKV and PD, or there might be performance issues."}

[192.168.138.23]: Ansible FAILED! => playbook: bootstrap.yml; TASK: machine_benchmark : Preflight check - Does fio randread iops of tikv_data_dir disk meet requirement; message: {"changed": false, "msg": "fio: randread iops of tikv_data_dir disk is too low: 3128 < 40000, it is strongly recommended to use SSD disks for TiKV and PD, or there might be performance issues."}

[192.168.138.24]: Ansible FAILED! => playbook: bootstrap.yml; TASK: machine_benchmark : Preflight check - Does fio randread iops of tikv_data_dir disk meet requirement; message: {"changed": false, "msg": "fio: randread iops of tikv_data_dir disk is too low: 8847 < 40000, it is strongly recommended to use SSD disks for TiKV and PD, or there might be performance issues."}

解决方式：

```
# vi roles/machine_benchmark/defaults/main.yml
```

修改min_ssd_randread_iops的大小。

<a name="244e1822"></a>
#### 跳过cpu、mem、disk检查

有些企业由于成本问题，在开发测试环境都是HHD，没法满足tidb的硬件要求，因此我们可以使用开发模式，跳过cpu、内存、硬盘的检查。

```
# ansible-playbook bootstrap.yml --extra-vars "dev_mode=True"
```

<a name="f023e41c"></a>
#### [注意事项]TiDB的binlog开启
/home/tidb/tidb-ansible/inventory.ini配置如果【enable_binlog = True 】
意味着需要配置[TiDB-Binlog](https://github.com/pingcap/docs-cn/blob/master/v3.0/how-to/deploy/tidb-binlog.md),当前集群按照[官方doc](https://pingcap.com/docs-cn/v3.0/how-to/deploy/tidb-binlog/)搭建了zk和kafka集群，然后部署了pump（抓取tidb的binlog塞到kafka集群）。

<a name="f20fc258"></a>
#### [坑]启动之后grafana进程没有

切换到部署目录/data/deploy/scripts<br />手动执行: ./start_grafana.sh

<a name="bcf29c71"></a>
#### tidb在navicat下修改表结构问题

tidb在navicat下修改表结构一次性不允许修改(添加或者修改)多个列，否则报错：<br />![mutil-schema-error.png](https://cdn.nlark.com/yuque/0/2019/png/186520/1564467485930-4cbeac67-1485-488b-850a-d4744af936dc.png#align=left&display=inline&height=746&name=mutil-schema-error.png&originHeight=746&originWidth=1366&size=74707&status=done&width=1366)

<a name="bb1c734e"></a>
### 登陆

- 使用mysql客户端登陆
  - 使用tidb(密码：tidb)登陆开发机，注意：必须是tidb用户。
    - mysql -u root -proot  -h 192.168.138.18 -P 4000
    - mysql -u tnp_test -ptnp_test  -h 192.168.138.18 -P 4000
    - PS:192.168.138.19 和 192.168.138.18都可以链接

<a name="1346328c"></a>
### 修改集群配置之后重启步骤/集群启动/集群关闭

- 配置<br />
对【/home/tidb/tidb-ansible/inventory.ini】进行修改后需要执行：
```
# ansible-playbook deploy.yml
```

- 目的是把配置下放到所有的机器。
- 启动集群<br />
ansible-playbook start.yml
- 关闭集群<br />
ansible-playbook stop.yml
| 启动集群 | ansible-playbook start.yml |
| --- | --- |
| 停止集群 | ansible-playbook stop.yml |
| 销毁集群 | ansible-playbook unsafe_cleanup.yml (若部署目录为挂载点，会报错，可忽略） |
| 清除数据(测试用) | ansible-playbook cleanup_data.yml |
| 滚动升级 | ansible-playbook rolling_update.yml |
| 滚动升级 TiKV | ansible-playbook rolling_update.yml –tags=tikv |
| 滚动升级除 PD 外模块 | ansible-playbook rolling_update.yml –skip-tags=pd |
| 滚动升级监控组件 | ansible-playbook rolling_update_monitor.yml |


<a name="5fca6be2"></a>
### Prometheus访问地址

[http://192.168.138.18:9090/graph](http://192.168.138.18:9090/graph)

<a name="d3a39edf"></a>
### Pushgateway访问地址

[http://192.168.138.18:9091/](http://192.168.138.18:9091/)

<a name="26614728"></a>
### Node_exporter访问地址

[http://192.168.138.18:9100/](http://192.168.138.18:9100/)

<a name="ea8acfdf"></a>
### grafana访问地址
[http://192.168.138.18:3000](http://192.168.138.18:3000)<br />用户名/密码:admin/admin<br />![image.png](https://cdn.nlark.com/yuque/0/2019/png/186520/1564561812914-82ca10bb-9686-417e-af46-276341021cd9.png#align=left&display=inline&height=633&name=image.png&originHeight=633&originWidth=1360&size=88976&status=done&width=1360)<br />指标解释：[https://github.com/pingcap/docs-cn/blob/master/dev/reference/key-monitoring-metrics/tidb-dashboard.md](https://github.com/pingcap/docs-cn/blob/master/dev/reference/key-monitoring-metrics/tidb-dashboard.md)

<a name="5f2e4fbc"></a>
### 定位慢查询

```
select `Query_time`, query from INFORMATION_SCHEMA.`SLOW_QUERY` where `Is_internal`=false order by `Query_time` desc limit 2;
```

官方doc：[https://pingcap.com/docs-cn/v3.0/how-to/maintain/identify-slow-queries/](https://pingcap.com/docs-cn/v3.0/how-to/maintain/identify-slow-queries/)

<a name="531e2324"></a>
### 扩容缩容

[https://pingcap.com/docs-cn/v3.0/how-to/scale/with-ansible/](https://pingcap.com/docs-cn/v3.0/how-to/scale/with-ansible/)


<a name="888fb2f9"></a>
### 与 MySQL 安全特性差异

仅支持 mysql_native_password 身份验证方案。<br />不支持外部身份验证方式（如 LDAP）。<br />不支持列级别权限设置。<br />不支持使用证书验证身份。#9708<br />不支持密码过期，最后一次密码变更记录以及密码生存期。#9709<br />不支持权限属性 max_questions，max_updated，max_connections 以及 max_user_connections。<br />不支持密码验证。#9741<br />不支持透明数据加密（TDE）。

<a name="DOG0X"></a>
### 对mysql的支持
TiDB 目前还不支持触发器、存储过程、自定义函数、外键，除此之外，TiDB 支持绝大部分 MySQL 5.7 的语法。

- 支持分布式事物
- TiDB 字符集默认就是 UTF8 而且目前只支持 UTF8，字符串就是 memcomparable 格式的。
- 自增id只保证自增和唯一，不保证顺序性(段式分配导致)。

<br />

<a name="gCrcg"></a>
### 事物
<a name="qA8ds"></a>
#### 事物隔离级别Snapshot Isolation
tidb只支持Snapshot Isolation事物隔离级别，TiDB 实现了快照隔离 (Snapshot Isolation) 级别的一致性。为与 MySQL 保持一致，又称其为“可重复读”。MySQL 可重复读隔离级别的一致性要弱于 Snapshot 隔离级别，也弱于 TiDB 的可重复读隔离级别。<br />另外多线程操作同一行数据，一定会有一个失败，失败的事物默认不会重试，而是以异常的形式抛出，是否重试交给应用来判断，但是也可以开启自动重试，只不过开启之后，重试事务可能会导致更新丢失，因为 TiDB 自动重试机制会把事务第一次执行的所有语句重新执行一遍，当一个事务里的后续语句是否执行取决于前面语句执行结果的时候，自动重试会违反快照隔离，导致更新丢失。<br />doc：[https://pingcap.com/docs-cn/v3.0/reference/transactions/transaction-isolation/](https://pingcap.com/docs-cn/v3.0/reference/transactions/transaction-isolation/)

<a name="MII0H"></a>
#### 乐观锁

- 数据操作冲突比较验证不适，会产生大量的重试，如果访问冲突并不十分严重，那么乐观锁模型具备较高的效率。
- 在冲突严重的场景下，推荐在系统架构层面解决问题，比如将计数器放在 Redis 中。

<a name="Z2FSN"></a>
#### 事务大小限制

- 单个事务包含的 SQL 语句不超过 5000 条（默认）
- 单条 KV entry 不超过 6MB
- KV entry 的总条数不超过 30W
- KV entry 的总大小不超过 100MB

建议无论是 Insert，Update 还是 Delete 语句，都通过分 Batch 或者是加 Limit 的方式限制。<br />具体罗亿乔之前的sql技术分享。

<a name="NTzxl"></a>
#### 支持悲观锁，但是官方不建议生产环境使用，因为在官方将其定义为实验性的特性

- 不支持 GAP Lock 和 Next Key Lock 在悲观事务内通过范围条件来更新多行数据的时候，其他的事务可以在这个范围内插入数据而不会被阻塞。<br />
- 不支持 SELECT LOCK IN SHARE MODE。

<a name="IPbGO"></a>
#### 事物限制

- 小事物比单机mysql性能要低，以为有网络参与，用显式事务代替 `auto_commit`，可优化该性能。
- 事物惰性检查，执行insert语句，不在 `INSERT` 语句执行时进行唯一约束的检查，而在事务提交时进行唯一约束的检查。
```
CREATE TABLE T (I INT KEY);
INSERT INTO T VALUES (1);
BEGIN;
INSERT INTO T VALUES (1); -- MySQL 返回错误；TiDB 返回成功
INSERT INTO T VALUES (2);
COMMIT; -- MySQL 提交成功；TiDB 返回错误，事务回滚
SELECT * FROM T; -- MySQL 返回 1 2；TiDB 返回 1
```

这样做的目的是为了减少网络开销。

<a name="UX5Mw"></a>
#### 小结
总的来说事物这方面的最贱实践是：乐观锁+事物失败应用级别处理+分布式锁加强，不建议开启事物失败重试机制（除非事物之间没有任何关系）。事物结束之后(commit之后)要判断返回值是否成功.

<a name="BuZyL"></a>
### 存在数据热点问题
相同的表数据会优先聚集到TiKV节点，如果某个表的数据比较热，那么TiKV很有可能成为系统的瓶颈，尤其是在很小范围的数据频繁操作，某个region会成为系统的热点。<br />[https://pingcap.com/blog-cn/tidb-best-practice/](https://pingcap.com/blog-cn/tidb-best-practice/)<br />解决之道（通过设置 `SHARD_ROW_ID_BITS` 来适度分解 Region 分片）：[https://pingcap.com/docs-cn/v3.0/reference/configuration/tidb-server/tidb-specific-variables/#shard-row-id-bits](https://pingcap.com/docs-cn/v3.0/reference/configuration/tidb-server/tidb-specific-variables/#shard-row-id-bits)<br />热点问题官方FAQ：https://asktug.com/t/tidb/358

<a name="IOKxo"></a>
### GC 垃圾回收
tidb使用MVCC关林数据的版本，老版本的数据通过垃圾收集器进行删除，时间默认是10分钟执行一次回收，回收线程和频率可以在系统表设置。

<a name="KKFlJ"></a>
###  TiDB 的最佳适用场景

- 数据量大，单机保存不下
- 不希望做 Sharding 或者懒得做 Sharding
- 访问模式上没有明显的热点
- 需要事务、需要强一致、需要灾备

<a name="mlgPE"></a>
### 在单台tidb做sybench

参考官方doc:[https://pingcap.com/docs-cn/v3.0/benchmark/how-to-run-sysbench/](https://pingcap.com/docs-cn/v3.0/benchmark/how-to-run-sysbench/)

<a name="0f4b6559"></a>
#### [坑]导入数据耗时较长，导入数据的命令要使用nohu执行

官方doc导入数据的命令会执行很长一段时间，当xshell超时的时候，我们没法监控命令的执行日志，因此要使用nohup：

```
nohup sysbench --config-file=config oltp_point_select --tables=32 --table-size=1000000 prepare 2>&1 &
nohup sysbench --config-file=config oltp_point_select --tables=32 --table-size=1000000 run 2>&1 &
nohup sysbench --config-file=config oltp_update_index --tables=32 --table-size=1000000 run 2>&1 &
```



- 样本数据
  - 32张表、每张表100万条数据，每张表大约1M数据。
- 集群规模

node1 192.168.138.18  PD1, TiDB1   4c16G 200GHHD<br />node2 192.168.138.19  PD2, TiDB2   4c16G 200GHHD<br />node3 192.168.138.21  PD3              2c16G 200GHHD<br />node4 192.168.138.22  TiKV1           2c16G 200GHHD<br />node5 192.168.138.23  TiKV2           2c16G 200GHHD<br />node6 192.168.138.24  TiKV3           2c16G 200GHHD<br /> <br />sysbench所有测试结果详情在[192.168.138.18]: vi /home/tidb/tidb-bench/nohup.out
<a name="oltp-point-select"></a>
###
<a name="FMg4L"></a>
#### oltp_point_select

- nohup sysbench --config-file=config oltp_point_select --tables=32 --table-size=1000000 prepare 2>&1 &

| threads | read | write | tps | qps | total time | min | avg | max | 95th |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | 5937332 | 0 | 5937332 (9895.26 per sec.) | 5937332 (9895.26 per sec.) | 600.0156s | 0.40 | 0.81 | 223.17 | 1.03 |
| 16 | 9396775 | 0 | 9396775 (15660.86 per sec.) | 9396775 (15660.86 per sec.) | 600.0148 | 0.39 | 1.02 | 177.08 | 1.52 |
| 32 | 12217819 | 0 | 12217819 (20362.72 per sec.) | 12217819 (20362.72 per sec.) | 600.0075s | 0.39 | 1.57 | 119.33 | 3.75 |
| 64 | 13085444 | 0 | 13085444 (21808.49 per sec.) | 13085444 (21808.49 per sec.) | 600.0142s | 0.41 | 2.93 | 270.10 | 8.43 |
| 128 | 13680931 | 0 | 13680931 (22800.08 per sec.) | 13680931 (22800.08 per sec.) | 600.0370s | 0.43 | 5.61 | 1033.14 | 13.70 |

![oltp_point_select.png](https://cdn.nlark.com/yuque/0/2019/png/186520/1564482895735-883dcc49-2e4a-422b-be32-bd7ffa706d08.png#align=left&display=inline&height=400&name=oltp_point_select.png&originHeight=400&originWidth=1312&size=33302&status=done&width=1312)

95th :[https://www.zhihu.com/question/20575291](https://www.zhihu.com/question/20575291)


<a name="tHki6"></a>
#### oltp_update_index

- nohup sysbench --config-file=config oltp_update_index --tables=32 --table-size=10000000 run 2>&1 &

| threads | read | write | tps | qps | total time | min | avg | max | 95th |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | 0 | 149902 | 149902 (249.82 per sec.) | 149902 (249.82 per sec.) | 600.0418s | 10.26 | 32.02 | 475.79 | 46.63 |
| 16 | 0 | 213850 | 213850 (356.39 per sec.) | 213850 (356.39 per sec.) | 600.0444s | 9.30 | 44.89 | 659.85 | 142.39 |
| 32 | 0 | 483912 | 483912 (806.47 per sec.) | 483912 (806.47 per sec.) | 600.0370s | 10.34 | 39.68 | 689.26 | 54.83 |
| 64 | 0 | 880168 | 880168 (1466.72 per sec.) | 880168 (1466.72 per sec.) | 600.0897s | 10.60 | 43.63 | 1109.14 | 58.92 |
| 128 | 0 | 1344814 | 1344814 (2241.17 per sec.) | 1344814 (2241.17 per sec.) | 600.0473s | 9.90 | 57.11 | 8177.34 | 75.82 |
| 256 | 0 | 1882603 | 1882603 (3137.16 per sec.) | 1882603 (3137.16 per sec.) | 600.0950s | 11.88 | 81.59 | 1418.85 | 211.60 |

![oltp_update_index.png](https://cdn.nlark.com/yuque/0/2019/png/186520/1564483495647-455b41ad-0547-47dd-aa64-439eba7858e7.png#align=left&display=inline&height=400&name=oltp_update_index.png&originHeight=400&originWidth=1312&size=35286&status=done&width=1312)
<a name="c1OR4"></a>
#### oltp_read_only

- nohup sysbench --config-file=config oltp_read_only --tables=32 --table-size=10000000 run 2>&1 &

| threads | total | tps | qps | total time | min | avg | max | 95th |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | 6204464 | 387779 (646.28 per sec.) | 6204464 (10340.44 per sec.) | 600.0174s | 8.88 | 12.38 | 427.50 | 16.41 |
| 16 | 9270576 | 579411 (965.65 per sec.) | 9270576 (15450.37 per sec.) | 600.0211s | 10.03 | 16.57 | 1203.28 | 26.20 |
| 32 | 11644768 | 727798 (1212.92 per sec.) | 11644768 (19406.73 per sec.) |  600.0359s | 9.18 | 26.38 | 1132.08 | 46.63 |
| 64 | 12632864 | 789554 (1315.79 per sec.) | 12632864 (21052.63 per sec.) | 600.0590s | 11.66 | 48.63 | 423.32 | 84.47 |
| 128 | 12792912 | 799557 (1332.37 per sec.) | 12792912 (21317.86 per sec.) | 600.1013s | 10.65 | 96.06 | 3153.57 | 150.29 |

![oltp_read_only.png](https://cdn.nlark.com/yuque/0/2019/png/186520/1564487404538-aa194ea1-8f25-411f-adc8-a92502c2a8e0.png#align=left&display=inline&height=400&name=oltp_read_only.png&originHeight=400&originWidth=1312&size=34084&status=done&width=1312)
<a name="fqVte"></a>
#
<a name="xBFtr"></a>
###  TPC-C测试
[https://pingcap.com/docs-cn/v3.0/benchmark/how-to-run-tpcc/](https://pingcap.com/docs-cn/v3.0/benchmark/how-to-run-tpcc/)<br />TPC-C 是一个对 OLTP（联机交易处理）系统进行测试的规范，使用一个商品销售模型对 OLTP 系统进行测试。<br />TPC-C 使用 tpmC 值（Transactions per Minute）来衡量系统最大有效吞吐量 (MQTh, Max Qualified Throughput)，其中 Transactions 以 NewOrder Transaction 为准，即最终衡量单位为每分钟处理的新订单数。

<a name="feB7I"></a>
#### BenchmarkSQL 配置
修改 `benchmarksql/run/props.mysql`

```
conn=jdbc:mysql://{HAPROXY-HOST}:{HAPROXY-PORT}/tpcc?useSSL=false&useServerPrepStmts=true&useConfigs=maxPerformance
warehouses=1000 # 使用 1000 个 warehouse
terminals=500   # 使用 500 个终端
loadWorkers=32  # 导入数据的并发数
```
<a name="3blds"></a>
#### 初始化数据库
```
create database tpcc
```

之后在 shell 中运行 BenchmarkSQL 建表脚本：
```
cd run
nohup  ./runSQL.sh props.mysql sql.mysql/tableCreates.sql  2>&1 &
nohup ./runSQL.sh props.mysql sql.mysql/indexCreates.sql 2>&1 &
```

运行导入数据脚本：
```
nohup ./runLoader.sh props.mysql 2>&1 &
```
这个过程时间会有点长。<br />验证导入的数据：

```
nohup  ./runSQL.sh props.mysql  sql.common/test.sql 2>&1 &
```

<a name="lc6vK"></a>
#### 运行测试

```
nohup ./runBenchmark.sh props.mysql &> test.log 2>&1 &

```

<a name="waCKQ"></a>
#### 测试结果
[192.168.138.18]  vi /home/tidb/benchmarksql/run/test.log

![tpc-c-result.png](https://cdn.nlark.com/yuque/0/2019/png/186520/1564626255512-417c0a26-cd7a-4af9-a6c3-ae48919b56c8.png#align=left&display=inline&height=92&name=tpc-c-result.png&originHeight=92&originWidth=659&size=9234&status=done&width=659)

系统每分钟的吞吐量是在4399.16(官方机器配置结果是：77373.25)，即集群每分钟能承载的订单数量是4399个订单。

<a name="FUbxC"></a>
### 其他企业在tidb的实践与分享
[https://github.com/pingcap/presentations](https://github.com/pingcap/presentations)
