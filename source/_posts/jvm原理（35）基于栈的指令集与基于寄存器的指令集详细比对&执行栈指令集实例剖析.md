---
title: jvm原理（35）基于栈的指令集与基于寄存器的指令集详细比对&执行栈指令集实例剖析
date: 2018-10-04 19:02:34
tags: [指令集,栈,寄存器]
categories: jvm
---


# 基于栈的指令集与基于寄存器的指令集详细比对
<!-- more -->

 现代JVM在执行Java代码的时候，通常都会将解释执行与编译执行二者结合起来进行。

 所谓解释之行，就是通过解释器来读取字节码，遇到相应的指令就去执行该指令。
 所谓编译执行，就是通过即时编译器(just in time jit)将字节码转换为本地机器码执行，现代jvm会根据代码热点生成相应的本地机器码。

 执行的方式有基于栈的和基于寄存器的执行方式：
 基于栈: 移植性好，java是基于栈的指令集，为了可移植性。由于栈是在内存里边出栈入栈，相比cpu寄存器，速度比较慢。
 完成相同的操作，基于栈的指令集要比基于寄存器的指令集所需要的指令数量要多。
 基于寄存器: 寄存器和硬件架构绑定在一块，因此移植性不ok，但是执行速度快。基于寄存器的指令集是在寄存器里边执行的，速度很快。
 虽然虚拟机可以采取一些优化手段，但总体来说，基于栈的指令集的执行速度要慢一些。

 比如我们要运算2-1，就会有如下的入栈出栈操作：
 1. iconst_1 //1入栈
 2. iconst_2 //2入栈
 3. isub     //(1)将栈顶元素出栈，栈顶元素下边的元素出栈;(2)栈顶元素减去栈顶下边的元素;(3)将结果放入栈顶; isub完成了是3个操作。
 4. istore_0 //将结果放在slot0处,slot0处可能是一个变量，方法返回的时候，可以把这个变量返回。

如果是基于寄存器去运算这个减法，第一步就是把2放到一个寄存器上，然后cpu执行减一，然后把结果直接放在原来的寄存器上。过程很简单。

# 执行栈指令集实例剖析

编写一个很简单的程序：

```
package com.twodragonlake.jvm.bytecode;
public class MyTest8 {
    public int myCalulate(){
        int a =1;
        int b =2;
        int c =3;
        int d =4;

        int result = (a + b - c) * d;
        return result;
    }
}
```
javap反编译：
javap -verbose -p com/twodragonlake/jvm/bytecode.MyTest8

找到myCalulate的字节码：
```
Code:
  stack=2, locals=6, args_size=1 //栈最大深度是2；栈最大的局部变量是6个；myCalulate方法的参数个数是1个(this)
     0: iconst_1 //将1入栈
     1: istore_1 //将1出栈，然后将1放在slot索引为1的位置的slot上(slot索引为0是this)
     2: iconst_2 //将2入栈
     3: istore_2 //将2出栈，然后将2放到slot索引为2的slot位置上
     4: iconst_3 //将3入栈
     5: istore_3 //将3出栈，然后放在索引为3的slot上
     6: iconst_4 //将4入栈
     7: istore        4  //将4出栈，然后放到索引为4的slot上，注意不是istore_4 因为istore_X最多到istore_3
     目前的状态如下：
         栈                 方法的局部变量表   
     ===========            ==============
     |         |            |     this    |
     -----------            ---------------
     |         |            |      1      |
     -----------            ---------------
                            |      2      |
                            ---------------
                            |      3      |
                            ---------------
                            |      4      |
                            ---------------   
                            |             |
                            ---------------                             

     9: iload_1 //将局部变量表索引为1的元素的值，推到栈顶
    10: iload_2 //将局部变量表索引为2的元素的值，推到栈顶
     目前的状态如下：
    栈                 方法的局部变量表   
===========            ==============
|    2    |            |     this    |
-----------            ---------------
|    1    |            |      1      | 已入栈
-----------            ---------------
                       |      2      | 已入栈
                       ---------------
                       |      3      |
                       ---------------
                       |      4      |
                       ---------------   
                       |             |
                       ---------------  

    11: iadd //将2和1弹出栈，然后相加（2+1=3），得到结果3，将三压入栈顶
    栈                 方法的局部变量表   
===========            ==============
|         |            |     this    |
-----------            ---------------
|    3    |            |      1      | 已入栈
-----------            ---------------
                       |      2      | 已入栈
                       ---------------
                       |      3      |
                       ---------------
                       |      4      |
                       ---------------   
                       |             |
                       ---------------  

    12: iload_3 //将局部变量表索引为3的位置的元素推送到栈顶
    栈                 方法的局部变量表   
===========            ==============
|    3    |            |     this    |
-----------            ---------------
|    3    |            |      1      | 已入栈
-----------            ---------------
                       |      2      | 已入栈
                       ---------------
                       |      3      | 已入栈
                       ---------------
                       |      4      |
                       ---------------   
                       |             |
                       ---------------  
    13: isub    //将栈顶元素弹出，相减（3-3=0），得到结果推送到栈顶
    栈                 方法的局部变量表   
===========            ==============
|    0    |            |     this    |
-----------            ---------------
|         |            |      1      | 已入栈
-----------            ---------------
                       |      2      | 已入栈
                       ---------------
                       |      3      | 已入栈
                       ---------------
                       |      4      |
                       ---------------   
                       |             |
                       ---------------
    14: iload         4 //将局部变量表索引为4的变量的值推送到栈顶
    栈                 方法的局部变量表   
===========            ==============
|    4    |            |     this    |
-----------            ---------------
|    0    |            |      1      | 已入栈
-----------            ---------------
                       |      2      | 已入栈
                       ---------------
                       |      3      | 已入栈
                       ---------------
                       |      4      | 已入栈
                       ---------------   
                       |             |
                       ---------------
    16: imul //栈顶2个元素弹出，执行乘法（0*4=0），得到的结果推送到栈顶
    栈                 方法的局部变量表   
===========            ==============
|    0    |            |     this    |
-----------            ---------------
|         |            |      1      | 已入栈
-----------            ---------------
                       |      2      | 已入栈
                       ---------------
                       |      3      | 已入栈
                       ---------------
                       |      4      | 已入栈
                       ---------------   
                       |             |
                       ---------------
    17: istore        5  //栈顶元素出栈，然后将索引为5的slot的设置的值为栈顶元素。就是局部变量表5的位置赋值为栈顶元素
    栈                 方法的局部变量表   
===========            ==============
|         |            |     this    |
-----------            ---------------
|         |            |      1      | 已入栈
-----------            ---------------
                       |      2      | 已入栈
                       ---------------
                       |      3      | 已入栈
                       ---------------
                       |      4      | 已入栈
                       ---------------   
                       |      0      |
                       ---------------
    19: iload         5  //将局部变量表5的位置推送到栈顶
    栈                 方法的局部变量表   
===========            ==============
|    0    |            |     this    |
-----------            ---------------
|         |            |      1      | 已入栈
-----------            ---------------
                       |      2      | 已入栈
                       ---------------
                       |      3      | 已入栈
                       ---------------
                       |      4      | 已入栈
                       ---------------   
                       |      0      | 已入栈
                       ---------------
    21: ireturn  //方法将栈顶元素返回

```

## iconst
第一个指令是iconst_1，我们到oracle的官方网站看一下他的说明：
https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.iconst_i

iconst_<i>
Operation
Push int constant
将一个常量入栈
Format
iconst_<i>
Forms
iconst_m1 = 2 (0x2) //-1入栈
iconst_0 = 3 (0x3)  //0入栈
iconst_1 = 4 (0x4)  //....
iconst_2 = 5 (0x5)
iconst_3 = 6 (0x6)
iconst_4 = 7 (0x7)
iconst_5 = 8 (0x8)

Operand Stack
... →

..., <i>

Description
Push the int constant <i> (-1, 0, 1, 2, 3, 4 or 5) onto the operand stack.
将(-1, 0, 1, 2, 3, 4 or 5)压入到栈顶

Notes
Each of this family of instructions is equivalent to bipush <i> for the respective value of <i>, except that the operand <i> is implicit.
每个指令等价于bipush <i>， <i>就等于iconst后边的数字，只不过操作数是隐式的。

## istore
istore指令，https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.istore_n
Operation
Store int into local variable
将一个整数村存储到一个变量里边

Format
istore_<n>

Forms
istore_0 = 59 (0x3b)
istore_1 = 60 (0x3c)
istore_2 = 61 (0x3d)
istore_3 = 62 (0x3e)

Operand Stack
..., value →

...

Description
The <n> must be an index into the local variable array of the current frame (§2.6). The value on the top of the operand stack must be of type int. It is popped from the operand stack, and the value of the local variable at <n> is set to value.
n 必须是局部变量表里边的一个索引，操作数栈的栈顶元素必须是整数类型，弹出栈顶元素，将这个元素放在局部变量n的位置

Notes
Each of the istore_<n> instructions is the same as istore with an index of <n>, except that the operand <n> is implicit.
每个istore_<n>等价于 istore指令 带上一个索引n，只不过n是隐式的。

## Store
https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.istore
Operation
Store int into local variable
将一个整型放到局部变量里边
Format

istore
index

Forms
istore = 54 (0x36)

Operand Stack
..., value →

...

Description
The index is an unsigned byte that must be an index into the local variable array of the current frame (§2.6). The value on the top of the operand stack must be of type int. It is popped from the operand stack, and the value of the local variable at index is set to value.

index必须是无符号（0--255）的，并且存在于局部变量表里边的一个索引，值是栈帧的顶部的元素，必须是整型的，将栈的顶部元素设置到局部变量表索引为index的位置。

Notes
The istore opcode can be used in conjunction with the wide instruction (§wide) to access a local variable using a two-byte unsigned index.

## iload
https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.iload_n

Operation
Load int from local variable
从局部变量表加载一个整型数据
Format
iload_<n>

Forms
iload_0 = 26 (0x1a)
iload_1 = 27 (0x1b)
iload_2 = 28 (0x1c)
iload_3 = 29 (0x1d)

Operand Stack
... →

..., value

Description
The <n> must be an index into the local variable array of the current frame (§2.6). The local variable at <n> must contain an int. The value of the local variable at <n> is pushed onto the operand stack.
n必须是局部变量表的一个索引，值是一个整型类型，将索引n处的值push到栈顶
Notes
Each of the iload_<n> instructions is the same as iload with an index of <n>, except that the operand <n> is implicit.
每个iload_<n>指令等价于 iload 跟上一个参数n，只不过iload_<n>的n是隐式的。

## iadd
https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.iadd

Operation
Add int
整数相加
Format
iadd
Forms

iadd = 96 (0x60)

Operand Stack
..., value1, value2 →

..., result

Description
Both value1 and value2 must be of type int. The values are popped from the operand stack. The int result is value1 + value2. The result is pushed onto the operand stack.

The result is the 32 low-order bits of the true mathematical result in a sufficiently wide two's-complement format, represented as a value of type int. If overflow occurs, then the sign of the result may not be the same as the sign of the mathematical sum of the two values.

Despite the fact that overflow may occur, execution of an iadd instruction never throws a run-time exception.

value1和value2必须是整型的，这些整数来自于操作数栈，即从操作数栈弹出来，整型的结果是value1加value2，然后将结果推送到栈顶。

结果是底位排序的整型类型，如果相加之后溢出，那么得到的结果不是数学意义上的结果，尽管会有溢出的可能，但是即使溢出了，也不会抛出运行时异常

## ireturn
https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.ireturn

Operation
Return int from method
方法返回
Format

ireturn
Forms
ireturn = 172 (0xac)

Operand Stack
..., value →

[empty]

Description
The current method must have return type boolean, byte, short, char, or int. The value must be of type int. If the current method is a synchronized method, the monitor entered or reentered on invocation of the method is updated and possibly exited as if by execution of a monitorexit instruction (§monitorexit) in the current thread. If no exception is thrown, value is popped from the operand stack of the current frame (§2.6) and pushed onto the operand stack of the frame of the invoker. Any other values on the operand stack of the current method are discarded.
当前方法必须返回一个Boolean、 byte, short, char, 或者 int的类型的值，如果方法是synchronized修饰的，那么进入monitor或者冲进入monitor，之后会有monitorexit就会方法退出，如果没有异常，返回值就是栈顶弹出的元素，返回的元素在调用者的栈帧里边会被推送到栈顶，当前方法的栈帧里边的其他所有元素都会被丢弃掉。

The interpreter then returns control to the invoker of the method, reinstating the frame of the invoker.

Run-time Exceptions
If the Java Virtual Machine implementation does not enforce the rules on structured locking described in §2.11.10, then if the current method is a synchronized method and the current thread is not the owner of the monitor entered or reentered on invocation of the method, ireturn throws an IllegalMonitorStateException. This can happen, for example, if a synchronized method contains a monitorexit instruction, but no monitorenter instruction, on the object on which the method is synchronized.

Otherwise, if the Java Virtual Machine implementation enforces the rules on structured locking described in §2.11.10 and if the first of those rules is violated during invocation of the current method, then ireturn throws an IllegalMonitorStateException.
