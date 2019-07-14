---
title: git(五)-checkout进阶与stash
date: 2018-10-04 12:00:52
tags: [git,checkout,stash]
categories: git
---

**git checkout -- test.txt原理：**
作用：**丢弃掉相对于暂存区最后一个添加的文件内容所做的变更。**
实际操作：
![这里写图片描述](20170730130722488.png)

范围：针对于工作区

**git reset HEAD test.txt作用：**
将之前添加到暂存区（stage index）的内容从暂存区移除到工作区。
实际操作：
```
$ git status
On branch master
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

        modified:   test.txt


Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ git reset HEAD test.txt
Unstaged changes after reset:
M       test.txt

Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ git status
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

        modified:   test.txt

no changes added to commit (use "git add" and/or "git commit -a")

```

git checkout 2424324 作用：
![这里写图片描述](20170730134220453.png)
**重点内容**
上面我们生成一个游离分支，接下来做一下修改在其上。
![这里写图片描述](20170730142812736.png)

整个过程：
![这里写图片描述](20170730142855766.png)  

**分支改名：**
git branch -m master master2

**stash命令：**
• 保存现场
• git stash
• git stash save ‘name XXX ’
• git stash list
• 恢复现场
• git stash apply（stash内容并不不删除，需要通过git stash drop
stash@{0}⼿手动删除）
• git stash pop（恢复的同时也将stash内容删除）
• git stash apply stash@{0}
git stash drop stash@{0} 删除保存的记录



实际操作:
我们在master分支创建新的分支dev，然后在master分支修改文件并且进行一次提交，接着切换到dev分支，在dev分支修改也进行一次提交，此时如果再次执行切换到master分支会出错：

```
$ git checkout master
error: Your local changes to the following files would be overwritten by checkout:
        test.txt
Please commit your changes or stash them before you switch branches.
Aborting

```
这在我们的日常开发中非常常见，从主干拉了2个分支A和B，开发者者在A分支开发了一半，但是紧接着要转到B分支进行开发，但是A分支的代码是不能提交的，因为没有开发完毕，才是就需要暂存A分支的内容，下次回到A的时候从暂存中恢复出来。
![这里写图片描述](20170730150702916.png)
