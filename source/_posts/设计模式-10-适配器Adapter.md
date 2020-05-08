---
title: 设计模式(10)-适配器Adapter
date: 2018-09-28 20:54:14
tags: DesignPatterns
categories: DesignPatterns
---
思想：将一个类的接口转换成另外一个接口，使得原本由于接口不兼容而不能一起工作的那些类可以一起工作。
场景：该 模式的应用场景太多了，很多需要的功能模块的接口和我们需要的不完全一致或者有多余或不足，但是需要和我们的系统协同工作，通过Adapter把 它包装一下就能让使它接口兼容了。
实现：定 义一个Adapter类，包含需要包装的类，实现需要的其它接口，调用被包装的类的方法来实现需要 的接口。
<!-- more -->
重构成本：低。
Adapter适配器模式是将两个不兼容的类组合在一起使用。生活中笔记本电脑和手机等数码产品的充电器就是一个适配器，将家用220V的交流电转换为笔记本或手机正常工作所需的目标电压和电流。适配器起到一种转换和包装的作用。
Adapter设计模式主要目的组合两个不相干类，常用有两种方法：第一种解决方案是修改各自类的接口。但是如果没有源码，或者不愿意为了一个应用而修改各自的接口，则需要使用Adapter适配器，在两种接口之间创建一个混合接口。
Adapter适配器设计模式中有3个重要角色：被适配者Adaptee，适配器Adapter和目标对象Target。其中两个现存的想要组合到一起的类分别是被适配者Adaptee和目标对象Target角色，我们需要创建一个适配器Adapter将其组合在一起。
实现Adapter适配器设计模式有两种方式：组合(compositon, has-a关系)和继承(inheritance,is-a关系)。
对象适配器模式使用组合和继承，UML图如下：
![这里写图片描述](20151031170024613.png)
假设要画图形，有圆形和方形两个类，现在需要一个既可以画圆形又可以画方形的类。
组合关系的Adapter适配器模式如下：

```
//圆形，目标对象
class Cirecle{
	public void drawCircle(){
	System.out.println(“Draw circle”);
}
}
//方形，被适配对象
class Square{
	public void drawSquare(){
	System.out.println(“Draw square”);
}
}
//既可以画圆形，又可以画方形，适配器
public class HybridShape extends Circle{
	private Square square;
	public HybridShape(Square square){
	this.square = square;
}
public void drawSquare(){
	square.drawSquare();
}
}
```
适配器继承目标对象，同时组合被适配对象，如果需要画圆时，直接调用父类的画圆方法即可，如果需要画方，则调用被适配对象的画方形方法。
继承关系的Adapter适配器模式如下：

```
interface ICircle{
	public void drawCircle();
}
interface ISquare{
	public void drawSquare();
}
//圆形
class Cirecle implements ICircle{
	public void drawCircle(){
	System.out.println(“Draw circle”);
}
}
//方形
class Square implements ISquare{
	public void drawSquare(){
	System.out.println(“Draw square”);
}
}
//既可以画圆形，又可以画方形，适配器
public class HybridShape implements ICircle, ISquare{
	private ISquare square;
	private ICircle circle;
	public HybridShape(Square square){
	this.square = square;
}
public HybridShape(Circle circle){
	this.circle = circle;
}
public void drawSquare(){
	square.drawSquare();
}
public void drawCircle(){
	circle.drawCircle();
}
}
```
Java中类不允许多继承，但是可以实现多个接口，继承关系的Adapter适配器设计模式就是利用java可以实现多个接口的特性。
另外在spring中也存在使用适配器的地方，比如[AOP拦截器部分](http://blog.csdn.net/wzq6578702/article/details/45898083)
JDK里面的适配器模式应用：
•java.util.Arrays#asList()
•java.io.InputStreamReader(InputStream)
•java.io.OutputStreamWriter(OutputStream)
•javax.xml.bind.annotation.adapters.XmlAdapter#marshal()
•javax.xml.bind.annotation.adapters.XmlAdapter#unmarshal()
