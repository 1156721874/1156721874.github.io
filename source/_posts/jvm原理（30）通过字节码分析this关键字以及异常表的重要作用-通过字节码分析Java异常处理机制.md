---
title: jvm原理（30）通过字节码分析this关键字以及异常表的重要作用&通过字节码分析Java异常处理机制
date: 2018-10-04 17:12:55
tags: [this关键字,异常表，字节码分析]
categories: jvm
---

**通过字节码分析this关键字以及异常表的重要作用**
编写代码：

```
public class MyTest3 {
    public void test(){
        try {
            InputStream inputStream = new FileInputStream("test.text");
            ServerSocket serverSocket = new ServerSocket(6666);
            serverSocket.accept();
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }catch (Exception ex){

        }finally {
            System.out.println("finally");
        }

    }
}
```

反编译:

```
public void test();
    descriptor: ()V
    flags: ACC_PUBLIC
    Code:
      stack=3, locals=4 (局部变量是4个), args_size=1 (参数大小是1个，即this)
         0: new           #2                  // class java/io/FileInputStream
         3: dup
         4: ldc           #3                  // String test.text
         6: invokespecial #4                  // Method java/io/FileInputStream."<init>":(Ljava/lang/String;)V
         9: astore_1
        10: new           #5                  // class java/net/ServerSocket
        13: dup
        14: sipush        6666
        17: invokespecial #6                  // Method java/net/ServerSocket."<init>":(I)V
        20: astore_2
        21: aload_2
        22: invokevirtual #7                  // Method java/net/ServerSocket.accept:()Ljava/net/Socket;
        25: pop
        26: getstatic     #8                  // Field java/lang/System.out:Ljava/io/PrintStream;
        29: ldc           #9                  // String finally
        31: invokevirtual #10                 // Method java/io/PrintStream.println:(Ljava/lang/String;)V
        34: goto          92
        37: astore_1
        38: aload_1
        39: invokevirtual #12                 // Method java/io/FileNotFoundException.printStackTrace:()V
        42: getstatic     #8                  // Field java/lang/System.out:Ljava/io/PrintStream;
        45: ldc           #9                  // String finally
        47: invokevirtual #10                 // Method java/io/PrintStream.println:(Ljava/lang/String;)V
        50: goto          92
        53: astore_1
        54: aload_1
        55: invokevirtual #14                 // Method java/io/IOException.printStackTrace:()V
        58: getstatic     #8                  // Field java/lang/System.out:Ljava/io/PrintStream;
        61: ldc           #9                  // String finally
        63: invokevirtual #10                 // Method java/io/PrintStream.println:(Ljava/lang/String;)V
        66: goto          92
        69: astore_1
        70: getstatic     #8                  // Field java/lang/System.out:Ljava/io/PrintStream;
        73: ldc           #9                  // String finally
        75: invokevirtual #10                 // Method java/io/PrintStream.println:(Ljava/lang/String;)V
        78: goto          92
        81: astore_3
        82: getstatic     #8                  // Field java/lang/System.out:Ljava/io/PrintStream;
        85: ldc           #9                  // String finally
        87: invokevirtual #10                 // Method java/io/PrintStream.println:(Ljava/lang/String;)V
        90: aload_3
        91: athrow
        92: return
      Exception table:
         from    to  target type
             0    26    37   Class java/io/FileNotFoundException
             0    26    53   Class java/io/IOException
             0    26    69   Class java/lang/Exception
             0    26    81   any
            37    42    81   any
            53    58    81   any
      LineNumberTable:
        line 36: 0
        line 37: 10
        line 38: 21
        line 46: 26
        line 47: 34
        line 39: 37
        line 40: 38
        line 46: 42
        line 47: 50
        line 41: 53
        line 42: 54
        line 46: 58
        line 47: 66
        line 43: 69
        line 46: 70
        line 47: 78
        line 46: 81
        line 49: 92
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
           10      16     1 inputStream   Ljava/io/InputStream;
           21       5     2 serverSocket   Ljava/net/ServerSocket;
           38       4     1     e   Ljava/io/FileNotFoundException;
           54       4     1     e   Ljava/io/IOException;
            0      93     0  this   Lcom/twodragonlake/jvm/bytecode/MyTest3;
      StackMapTable: number_of_entries = 5
        frame_type = 101 /* same_locals_1_stack_item */
          stack = [ class java/io/FileNotFoundException ]
        frame_type = 79 /* same_locals_1_stack_item */
          stack = [ class java/io/IOException ]
        frame_type = 79 /* same_locals_1_stack_item */
          stack = [ class java/lang/Exception ]
        frame_type = 75 /* same_locals_1_stack_item */
          stack = [ class java/lang/Throwable ]
        frame_type = 10 /* same */
```

字节码中args_size=1，意思是方法参数个数是1个，但是在源代码当中test的参数是空的，原因是：
     * 对于java类中的每一个实例方法(非static方法)。其在编译后所生成的字节码当中，方法参数的数量总是
     * 会比源代码中方法参数的数量多一个（多了this），它位于方法的第一个参数位置处；这样，我们就可以在java
     * 的实例方法中使用this来去访问当前对象的属性以及其他方法。
     *
     * 这个操作是在编译期间完成的，既由javac编译器在编译的时候将对this的访问转化为对一个普通实例方法参数的访问；
     * 接下来在运行期间，由jvm在调用实例方法时，自动向实例方法传入该this参数，所以，在实例方法的局部变量表中，
     * 至少会有一个指向当前对象的局部变量。

  locals=4 有四个局部变量：this、inputStream、serverSocket、最后我们有三个catch，那么java在运行的时候如果抛出异常，那么只有一个catch
  可以进入，catch上都有一个ex变量，所有说第四个局部变量就是某一个ex。
max_stack:
表示这个方法运行的任何时刻所能达到的操作数栈的最大深度。
max_locals表示方法执行期间创建的局部变量的数目，包含用来表示传入的参数的局部变量。
exception_table:表项由start_pc\end_pc/handler_pc/catch_type组成。
start_pc 和 end_pc表示在code数组中的从start_pc到end_pc处（包含start_pc，不包含end_pc）的指令抛出的异常
会由这个表项来处理
handler_pc表示处理异常的代码的开始处。
catch_type表示会被处理的异常类型，他指向常量池里的一个异常类，当catch_type为时，表示处理所有异常。

**通过字节码分析Java异常处理机制**
在jclasslib插件中我们找到test方法的code的字节码：

```
0 new #2 <java/io/FileInputStream>
 3 dup
 4 ldc #3 <test.text>
 6 invokespecial #4 <java/io/FileInputStream.<init>>
 9 astore_1 //到此是完成 InputStream inputStream = new FileInputStream("test.text");
10 new #5 <java/net/ServerSocket>
13 dup
14 sipush 6666
17 invokespecial #6 <java/net/ServerSocket.<init>>
20 astore_2 到此是完成ServerSocket serverSocket = new ServerSocket(6666);
21 aload_2
22 invokevirtual #7 <java/net/ServerSocket.accept>  到此是 serverSocket.accept();
25 pop
26 getstatic #8 <java/lang/System.out>
29 ldc #9 <finally>
31 invokevirtual #10 <java/io/PrintStream.println>  到此是finally块的打印
34 goto 92 (+58)
37 astore_1
38 aload_1
39 invokevirtual #12 <java/io/FileNotFoundException.printStackTrace>
42 getstatic #8 <java/lang/System.out>
45 ldc #9 <finally>
47 invokevirtual #10 <java/io/PrintStream.println>
50 goto 92 (+42)
53 astore_1
54 aload_1
55 invokevirtual #14 <java/io/IOException.printStackTrace>
58 getstatic #8 <java/lang/System.out>
61 ldc #9 <finally>
63 invokevirtual #10 <java/io/PrintStream.println>
66 goto 92 (+26)
69 astore_1
70 getstatic #8 <java/lang/System.out>
73 ldc #9 <finally>
75 invokevirtual #10 <java/io/PrintStream.println>
78 goto 92 (+14)
81 astore_3
82 getstatic #8 <java/lang/System.out>
85 ldc #9 <finally>
87 invokevirtual #10 <java/io/PrintStream.println>
90 aload_3
91 athrow
92 return

```
行开始会看到有很多goto语句，因为程序在运行的时候才会知道到底跳转到那个catch，所以需要提前罗列出所有的跳转的goto语句，当抛出异常的时候match到某个异常，直接goto到某个catch块。

Exception table:

| Nr.0|start_pc|end_pc|handler_pc|catch_type|
|-|-|-|-|-|
|0	|0 |26	|37	|cp_info #11 FileNotFoundException |
|1	|0	|26	|49|cp_info #13 IOException |
|2	|0	|26	|61|cp_info #15 Exception |
|3	|0	|26	|73|cp_info #0  |


第一条解释：
从第0行到26行（不包含26）所有的代码某一行如果出现异常就会被捕捉到如果是FileNotFoundException就会goto到37条handler，37是【37 astore_1】  [astore_1](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-6.html#jvms-6.5.astore_n)
是赋值 操作，发生异常时，会将异常对象赋值给FileNotFoundException e的e，让e指向这个抛出的异常对象。然后就是到了finally块：

```
42 getstatic #8 <java/lang/System.out>
45 ldc #9 <finally>
47 invokevirtual #10 <java/io/PrintStream.println>
```
打印输出，然后紧接着是：50 goto 92 (+42) 跳转到92条，92条是【92 return】 也就是程序方法返回。
第二条也是同样的道理，只不过是跳转到IOException 的catch的处理，然后也会执行finally块，然后跳转92条是【92 return】 程序返回。

另外编译器还自动生成了一个Any类型的异常，用于处理其他不可预期的异常处理。同样的这个any类型的也会最终执行finally，然后程序方法返回。即：
|3	|0	|26	|73|cp_info #0  |

 * java字节码对于异常的处理方式：
 * 1、统一采用异常表的方式对异常进行处理。
 * 2、在jdk1.4.2之前的版本中，并不是使用异常表的方式来对异常进行处理的，而是采用特定的指令方式。
 * 3、当异常处理在finally语句块时，线代的jvm采取的处理方式是将finally语句块的字节码拼接到每一个catch块后面，
 * 换句换说，程序中存在多少个catch块，就会在每一个catch块后面重复多少个finally语句块的字节码。

**lineNumberTables:**
java字节码和java源代码的行号对应关系，用于调试。

**localVariableTable**

| Nr.0 | start_pc |  length |  index  | name |  descriptor  |
| ------ | ------ | ------ | ------ | ------ |
| 0	|10	|16	|1	|cp_info #24	|cp_info #25 inputStream|
|1  |21	|5  |2	|cp_info #26	|cp_info #27 serverSocket|
|2	|0	|85	|0	|cp_info #21	|cp_info #22 this|
三个局部变量this、serverSocket、inputStream 另外的ex的赋值，需要在运行时才能看到，此处是静态编译无法看到。
