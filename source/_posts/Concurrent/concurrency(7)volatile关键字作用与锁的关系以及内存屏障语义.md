---
title: concurrency(7)volatile关键字作用与锁的关系以及内存屏障语义
date: 2020-05-04 14:00:45
tags: [volatile 内存屏障 JMM与happen-befor规则]
categories: concurrency
---

### volatile关键字
volatile英文翻译：易变的，挥发物，不稳定的
#### volatile的三个方面的作用：
- 实现long/double类型变量的原子操作
  valatile double a = 1.0
  64位的double和long的在写写和写读的时候存在中间状态，其他线程会读到这种中间状态，volatile可以让其成为原子操作。
  volatile可以确保对变量写操作的原子性，但是不具备排他性，另外的重要一点在于：使用锁可能会导致线程上下文切换（内核态与用户态的切换），但是使用volatile比不会出现这种情况。
  volatile int a = b + 2; 这种情况不会保证a操作的原子性，因为可能2个线程对b 的取值会不同，即使b也是被volatile修饰也是不行的，也会存在多线程操作的场景，因此volatile不要以这种形式使用。
  volatile int a = a++; 也是不行的。
  如下2中方式推荐的，符合volatile的底层的原理：
  volatile int count = 1;
  volatile boolean flag = false;

  如果要实现volatile写操作的原子性，那么在等号右侧的赋值变量中就不能出现被多线程所共享的变量，哪怕这个变量也是个volatile也是不可以。
  volatile Date date = new Date();这样也是不行的，因为创建Date对象首先在堆里边创建对象，第二步是将堆的地址赋值给date变量，也不是原子性的，它只能保证堆地址赋值给date变量是原子性的。
- 防止指令重排序
  在多线程的情况下，指令重排序会带来临界资源访问混乱问题，出现错乱。
  ```
    int a = 1;
    String a = "hello";
    内存屏障(Release Barrier,释放屏障)
    volatile boolean v = false; //写入操作
    内存屏障(Store Barrier，存储屏障)

    内存屏障(Load Barrier,加载屏障)
    boolean v1 = v; // 保证v是最新的
    内存屏障(Acquire Barrier,获取屏障)
    int a = 1;
    String a = "hello";
  ```
  Release Barrier：防止下面的volatile与上面的所有操作的指令重排序。volatile写操作以上的所有指令被发布，其他的线程得到共享变量都是volatile写之前的状态，防止了指令重排序。
  Store Barrier： 重要的作用是刷新处理器的缓存，结果是可以确保该存储屏障之前的操作所生成的结果对于其他处理器来说都可见。

  Load Barrier: 可以刷新处理器缓存，同步其他处理器对该volatile变量的修改结果。
  PS：Store Barrier和Load Barrier一般搭配使用，刷新处理器缓存存储完毕之后就能立马加载过来，这两个屏障一起保证了数据在多处理器之间是可见的。
  Acquire Barrier: 可以防止上面的volatile读取操作与下面的所有操作语句的指令重排序。
  PS： Acquire Barrier和Release Barrier一般搭配使用，这两个屏障一起保证了临界区中的任何读写操作不可能被重排序到临界区之外。

  对于volatile关键字变量的读写操作，本质上都是通过内存屏障来执行的。
  内存屏障兼具了两方面能力：1. 防止指令重排序；2. 实现变量内存的可见性.
  1. 对于读取操作，volatile可以确保该操作与其后续的所有读写操作都不会进行指令重排序。
  2. 对于修改操作来说，volatile可以确保该操作与其上面的所有读写操作都不会进行指令重排序。
  PS：先读后写
  **以上的屏障对于原生类型是可以的，但是对于引用类型来说是不适用的。**
  比如对于一个被volatile修饰的集合对象的检索并且赋值这个过程volatile是不能保证防止其内存重排序的，但是一个集合类型的引用赋值给另一个集合类型的引用这个操作是可以防止指令重排序的。
- 实现变量的可见性
  当使用volatile修饰变量时，应用就不会从寄存器中获取该变量的值，而是从内存(高速缓存)中获取。

  **防止指令重排序与实现变量可见性都是通过一种手段来实现的：内存屏障(memory barrier)**



### volatile和锁
volatile不是排他的，而锁是可以排他的，对一个volatile的写是可以同时多个线程进行的，只不过volatile能保证原子性而已。
#### volatile和锁的相似的两个地方：
- 确保变量的内存可见性
- 防止指令重排序

**锁同样具备变量内存可见性与防止指令重排序的功能。**
monitorenter
  内存屏障(Acquire Barrier,获取屏障)
  ......
  内存屏障(Release Barrier,释放屏障)
monitorexit

进入monitorenter之后插入一个Acquire Barrier取得缓存当中变量最新的值;
在monitorexit之前插入Release Barrier，刷新处理器的缓存，使得其他的处理器能看到当前处理器对变量的修改

使用volatile的性能会有所消耗，如果没有使用volatile关键字，取值会从寄存器里边取出，而使用了volatile会去内存里边取值，内存的速度肯定比寄存器的速度慢，所以使用volatile的性能会有所损耗。


### JMM与happen-befor规则

1. 变量的原子性问题
2. 变量的可见性问题
3. 变量修改的时序问题


#### happen-befor重要规则
1. 顺序执行规则（限定在单个线程上的）
  该线程的每个动作都bappen-befor它的后面的动作。指令重排序和happen-befor是可以同时存在的。
  如果abc三个动作之间没有关系。a不一定必须先执行在b之前，但是如果abc之间有关系，那么肯定会防止指令重排序。
2. 隐式锁(monitor)规则
  同一把锁，unlock一定happen-befor lock，之前的线程对于同步代码块的作用所有的执行结果对于后续获取锁的线程来说都是可见的。
3. volatile读写规则
  对于一个volatile变量的写操作，一定会happen-befor后续对该变量的读操作。
4. 多线程的启动规则
  Thread对象的start方法happen-befor该线程run方法中的任何一个动作，包括在其中启动的任何子线程。
5. 多线程的终止规则
  一个线程启动了一个子线程，并且调用了子线程的join方法等待期结束，那么当子线程结束后，父线程的接下来的所有操作都可以看到子线程run方法中的执行结果。
6. 线程的中断规则
  可以调用interrupt方法来中断线程，这个调用happen-befor对该线程中断的检查(isInterrupted)。
