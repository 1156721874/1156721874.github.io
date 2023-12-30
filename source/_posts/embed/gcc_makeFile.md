---
title: gcc编译器和makeFile详解
date: 2023-11-19 16:00:00
tags: [embed]
categories: embed
---


# gcc常用选项
- x86平台
  - windos应用程序:建立工程-编辑-编译(vc6.0)-运行
  - ubuntu应用程序:编辑-编译(gcc)-运行
- arm裸机：编辑-编译(arm-linux-gcc)-烧写-运行
  - hello.c ---预处理---> hello.i ---编译---> hello.s ---汇编---> hello.o ---连接---> hello


# gcc常用编译选项

gcc和arm-linux-gcc的常用选项


### gcc的使用方法：
gcc  [选项]   文件名

gcc常用选项：
  -v：查看gcc编译器的版本，显示gcc执行时的详细过程
  -o <file>                Place the output into <file>
                           指定输出文件名为file，这个名称不能跟源文件名同名
  -E                       Preprocess only; do not compile, assemble or link
                           只预处理，不会编译、汇编、链接
  -S                       Compile only; do not assemble or link
                           只编译，不会汇编、链接
  -c                       Compile and assemble, but do not link
                           编译和汇编，不会链接    
//==================================================
gcc  -v：查看gcc编译器的版本

#### 方式1：
gcc hello.c  输出一个a.out，然后./a.out来执行该应用程序。

gcc -o hello hello.c  输出hello，然后./hello来执行该应用程序。


#### 方式2：
gcc -E -o hello.i hello.c
gcc -S -o hello.s hello.i
gcc -c -o hello.o hello.s
gcc -o hello hello.o



.o:object file(OBJ文件)
小结：
1）输入文件的后缀名和选项共同决定gcc到底执行那些操作。
2）在编译过程中，除非使用了-E、-S、-c选项(或者编译出错阻止了完整的编译过程)
   否则最后的步骤都是链接。


#### 方式3：
gcc -c -o hello.o hello.c
gcc -o hello hello.o

gcc会对.c文件默认进行预处理操作，-c再来指明了编译、汇编，从而得到.o文件
再通过gcc -o hello hello.o将.o文件进行链接，得到可执行应用程序。


链接就是将汇编生成的OBJ文件、系统库的OBJ文件、库文件链接起来，
最终生成可以在特定平台运行的可执行程序。

crt1.o、crti.o、crtbegin.o、crtend.o、crtn.o是gcc加入的系统标准启动文件，
对于一般应用程序，这些启动是必需的。

-lc：链接libc库文件，其中libc库文件中就实现了printf等函数。


gcc -v -nostdlib -o hello hello.o会提示因为没有链接系统标准启动文件和标准库文件，而链接失败。
这个-nostdlib选项常用于裸机/bootloader、linux内核等程序，因为它们不需要启动文件、标准库文件。

一般应用程序才需要系统标准启动文件和标准库文件。
裸机/bootloader、linux内核等程序不需要启动文件、标准库文件。


动态链接使用动态链接库进行链接，生成的程序在执行的时候需要加载所需的动态库才能运行。
动态链接生成的程序体积较小，但是必须依赖所需的动态库，否则无法执行。

静态链接使用静态库进行链接，生成的程序包含程序运行所需要的全部库，可以直接运行，
不过静态链接生成的程序体积较大。

gcc -c -o hello.o hello.c
gcc -o hello_shared  hello.o
gcc -static -o hello_static hello.o

# makeFile
##  Makefile的引入及规则
使用keil, mdk, avr等工具开发程序时点点鼠标就可以编译了，
它的内部机制是什么？它怎么组织管理程序？怎么决定编译哪一个文件？

gcc -o test a.c b.c  
// 简单,
// 但是会对所有文件都处理一次,
// 文件多时如果只修改其中一个文件会导致效率低

Makefile的核心---规则 :

目标 : 依赖1 依赖2 ...
[TAB]命令

当"目标文件"不存在,
或
某个依赖文件比目标文件"新",
则: 执行"命令"


# C语言复习





## Makefile的语法
a. 通配符: %.o
   $@ 表示目标
   $< 表示第1个依赖文件
   $^ 表示所有依赖文件

b. 假想目标: .PHONY

c. 即时变量、延时变量, export
简单变量(即时变量) :
A := xxx   # A的值即刻确定，在定义时即确定
B = xxx    # B的值使用到时才确定

:=   # 即时变量
=    # 延时变量
?=   # 延时变量, 如果是第1次定义才起效, 如果在前面该变量已定义则忽略这句
+=   # 附加, 它是即时变量还是延时变量取决于前面的定义


参考文档:
a. 百度搜 "gnu make 于凤昌"
b. 官方文档: http://www.gnu.org/software/make/manual/

如果想深入, 可以学习这视频:
第3期视频项目1, 第1课第4节_数码相框_编写通用的Makefile_P

## Makefile函数
a. $(foreach var,list,text)
b. $(filter pattern...,text)      # 在text中取出符合patten格式的值
   $(filter-out pattern...,text)  # 在text中取出不符合patten格式的值

c. $(wildcard pattern)            # pattern定义了文件名的格式,
                                  # wildcard取出其中存在的文件
d. $(patsubst pattern,replacement,$(var))  # 从列表中取出每一个值
                                           # 如果符合pattern
										   # 则替换为replacement

## Makefile实例
a. 改进: 支持头文件依赖
http://blog.csdn.net/qq1452008/article/details/50855810

gcc -M c.c // 打印出依赖

gcc -M -MF c.d c.c  // 把依赖写入文件c.d

gcc -c -o c.o c.c -MD -MF c.d  // 编译c.o, 把依赖写入文件c.d

b. 添加CFLAGS
c. 分析裸板Makefile
