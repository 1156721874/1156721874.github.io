---
title: jvm原理（2）常量的本质含义与反编译及助记符详解
date: 2018-10-04 15:38:15
tags: 常量池 助记词
categories: jvm
---

先运行一段程序：

```
public class MyTest2 {

    public static void main(String[] args) {
        System.out.println(MyParent2.str);
    }

}
class MyParent2{
    public static final String  str =  "hello world ";
    static {
        System.out.println("MyParent2 static block");
    }
}
```
输出的结果就是 ： hello world
注意我们在str变量的修饰上加了final修饰符，如果我们不加final修饰符，那么打印的结果会是：

```
MyParent2 static block
hello world
```
加了final关键字之后str就会变成常量：
常量在编译阶段会存入到调用这个常量方法所在的类的常量池中
本质上，调用类并没有直接引用到定义常量的类，因此并不会触发定义常量的类的初始化
注意：我们指的是将常量存放到了Mytest2的常量池中，之后Mytest2与MyParent2就没有任何关系了
甚至：我们可以将MyParent的class文件删除
我们可以试验一下：
![这里写图片描述](20180225165758669.png)
程序照样输出 ，而且不会报错，这就验证了上边的介绍。
我们反编译一下Mytest2：
![这里写图片描述](20180225171208887.png)  
出现一个助记符ldc
助记符：
ldc:表示将int、float、或是String类型的常量从常量池中推送至栈顶。
其实还有其他的助记符：
![这里写图片描述](20180225171559932.png)
bipush:表示将单字节(-128 ~ 127 )的常量推送到栈顶
sipush : 表示将一个短整型常量值(-32768 ~ 32767)推送到栈顶
iconst_1 表示将int类型1推送到栈顶(iconst_m1 -- iconst_5)
这些助记符其实可以在jdk的com.sun.org.apache.bcel.internal.generic里边可以看到对用的类，是从apache基金会吸收过来的。
