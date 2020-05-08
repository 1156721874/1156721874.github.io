---
title: git(十六) git rebase 原理深度剖析
date: 2018-10-04 14:02:30
tags: [git,rebase]
categories: git
---

rebase：变基，意即改变分支的根基
从某种程度来说，rebase和merge可以完成类似的工作，不过2者的工作方式有显著的差异。
<!-- more -->
**我们先从merge切入看看merge和rebase的差异。**
![这里写图片描述](20170805173058949.png)

merge的2个节点origin和mywork都有公共的祖先c2：
![这里写图片描述](20170805173209090.png)

执行merge：
![这里写图片描述](20170805173254089.png)  

**rebase**
• git checkout mywork
• git rebase origin
![这里写图片描述](20170805173401824.png)	 

![这里写图片描述](20170805173446088.png)  

历史区别：
![这里写图片描述](20170805173535613.png)  

![这里写图片描述](20170805173613469.png)  

**rebase注意事项**
• rebase过程中也会出现冲突
• 解决冲突后，使⽤用git add添加，然后执⾏行行
• git rebase - - continue
• 接下来Git会继续应⽤用余下的补丁
• 任何时候都可以通过如下命令终⽌止rebase，分⽀支会恢复到
rebase开始前的状态
• git rebase - - abort

**rebase最佳实践**
• **不不要对master分⽀支执⾏行行rebase，否则会引起很多
问题**
• **⼀一般来说，执⾏行行rebase的分⽀支都是⾃自⼰己的本地分
⽀支，没有推送到远程版本库**
