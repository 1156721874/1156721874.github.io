---
title: jvm原理（25）Java字节码文件结构剖析
date: 2018-10-04 16:42:44
tags: java字节码解析
categories: jvm
---

编写java文件：
```
<!-- more -->
public class MyTest1 {
    private int a = 1;

    public int getA() {
        return a;
    }

    public void setA(int a) {
        this.a = a;
    }
}
```
我要要看一下java文件对应的class文件的结构，定位到工程的out\production\classes下边执行：
```
javap -c com.twodragonlake.jvm.bytecode.MyTest1
```
得到字节码文件结构：
```
Compiled from "MyTest1.java"
public class com.twodragonlake.jvm.bytecode.MyTest1 {
  public com.twodragonlake.jvm.bytecode.MyTest1();
    Code:
       0: aload_0
       1: invokespecial #1                  // Method java/lang/Object."<init>":()V
       4: aload_0
       5: iconst_1
       6: putfield      #2                  // Field a:I
       9: return

  public int getA();
    Code:
       0: aload_0
       1: getfield      #2                  // Field a:I
       4: ireturn

  public void setA(int);
    Code:
       0: aload_0
       1: iload_1
       2: putfield      #2                  // Field a:I
       5: return
}
```
也可以使用 javap -verbose com/twodragonlake/jvm/bytecode/MyTest1
打印更多信息：
```
Classfile /E:/Study/intelIde/jvm_lecture/out/production/classes/com/twodragonlake/jvm/bytecode/MyTest1.class
  Last modified 2018-7-28; size 507 bytes
  MD5 checksum 372d96fd3e5e97ce3e964e7f9e1e2d67
  Compiled from "MyTest1.java"
public class com.twodragonlake.jvm.bytecode.MyTest1
  minor version: 0
  major version: 52
  flags: ACC_PUBLIC, ACC_SUPER
Constant pool:
   #1 = Methodref          #4.#20         // java/lang/Object."<init>":()V
   #2 = Fieldref           #3.#21         // com/twodragonlake/jvm/bytecode/MyTest1.a:I
   #3 = Class              #22            // com/twodragonlake/jvm/bytecode/MyTest1
   #4 = Class              #23            // java/lang/Object
   #5 = Utf8               a
   #6 = Utf8               I
   #7 = Utf8               <init>
   #8 = Utf8               ()V
   #9 = Utf8               Code
  #10 = Utf8               LineNumberTable
  #11 = Utf8               LocalVariableTable
  #12 = Utf8               this
  #13 = Utf8               Lcom/twodragonlake/jvm/bytecode/MyTest1;
  #14 = Utf8               getA
  #15 = Utf8               ()I
  #16 = Utf8               setA
  #17 = Utf8               (I)V
  #18 = Utf8               SourceFile
  #19 = Utf8               MyTest1.java
  #20 = NameAndType        #7:#8          // "<init>":()V
  #21 = NameAndType        #5:#6          // a:I
  #22 = Utf8               com/twodragonlake/jvm/bytecode/MyTest1
  #23 = Utf8               java/lang/Object
{
  public com.twodragonlake.jvm.bytecode.MyTest1();
    descriptor: ()V
    flags: ACC_PUBLIC
    Code:
      stack=2, locals=1, args_size=1
         0: aload_0
         1: invokespecial #1                  // Method java/lang/Object."<init>":()V
         4: aload_0
         5: iconst_1
         6: putfield      #2                  // Field a:I
         9: return
      LineNumberTable:
        line 26: 0
        line 27: 4
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0      10     0  this   Lcom/twodragonlake/jvm/bytecode/MyTest1;

  public int getA();
    descriptor: ()I
    flags: ACC_PUBLIC
    Code:
      stack=1, locals=1, args_size=1
         0: aload_0
         1: getfield      #2                  // Field a:I
         4: ireturn
      LineNumberTable:
        line 30: 0
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0       5     0  this   Lcom/twodragonlake/jvm/bytecode/MyTest1;

  public void setA(int);
    descriptor: (I)V
    flags: ACC_PUBLIC
    Code:
      stack=2, locals=2, args_size=2
         0: aload_0
         1: iload_1
         2: putfield      #2                  // Field a:I
         5: return
      LineNumberTable:
        line 34: 0
        line 35: 5
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0       6     0  this   Lcom/twodragonlake/jvm/bytecode/MyTest1;
            0       6     1     a   I
}
```
ok，我们也可以使用二进制文件查看器查看class文件的16进制信息（[winhex下载](http://www.x-ways.net/winhex.zip)）：
![这里写图片描述](20180728170150241.png)
16文件查看器里边第一行的CA 就是一个字节的容量（8位bit）。
**1、javap -verbos**
使用javap -verbos 命令分析一个字节码文件时，将会分析该字节码文件的魔数、版本号、常量池、类信息、类的构造方法信息、类变量与成员变量等信息。
**2、魔数：**
所有的.class字节码文件的前4个字节都是魔数，魔数值为固定值：0xCAFEBABE  (詹姆斯.高斯林设计的，蕴意：咖啡宝贝，java的图标是咖啡，哈哈哈，因缺思厅~~~很有意思的一件事情)。
**3、版本号**
魔数之后的4个字节为版本信息，前2个字节表示minor versio（次版本号），后两个字节表示major version（主版本号）。
接下来分析剩下的16进制信息的含义。
00 00 00 34 ：版本信息，00 00 （前2个字节）代表是次版本号（minor version），00 34 （后2个字节）代表的是主版本号major version，34是16进制，转换为10进制：3*16+4=52，52是jdk8，51是jdk7，50是jdk6，以此类推，可以通过java -version命令来验证这一点。
```
$ java -version
java version "1.8.0_111"
Java(TM) SE Runtime Environment (build 1.8.0_111-b14)
Java HotSpot(TM) 64-Bit Server VM (build 25.111-b14, mixed mode)
```
java version "1.8.0_111" 中1.8是主版本号，0是次版本号，111是更新版本号。
这个和javap反编译出来的major version是52是对应的。1.7的jdk不能运行1.8编译出来的class文件。低版本不可以兼容高版本的class文件。
**4、常量池（constant pool）：**
紧接着版本号之后的就是常量池入口，一个java类中定义的很多信息就是由常量池来维护和描述的，可以将常量池看作是Class文件的资源仓库，比如说java类中定义的方法与变量信息，都是存储在常量池中。常量池中主要存储两类常量：字面量与符号引用。字面量比如文本字符串，java中声明为final的常量等，而符号引用如类和接口的全局限定名，字段的名称和描述符，方法的名称和描述符等。
**5、常量池的总体结构：**
java类所对应的常量池主要由常量池数量与常量池数组这2部分共同构成。常量池数量紧跟在主版本号后面，占据2个字节；常量池数组则紧跟在常量池数量之后。常量池数组与一般的数组不同的是，常量池数组中不同的元素的类型、结构都是不同的；但是每一种元素的第一个数据都是一个u1类型，该字节是个标志位，占据1个字节。jvm在解析常量池时，会根据这个ul类型来获取元素的具体类型。
ok那么主版本号之后的2个字节是常量池数量，即 00 34 后边的 00 18 是常量池数量18对应的十进制是1*16+8=24，所以常量池的数量书24个。
但是我们用javap反编译出来的Constant pool是23个，那是因为常量池中元素的个数=常量池数 - 1 （其中0暂时不使用），目的是满足某些常量池索引值的数据在特定情况下需要表达【不引用任何一个常量池】的含义；根本原因在于，索引为0也是一个常量（保留常量），只不过他不位于常量表中，这个常量就对应null值；所以，常量池的索引从1而非0开始。
那么我看到的16进制文件中 00 18  后边的就是实际的一个个的元素体，每个常量元素的大小都是不一样的，那么每个元素的结构是怎样的呢？
![这里写图片描述](20180728182044938.png)
00 18 后边是第一个常量，第一个字节是标志位：0A（十进制10），十进制10在java字节码表格中对应的是CONSTANT_Methodref_info常量，那么后边的2个字节00 04 （十进制4）就是U2（第一个index），即指向声明方法的类描述符CONSTANT_Class_info的索引项，而第二个索引（第二个index）00 14（十进制20） 指向名称及类型描述符CONSTANT_NameAndType_info的索引项，到此0A 00 04 00 14表示了第一个常量。那么我们借助反编译工具看一下4和20的索引位置时什么：

```
   #1 = Methodref          #4.#20         // java/lang/Object."<init>":()V
   #2 = Fieldref           #3.#21         // com/twodragonlake/jvm/bytecode/MyTest1.a:I
   #3 = Class              #22            // com/twodragonlake/jvm/bytecode/MyTest1
   #4 = Class              #23            // java/lang/Object
   #5 = Utf8               a
   #6 = Utf8               I
   #7 = Utf8               <init>
   #8 = Utf8               ()V
   #9 = Utf8               Code
  #10 = Utf8               LineNumberTable
  #11 = Utf8               LocalVariableTable
  #12 = Utf8               this
  #13 = Utf8               Lcom/twodragonlake/jvm/bytecode/MyTest1;
  #14 = Utf8               getA
  #15 = Utf8               ()I
  #16 = Utf8               setA
  #17 = Utf8               (I)V
  #18 = Utf8               SourceFile
  #19 = Utf8               MyTest1.java
  #20 = NameAndType        #7:#8          // "<init>":()V
  #21 = NameAndType        #5:#6          // a:I
  #22 = Utf8               com/twodragonlake/jvm/bytecode/MyTest1
  #23 = Utf8               java/lang/Object
```
4是【 #4 = Class              #23            // java/lang/Object】即指向声明方法的类描述符CONSTANT_Class_info的索引项；
4引用的是23，23对应的是 java/lang/Object，
20是【#20 = NameAndType        #7:#8          // "`<init>`":()V】 指向名称及类型描述符CONSTANT_NameAndType_info的索引项；
20指向的是索引7和8，7是 `<init> `，8是()V
这个和表格里边是一致的。
tip：
**6、数据类型**
在JVM规范中，每个变量/字段都有描述信息，描述信息主要的作用是描述字段的数据类型，方法的参数列表（包括数量、类型与顺序）与返回值。根据描述符规则，基本数据类型和代表无返回值的void类型都用一个大写字符来表示，对象类型则使用字符L加对象的全限名称来表示。为了压缩字节码文件的体积，对于基本数据类型，JVM基本数据类型，JVM都只是使用一个大写字母来表示，如下所示：B - byte, C - char,D - double,F - float,
I - int ,J - long S - short,Z - boolean, V - void ,L - 对象类型，如：Ljava/lang.String;
**7、数组**
对于数组类型来说，每个维度使用一个前置的[来表示，如int[]被记录为[I, String[][]被记录为[[Ljava/lang/String;
**8、描述符**
用描述符描述方法时，按照先参数列表，后返回值的顺序来描述，参数列表按照参数的严格顺序放在一组（）之内，如方法：String getRealNameByIdAndNickName(int id,String name)的描述符为：(I,Ljava/lang/String;)Ljava/lang/String;


接下来是第二个常量：09 00 03   00 15 ，09是标志位对用的是CONSTANT_Fieldref_info,第一个索引指向的是声明字段的类或接口描述符，CONSTANT_Class_info的索引项。
第二个索引：指向字段描述符CONSTANT_NameAndType_info 的索引项。
00 03十进制是索引3 ，3对应的是【#22            // com/twodragonlake/jvm/bytecode/MyTest1】，而22对应的是
【#22 = Utf8               com/twodragonlake/jvm/bytecode/MyTest1】
00 15十进制是21，21对应的是【 #21 = NameAndType        #5:#6          // a:I】，索引5对应的是【 #5 = Utf8               a】
所用6对应的【#6 = Utf8               I】所以第二个常量表示为：【 #3.#21         // com/twodragonlake/jvm/bytecode/MyTest1.a:I】

接下来是第三个常量：07 00 16：
00 16 十进制是22 ，07是常量CONSTANT_CLass_info，只有一个index，指向的是指定权限定名常量项的索引， 00 16 是十进制22，22是【 #22 = Utf8               com/twodragonlake/jvm/bytecode/MyTest1】

接下来是第四个常量：07 00 17 ，07是常量CONSTANT_CLass_info，只有一个index，指向的是指定权限定名常量项的索引，00 17 十进制是23，
23指向的是【#23 = Utf8               java/lang/Object】

接下来是第五个常量：01 00 01 ... (后边的字节大小受00 01的约束) ，01 是常量CONSTANT_UTF8_Info,U2是length表示UTF-8编码的字符串的长度（占2个字节），
然后能是U1，表示bytes，长度是length的UTF-8编码的字符串长度。
所以00 01 是占用2个字节的表示bytes的长度， 00 01 的十进制是1，即后边的一个字节是bytes，后边的一个字节是61，61在asc码表里边是a的索引，即
01 00 01 61 表示字母a。就是反编译出来的第五个常量：【#5 = Utf8               a】。

第六个常量：01 00 01 ，01 是常量CONSTANT_UTF8_Info长度：00 01（十进制1），后边是1个字节是：49，49对应的十进制4*16+9=75，75对应的是字母I，
所以第六个常量：【#6 = Utf8               I】

第七个常量：01 00 06 ，还是常量CONSTANT_UTF8_Info，长度00 06 是6，往后6个字节：
![这里写图片描述](20180729150017678.png)
对应的是`<init>`,即， 【#7 = Utf8               `<init>`】

第八个常量01 00 03 还是是常量CONSTANT_UTF8_Info，长度00 03 是长度3，往后三个字节是：28 29 56 ，对应的是：() V,即常量：
【#8 = Utf8               ()V】

第九个常量：01 00 04 是是常量CONSTANT_UTF8_Info，长度00 04是4个字节，往后4个字节是：43 6F 64 65 表示：Code，即常量：
【#9 = Utf8               Code】

第十个常量：01 00 0F:是常量CONSTANT_UTF8_Info,长度是00 0F（十进制15），往后15个字节：4C 69 6E 65 4E 75 6D 62 65 72 54 61 62 6C 65
表示LineNumberTable，即常量：【#10 = Utf8               LineNumberTable】，

第十一个常量：01 00 12 是常量CONSTANT_UTF8_Info ，长度00 12 （十进制18），往后18个字节是：4C6F63616C5661726961626C655461626C65
对应：LocalVariableTable，即常量：【#11 = Utf8               LocalVariableTable】

第十二个常量：01 00 04 是常量CONSTANT_UTF8_Info，长度00 04 （十进制4），往后4个字节：74686973 表示字符串“this”，即常量：【#12 = Utf8               this】

第十三个常量：01 00 28 是常量CONSTANT_UTF8_Info，长度00 28（十进制40），往后40个字节：4C636F6D2F74776F647261676F6E6C616B652F6A766D2F62797465636F64652F4D7954657374313B 表示字符串Lcom/twodragonlake/jvm/bytecode/MyTest1;
即常量：#13 = Utf8               Lcom/twodragonlake/jvm/bytecode/MyTest1;

第十四个变量：01 00 04  常量CONSTANT_UTF8_Info，长度00 04 （十进制4），往后4个字节：67657441 表示字符串"getA"。即，常量 【#14 = Utf8               getA】

第十五个变量：01 00 03 是常量CONSTANT_UTF8_Info，长度00 03 （十进制3）往后三个字节：28 29 49 表示字符串"()I"，即，常量：【#15 = Utf8               ()I】

14号和15号常量表示了一个方法，表示一个方法：方法的名字和方法的描述法，14号常量时方法的名字，15号常量时方法的描述符（没有参数，但是有一个int的返回值）。

第十六个常量: 01 00 04 常量CONSTANT_UTF8_Info，长度00 04 （十进制4），往后4个字节：73 65 74 41 表示字符串："setA",即常量：【#16 = Utf8        
       setA】
第十七个常量：01 00 04 常量CONSTANT_UTF8_Info，长度00 04 （十进制4），往后4个字节：28 49 29 56 表示字符串"(I)V"，即常量：【#17 = Utf8               (I)V】

16和17号常量表示了一个方法：方法名字setA，方法有一个int类型的入参，但是没有返回值。

第十八个常量：01 00 0A  常量CONSTANT_UTF8_Info，长度00 0A （十进制10），往后10个字节：536F7572636546696C65 表示字符串："SourceFile"，即，常量：【#18 = Utf8               SourceFile】

第十九个常量：01 00 0C 常量CONSTANT_UTF8_Info，长度00 0C（十进制12），往后12个字节：4D7954657374312E6A617661 表示字符串："MyTest1.java"，即常量【#19 = Utf8               MyTest1.java】

18号和19号常量表示当前的class文件是由那个源文件编译出来的。

第20个常量：0c 00 07 常量 CONSTANT_NameAndType_info，此常量拥有2个index，第一个index占2个字节：指向该字段或方法名称常量项的索引；第二个index占2个字节：指向该字段或方法描述符常量项的索引，00 07（十进制7，指向7号常量：【#7 = Utf8               `<init>`】 ,第二个index：00 08 (十进制8)，指向的是8号常量：【#8 = Utf8               ()V】，因此，20号常量：【#20 = NameAndType        #7:#8          // `<init>`:()V】  
20号常量表示的是无参的构造方法。

第21号常量：0C 00 05 00 06 常量 CONSTANT_NameAndType_info，第一个index：00 05（十进制5）指向5号常量：【#5 = Utf8               a】，第二个索引00 06（十进制6）指向的的是6号常量：【#6 = Utf8               I】,因此。21号常量：【#21 = NameAndType        #5:#6          // a:I】

第22个常量：01 00 26 常量CONSTANT_UTF8_Info，长度00 26 （十进制38），往后38个字节：636F6D2F74776F647261676F6E6C616B652F6A766D2F62797465636F64652F4D795465737431 表示字符串："com/twodragonlake/jvm/bytecode/MyTest1"，即，常量：【#22 = Utf8               com/twodragonlake/jvm/bytecode/MyTest1】

第23个常量：01 00 10 常量CONSTANT_UTF8_Info，长度00 10 （十进制10），往后16个字节：6A6176612F6C616E672F4F626A656374 表示字符串："java/lang/Object"，即常量：【#23 = Utf8               java/lang/Object】表示的是MyTest1的父类全量限定名。
