---
title: 4-docker-数据卷
date: 2018-11-24 16:21:55
tags: [volume,数据卷,挂载主机目录]
categories: docker
---

## 数据卷
  数据卷 是一个可供一个或多个容器使用的特殊目录，它绕过 UFS，可以提供很多有用的特性：
  - 数据卷可以在容器之间共享和重用
  - 对数据卷 的修改会立马生效
  - 对数据卷 的更新，不会影响镜像
  - 数据卷 默认会一直存在，即使容器被删除

### 创建一个数据卷

  ```
  >docker  volume create volume-1
  volume-1

  >docker volume ls
  DRIVER              VOLUME NAME
  local               volume-1
  #查看数据卷的具体信息
  >docker volume inspect volume-1
  [
    {
        "CreatedAt": "2018-11-24T08:25:17Z",
        "Driver": "local",
        "Labels": {},
        "Mountpoint": "/var/lib/docker/volumes/volume-1/_data",
        "Name": "volume-1",
        "Options": {},
        "Scope": "local"
    }
  ]
  ```
### 启动一个挂载数据卷的容器
  docker run 命令的时候，使用 --mount 标记来将 数据卷 挂载到容器里。在一次docker run 中可以挂载多个 数据卷 。
  ```
  >docker run -dit --name myjdk8 --mount source=volume-1,target=/webapp jdk8:v1
  ```

### 查看容器当中数据卷的具体信息
  ```
  >docker inspect myjdk8
  [
    {
        "Id": "c9c346fdf8dcb7d4923d7f07b369e2f07779c14913f42a07b3b9f0accb73dac9",
        "Created": "2018-11-24T08:28:50.9454735Z",
        "Path": "/bin/bash",
        "Args": [],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 3941,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2018-11-24T08:28:53.3865482Z",
            "FinishedAt": "0001-01-01T00:00:00Z"
        },
        "Image": "sha256:a70ba00548f32c4d0152cb12e9aafdc419fc5bbb14744780bdfffb11f074ec03",
        "ResolvConfPath": "/var/lib/docker/containers/c9c346fdf8dcb7d4923d7f07b369e2f07779c14913f42a07b3b9f0accb73dac9/resolv.conf",
        "HostnamePath": "/var/lib/docker/containers/c9c346fdf8dcb7d4923d7f07b369e2f07779c14913f42a07b3b9f0accb73dac9/hostname",
        "HostsPath": "/var/lib/docker/containers/c9c346fdf8dcb7d4923d7f07b369e2f07779c14913f42a07b3b9f0accb73dac9/hosts",
        "LogPath": "/var/lib/docker/containers/c9c346fdf8dcb7d4923d7f07b369e2f07779c14913f42a07b3b9f0accb73dac9/c9c346fdf8dcb7d4923d7f07b369e2f07779c14913f42a07b3b9f0accb73dac9-json.log",
        "Name": "/myjdk8",
        "RestartCount": 0,
        "Driver": "overlay2",
        "Platform": "linux",
        "MountLabel": "",
        "ProcessLabel": "",
        "AppArmorProfile": "",
        "ExecIDs": null,
        "HostConfig": {
            "Binds": null,
            "ContainerIDFile": "",
            "LogConfig": {
                "Type": "json-file",
                "Config": {}
            },
            "NetworkMode": "default",
            "PortBindings": {},
            "RestartPolicy": {
                "Name": "no",
                "MaximumRetryCount": 0
            },
            "AutoRemove": false,
            "VolumeDriver": "",
            "VolumesFrom": null,
            "CapAdd": null,
            "CapDrop": null,
            "Dns": [],
            "DnsOptions": [],
            "DnsSearch": [],
            "ExtraHosts": null,
            "GroupAdd": null,
            "IpcMode": "shareable",
            "Cgroup": "",
            "Links": null,
            "OomScoreAdj": 0,
            "PidMode": "",
            "Privileged": false,
            "PublishAllPorts": false,
            "ReadonlyRootfs": false,
            "SecurityOpt": null,
            "UTSMode": "",
            "UsernsMode": "",
            "ShmSize": 67108864,
            "Runtime": "runc",
            "ConsoleSize": [
                50,
                189
            ],
            "Isolation": "",
            "CpuShares": 0,
            "Memory": 0,
            "NanoCpus": 0,
            "CgroupParent": "",
            "BlkioWeight": 0,
            "BlkioWeightDevice": [],
            "BlkioDeviceReadBps": null,
            "BlkioDeviceWriteBps": null,
            "BlkioDeviceReadIOps": null,
            "BlkioDeviceWriteIOps": null,
            "CpuPeriod": 0,
            "CpuQuota": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "CpusetCpus": "",
            "CpusetMems": "",
            "Devices": [],
            "DeviceCgroupRules": null,
            "DiskQuota": 0,
            "KernelMemory": 0,
            "MemoryReservation": 0,
            "MemorySwap": 0,
            "MemorySwappiness": null,
            "OomKillDisable": false,
            "PidsLimit": 0,
            "Ulimits": null,
            "CpuCount": 0,
            "CpuPercent": 0,
            "IOMaximumIOps": 0,
            "IOMaximumBandwidth": 0,
            "Mounts": [
                {
                    "Type": "volume",
                    "Source": "volume-1",
                    "Target": "/webapp"
                }
            ],
            "MaskedPaths": [
                "/proc/acpi",
                "/proc/kcore",
                "/proc/keys",
                "/proc/latency_stats",
                "/proc/timer_list",
                "/proc/timer_stats",
                "/proc/sched_debug",
                "/proc/scsi",
                "/sys/firmware"
            ],
            "ReadonlyPaths": [
                "/proc/asound",
                "/proc/bus",
                "/proc/fs",
                "/proc/irq",
                "/proc/sys",
                "/proc/sysrq-trigger"
            ]
        },
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/49a437db0a547c82e213cb31090398d94d64ad11b1dfa7112f1e5f64897fca00-init/diff:/var/lib/docker/overlay2/2796cd7903fb6c509b276acb83505d05b1d685e010dc32557fe6baa06160e0a3/diff:/var/lib/docker/overlay2/15b4eabde2002d7fa67849c36b175b93827b911465b6cc8021e47f467ec2cca3/diff:/var/lib/docker/overlay2/9a004f009ec50069f1f7a8985bf40a256eda15b48402ccbefb6831ae52d2bbb8/diff:/var/lib/docker/overlay2/1d31c352fff2c856f6f208be8c9448ecc30447edcfacb10fd73e4d62ebef989d/diff",
                "MergedDir": "/var/lib/docker/overlay2/49a437db0a547c82e213cb31090398d94d64ad11b1dfa7112f1e5f64897fca00/merged",
                "UpperDir": "/var/lib/docker/overlay2/49a437db0a547c82e213cb31090398d94d64ad11b1dfa7112f1e5f64897fca00/diff",
                "WorkDir": "/var/lib/docker/overlay2/49a437db0a547c82e213cb31090398d94d64ad11b1dfa7112f1e5f64897fca00/work"
            },
            "Name": "overlay2"
        },
        "Mounts": [
            {
                "Type": "volume",
                "Name": "volume-1",
                "Source": "/var/lib/docker/volumes/volume-1/_data",
                "Destination": "/webapp",
                "Driver": "local",
                "Mode": "z",
                "RW": true,
                "Propagation": ""
            }
        ],
        "Config": {
            "Hostname": "c9c346fdf8dc",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": true,
            "OpenStdin": true,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/bin:/bin",
                "JAVA_HOME=/usr/local/jdk1.8.0_151",
                "MAVEN_HOME=/usr/local/apache-maven-3.6.0",
                "MAVEN_CONFIG=/root/.m2",
                "CLASSPATH=/lib/dt.jar:/lib/tools.jar"
            ],
            "Cmd": [
                "/bin/bash"
            ],
            "ArgsEscaped": true,
            "Image": "jdk8:v1",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": {
                "org.label-schema.build-date": "20181006",
                "org.label-schema.license": "GPLv2",
                "org.label-schema.name": "CentOS Base Image",
                "org.label-schema.schema-version": "1.0",
                "org.label-schema.vendor": "CentOS"
            }
        },
        "NetworkSettings": {
            "Bridge": "",
            "SandboxID": "05a4601c60f48b659a4f5652223ce66518fda32ea775ee03af43bac25d2c2a6b",
            "HairpinMode": false,
            "LinkLocalIPv6Address": "",
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": {},
            "SandboxKey": "/var/run/docker/netns/05a4601c60f4",
            "SecondaryIPAddresses": null,
            "SecondaryIPv6Addresses": null,
            "EndpointID": "f24c035e996439590c88b2d0ab3d26cdf32115cdb3d9ec5fa50710cb7ef832d6",
            "Gateway": "172.17.0.1",
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "172.17.0.2",
            "IPPrefixLen": 16,
            "IPv6Gateway": "",
            "MacAddress": "02:42:ac:11:00:02",
            "Networks": {
                "bridge": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "dac87c8ed4bd04308689a40796a465fa0fe175a30e82a0907a40c76405ba7c88",
                    "EndpointID": "f24c035e996439590c88b2d0ab3d26cdf32115cdb3d9ec5fa50710cb7ef832d6",
                    "Gateway": "172.17.0.1",
                    "IPAddress": "172.17.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:11:00:02",
                    "DriverOpts": null
                }
            }
        }
    }
  ]
  ```

  数据卷的信息在"Mounts"里边：
  ```
  "Mounts": [
    {
        "Type": "volume",
        "Source": "volume-1",
        "Target": "/webapp"
    }
  ]
  ```

### 删除数据卷

  ```
  >docker volume rm volume-1
  #如果数据卷 volume-1别其他容器引用，则是无法删除的，并且删除的时候会提示：
  # Error response from daemon: remove volume-1: volume is in use - [c9c346fdf8dcb7d4923d7f07b369e2f07779c14913f42a07b3b9f0accb73dac9]
  #需要先把容器删除
  ```

  数据卷设计的是用来存放数据的，并不会随着容器的删除而删除，有点类似于Linux里边的mount操作，如果想在删除容器的时候顺带删除数据卷，可以使用docker rm -v。

  无主的数据卷可能会占据很多空间，要清理请使用以下命令：
  
  ```
  >docker volume prune
  ```

## 挂载主机目录

### 挂载一个主机目录作为数据卷

  加载主机的 E:\Study\dockerWorkspace\volumes\volume1 目录到容器的 /opt/webapp 目录,此功能可以在测试的时候发挥作用，比如我们可以在source下边添加文件，依次来判定容器是否工作。
  PS： --mount 参数时如果本地目录不存在，Docker 会报错
  ```
  >docker run -dit --name myjdk8 --mount type=bind,source=E:\Study\dockerWorkspace\volumes\volume1,target=/webapp jdk8:v1
  #查看容器里边的挂载目录的信息
  >>docker inspect myjdk8
  [
    {
        "Id": "c28039a147a1ae4210e6cdf5491a56bb9dae25ca11c6ae2e91c9f55075d1ba5c",
        "Created": "2018-11-24T08:55:43.3658908Z",
        "Path": "/bin/bash",
        "Args": [],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 4170,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2018-11-24T08:55:45.2437582Z",
            "FinishedAt": "0001-01-01T00:00:00Z"
        },
        "Image": "sha256:a70ba00548f32c4d0152cb12e9aafdc419fc5bbb14744780bdfffb11f074ec03",
        "ResolvConfPath": "/var/lib/docker/containers/c28039a147a1ae4210e6cdf5491a56bb9dae25ca11c6ae2e91c9f55075d1ba5c/resolv.conf",
        "HostnamePath": "/var/lib/docker/containers/c28039a147a1ae4210e6cdf5491a56bb9dae25ca11c6ae2e91c9f55075d1ba5c/hostname",
        "HostsPath": "/var/lib/docker/containers/c28039a147a1ae4210e6cdf5491a56bb9dae25ca11c6ae2e91c9f55075d1ba5c/hosts",
        "LogPath": "/var/lib/docker/containers/c28039a147a1ae4210e6cdf5491a56bb9dae25ca11c6ae2e91c9f55075d1ba5c/c28039a147a1ae4210e6cdf5491a56bb9dae25ca11c6ae2e91c9f55075d1ba5c-json.log",
        "Name": "/myjdk8",
        "RestartCount": 0,
        "Driver": "overlay2",
        "Platform": "linux",
        "MountLabel": "",
        "ProcessLabel": "",
        "AppArmorProfile": "",
        "ExecIDs": null,
        "HostConfig": {
            "Binds": null,
            "ContainerIDFile": "",
            "LogConfig": {
                "Type": "json-file",
                "Config": {}
            },
            "NetworkMode": "default",
            "PortBindings": {},
            "RestartPolicy": {
                "Name": "no",
                "MaximumRetryCount": 0
            },
            "AutoRemove": false,
            "VolumeDriver": "",
            "VolumesFrom": null,
            "CapAdd": null,
            "CapDrop": null,
            "Dns": [],
            "DnsOptions": [],
            "DnsSearch": [],
            "ExtraHosts": null,
            "GroupAdd": null,
            "IpcMode": "shareable",
            "Cgroup": "",
            "Links": null,
            "OomScoreAdj": 0,
            "PidMode": "",
            "Privileged": false,
            "PublishAllPorts": false,
            "ReadonlyRootfs": false,
            "SecurityOpt": null,
            "UTSMode": "",
            "UsernsMode": "",
            "ShmSize": 67108864,
            "Runtime": "runc",
            "ConsoleSize": [
                50,
                189
            ],
            "Isolation": "",
            "CpuShares": 0,
            "Memory": 0,
            "NanoCpus": 0,
            "CgroupParent": "",
            "BlkioWeight": 0,
            "BlkioWeightDevice": [],
            "BlkioDeviceReadBps": null,
            "BlkioDeviceWriteBps": null,
            "BlkioDeviceReadIOps": null,
            "BlkioDeviceWriteIOps": null,
            "CpuPeriod": 0,
            "CpuQuota": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "CpusetCpus": "",
            "CpusetMems": "",
            "Devices": [],
            "DeviceCgroupRules": null,
            "DiskQuota": 0,
            "KernelMemory": 0,
            "MemoryReservation": 0,
            "MemorySwap": 0,
            "MemorySwappiness": null,
            "OomKillDisable": false,
            "PidsLimit": 0,
            "Ulimits": null,
            "CpuCount": 0,
            "CpuPercent": 0,
            "IOMaximumIOps": 0,
            "IOMaximumBandwidth": 0,
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": "/host_mnt/e/Study/dockerWorkspace/volumes/volume1",
                    "Target": "/webapp"
                }
            ],
            "MaskedPaths": [
                "/proc/acpi",
                "/proc/kcore",
                "/proc/keys",
                "/proc/latency_stats",
                "/proc/timer_list",
                "/proc/timer_stats",
                "/proc/sched_debug",
                "/proc/scsi",
                "/sys/firmware"
            ],
            "ReadonlyPaths": [
                "/proc/asound",
                "/proc/bus",
                "/proc/fs",
                "/proc/irq",
                "/proc/sys",
                "/proc/sysrq-trigger"
            ]
        },
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/2a1d010cd96bb1307be40e1b5e23a0b2f9ecbbcb124b4b8abfba963a0b37bf72-init/diff:/var/lib/docker/overlay2/2796cd7903fb6c509b276acb83505d05b1d685e010dc32557fe6baa06160e0a3/diff:/var/lib/docker/overlay2/15b4eabde2002d7fa67849c36b175b93827b911465b6cc8021e47f467ec2cca3/diff:/var/lib/docker/overlay2/9a004f009ec50069f1f7a8985bf40a256eda15b48402ccbefb6831ae52d2bbb8/diff:/var/lib/docker/overlay2/1d31c352fff2c856f6f208be8c9448ecc30447edcfacb10fd73e4d62ebef989d/diff",
                "MergedDir": "/var/lib/docker/overlay2/2a1d010cd96bb1307be40e1b5e23a0b2f9ecbbcb124b4b8abfba963a0b37bf72/merged",
                "UpperDir": "/var/lib/docker/overlay2/2a1d010cd96bb1307be40e1b5e23a0b2f9ecbbcb124b4b8abfba963a0b37bf72/diff",
                "WorkDir": "/var/lib/docker/overlay2/2a1d010cd96bb1307be40e1b5e23a0b2f9ecbbcb124b4b8abfba963a0b37bf72/work"
            },
            "Name": "overlay2"
        },
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/host_mnt/e/Study/dockerWorkspace/volumes/volume1",
                "Destination": "/webapp",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            }
        ],
        "Config": {
            "Hostname": "c28039a147a1",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": true,
            "OpenStdin": true,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/bin:/bin",
                "JAVA_HOME=/usr/local/jdk1.8.0_151",
                "MAVEN_HOME=/usr/local/apache-maven-3.6.0",
                "MAVEN_CONFIG=/root/.m2",
                "CLASSPATH=/lib/dt.jar:/lib/tools.jar"
            ],
            "Cmd": [
                "/bin/bash"
            ],
            "ArgsEscaped": true,
            "Image": "jdk8:v1",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": {
                "org.label-schema.build-date": "20181006",
                "org.label-schema.license": "GPLv2",
                "org.label-schema.name": "CentOS Base Image",
                "org.label-schema.schema-version": "1.0",
                "org.label-schema.vendor": "CentOS"
            }
        },
        "NetworkSettings": {
            "Bridge": "",
            "SandboxID": "d20c63fb42c257b9e1313b637d80d8c2841f4bec9d54c5941e2381a6f537b106",
            "HairpinMode": false,
            "LinkLocalIPv6Address": "",
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": {},
            "SandboxKey": "/var/run/docker/netns/d20c63fb42c2",
            "SecondaryIPAddresses": null,
            "SecondaryIPv6Addresses": null,
            "EndpointID": "89f640f036d7de25ad93e120e7352da9c99f254e82a4384972c43c6803f6c713",
            "Gateway": "172.17.0.1",
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "172.17.0.2",
            "IPPrefixLen": 16,
            "IPv6Gateway": "",
            "MacAddress": "02:42:ac:11:00:02",
            "Networks": {
                "bridge": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "dac87c8ed4bd04308689a40796a465fa0fe175a30e82a0907a40c76405ba7c88",
                    "EndpointID": "89f640f036d7de25ad93e120e7352da9c99f254e82a4384972c43c6803f6c713",
                    "Gateway": "172.17.0.1",
                    "IPAddress": "172.17.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:11:00:02",
                    "DriverOpts": null
                }
            }
        }
    }
  ]
  ```

  挂载信息：
  ```
  "Mounts": [
      {
          "Type": "bind",
          "Source": "/host_mnt/e/Study/dockerWorkspace/volumes/volume1",
          "Destination": "/webapp",
          "Mode": "",
          "RW": true,
          "Propagation": "rprivate"
      }
  ]
  ```

  Docker 挂载主机目录的默认权限是 读写 ，用户也可以通过增加 readonly 指定为 只读 。
  ```
  docker run -dit --name myjdk8 --mount type=bind,source=E:\Study\dockerWorkspace\volumes\volume1,target=/webapp readonly jdk8:v1
  ```
  此时如果向/webapp写操作，都会异常。

## 挂载一个本地主机文件作为数据卷

  --mount 标记也可以从主机挂载单个文件到容器中

### 记录在容器输入过的命令

  ```
  >docker run -dit --name myjdk8 --mount type=bind,source=E:\Study\dockerWorkspace\volumes\volume1\.bash_history,target=/root/.bash_history jdk8:v1
  d2bc7b21ca877bf952246bf147e29d9bc81a0b4769e1be3dca2cb49a30f20bec
  #这样就可以记录在容器输入过的命令了。
  >docker exec -it  d2b bash
  [root@d2bc7b21ca87 /]# pwd
  /
  [root@d2bc7b21ca87 /]# cd /root
  [root@d2bc7b21ca87 ~]# ls
  anaconda-ks.cfg
  [root@d2bc7b21ca87 ~]# more .bash_history
  [root@d2bc7b21ca87 ~]# ps
    PID TTY          TIME CMD
     19 pts/1    00:00:00 bash
     37 pts/1    00:00:00 ps
  [root@d2bc7b21ca87 ~]# top
  top - 09:10:52 up  3:36,  0 users,  load average: 0.23, 0.06, 0.02
  Tasks:   3 total,   1 running,   2 sleeping,   0 stopped,   0 zombie
  %Cpu(s):  0.2 us,  0.0 sy,  0.0 ni, 99.8 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
  KiB Mem :  2027756 total,    95516 free,   355696 used,  1576544 buff/cache
  KiB Swap:  1048572 total,  1048572 free,        0 used.  1478204 avail Mem

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
      1 root      20   0   11832   2820   2544 S   0.0  0.1   0:00.05 bash
     19 root      20   0   11832   2992   2616 S   0.0  0.1   0:00.03 bash
     38 root      20   0   56176   3848   3296 R   0.0  0.2   0:00.00 top
     [root@d2bc7b21ca87 ~]# ll
   total 4
   -rw------- 1 root root 3415 Oct  6 19:15 anaconda-ks.cfg
   [root@d2bc7b21ca87 ~]# java -c
   Unrecognized option: -c
   Error: Could not create the Java Virtual Machine.
   Error: A fatal exception has occurred. Program will exit.
   [root@d2bc7b21ca87 ~]# java -v
   Unrecognized option: -v
   Error: Could not create the Java Virtual Machine.
   Error: A fatal exception has occurred. Program will exit.
   [root@d2bc7b21ca87 ~]# java -v
   Unrecognized option: -v
   Error: Could not create the Java Virtual Machine.
   Error: A fatal exception has occurred. Program will exit.
   [root@d2bc7b21ca87 ~]# java -v
   Unrecognized option: -v
   Error: Could not create the Java Virtual Machine.
   Error: A fatal exception has occurred. Program will exit.
   [root@d2bc7b21ca87 ~]# java -version
   java version "1.8.0_151"
   Java(TM) SE Runtime Environment (build 1.8.0_151-b12)
   Java HotSpot(TM) 64-Bit Server VM (build 25.151-b12, mixed mode)
  ```

  我们在容器里边敲了很多命令，
  那么此时我们可以到宿主机的E:\Study\dockerWorkspace\volumes\volume1\.bash_history里边看一下，
  我们敲得命令的记录：
  ![4-2](4-2.png)
