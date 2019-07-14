---
title: 设计模式(3)- 状态设计模式State
date: 2018-09-28 20:23:38
tags: DesignPatterns
categories: DesignPatterns
---
![这里写图片描述](20151010152832034.png)
![这里写图片描述](20151010145641255.png)
状态模式用来改变对象的行为，当状态发生变化时，行为也随着发生变化，和switch分支语句有点类似，比如如下的代码：

```
public class Creature{
     private Boolean isFrog = true;//标识
     public void greet(){
           if(isForg){
		System.out.println(“Ribbet!”);
	   }else{
		System.out.println(“Darling!”);
	   }
     }
     //转换标识
     public void kiss(){
	isForg = false;
     }
     public static void main(String[] args){
           Creature creature = new Creature();
           creature.greet();
           creature.kiss();
           creature.greet();
     }
}

```
greet()方法在业务复杂的时候if else会很多，而替换为状态模式就变得优雅了许多：
简单的状态模式
```
public class Creature{
    //状态接口
    private interface State{
          String response();
    }
    private class Forg implements State{
          public String response(){
	   return “Ribbet!”;
          }
    }
    private class Prince implements State{
          public String response(){
	   return “Darling!”;
          }
    }
    private State state = new Forg();
    public void greet(){
          System.out.println(state.response);
    }
    public void kiss(){
          state = new Prince();
    }
    public static void main(String[] args){
          Creature creature = new Creature();
          creature.greet();
          creature.kiss();
          creature.greet();
    }
}

```
在状态模式中可以有多个状态，同时对应多个分支程序;

```
//状态接口
interface State{
    void operation1();
    void operation2();
    void operation3();
}
//状态实现类1
class implementation1 implements State{
    public void operation1(){
        System.out.println(“Implementation1.operation1()”);
    }
    public void operation2(){
        System.out.println(“Implementation1.operation2()”);
    }
   public void operation3(){
        System.out.println(“Implementation1.operation3()”);
    }
}
//状态实现类2
class implementation2 implements State{
    public void operation1(){
        System.out.println(“Implementation2.operation1()”);
    }
    public void operation2(){
        System.out.println(“Implementation2.operation2()”);
    }
   public void operation3(){
        System.out.println(“Implementation2.operation3()”);
    }
}
//服务提供者
class ServiceProvider{
    private State state;
    public ServiceProvider(State state){
         this.state = state;
    }
    //状态更改
    public void changeState(State newState){
         state = newState;
    }
    public void service1(){
          //……
          state.operation1();
          //……
          state.operation3();
    }
    public void service2(){
          //……
          state.operation1();
          //……
          state.operation2();
    }
    public void service3(){
          //……
          state.operation3();
          //……
          state.operation2();
    }
}
public class StateDemo{
    private ServiceProvider sp = new ServiceProvider(new Implementation1());
    private void run(ServiceProvider sp){
         sp.service1();
         sp.service2();
         sp.service3();
    }
    public static void main(String[] args){
        StateDemo demo = new StateDemo();
        demo.run(sp);
        sp.changeState(new Implementation2());
        demo.run(sp);
    }
}

```
状态模式和代理模式有相似之处，都有目标对象和代理的相似概念
但是他们之间是有区别的：
1.代理模式目标对象只有一个，而状态模式可以有多个目标对象，即，多个状态。
2.代理模式是为了控制目标对象的访问，状态模式是为了根据状态或者标示判断使用哪个目标。
