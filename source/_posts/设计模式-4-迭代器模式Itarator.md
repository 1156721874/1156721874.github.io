---
title: 设计模式(4)-迭代器模式Itarator
date: 2018-09-28 20:26:05
tags: DesignPatterns
categories: DesignPatterns
---
**思想**：提 供一种方法顺序访问一个聚合对象中各个元素, 而又不需暴露该对象的内部表示。
**场景**：访 问一个聚合对象的内容而无需暴露它的内部表示。支持对聚合对象的多种遍历。为遍历不同的聚合结构提供一个统一的接口(即, 支持多态迭代)。
**实现**：其 实就是定义一个逻辑上类似一个指针的迭代类。专门用于这种迭代工作。如果对C++ STL火锅功夫 学习的朋友一定不会陌生啦。实际使用过一下就明白了。除了功能之外，他给我最大的感受就是他让我熟悉的for语句，变长了好多。^-^
<!-- more -->
迭代器模式由以下角色组成：
1 迭代器角色（Iterator）：迭代器角色负责定义访问和遍历元素的接口。
2 具体迭代器角色（Concrete Iterator）：具体迭代器角色要实现迭代器接口，并要记录遍历中的当前位置。
3 容器角色（Container）：容器角色负责提供创建具体迭代器角色的接口。
4 具体容器角色（Concrete Container）：具体容器角色实现创建具体迭代器角色的接口——这个具体迭代器角色于该容器的结构相关。
迭代器模式UML图如下：
![这里写图片描述](2018/09/28/设计模式-4-迭代器模式Itarator/20151010164947153.png)

迭代器模式在java中的集合框架中用的非常极致：
![这里写图片描述](2018/09/28/设计模式-4-迭代器模式Itarator/20151010165653094.png)

```
//迭代器 ，该接口提供了迭代遍历的通用方法
public interface Iterator {
      boolean hasNext();
      Object next();
      void remove();
}
//容器迭代化接口，凡是实现此接口的集合容器距可以生成相应的迭代器
public interface Iterable<T>{
      //产生迭代器，将容器对象转换为迭代器对象
      Iterator<T> interator();
}
//java集合框架的根接口，该接口继承了容器迭代化接口，因此java中的集合都可以被迭代
public interface Collection<E> extends Iterable<E>
```
自定义迭代器：
以ArrayList为例子

```
public class MyIterator implements Iterable {
      //存放数据的集合
      private ArrayList list;
     //负责创建具体迭代器角色的工厂方法
     public Iterator iterator() {
          return new Itr(list);
     }
    //作为内部类的具体迭代器角色
    private class Itr implements Iterator {
           ArrayList myList;
          int position = 0;
           public Itr(ArrayList list) {
                  this.myList = list;
           }
           public Object next() {
                  Object obj = myList.get(position);
                  position++;
                  return obj;
          }
          public boolean hasNext() {
                 if (position >= myList.size()) {
                       return false;
                 } else {
                     return true;
                 }
           }
        //不支持remove操作
        public void remove(){
              throw new UnsupportedOperationException(
            "Alternating MyIterator does not support remove()");
}
 }
 }
```
此处可以为MyIterator 指定被迭代对象的构造器。
Iterator模式的优点：
(1).实现功能分离，简化容器接口。让容器只实现本身的基本功能，把迭代功能委让给外部类实现，符合类的设计原则。
(2).隐藏容器的实现细节。
(3).为容器或其子容器提供了一个统一接口，一方面方便调用；另一方面使得调用者不必关注迭代器的实现细节。
(4).可以为容器或其子容器实现不同的迭代方法或多个迭代方法。
