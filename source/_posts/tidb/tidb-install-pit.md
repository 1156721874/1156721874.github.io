---
title: tidb-install-pit
date: 2019-07-25 14:05:45
tags: [tidb-install]
categories: cloud
---

### 前言
近期随着公司的业务发展，现有的mysql分库分表，无缝动态扩容，分布式事物，分布式id等等一些问题得不到满足，为此我们做了一次对tidb的考察，此文是记录tidb的安装遇到的坑进行记录,详情按照官方doc进行。

### 环境

集群规模：
node1 192.168.138.18  PD1, TiDB1
node2 192.168.138.19  PD2, TiDB2
node3 192.168.138.21  PD3
node4 192.168.138.22  TiKV1
node5 192.168.138.23  TiKV2
node6 192.168.138.24  TiKV3

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
每台机器有2块硬盘，按照官方要求外挂的那块文件系统是ext4的。
需要安装git。

### 官方安装doc
https://pingcap.com/docs-cn/v3.0/how-to/deploy/orchestrated/ansible/

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
#### [坑]No package epel-release available
根据[epel-repo-centos-7](https://www.shellhacks.com/epel-repo-centos-7-6-install/)指南需要执行:
```
# rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
```
然后在执行[yum -y install epel-release git curl sshpass]才会成功.

#### [坑]提前配置Grafana Dashboard 上的 Report 按钮可用来生成 PDF 文件
在Grafana部署的机器上执行:
```
sudo yum install fontconfig open-sans-fonts
```

#### [坑]PD 和 TiDB 同时部署的机器要求要有8个cpu core
异常如下：
[192.168.138.18]: Ansible FAILED! => playbook: bootstrap.yml; TASK: check_system_optional : Preflight check - Check TiDB server's CPU; message: {"changed": false, "msg": "This machine does not have sufficient CPU to run TiDB, at least 8 cores."}

[192.168.138.19]: Ansible FAILED! => playbook: bootstrap.yml; TASK: check_system_optional : Preflight check - Check TiDB server's CPU; message: {"changed": false, "msg": "This machine does not have sufficient CPU to run TiDB, at least 8 cores."}
解决方式：
- 找运维增加虚拟机的cpu core数量
- 修改参数：vi roles/check_system_optional/defaults/main.yml
```
tidb_min_cpu: 2
tikv_min_cpu: 2
pd_min_cpu: 2
monitor_min_cpu: 2
```
其他的内存和硬盘的检查参数也在这个文件配置。
- 参考： https://github.com/pingcap/tidb/issues/6423

#### [坑]磁盘检查异常
异常信息：
[192.168.138.22]: Ansible FAILED! => playbook: bootstrap.yml; TASK: machine_benchmark : Preflight check - Does fio randread iops of tikv_data_dir disk meet requirement; message: {"changed": false, "msg": "fio: randread iops of tikv_data_dir disk is too low: 7748 < 40000, it is strongly recommended to use SSD disks for TiKV and PD, or there might be performance issues."}

[192.168.138.23]: Ansible FAILED! => playbook: bootstrap.yml; TASK: machine_benchmark : Preflight check - Does fio randread iops of tikv_data_dir disk meet requirement; message: {"changed": false, "msg": "fio: randread iops of tikv_data_dir disk is too low: 3128 < 40000, it is strongly recommended to use SSD disks for TiKV and PD, or there might be performance issues."}

[192.168.138.24]: Ansible FAILED! => playbook: bootstrap.yml; TASK: machine_benchmark : Preflight check - Does fio randread iops of tikv_data_dir disk meet requirement; message: {"changed": false, "msg": "fio: randread iops of tikv_data_dir disk is too low: 8847 < 40000, it is strongly recommended to use SSD disks for TiKV and PD, or there might be performance issues."}

解决方式：
```
# vi roles/machine_benchmark/defaults/main.yml
```
修改min_ssd_randread_iops的大小。

#### 跳过cpu、mem、disk检查
有些企业由于成本问题，在开发测试环境都是HHD，没法满足tidb的硬件要求，因此我们可以使用开发模式，跳过cpu、内存、硬盘的检查。
```
# ansible-playbook bootstrap.yml --extra-vars "dev_mode=True"
```

#### [注意事项]TiDB的binlog开启
/home/tidb/tidb-ansible/inventory.ini配置如果【enable_binlog = False 】
意味着需要配置[TiDB-Binlog](https://github.com/pingcap/docs-cn/blob/master/v3.0/how-to/deploy/tidb-binlog.md),当前我们配置的集群没有开启binlog。

#### [坑]启动之后grafana进程没有
切换到部署目录/data/deploy/scripts
手动执行: ./start_grafana.sh


### 登陆
- 使用mysql客户端登陆
  - 使用tidb(密码：tidb)登陆开发机，注意：必须是tidb用户。
    - mysql -u root -proot  -h 192.168.138.18 -P 4000

### 修改集群配置之后重启步骤/集群启动/集群关闭
- 配置
  对【/home/tidb/tidb-ansible/inventory.ini】进行修改后需要执行：
  ```
  # ansible-playbook deploy.yml
  ```
  目的是把配置下放到所有的机器。
- 启动集群
  ansible-playbook start.yml
- 关闭集群
  ansible-playbook stop.yml

### Prometheus访问地址
http://192.168.138.18:9090/graph

### Pushgateway访问地址
http://192.168.138.18:9091/

### Node_exporter访问地址
http://192.168.138.18:9100/  

### grafana访问地址
http://192.168.138.18:3000
用户名/密码:admin/admin
