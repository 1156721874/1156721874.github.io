---
title: 第1个ARM裸板程序及引申
date: 2023-05-01 16:00:00
tags: [embed]
categories: embed
---

# 硬件知识_LED原理图(辅线)
怎样点亮一个LED？
1. 看原理图，确定控制LED的引脚，
2. 看主芯片手册，确定如何设置/控制引脚
3. 写程序
![image.png](https://s2.loli.net/2023/11/12/YITWXSRGCQB8em9.png)
<!-- more -->

## 原理图
led的电阻很小，接通电源以后，其本身的电流很大，会被烧毁
![image.png](https://s2.loli.net/2023/05/01/TMUk48wPXho9KWE.png)
因此在他之前加了一个电阻：
![image.png](https://s2.loli.net/2023/05/01/gkCuEthS3zjFmX1.png)

这里的开关使我们手动的，在芯片里边都是引脚，引脚可以输出一个电压值
![image.png](https://s2.loli.net/2023/05/01/PVkBqd91YbR8zUX.png)
还可以
![image.png](https://s2.loli.net/2023/05/01/bBUsd51ZpfOxciu.png)

有些芯片的引脚驱动不足，电压很低，不能驱动LED，这个时候需要三极管
![image.png](https://s2.loli.net/2023/05/01/mHWpOifNJRslraG.png)
![image.png](https://s2.loli.net/2023/05/01/f3QMhN9qomtFWBg.png)

## 硬件知识
打开s3c2440的芯片手册，搜索LED
![image.png](https://s2.loli.net/2023/05/01/KmMtz96dpRVCBwF.png)
这个LED接了一个3.3V的电源，然后接到芯片的nLED_1，当nLED_1输出高电平的时候，LED熄灭，当nLED_1输出低电平的时候，n指的是低电平有效。
我们在s3c2440手册里边找到nLED_1连接的脚本是EINT4/GPT4
![image.png](https://s2.loli.net/2023/05/01/gQR2Vx6OYCcDtjJ.png)

我们打开s3c2440找到gpt4的使用，芯片里边有A-J组引脚，gpt4在Port F(GPF)这一组里边
![image.png](https://s2.loli.net/2023/05/01/V6tceIa2QZNYdGE.png)
现在的问题是怎么把GPT4的引脚设置为输出低电平？
1. GPT4配置为输出引脚，注意每个引脚都可以配置为输出引脚还是输入引脚
![image.png](https://s2.loli.net/2023/05/01/V6tceIa2QZNYdGE.png)
GPT4可以设置输入，也可以设置输出，也可以设置中断功能。
![image.png](https://s2.loli.net/2023/05/01/wHu3a9y4tqZSknX.png)

# 编程设置它的状态
这个是GPFCON和GPFDAT寄存器的地址：
![image.png](https://s2.loli.net/2023/05/01/Hq2pimJxKaRrwDv.png)
设置GPFCON的[9:8]为0b01，那么GPF4设置为输出引脚,即把0x100写入GPFCON，就是写到地址0x56000050.
下面是GPFDATA寄存器的设置说明
![image.png](https://s2.loli.net/2023/05/01/G4q2T3K6aUlXE1A.png)
GPFDATA的意思是设置对应引脚编号的位置为对应引脚输出的值。
比如是GPF4：
LED熄灭：那么就设置GPFDATA的第4位为1，即为输出高电平，把0x10写到地址0x56000054上；
LED点亮：设置GPFDATA的第4位为0，即为输出低电平，把0写到地址0x56000054上；

接下来就是写代码去配置，在写代码配置之前，需要先来了解下s3c2440框架和启动过程
![image.png](https://s2.loli.net/2023/05/01/H5GrkCWlLD2Qw7T.png)
启动过程如下：
1. nor启动：nor flash基地址为0，片内RAM地址为0x4000,0000
cpu读出nor上第一个指令（前4字节），执行。
cpu继续读出其他指令执行。

3. nand启动：片内4Kram基地址为0，nor flash不可访问，2440硬件把nand前4K内容复制到片内RAM，然后cpu从0地址取出第一条指令执行。

另外，cpu操作寄存器的形式如下：
![](https://s3.bmp.ovh/imgs/2023/05/27/6c3d971cd12ba611.png)

4. 操作寄存器的几个汇编指令
4.1 LDR 指令
读内存，LDR R0,[R1] ,假设R1的值是x，读取地址x上的数据（4字节），保存到R0中。
4.2 STR指令
写内存指令，STR R0,[R1]
假设R1的值是x，把R0的值写到地址X（4字节）
4.3 B指令
跳转
4.4 MOV指令
MOV R0,R1 把R1的值赋值给R0，R0=R1；
MOV R0,#0x100，R0=0x100;
4.5 LDR R0,=0x12345678:R0=0x12345678
这是一条伪指令，它会被拆分为几条真正的RAM指令
如果我们用MOV R0,0x12345678，这样是错误的，不能正确执行，因为一条ARM指令长度是32位，除了数据意外，还需要表示指令本身以及其他变量。
![](https://s3.bmp.ovh/imgs/2023/05/27/88729adcce5541c4.png)
所以引入伪指令 LDR R0,=0x12345678
4.6 加减法
add r0,r1,#4:r0=r1+4 ;
sub r0,r1,#4:r0=r1-4;
sub r0,r1,r2:r0=r1-r2;
4.7 bl指令
branch and link


5. 编写程序
我们写的第一个程序是汇编程序，不会上来就写c语言main函数。
新建文件led_on.S
```


/*
 * 点亮LED1: gpf4
 */

.text
.global _start

_start:

/* 配置GPF4为输出引脚
 * 把0x100写到地址0x56000050
 */
	ldr r1, =0x56000050
	ldr r0, =0x100	/* mov r0, #0x100 */
	str r0, [r1]


/* 设置GPF4输出高电平
 * 把0写到地址0x56000054
 */
	ldr r1, =0x56000054
	ldr r0, =0	/* mov r0, #0 */
	str r0, [r1]

	/* 死循环 */
halt:
	b halt
```
将此文件放在linux系统编译：
5.1.  预编译
 arm-linux-gcc -c -o led_on.o led_on.S
5.2. 连接
arm-linux-ld -Ttext 0 led_on.o -o led_on.elf
5.3. 得到bin文件
arm-linux-objcopy -o binary -S led_on.elf led_on.bin
这些命令写的时候容易出错，可以放在一个文件里边。
文件名为Makefile
```
all:
	arm-linux-gcc -c -o led_on.o led_on.S
	arm-linux-ld -Ttext 0 led_on.o -o led_on.elf
	arm-linux-objcopy -O binary -S led_on.elf led_on.bin
	arm-linux-objdump -D led_on.elf > led_on.dis
clean:
	rm *.bin *.o *.elf

```

5.4. 然后使用make clean来清除，使用make命令来编译

# 烧写
将在linux下编译好的并文件copy到windows平台下
硬件接好烧写器
烧写命令:
oflash led_on.bin
![](https://s3.bmp.ovh/imgs/2023/05/27/535c9277e2ab23f9.png)
一次输入0、1、0、0、0
接下来把烧写排线拔掉，关电，设置为nand启动，上电。
效果就是有一个灯亮了。

# 汇编与机器码
上边的makefile文件有一条	arm-linux-objdump -D led_on.elf > led_on.dis 这条命令是反汇编指令，会得到一个 led_on.dis文件
```
led_on.elf:     file format elf32-littlearm

Disassembly of section .text:

00000000 <_start>:
   0:	e59f1014 	ldr	r1, [pc, #20]	; 1c <.text+0x1c>
   4:	e3a00c01 	mov	r0, #256	; 0x100
   8:	e5810000 	str	r0, [r1]
   c:	e59f100c 	ldr	r1, [pc, #12]	; 20 <.text+0x20>
  10:	e3a00000 	mov	r0, #0	; 0x0
  14:	e5810000 	str	r0, [r1]

00000018 <halt>:
  18:	eafffffe 	b	18 <halt>
  1c:	56000050 	undefined
  20:	56000054 	undefined

```

上边我们提到cpu可以直接访问的寄存器从R0到R15，pc是什么，pc是一个别名，有一张如下的映射表：

User 模式  SVC 模式   IRQ 模式   FIQ 模式  APCS

R0 ------- R0 ------- R0 ------- R0        a1
R1 ------- R1 ------- R1 ------- R1        a2
R2 ------- R2 ------- R2 ------- R2        a3
R3 ------- R3 ------- R3 ------- R3        a4
R4 ------- R4 ------- R4 ------- R4        v1
R5 ------- R5 ------- R5 ------- R5        v2
R6 ------- R6 ------- R6 ------- R6        v3
R7 ------- R7 ------- R7 ------- R7        v4
R8 ------- R8 ------- R8         R8_fiq    v5
R9 ------- R9 ------- R9         R9_fiq    v6
R10 ------ R10 ------ R10        R10_fiq   sl
R11 ------ R11 ------ R11        R11_fiq   fp
R12 ------ R12 ------ R12        R12_fiq   ip
R13        R13_svc    R13_irq    R13_fiq   sp
R14        R14_svc    R14_irq    R14_fiq   lr
------------- R15 / PC -------------       pc
上边的汇编指令执行的时候哦，会是如下的方式：
![](https://s3.bmp.ovh/imgs/2023/05/27/15efca16247ab67c.png)

# 字节序和位操作
![编程知识_节序_位操作.jpg](https://s2.loli.net/2023/11/12/rkCfSFTe5vRscgV.jpg)

# C语言点亮LED

```
int main()
{
	unsigned int *pGPFCON = (unsigned int *)0x56000050;
	unsigned int *pGPFDAT = (unsigned int *)0x56000054;

	/* 配置GPF4为输出引脚 */
	*pGPFCON = 0x100;

	/* 设置GPF4输出0 */
	*pGPFDAT = 0;

	return 0;
}
```

新建一个Start.S文件，用于为C语言文件设置内存，调用main函数：
```

.text
.global _start

_start:

	/* 设置内存: sp 栈 */
	ldr sp, =4096  /* nand启动 */
//	ldr sp, =0x40000000+4096  /* nor启动 */

	/* 调用main */
	bl main

halt:
	b halt
```

C语言视角内存操作：
![编写C程序控制LED.jpg](https://s2.loli.net/2023/11/12/azStEmYAbQKjl3f.jpg)

# 解析C程序的内部机制
上面点亮LED的代码，反编译为汇编指令:
```

led.elf:     file format elf32-littlearm

Disassembly of section .text:

00000000 <_start>:
   0:	e3a0da01 	mov	sp, #4096	; 0x1000
   4:	eb000000 	bl	c <main>

00000008 <halt>:
   8:	eafffffe 	b	8 <halt>

0000000c <main>:
   c:	e1a0c00d 	mov	ip, sp
  10:	e92dd800 	stmdb	sp!, {fp, ip, lr, pc}
  14:	e24cb004 	sub	fp, ip, #4	; 0x4
  18:	e24dd008 	sub	sp, sp, #8	; 0x8
  1c:	e3a03456 	mov	r3, #1442840576	; 0x56000000
  20:	e2833050 	add	r3, r3, #80	; 0x50
  24:	e50b3010 	str	r3, [fp, #-16]
  28:	e3a03456 	mov	r3, #1442840576	; 0x56000000
  2c:	e2833054 	add	r3, r3, #84	; 0x54
  30:	e50b3014 	str	r3, [fp, #-20]
  34:	e51b2010 	ldr	r2, [fp, #-16]
  38:	e3a03c01 	mov	r3, #256	; 0x100
  3c:	e5823000 	str	r3, [r2]
  40:	e51b2014 	ldr	r2, [fp, #-20]
  44:	e3a03000 	mov	r3, #0	; 0x0
  48:	e5823000 	str	r3, [r2]
  4c:	e3a03000 	mov	r3, #0	; 0x0
  50:	e1a00003 	mov	r0, r3
  54:	e24bd00c 	sub	sp, fp, #12	; 0xc
  58:	e89da800 	ldmia	sp, {fp, sp, pc}
Disassembly of section .comment:

00000000 <.comment>:
   0:	43434700 	cmpmi	r3, #0	; 0x0
   4:	4728203a 	undefined
   8:	2029554e 	eorcs	r5, r9, lr, asr #10
   c:	2e342e33 	mrccs	14, 1, r2, cr4, cr3, {1}
  10:	Address 0x10 is out of bounds.
```
在讲解这段指令之前，需要先解释下里边的一些陌生指令：
stmdb和ldmia指令。
![image.png](https://s2.loli.net/2023/11/19/Bs1eIUb5qH9ayEL.png)

下面对这段指令进行解析:
![解析C程序的内部机制.jpg](https://s2.loli.net/2023/11/12/U4LcDuHOaCokinr.jpg)


# 给C程序传递参数
修改Start.S文件:
```

.text
.global _start

_start:

	/* 设置内存: sp 栈 */
	ldr sp, =4096  /* nand启动 */
//	ldr sp, =0x40000000+4096  /* nor启动 */

	mov r0, #4
	bl led_on

	ldr r0, =100000
	bl delay

	mov r0, #5
	bl led_on

halt:
	b halt

```
修改ldc.c文件：
```

void delay(volatile int d)
{
	while (d--);
}

int led_on(int which)
{
	unsigned int *pGPFCON = (unsigned int *)0x56000050;
	unsigned int *pGPFDAT = (unsigned int *)0x56000054;

	if (which == 4)
	{
		/* 配置GPF4为输出引脚 */
		*pGPFCON = 0x100;
	}
	else if (which == 5)
	{
		/* 配置GPF5为输出引脚 */
		*pGPFCON = 0x400;
	}

	/* 设置GPF4/5输出0 */
	*pGPFDAT = 0;

	return 0;
}

```
程序先让第一个灯亮，然后等了一段时间(delay函数)，又让第二个灯亮，参数传递使用了r0寄存器，那么调用者和被调用者之前都是使用那些寄存器呢，下面是一套使用标准：
![image.png](https://s2.loli.net/2023/11/19/Qfd6RgjpSiBbqEh.png)


# 关闭看门狗
以上程序在运行的时候，2个灯被依次点亮，然后又会往复循环点亮，这是因为系统有保护机制，防止程序卡死，不能使用，会重新复位系统，内置了看门狗机制，我们可以关闭看门狗：
Start.S修改：
```
.text
.global _start

_start:

  /* 关闭看门狗 */
  ldr r0, =0x53000000
  ldr r1, =0
  str r1, [r0]

	/* 设置内存: sp 栈 */
	ldr sp, =4096  /* nand启动 */
//	ldr sp, =0x40000000+4096  /* nor启动 */

	mov r0, #4
	bl led_on

	ldr r0, =100000
	bl delay

	mov r0, #5
	bl led_on

halt:
	b halt
```

# 程序兼容nor启动和nand启动
修改Start.S
```

.text
.global _start

_start:

	/* 关闭看门狗 */
	ldr r0, =0x53000000
	ldr r1, =0
	str r1, [r0]

	/* 设置内存: sp 栈 */
	/* 分辨是nor/nand启动
	 * 写0到0地址, 再读出来
	 * 如果得到0, 表示0地址上的内容被修改了, 它对应ram, 这就是nand启动
	 * 否则就是nor启动
	 */
	mov r1, #0
	ldr r0, [r1] /* 读出原来的值备份 */
	str r1, [r1] /* 0->[0] */
	ldr r2, [r1] /* r2=[0] */
	cmp r1, r2   /* r1==r2? 如果相等表示是NAND启动 */
	ldr sp, =0x40000000+4096 /* 先假设是nor启动 */
	moveq sp, #4096  /* nand启动 */
	streq r0, [r1]   /* 恢复原来的值 */


	bl main

halt:
	b halt

```
修改led.c文件：
```

#include "s3c2440_soc.h"

void delay(volatile int d)
{
	while (d--);
}

int main(void)
{
	int val = 0;  /* val: 0b000, 0b111 */
	int tmp;

	/* 设置GPFCON让GPF4/5/6配置为输出引脚 */
	GPFCON &= ~((3<<8) | (3<<10) | (3<<12));
	GPFCON |=  ((1<<8) | (1<<10) | (1<<12));

	/* 循环点亮 */
	while (1)
	{
		tmp = ~val;
		tmp &= 7;
		GPFDAT &= ~(7<<4);
		GPFDAT |= (tmp<<4);
		delay(100000);
		val++;
		if (val == 8)
			val =0;

	}

	return 0;
}
```
以上2个文件兼容nor和nand启动。


# 按钮控制led点亮
![image.png](https://s2.loli.net/2023/11/19/BfnTmzg1GlW3j2c.png)
<<<<<<< HEAD
EINT0控制LED_1，EINT2控制LED_2，EINT11控制LED_4。查看原理图
![image.png](https://s2.loli.net/2023/11/19/Zvu4QGN2dimYbg1.png)
寻找他们对应的引脚：
![image.png](https://s2.loli.net/2023/11/19/cCRre7P5ptQwE1T.png)
![image.png](https://s2.loli.net/2023/11/19/SrUzhMkGpNlt7CT.png)
按键和引脚的对应关系:EINT0:GPF0,EINT2:GPF2,EINT11:GPG3;
想找到GPFCON的2个引脚配置：
GPFCON引脚的地址是：0x56000050
![image.png](https://s2.loli.net/2023/11/19/AYKRnj7pq8skNxB.png)
GPGCON引脚配置：
GPGCON引脚的地址是：0x56000060
![image.png](https://s2.loli.net/2023/11/19/c9ybNWzfK8GJskm.png)
GPFDATA和GPGDATA的地址分别是：0x56000054、0x56000064，这些都可以通过S3C2440芯片手册找到。
还有一个问题是，怎么判断按键是被按下或者松开？看下原理图：
![image.png](https://s2.loli.net/2023/11/19/5UwPS8ib1pcsnhf.png)
这样，只要我们的程序只要检测到引脚GPF0是高电平意味着开关没有被按下，如果是低电平，意味着开关被按下。
然后就是确认3盏灯的控制引脚：
![image.png](https://s2.loli.net/2023/11/19/kSNCWVE8YcpK7a9.png)
=======

EINT0控制LED_1，EINT2控制LED_2，EINT11控制LED_4。查看原理图

![image.png](https://s2.loli.net/2023/11/19/Zvu4QGN2dimYbg1.png)

寻找他们对应的引脚：

![image.png](https://s2.loli.net/2023/11/19/cCRre7P5ptQwE1T.png)

![image.png](https://s2.loli.net/2023/11/19/SrUzhMkGpNlt7CT.png)

按键和引脚的对应关系:EINT0:GPF0,EINT2:GPF2,EINT11:GPG3;
想找到GPFCON的2个引脚配置：
GPFCON引脚的地址是：0x56000050

![image.png](https://s2.loli.net/2023/11/19/AYKRnj7pq8skNxB.png)

GPGCON引脚配置：
GPGCON引脚的地址是：0x56000060

![image.png](https://s2.loli.net/2023/11/19/c9ybNWzfK8GJskm.png)

GPFDATA和GPGDATA的地址分别是：0x56000054、0x56000064，这些都可以通过S3C2440芯片手册找到。
还有一个问题是，怎么判断按键是被按下或者松开？看下原理图：

![image.png](https://s2.loli.net/2023/11/19/5UwPS8ib1pcsnhf.png)

这样，只要我们的程序只要检测到引脚GPF0是高电平意味着开关没有被按下，如果是低电平，意味着开关被按下。
然后就是确认3盏灯的控制引脚：

![image.png](https://s2.loli.net/2023/11/19/kSNCWVE8YcpK7a9.png)

>>>>>>> db05d90729ee645598105d778a95820856c0bfea
分别是GPF4，GPF5，GPF6.
接下里就可以把led.c程序写出来：
```
#include "s3c2440_soc.h"

void delay(volatile int d)
{
	while (d--);
}

int main(void)
{
	int val1, val2;

	/* 设置GPFCON让GPF4/5/6配置为输出引脚 */
	GPFCON &= ~((3<<8) | (3<<10) | (3<<12));
	GPFCON |=  ((1<<8) | (1<<10) | (1<<12));

	/* 配置3个按键引脚为输入引脚:
	 * GPF0(S2),GPF2(S3),GPG3(S4)
	 */
	GPFCON &= ~((3<<0) | (3<<4));  /* gpf0,2 */
	GPGCON &= ~((3<<6));  /* gpg3 */

	/* 循环点亮 */
	while (1)
	{
		val1 = GPFDAT;
		val2 = GPGDAT;

		if (val1 & (1<<0)) /* s2 --> gpf6 */
		{
			/* 松开 */
			GPFDAT |= (1<<6);
		}
		else
		{
			/* 按下 */
			GPFDAT &= ~(1<<6);
		}

		if (val1 & (1<<2)) /* s3 --> gpf5 */
		{
			/* 松开 */
			GPFDAT |= (1<<5);
		}
		else
		{
			/* 按下 */
			GPFDAT &= ~(1<<5);
		}

		if (val2 & (1<<3)) /* s4 --> gpf4 */
		{
			/* 松开 */
			GPFDAT |= (1<<4);
		}
		else
		{
			/* 按下 */
			GPFDAT &= ~(1<<4);
		}


	}

	return 0;
}

```


如果你觉得我的文章有用，可以打赏我一杯雀巢咖啡
![image.jpg](https://i.postimg.cc/8Pmvqq4J/b1c4562d7729c208aef2f861473f309.jpg)