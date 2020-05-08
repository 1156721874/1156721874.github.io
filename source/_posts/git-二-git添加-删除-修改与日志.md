---
title: git(二)-git添加-删除-修改与日志
date: 2018-10-04 11:54:00
tags: [git,删除,修改,日志]
categories: git
---

题外话：
echo 'hello world' >　test2.txt
<!-- more -->
如果此命令敲错了，想跳到开头快捷键：ctrl+A，跳到命令结尾：ctrl+E

**删除操作**
*第一种删除(git rm )：*
我们新建一个test.txt文件提交到远程版本库

```
Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ ls
test.txt  test2.txt

Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ git status
On branch master
nothing to commit, working tree clean
```
然后我们删除test.txt
![这里写图片描述](20170628211149639.png)
并且ls查看目录当前目录test2.txt已经不存在了，证明删除成功。

 此时我们要撤销删除：
 ![这里写图片描述](20170628212228337.png)

我们把test2删除：
![这里写图片描述](20170628212759004.png)

git rm完成2件事情：
1、将被删除的文件放到暂存区，因此 git  reset  HEAD   file 是将文件从暂存区放回已修改区。
2、删除一个文件（一个删除操作） 那么 git checkout -- file 是将删除操作回退。

*第二种删除(直接使用操作系统的rm)：*
还是新建文件test.txt
![这里写图片描述](20170628213030357.png)  

然后我们使用操作系统的rm删除命令 ，然后接着我们要恢复test2：
![这里写图片描述](20170628214736956.png)  

rm操作只做了一件事情：
执行了删除操作，被删除的文件并没有纳入到暂存区当中。此时是commit是非法的，因为暂存区不存在此文件，
那么要想回退只用git checkout -- file就能撤销删除操作。

**重命名**
第一种git rm a b
![这里写图片描述](20170628223000054.png)

![这里写图片描述](20170628223537610.png)  

第二种 mv a b
![这里写图片描述](20170628224553518.png)

**修改提交日志**
我们进行了一次提交，但是提交日志不小心写错了：
![这里写图片描述](20170628225329525.png)

修复：

git commit --amend -m '修正的提交消息'  即 将原来的提交消息覆盖掉。
![这里写图片描述](20170628225522634.png)

git log参数:
git log -3 查看最近的三条
git log pretty=oneline：
![这里写图片描述](20170628230022202.png)  
git log --pretty==format:"%h - %an, %ar :%ｓ"
![这里写图片描述](20170628230312893.png)
