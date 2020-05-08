---
title: 设计模式(6)-工厂模式Factory
date: 2018-09-28 20:29:41
tags: DesignPatterns
categories: DesignPatterns
---
工厂模式有三种：简单工厂模式，抽象工厂模式和工厂方法模式。
1、简单工厂模式
![这里写图片描述](20151011152009034.png)
<!-- more -->
以图形为例：
```
//图形接口
interface Shape(){
	public void draw();
}
//圆形
class Circle implements Shape{
	public void draw(){
	System.out.println(“Circle is drawing”);
}
}
//矩形
class Rectangle implements Shape{
	public void draw(){
	System.out.println(“Rectangle is drawing”);
}
}
//图形工厂
class ShapeFactory{
	public static Shape createShape(String name) throws InstantiationException,
                                      IllegalAccessException, 
                                      ClassNotFoundException
 	{
	//使用java的反射机制来产生对象实例
	return (Shape)class.forName(name).newInstance();
}
}
public class ShapeDemo{
	public static void draw(Shape shape){
	shape.draw();
}
	public static void main(String[] args){
	draw(ShapeFactory.createShape(“Circle”));
	draw(ShapeFactory.createShape(“Rectangle”));
}
}
```
2、抽象工厂模式
抽象工厂模式中可以包括多个抽象产品类，每个抽象产品类可以产生出多个具体产品类，一个抽象工厂用于定义所需产品的组合形式，抽象工厂派生具体工厂类，这些具体工厂类就是简单工厂模式中的工厂类，具体工厂类负责具体产品实例的创建：

![这里写图片描述](20151011153515037.png)
以换肤为例：

```
//软件皮肤类
class Skin{
	private SkinFactory skinFactory;
	public Skin(SkinFactory factory){
	setSkinFactory(factory);
}
public void setSkinFactory(SkinFactory factory){
	this.skinFactory = factory
}
public void showSkin(){
	System.out.println(“Style=” + factory.getStyle().showStyle() + “, color=” + factory.getColor().showColor());
}
}
//软件Style
interface Style(){
	public void showStyle();
}
//IOS style
class IOSStyle implements Style{
	public void showStyle(){
	System.out.println(“This is IOS style”);
}
}
//Android style
class AndroidStyle implements Style{
	public void showStyle(){
	System.out.println(“This is Android style”);
}
}
//软件Color
interface Color(){
	public void showColor();
}
//IOS color
class IOSColor implements Color{
	public void showColor(){
	System.out.println(“This is IOS color”);
}
}
//Android color
class AndroidColor implements Color{
	public void showColor(){
	System.out.println(“This is Android color”);
}
}
//抽象皮肤工厂
interface SkinFactory{
	public Style getStyle();
	public Color getColor();
}
//IOS皮肤工厂
class IOSSkinFactory implements SkinFactory{
	public Style getStyle(){
		return new IOSStyle();
}
	public Color getColor(){
		return new IOSColor();
}
}
//Android皮肤工厂
class AndroidSkinFactory implements SkinFactory{
	public Style getStyle(){
		return new AndroidStyle();
}
	public Color getColor(){
		return new AndroidColor();
}
}
public class SkinDemo{
	public static void main(String[] args){
		//显示一套IOS皮肤
	Skin skin = new Skin(new IOSSkinFactory());
	skin.showSkin();
	//换一套Android的皮肤
	skin.setSkinFactory(new AndroidSkinFactory());
	skin.showSkin();
}
}
```
3、工厂方法模式
工厂方法中也只包含一个抽象产品类，抽象产品类可以派生出多个具体产品类。工厂方法定义一个用于创建产品的接口，让子类决定实例化哪一个类，使得类的实例化延迟到子类。
![这里写图片描述](20151011154239096.png)
以汽车制造为例：

```
//汽车接口
interface ICar{
	public void run();
}
//奔驰车
class BenzCar implements ICar{
	public void run(){
	System.out.println(“Benz car run”);
}
}
//宝马车
class BMWCar implements ICar{
	public void run(){
	System.out.println(“BMW car run”);
}
}
//抽象汽车工厂
abstract class CarFactory{
	public abstract ICar createCar();
}
//奔驰车工厂
class BenzCarFactory extends CarFactory{
	public ICar createCar(){
	return new BenzCar();
}
}
//宝马车工厂
class BMWCarFactory extends CarFactory{
	public ICar createCar(){
	return new BMWCar();
}
}
public class FactoryMethodDemo{
	public static void main(String[] args){
	CarFactory factory = new BenzCarFactory();
	ICar car = factory.createCar();
	car.run();
	factory = new BMWCarFactory();
	car = factory.createCar();
	car.run();
}
}
```
工厂模式中，重要的是工厂类，而不是产品类。产品类可以是多种形式，多层继承或者是单个类都是可以的。但要明确的，工厂模式的接口只会返回一种类型的实例，这是在设计产品类的时候需要注意的，最好是有父类或者共同实现的接口。
使用工厂模式，返回的实例一定是工厂创建的，而不是从其他对象中获取的。工厂模式返回的实例可以不是新创建的，返回由工厂创建好的实例也是可以的。
三种工厂模式的区别：
简单工厂 ： 用来生产同一等级结构中的任意产品，对于增加新的产品，无能为力。
工厂方法 ：用来生产同一等级结构中的固定产品，支持增加任意产品。
抽象工厂 ：用来生产不同产品族(由不同产品组合成的一套产品)的全部产品，对于增加新的产品，无能为力；支持增加产品族。
