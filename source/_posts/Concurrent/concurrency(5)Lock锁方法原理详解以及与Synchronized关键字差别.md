---
title: concurrency(5)Lock锁方法原理详解以及与Synchronized关键字差别
date: 2020-01-04 13:12:45
tags: [concurrency Lock]
categories: concurrency
---

### ReentrantLock

可重入锁的example：
```
public class MyTest1 {
    private Lock lock = new ReentrantLock();

    public void myMethod1() {
        try {
            lock.lock();
            System.out.println("myMethod1 invoked");
        } finally {
            lock.unlock();
        }
    }

    public void myMethod2() {
        try {
            lock.lock();
            System.out.println("myMethod2 invoked");
        } finally {
            lock.unlock();
        }
    }

    public static void main(String[] args) {
        MyTest1 myTest1 = new MyTest1();
        Thread t1 = new Thread(() -> {
            for(int i = 0;i<10;i++){
                myTest1.myMethod1();
                try {
                    Thread.sleep(2000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        });

        Thread t2 = new Thread(() -> {
            for(int i = 0;i<10;i++){
                myTest1.myMethod2();
                try {
                    Thread.sleep(300);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        });
        t1.start();
        t2.start();
    }
}
```
输出：
```
myMethod1 invoked
myMethod2 invoked
myMethod2 invoked
myMethod2 invoked
myMethod2 invoked
myMethod2 invoked
myMethod2 invoked
myMethod2 invoked
myMethod1 invoked
myMethod2 invoked
myMethod2 invoked
myMethod2 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
```
如果我们把myMethod1方法里边的  lock.unlock();注释掉。然后再去运行得到的输出：
```
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
```
myMethod1打印了10次，但是程序还是没有退出。
原因是线程t1使用了ReentrantLock可重入，但是没有解锁，导致线程t2一致无法获取到锁，t1由于可以重入，所以打印了10次，而t2一直在等待获取到锁，程序一直没有结束。

再次改造,这次我们使用tryLock：
```
public class MyTest1 {
    private Lock lock = new ReentrantLock();

    public void myMethod1() {
        try {
            lock.lock();
            System.out.println("myMethod1 invoked");
        } finally {
          //  lock.unlock();
        }
    }

    public void myMethod2() {
        boolean result = false;
        try {
            result = lock.tryLock(800, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        if(result){
            System.out.println("get the lock");
        }else {
            System.out.println("can`t get the lock");
        }
    }


    public static void main(String[] args) {
        MyTest1 myTest1 = new MyTest1();
        Thread t1 = new Thread(() -> {
            for(int i = 0;i<10;i++){
                myTest1.myMethod1();
                try {
                    Thread.sleep(2000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        });

        Thread t2 = new Thread(() -> {
            for(int i = 0;i<10;i++){
                myTest1.myMethod2();
                try {
                    Thread.sleep(300);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        });
        t1.start();
        t2.start();
    }
}
```

打印结果：
```
myMethod1 invoked
can`t get the lock
can`t get the lock
myMethod1 invoked
can`t get the lock
myMethod1 invoked
can`t get the lock
can`t get the lock
myMethod1 invoked
can`t get the lock
can`t get the lock
myMethod1 invoked
can`t get the lock
can`t get the lock
myMethod1 invoked
can`t get the lock
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
myMethod1 invoked
```
这个时候t2就不会出现阻塞。

### 关于Lock和Synchronized关键字在锁的处理方式的重要差别

- 锁的获取方式： 前者是通过程序代码的方式由开发者手工获取，后者是通过jvm来获取（无需开发者干预）
- 具体实现方式：前者是通过java代码的方式来实现，后者是通过jvm底层来实现（无需开发者关注）
- 锁的释放方式：前者务必通过unlock()方法在finally块中手工释放，后者通过jvm来释放（无需开发者关注）
- 锁的具体类型：前者提供了多种，如公平锁，非公平锁，后者与前者均提供了可重入性。
