---
title: git(四)-分支进阶与版本回退
date: 2018-10-04 11:58:28
tags: [git,版本回退]
categories: git
---

当前只有一个分支：
![这里写图片描述](20170730111032675.png)

刚刚创建了一个dev分支：
![这里写图片描述](20170730111132706.png)

dev分支进行了修改并且提交，形成新的节点：
![这里写图片描述](20170730111230311.png)

将分支进行合并：
![这里写图片描述](20170730111328285.png)
这种merge是一种平fast forward的快进的方式，就是将master的指针指向dev的提交节点位置，不会产生新的提交。

将dev分支删除之后：
![这里写图片描述](20170730111528831.png)

分支 合并冲突，在第三个节点创建feature1分支，然后在feature1进行了一次提交，然后在master进行了一次提交，最后合并：
![这里写图片描述](20170730111839977.png)  

fast-forward：
• 如果可能，合并分⽀支时Git会使⽤用fast-forward模式
• 在这种模式下，删除分⽀支时会丢掉分⽀支信息
• 合并时加上 - - no-ff参数会禁⽤用fast-forward，这样会多出⼀一
个commit id
• git merge - -no-ff dev
• 查看log
• git log - -graph

实际操作验证非快进提交：
![这里写图片描述](20170730112802333.png)

切换到master：
![这里写图片描述](20170730113137409.png)  

然后执行：git merge --no-ff dev

此时出现提交界面：
![这里写图片描述](20170730113325901.png)  

最后我们merge完毕之后看master的日志：
![这里写图片描述](20170730113547340.png)

很明显出现了一次提交，这样就保留了分支不被删除。

**版本的回退：**
当前版本库有四次提交;
![这里写图片描述](20170730115924491.png)

![这里写图片描述](20170730120647419.png)

命令：

```
$ git reset --hard HEAD^
HEAD is now at 25db944 third commit

 $ git reset --hard HEAD^^
HEAD is now at adeef6e fisrt commit in test.txt

$ git reset --hard 8214
HEAD is now at 821425d fourth commit

$ git reset --hard HEAD~2
HEAD is now at 1806ac5 second commit

``
另外我们在回退的时候，在想回去的话，之前的版本号我们没法通过git log命令找到，因为git log记录的是提交记录。
但是我们可以使用git reflog命令得到版本号。git reflog记录的是工作日志。

```
$ git reflog
1806ac5 (HEAD -> master) HEAD@{0}: reset: moving to HEAD~2
821425d HEAD@{1}: reset: moving to 8214
adeef6e HEAD@{2}: reset: moving to HEAD^^
25db944 HEAD@{3}: reset: moving to HEAD^
821425d HEAD@{4}: commit: fourth commit
25db944 HEAD@{5}: commit: third commit
1806ac5 (HEAD -> master) HEAD@{6}: commit: second commit
adeef6e HEAD@{7}: commit (initial): fisrt commit in test.txt

```
