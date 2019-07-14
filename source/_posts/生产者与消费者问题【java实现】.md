---
title: 生产者与消费者问题【java实现】
date: 2018-09-28 20:42:49
tags: Producer Consumer
categories: Thread
---
**定义面包类：**

```
package ProducerAndConsumer;

public class Bread {
public int id;
public int producerid;
public Bread(int id,int producerid){
	this.id = id;
	this.producerid = producerid;
}
}

```
**定义一个篮子，里边放一个数组存放面包：**

```
package ProducerAndConsumer;

public class Basket {
	private Bread[] basket = new Bread[10];
    private int index = 0;
	public synchronized void push(Bread bread) {
	//发现篮子满了，就在那里不停的等着
	System.out.println("生产者等待。。。。。。");
		while(this.index==basket.length){
			try {
			//（一个生产线程）开始不停等待  
                // 他需要等待顾客(一个消费线程)把它叫醒
				this.wait();
			} catch (InterruptedException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
		     // 唤醒一个正在等待的线程，如果唤醒的线程为生产线程，则又会进入等待状态，  
        // 如果为消费线程，则因生产线程生产了面包的缘故，消费线程可以进行消费  
		this.notify();
		basket[this.index] = bread;
		this.index++;
		System.out.println("生产者"+bread.producerid+"生产一个面包");		
	}

	public synchronized void pop(int index){
		while(this.index==0){
			System.out.println("消费者等待。。。。。。。。");
			try {
				this.wait();
			} catch (InterruptedException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
		this.notify();
		basket[this.index]=null;
		this.index--;
		System.out.println("消费者"+index+"取走一个面包");
	}

}

```
**定义生产者者：**

```
package ProducerAndConsumer;

public class Producer implements Runnable{
private int id;
private Basket basket;
public Producer(int id,Basket basket){
	this.id = id;
	this.basket = basket;
}
	public void run() {
		for(int i=0;i<=10;i++){
			Bread bread = new Bread(i,this.id);
			basket.push(bread);
			try {
				Thread.sleep(1);
			} catch (InterruptedException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
	}

}

```
**定义消费者：**

```
package ProducerAndConsumer;

public class Consumer implements Runnable{
private int id;
private Basket basket;
	public Consumer(int id,Basket basket){
		this.id=id;
		this.basket = basket;
	}
	public void run() {
		for(int i=0;i<=10;i++){
			basket.pop(id);
			try {
				Thread.sleep(1);
			} catch (InterruptedException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
	}

}

```
**测试类：**

```
package ProducerAndConsumer;

public class Launcher {

	public static void main(String[] args) {
		Basket basket = new Basket();
		Producer p1 = new Producer(1,basket);
		Producer p2 = new Producer(2,basket);

		Consumer c1 = new Consumer(1,basket);
		Consumer c2 = new Consumer(2,basket);

		new Thread(p1).start();
		new Thread(p2).start();
		new Thread(c1).start();
		new Thread(c2).start();
	}
}

```
**数据**

```
生产者1生产一个面包
生产者2生产一个面包
消费者1取走一个面包
消费者2取走一个面包
生产者2生产一个面包
消费者1取走一个面包
消费者等待。。。。。。。。
生产者1生产一个面包
消费者2取走一个面包
生产者2生产一个面包
消费者2取走一个面包
生产者1生产一个面包
消费者1取走一个面包
生产者1生产一个面包
消费者1取走一个面包
消费者等待。。。。。。。。
生产者2生产一个面包
消费者2取走一个面包
生产者2生产一个面包
消费者2取走一个面包
消费者等待。。。。。。。。
生产者1生产一个面包
消费者1取走一个面包
生产者2生产一个面包
消费者2取走一个面包
消费者等待。。。。。。。。
生产者1生产一个面包
消费者1取走一个面包
消费者等待。。。。。。。。
消费者等待。。。。。。。。
生产者2生产一个面包
消费者2取走一个面包
消费者等待。。。。。。。。
生产者1生产一个面包
消费者1取走一个面包
生产者2生产一个面包
生产者1生产一个面包
消费者2取走一个面包
消费者1取走一个面包
生产者2生产一个面包
消费者2取走一个面包
消费者等待。。。。。。。。
生产者1生产一个面包
消费者1取走一个面包
消费者等待。。。。。。。。
生产者2生产一个面包
生产者1生产一个面包
消费者2取走一个面包
消费者1取走一个面包
生产者2生产一个面包
消费者2取走一个面包
消费者等待。。。。。。。。
生产者1生产一个面包
消费者1取走一个面包


```
