---
title: CopyOnWriteArrayList和CopyOnWriteArraySet
date: 2018-10-04 10:16:57
tags: [CopyOnWriteArrayList, CopyOnWriteArraySet]
categories: Thread
---

CopyOnWriteArrayList和CopyOnWriteArraySet应用场合一般 是在读多写少的情况，比如黑名单，他们之间的区别就是list和set的区别，但是在实现上CopyOnWriteArraySet使用CopyOnWriteArrayList来实现的，就像set使用了hashmap，treeset使用treemap，下面先看CopyOnWriteArrayList的添加操作.

```
    /**
     * Inserts the specified element at the specified position in this
     * list. Shifts the element currently at that position (if any) and
     * any subsequent elements to the right (adds one to their indices).
     *
     * @throws IndexOutOfBoundsException {@inheritDoc}
     */
    public void add(int index, E element) {
        final ReentrantLock lock = this.lock;
        //加锁，CopyOnWriteArrayList是线程安全的
        lock.lock();
        try {
            Object[] elements = getArray();
            int len = elements.length;
            if (index > len || index < 0)
                throw new IndexOutOfBoundsException("Index: "+index+
                                                    ", Size: "+len);
            Object[] newElements;
            int numMoved = len - index;
            //如果位移实在列表的尾部，那么直接复制数组，，使用Arrays.copyOf()
            if (numMoved == 0)
                newElements = Arrays.copyOf(elements, len + 1);
            else {
            //否则，以index为中心点，把原始数组分成2段，index左边一段，右边一段，index放要插入的数据元素，放进新的数组newElements。
                newElements = new Object[len + 1];
                System.arraycopy(elements, 0, newElements, 0, index);
                System.arraycopy(elements, index, newElements, index + 1,
                                 numMoved);
            }
            newElements[index] = element;
            //覆盖原来的数组，原来的数组失去引用，被jvm回收
            setArray(newElements);
        } finally {
         //解锁
            lock.unlock();
        }
    }
```

再看remove方法：

```
    /**
     * Removes the first occurrence of the specified element from this list,
     * if it is present.  If this list does not contain the element, it is
     * unchanged.  More formally, removes the element with the lowest index
     * <tt>i</tt> such that
     * <tt>(o==null&nbsp;?&nbsp;get(i)==null&nbsp;:&nbsp;o.equals(get(i)))</tt>
     * (if such an element exists).  Returns <tt>true</tt> if this list
     * contained the specified element (or equivalently, if this list
     * changed as a result of the call).
     *
     * @param o element to be removed from this list, if present
     * @return <tt>true</tt> if this list contained the specified element
     */
    public boolean remove(Object o) {
        final ReentrantLock lock = this.lock;
        //加锁，
        lock.lock();
        try {
            Object[] elements = getArray();
            int len = elements.length;
            if (len != 0) {
                // Copy while searching for element to remove
                // This wins in the normal case of element being present
                int newlen = len - 1;
                Object[] newElements = new Object[newlen];

                for (int i = 0; i < newlen; ++i) {
                    if (eq(o, elements[i])) {
                        // found one;  copy remaining and exit
                        //找到要删除的元素，然后将元素后面的数据复制到新的数组里边
                        for (int k = i + 1; k < len; ++k)
                            newElements[k-1] = elements[k];
                        setArray(newElements);
                        return true;
                    } else
                        //不是删除数据，直接进入新的数组
                        newElements[i] = elements[i];
                }

                // special handling for last cell
                //最后一个元素的单独处理
                if (eq(o, elements[newlen])) {
                    setArray(newElements);
                    return true;
                }
            }
            return false;
        } finally {
        //解锁
            lock.unlock();
        }
    }
```
再看CopyOnWriteArraySet
内部维护了一个

```
    private final CopyOnWriteArrayList<E> al;
```

因为CopyOnWriteArraySet元素不能重复，所以CopyOnWriteArraySet的add用的是CopyOnWriteArrayList的addIfAbsent，
```
    public boolean add(E e) {
        return al.addIfAbsent(e);
    }
```
删除操作用的是CopyOnWriteArrayList的remove

```
    public boolean remove(Object o) {
        return al.remove(o);
    }
```
