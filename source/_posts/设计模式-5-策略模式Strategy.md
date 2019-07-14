---
title: 设计模式(5)-策略模式Strategy
date: 2018-09-28 20:28:00
tags: DesignPatterns
categories: DesignPatterns
---
![这里写图片描述](20151011142912495.png)
**思想：**定 义一系列的算法,把它们一个个封装起来, 并 且使它们可相互替换。本模式使得算法可独立于使用它的客户而变化。
**场景：**该 模式实际上也可以理解为一种Bridge模式的变种。只是它突出的是，一般当我们把一个类或者一组 类的一些代码独立成一个Strategy类的时候，我们可能会为同样接口的这些算法定义多个接口一 致，但是实现方法不同的版本，并在需要的时候灵活的替换这些算法。
**实现：**实 现方式同Bridge模式。
**重构成本：**中。

```
//文本替换策略
abstract class TextStrategy {
    protected String text;

    public TextStrategy(String text) {
        this.text = text;
    }
    public abstract String replace();
}  
//替换算法1：将文本中"@r@n"替换为"@n"
class StrategyOne extends TextStrategy {
    public StrategyOne(String text) {
        super(text);
    }
    public String replace() {
        System.out.println(“StrategyOne:”);
        String result = text.replaceAll("@r@n", "@n"));
        return result;
    }
}  
//替换算法2：将文本中"@n"替换为"@r@n"
class StrategyTwo extends TextStrategy {
    public StrategyTwo(String text) {
        super(text);
    }
    public String replace() {
        System.out.println(“StrategyTwo:”);
        String result = text.replaceAll(“@n", "@r@n"));
        return result;
    }
}  
public class TextCharChange {
    public static void replace(TextStrategy strategy) {
        strategy.replace();
    }
public static void main(String[] args){
	String testText1 = "This is a test text!!@n Oh! Line Return!!@n";
        String testText2 = This is a test text!!@r@n Oh! Line Return@r@n";
TextCharChange.replace(new StrategyOne(testText2));
    TextCharChange.replace(new StrategyTwo(testText1));
}
}
```
State状态模式和Strategy策略模式非常类似，但是有如下区别：
(1).State状态模式重点在于设定状态变化，根据状态，返回相应的响应。
(2).Strategy策略模式重点在于根据需求直接采用设定的策略，即根据场景选择合适的处理算法，而不需要改变状态。
JDK中策略模式的应用：
•java.util.concurrent.ThreadPoolExecutor.AbortPolicy
•java.util.concurrent.ThreadPoolExecutor.CallerRunsPolicy
•java.util.concurrent.ThreadPoolExecutor.DiscardOldestPolicy
•java.util.concurrent.ThreadPoolExecutor.DiscardPolicy
•java.util.Comparator
