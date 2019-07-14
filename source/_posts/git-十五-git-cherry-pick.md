---
title: git(十五)-git cherry-pick
date: 2018-10-04 14:00:35
tags: [git,cherry-pack]
categories: git
---

cherry-pick：现在有哦2个分支和dev和master，我们在dev下边进行了2此提交，我们这个时候发现这个2个提交不应该发生在dev分支，应该在master分支进行，于是我们把dev当前修改的内容的文件被备份到其他的地方存储，然后将dev回退到之前没有修改的状态，紧接着切换到master分支，将备份的文件覆盖master上对应的文件，完成修正，这种方法能解决问题，但是效率太低了，并且容易出现问题。此时我们可以使用cherry-pick将这2次提交应用到master分支。
演示：
在dev分支做2次提交
![这里写图片描述](20170805121857928.png)

出线2次提交的id：

```
dministrator@CeaserWang MINGW64 /e/Study/child (dev)
$ git log -3
commit db37ad8478eea03a8315fc74bd6f9e16d71b6e43 (HEAD -> dev)
Author: zhangsan <zhangsan@git.com>
Date:   Sat Aug 5 12:16:11 2017 +0800

    add line2

commit f46e43054c20537fbecbc0502223015a61eef957
Author: zhangsan <zhangsan@git.com>
Date:   Sat Aug 5 12:15:34 2017 +0800

    add line 1

commit 4a510291d57a857337d567a43401e3b636da0a0c (origin/master, master)
Author: zhangsan <zhangsan@git.com>
Date:   Sat Aug 5 11:48:40 2017 +0800

    add child4 and child5

```

 此时返现分支搞错了，不应该在dev下边做这2次提交，应该是在master下做，解决方式：

在master使用 git cherry-pick 《dev提交id》

 ![这里写图片描述](20170805122325346.png)
我们能否直接 git cherry-pick   db37ad8478eea03a8315fc74bd6f9e16d71b6e43  这个id呢？做个试验，在dev新增2个提交：

```
commit 6525f476721e83d0254a785b1d3b8a44d3ad2400 (HEAD -> dev)
Author: zhangsan <zhangsan@git.com>
Date:   Sat Aug 5 13:18:54 2017 +0800

    add 2 lines

commit db37ad8478eea03a8315fc74bd6f9e16d71b6e43
Author: zhangsan <zhangsan@git.com>
Date:   Sat Aug 5 12:16:11 2017 +0800

    add line2

```
然后切换到master分支，我们直接 git cherry-pick 6525f476721e83d0254a785b1d3b8a44d3ad2400 :

```
 git cherry-pick 6525f476721e83d0254a785b1d3b8a44d3ad2400
[master 27ffd95] add 2 lines
 Date: Sat Aug 5 13:18:54 2017 +0800
 1 file changed, 2 insertions(+)

Administrator@CeaserWang MINGW64 /e/Study/child (master)
$ cat line.txt
line 1
line2
 line 4
 line 5

```
可以看到可以直接跨commit id 进行操作。

还有一个遗留问题：
dev分支需要还原到初始状态，
初始状态所在位置：
![这里写图片描述](20170805133311617.png)
1、 git checkout aa261fee67458af84f3406d4f132232ca3c8825b

```
$ git checkout aa261fee67458af84f3406d4f132232ca3c8825b
Note: checking out 'aa261fee67458af84f3406d4f132232ca3c8825b'.

You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by performing another checkout.

If you want to create a new branch to retain commits you create, you may
do so (now or later) by using -b with the checkout command again. Example:

  git checkout -b <new-branch-name>

HEAD is now at aa261fe... add welcome in hello.txt

```

2、 git branch -D dev
3、 git checkout -b dev
