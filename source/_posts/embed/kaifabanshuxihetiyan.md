---
title: 开发板熟悉与体验(jz2440)
date: 2023-04-24 22:12:45
tags: [embed]
categories: embed
---

# 选择什么开发板
我们学习单片机的目的是什么，是为了后期学习linux系统驱动做铺垫。
它的层级结构是这样的：
单片机->bootloader->linux系统/驱动->app
                                      :纯c/c++无界面
                                      :qt/android

在单片机->bootloader->linux系统/驱动->app->qt这个学习路线上我们可以使用同一套开发板。
怎么选择开发板？答案是资料丰富
![image.png](https://s2.loli.net/2023/11/12/XI9cFBofaCWkiH8.png)
<!-- more -->
他们百度搜索结果条数
- 三星系列的
 - s3c2440     92万
 - s3c6410     43万
 - s5pv210     22万
 - exynos4412  14万
- ti
 - AM437x       4.5万
 - AM335x       164万 营销好 用户多，工控芯片
- freescale
  - I.MX6       21万

- 全志，瑞芯微  资料不开放
从教程丰富程度，我们选择s3c2440
## 错误观点
有人说s3c2440过时了，他的cpu还是arm9，性能差，过时了，但是他的知识没有过时。
![image.png](https://s2.loli.net/2023/05/01/BGu1cCqo2LsmU3y.png)
我们在操作硬件的时候，不是操作的cpu，不接触cpu的指令，而是操作内存和寄存器，以及硬件的口径。
只有在中断的时候，才和cpu有点关系，但是不同的cpu之间关系比较小，没啥成本，并且我们以后再学习linux内核的时候，linux已经帮我们做好了封装和处理，根本不需要我们关心。

驱动=软件框架+硬件操作

软件框架都是一样的，所有内核都是linux内核，硬件操作，只要在s3c2440掌握了i2c，spi的原理，其他的硬件开发板都是一样的。

# 使用什么开发工具
ads,keil,mdk
只要写一个main函数，所有细节都封装了，谁来调main，c写的main函数代码生成代码怎么放在内存里边，这些工具都帮你做了，但是这些工具封装了太多的细节，不适合初学者，初学者应该学习细节，扎实基础，因此不会使用这些开发工具。
基于arm+linux裸机学习我们可以学习更多知识。
学习了s3c2440+linux裸机开发+arm芯片，回过头来再去学习STM32就是几分钟搞定的事情。
这样我们就能无缝进入后续的学习bootloader、linux驱动。


# 开发板介绍
s3c2440开发板，实际上他的性能并不是很强，但是他的资料非常的丰富
![20210906021414799.png](https://s2.loli.net/2023/05/01/YzpM71Xv3flhreC.png)
![20210906021415633.png](https://s2.loli.net/2023/05/01/4XcUry2pGwILqWY.png)

# 开发板接口介绍与串口连接
## 怎么使用这个开发板，它里边有如下几个核心接口

![image.png](https://s2.loli.net/2023/05/01/UBo9PQyFuNbHh1X.png)

- 接通电源
- 按下开关
- 使用串口(usb串口)观察信息
  - 连接以后windows会自动安装驱动(如果没法自动安装，可以下载PL2303_Prolific_DriverInstaller_v1.7.0.exe或者驱动精灵暗转)
  - 然后我们需要在pc安装一个mobaxterm软件，用来连接串口，这样开发板通过串口返回的信息我们可以在这个软件里边看到，也可以用这个软件通过串口发送命令给开发板
- 使用jtag口（usb烧写器）烧写程序
- 如果板上程序支持usb下载，板子的bus接口连接pc的usb接口
  - 烧写软件：oflash.ext
  - 硬件:op/eop、 easy open jtag
  - 驱动
    - eop连接到pc
    - 安装eop驱动
    - 暗转app
    - 开发板通过排线连接到eop，eop通过usb线连接到pc
    - 执行oflash.exe xxx.bin
    - 断开开发板和eop，断开eop和pc的连线
    - 设置从nor或者nand启动
    - 重新上电
- 启动选择开关：从nor启动，还是从nand启动

mobaxterm设置串口的时候，注意下波特率和不选中限流：
![image.png](https://s2.loli.net/2023/05/01/KaMgHwTV1Fb6tJv.png)

# 使用eop烧写裸板程序
## eop烧写
 将eop连接到pc，然后安装驱动(下载驱动程序OpenOCD with GUI setup.exe)，开发板通过排线连接到eop，eop通过usb线连接到pc 这三个步骤做完。
 oflash.exe烧写的bin文件，可以是u-boot.bin，它可以选择烧写到nor或者nand上，烧写到0地址。
 也可以直接烧写我么自己写的程序，比如led.bin。烧写到nand上去，烧写到0地址。
1. 命令模式下，切换到要烧写的文件所在的目录里，执行oflash xx.bin
![image.png](https://s2.loli.net/2023/05/01/1Z6qYdcQ8eHUC4A.png)

2. 烧写到nand flash（2次确认）
![image.png](https://s2.loli.net/2023/05/01/Zbvy9qhVoYw36cT.png)

3. 烧写到0地址
![image.png](https://s2.loli.net/2023/05/01/jDoGpTqfAK4Qy5H.png)

4. 将开发板的启动开关设置为nand启动
5. 将jtag线拔掉，拔掉的原因是jtag上有复位引脚，不然无法启动
6. 按下电源开关关闭开发板，然后重新上电，启动开发板，就会看到烧写的程序运行，如果是led的程序，开发板的灯就会闪烁

如果是烧写uboot，在启动以后我们可以通过mobaxterm连接到串口，在uboot等待3秒之内，在mobaxterm的串口命令窗口按下空格键，就会进入uboot 的菜单
![image.png](https://s2.loli.net/2023/05/01/DYPBrMJLq8m4uG5.png)
空格以后：
![image.png](https://s2.loli.net/2023/05/01/nghrGv7b1RkWEUF.png)
【本节结束】


![image.png](https://s2.loli.net/2023/11/12/F7zHMlmXtxbu81j.png)

如果你觉得我的文章有用，可以打赏我一杯雀巢咖啡
![image.jpg](https://i.postimg.cc/8Pmvqq4J/b1c4562d7729c208aef2f861473f309.jpg)
