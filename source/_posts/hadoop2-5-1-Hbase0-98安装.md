---
title: hadoop2.5.1+Hbase0.98安装
date: 2018-09-28 21:05:36
tags: hadoop hbase
categories: cloud
---
**一、Hadoop2.5.1编译zlib的安装与使用**

zlib是一个很好的压缩解压缩库，今天我们分别介绍如何在Linux与Windows上安装与使用：
**一：Linux平台**
首先看看自己的机器上是不是已经安装好zlib了：
whereis zlib
如果安装好了，会输出zlib的路径，这样直接跳过前2步。

*1.	下载*
在http://www.zlib.net/下载zlib的最新版，我的是1.2.3（官网貌似上不去，可以找别的地方下载）
*2.解压，编译：*
./configure
make
sudo make install
再进行配置一下系统的文件，加载刚才编译安装的zlib生成的库文件
 vi /etc/ld.so.conf.d/zlib.conf
加入如下内容后保存退出
/data/program/zlib/lib
也就是添加安装目录的文件路径，库文件。ldconfig  运行之后就会加载安装的库文件了

Openssl安装：
yum install openssl-devel

**Protobuf 安装：**
Tar –xzvf protobuf-2.5.0.tar.gz
执行：
   cd protobuf-2.5.0
   ./configure --prefix=/usr/local/protoc/
   make
   make install
**添加环境变量：**
exportPATH=.:/usr/local/protoc/bin:$PATH  
更新配置文件source /etc/profile
   验证 protoc –version    libprotoc 2.5.0
**Hadoop2.5.1编译**
 初次运行：
    $mvn package -Pdist,native -Dskiptests -Dtar   
    再次运行：
    $mvn clean package -Dmaven.test.skip=true
    $mvn package -Pdist,native -Dskiptests -Dtar
    正常编译需要等待40分钟左右
$cp hadoop-2.5.1-src/hadoop-dist/target/hadoop-2.5.1/lib/native

**二、hadoop的安装预配置**
1、Hadoop2.5.1环境变量配置（配置/etc/profile）

```
export JAVA_HOME=/usr/java/jdk1.7.0_55
export HADOOP_HOME=/usr/hadoop
export HBASE_HOME=/usr/hbase-0.94.20
export PIG_HOME=/usr/pig-0.12.0
export HIVE_HOME=/usr/hive
export SQOOP_HOME=/usr/sqoop
export MAVEN_HOME=/usr/apache-maven-3.0.5
export FINDBUGS_HOME=/usr/findbugs-3.0.0
export ANT_HOME=/usr/apache-ant-1.9.4
export PATH=.:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$JAVA_HOME/bin:$HBASE_HOME/bin:$PIG_HOME/bin:$HIVE_HOME/bin:$SQOOP_HOME:$PATH:$MAVEN_HOME/bin:/usr/local/protoc/bin:/usr/local/zlib/lib:$FINDBUGS_HOME/bin:$ANT_HOME/bin
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
export	JAVA_LIBRARY_PATH=$JAVA_LIBRARY_PATH:$HADOOP_HOME/lib/nativeexport PIG_CLASSPATH=$HADOOP_HOME/conf/
export JAVA_HOME
export PATH
export CLASSPATH

```
2、hadoop-env.sh

```
export JAVA_HOME=/usr/java/jdk1.7.0_55
#export HADOOP_HOME=/usr/hadoop
export HADOOP_PREFIX=/usr/hadoop

```
3、core-site.xml

```
<configuration>
          <property>        
            <name>fs.defaultFS</name>        
            <value>hdfs://hadoop:9000</value>   
            <description></description>   
           </property>    

	<property>
	    <name>io.file.buffer.size</name>        
            <value></value>   
        </property>              
           <property>        
            <name>hadoop.tmp.dir</name>       
            <value>/usr/hadoop/tmp</value>   
            <description>自己设置tmp，默认位置会被定期清除</description>             
           </property>
	<property>
	    <name>hadoop.native.lib</name>        
            <value>false</value>   
        </property>
</configuration>

```
4、Hdfs-site.xml

```
<configuration>
	<property>  
            <name>dfs.replication</name>    
            <value>1</value>  
            <description>dfs备份数量</description>    
         </property>
<!--
            <property>    
            <name>dfs.namenode.handler.count</name>    
            <value>100</value>    
            </property>
-->
            <property>    
            <name>dfs.namenode.name.dir</name>    
            <value>/usr/hadoop/tmp/dfs/name</value>    
            </property>

            <property>    
            <name>dfs.namenode.data.dir</name>    
            <value>/usr/hadoop/tmp/dfs/data</value>      
            </property>

            <property>    
            <name>dfs.permissions </name>    
            <value>true</value>     
<description>文件读写的权限检查 </description>  
            </property>


</configuration>

```
5、Yarn-site.xml

```
<configuration>

<!-- Site specific YARN configuration properties -->
<!--
<property>   
    <name>yarn.nodemanager.aux-services</name>   
    <value>mapreduce_shuffle</value>     
  </property>

<property>   
    <name>yarn.ac1.enable</name>   
    <value>false</value>     
  </property>

<property>   
    <name>yarn.admin.ac1</name>   
    <value>Admin ACL</value>     
  </property>

<property>   
    <name>yarn.log-aggregation-enable</name>   
    <value>false</value>     
  </property>

<property>   
    <name>yarn.log-aggregation-enable</name>   
    <value>false</value>     
  </property>
-->
  <property>   
    <name>yarn.nodemanager.aux-services</name>   
    <value>mapreduce_shuffle</value>     
  </property>         
  <property>  
    <description>The address of the applications manager interface in the RM.</description>           
    <name>yarn.resourcemanager.address</name>             
    <value>hadoop:18040</value>               
  </property>  
  <property>   
    <description>The address of the scheduler interface.</description>   
    <name>yarn.resourcemanager.scheduler.address</name>     
    <value>hadoop:18030</value>       
  </property>  
  <property>   
    <description>The address of the RM web application.</description>   
    <name>yarn.resourcemanager.webapp.address</name>     
    <value>hadoop:18088</value>       
  </property>  
  <property>   
    <description>The address of the resource tracker interface.</description>   
    <name>yarn.resourcemanager.resource-tracker.address</name>     
     <value>hadoop:8025</value>      
  </property>  
</configuration>

```
**三、Hbase 0.98搭建**

**hbase-env.sh**

```
# The java implementation to use.  Java 1.6 required.
export JAVA_HOME=/usr/java/jdk1.7.0_71

```
**hbase-site.xml**

```
<configuration>
<property>
<name>hbase.rootdir</name>
<value>hdfs://hadoopmaster:9000/hbase</value>
</property>
<property>  
  <name>hbase.cluster.distributed</name>  
  <value>true</value>  
</property>  
<property>  
  <name>hbase.master</name>  
  <value>hdfs://hadoopmaster:60000</value>  
</property>  
<property>  
  <name>hbase.tmp.dir</name>  
  <value>/home/hbase/tmp</value>  
</property>  
<property>  
  <name>hbase.zookeeper.quorum</name>  
  <value>hadoopmaster</value>  
</property>  
<property>  
  <name>hbase.zookeeper.property.clientPort</name>  
  <value>2181</value>  
</property>  
<property>  
  <name>hbase.zookeeper.property.dataDir</name>  
  <value>/home/hbase/zookeeper</value>
</property>
</configuration>

```
Conf下增加文件regionservers 加入节点名字，比如hadoopmaster。

至此，进程如下：
[root@hadoopmaster conf]# jps
5841 NodeManager
5739 ResourceManager
5386 DataNode
7482 HRegionServer
5526 SecondaryNameNode
7348 HMaster
5290 NameNode
7563 Jps
7280 HQuorumPeer
注：启动hbase的时候 hadoop的slf4j-log4j12-1.7.5.jar与hbase 的slf4j-log4j12-1.6.4.jar会发生冲突 把hbase的删除即可。
查看所有监控的ip以及端口启动情况
Netstat –tnlp
**四、部分配置与hadoop原理**
1 、启动HDFS
![这里写图片描述](20151211140929829.png)
2、日志文件结构：
![这里写图片描述](20151211140958933.png)
![这里写图片描述](20151211141028540.png)
3、Uber模式:
![这里写图片描述](20151211141128852.png)
4、Uber作业条件:
![这里写图片描述](20151211141159862.png)
5、历史服务器:
![这里写图片描述](20151211141228405.png)
6、secondary namenode
![这里写图片描述](20151211142336518.png)
7、安全模式;
	安全模式(系统升级时使用)：
	查看namenode出于那个状态
	Hadoop dfsadmin –safemode  get
	进入安全模式（hadoop启动的时候是安全模式）
	Hadoop dfsadmin –safemode enter
	离开安全模式
	Hadoop dfsadmin –safemode leave
8 、文件读取过程
![这里写图片描述](20151211142510437.png)
9、文件写入过程
![这里写图片描述](20151211142610720.png)
10、Hadoop管理员常用命令
![这里写图片描述](20151211142652408.png)
