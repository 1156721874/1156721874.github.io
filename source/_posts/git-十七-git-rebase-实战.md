---
title: git(十七) git rebase 实战
date: 2018-10-04 14:04:30
tags: [git,rebase]
categories: git
---

我们新建三个分支分别是master、dev、test,之后在dev分支的test.txt文件新建2个提交，在test分支的test.txt文件新建2个提交。
切换到test分支，然后执行git rebase dev 我们要将dev分支的提交应用到test分支：
![这里写图片描述](20170805204123755.png)
然后在test分支执行git rebase dev

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git rebase dev
First, rewinding head to replay your work on top of it...
Applying: [test branch] add -test1- in text.txt //将test的第一次提交应用到dev的最后一个节点
error: Failed to merge in the changes.
Using index info to reconstruct a base tree...
M       test.txt
Falling back to patching base and 3-way merge...
Auto-merging test.txt
CONFLICT (content): Merge conflict in test.txt
Patch failed at 0001 [test branch] add -test1- in text.txt
The copy of the patch that failed is found in: .git/rebase-apply/patch

When you have resolved this problem, run "git rebase --continue".
If you prefer to skip this patch, run "git rebase --skip" instead.
To check out the original branch and stop rebasing, run "git rebase --abort".


Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 1/2)
$ cat test.txt
master1
<<<<<<< HEAD
dev1
dev2
=======
test1
>>>>>>> [test branch] add -test1- in text.txt
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 1/2)
$ git status
rebase in progress; onto f28df0d
You are currently rebasing branch 'test' on 'f28df0d'.//对dev 的'f28df0d'应用补丁。
  (fix conflicts and then run "git rebase --continue")
  (use "git rebase --skip" to skip this patch)//使用dev的补丁，废弃test的修改。
  (use "git rebase --abort" to check out the original branch)//终止rebase过程

Unmerged paths:
  (use "git reset HEAD <file>..." to unstage)
  (use "git add <file>..." to mark resolution)

        both modified:   test.txt

no changes added to commit (use "git add" and/or "git commit -a")


```

git rebase --abort的意思是终止当前rebase的操作，回到原始状态。

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 1/2)
$ git rebase --abort

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ cat test.txt
master1
test1
test2

```

刚才演示了abort的效果，我们重新rebase回到rebase状态：

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git rebase dev
First, rewinding head to replay your work on top of it...
Applying: [test branch] add  a line  in test.txt
error: Failed to merge in the changes.
Using index info to reconstruct a base tree...
M       test.txt
Falling back to patching base and 3-way merge...
Auto-merging test.txt
CONFLICT (content): Merge conflict in test.txt
Patch failed at 0001 [test branch] add  a line  in test.txt
The copy of the patch that failed is found in: .git/rebase-apply/patch

When you have resolved this problem, run "git rebase --continue".
If you prefer to skip this patch, run "git rebase --skip" instead.
To check out the original branch and stop rebasing, run "git rebase --abort".


Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 1/2)
$ cat test.txt
master1
<<<<<<< HEAD
dev1
dev2
=======
test1
>>>>>>> [test branch] add  a line  in test.txt

```
test.txt文件里边的冲突部分是dev分支的“dev1 dev2”2行和test分支的“test1”， 即以dev的2次提交为基准，那么如果执行git rebase --skip所做的操作是：
丢弃test的第一次提交的修改，保留dev的修改：

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 1/2)
$ git rebase --skip
Applying: [test branch] add -test2- in text.txt //应用test的第二次提交。
error: Failed to merge in the changes.
Using index info to reconstruct a base tree...
M       test.txt
Falling back to patching base and 3-way merge...
Auto-merging test.txt
CONFLICT (content): Merge conflict in test.txt
Patch failed at 0002 [test branch] add -test2- in text.txt
The copy of the patch that failed is found in: .git/rebase-apply/patch

When you have resolved this problem, run "git rebase --continue".
If you prefer to skip this patch, run "git rebase --skip" instead.
To check out the original branch and stop rebasing, run "git rebase --abort".


Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 2/2)
$ cat test.txt
master1
<<<<<<< HEAD
dev1
dev2
=======
test1
test2 //test2出现。
>>>>>>> [test branch] add -test2- in text.txt

```
此时如果我们再次执行git rebase --skip 就会将test的第二次提交丢弃，保留dev的修改：

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 2/2)
$ git rebase --skip

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ cat test.txt
master1
dev1
dev2

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$

```
可以看到保留的2次的dev出现在文件里边，即“dev1 “和”dev2”这2次提交。
同时我们看一下git log：

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git log
commit f28df0d2c6fcb11d34e7551d5bb9b337aa46b259 (HEAD -> test, dev)
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 20:38:36 2017 +0800

    [dev  branch] add -dev2- in test.txt

commit 9ad27e0c99795978f259af4d2e17b99b77448f91
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 20:38:22 2017 +0800

    [dev  branch] add -dev1- in test.txt

commit 72d9d551a336c1db8976a8d1f595f4d9dbd5569b (master)
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 19:55:40 2017 +0800

    master branch add file test.txt with master1 content

commit 62046ccba0fea0b8e922697312632972edc8f0f8
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 19:48:49 2017 +0800

    master branch add file test.txt with line master1 commtent

```
里边有dev的2次提交的commit id验证了我们所说的。
此时我们切换到dev分支，演示出现冲突的一种情况，上边我们演示的是丢弃test的提交，那么我们接下来演示不丢弃test的提交，切换到dev的时候我们 git merge test，进行的是fast forward：

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$  git checkout dev
Switched to branch 'dev'

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ git merge test
Already up-to-date.
```
我们增加dev3和dev4：

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ cat test.txt
master1
dev1
dev2

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ echo 'dev3' >> test.txt

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ git add test.txt
warning: LF will be replaced by CRLF in test.txt.
The file will have its original line endings in your working directory.

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ git commit -m '[dev branch] add -dev3- in test.txt'
[dev f018dc6] [dev branch] add -dev3- in test.txt
 1 file changed, 1 insertion(+)

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ echo 'dev4' >> test.txt

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ git add test.txt
warning: LF will be replaced by CRLF in test.txt.
The file will have its original line endings in your working directory.

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ git commit -m '[dev branch] add -dev4- in test.txt'
[dev 3d74c2e] [dev branch] add -dev4- in test.txt
 1 file changed, 1 insertion(+)

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ cat test.txt
master1
dev1
dev2
dev3
dev4
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ git log -3
commit 3d74c2ee12b7556cdbd576eb9f6fd9795898ddf6 (HEAD -> dev)
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 21:08:39 2017 +0800

    [dev branch] add -dev4- in test.txt

commit f018dc6f17d1a9b7c835e43064b695dd4b74e8df
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 21:08:23 2017 +0800

    [dev branch] add -dev3- in test.txt

commit f28df0d2c6fcb11d34e7551d5bb9b337aa46b259 (test)
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 20:38:36 2017 +0800

    [dev  branch] add -dev2- in test.txt

```
切换到test分支增加test3 和test4：

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ cat test.txt
master1
dev1
dev2

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ echo 'test3' >> test.txt

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git add test.txt
warning: LF will be replaced by CRLF in test.txt.
The file will have its original line endings in your working directory.

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git commit -m '[test branch] add -test3- in test.txt'
[test 17794bd] [test branch] add -test3- in test.txt
 1 file changed, 1 insertion(+)

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ echo 'test4' >> test.txt

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git add test.txt
warning: LF will be replaced by CRLF in test.txt.
The file will have its original line endings in your working directory.

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git commit -m '[test branch] add -test4- in test.txt'
[test d5a085e] [test branch] add -test4- in test.txt
 1 file changed, 1 insertion(+)

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git log -3
commit d5a085e27b6f25f354c3292078d0069a3605eeaa (HEAD -> test)
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 21:12:56 2017 +0800

    [test branch] add -test4- in test.txt

commit 17794bda63b337577ad0da88826c28ef2b17ba67
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 21:12:43 2017 +0800

    [test branch] add -test3- in test.txt

commit f28df0d2c6fcb11d34e7551d5bb9b337aa46b259
Author: ceaser <ceaserwang@outlook.com>
Date:   Sat Aug 5 20:38:36 2017 +0800

    [dev  branch] add -dev2- in test.txt
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ cat test.txt
master1
dev1
dev2
test3
test4

```
test分支下执行git rebase dev:

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git rebase dev
First, rewinding head to replay your work on top of it...
Applying: [test branch] add -test3- in test.txt
error: Failed to merge in the changes.
Using index info to reconstruct a base tree...
M       test.txt
Falling back to patching base and 3-way merge...
Auto-merging test.txt
CONFLICT (content): Merge conflict in test.txt
Patch failed at 0001 [test branch] add -test3- in test.txt
The copy of the patch that failed is found in: .git/rebase-apply/patch

When you have resolved this problem, run "git rebase --continue".
If you prefer to skip this patch, run "git rebase --skip" instead.
To check out the original branch and stop rebasing, run "git rebase --abort".


Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 1/2)
$ cat test.txt
master1
dev1
dev2
<<<<<<< HEAD
dev3
dev4
=======
test3
>>>>>>> [test branch] add -test3- in test.txt

```
此时出现的冲突我们先保留test3：
vi test.txt 删除456行：
![这里写图片描述](20170805211736486.png)

```
$ cat test.txt
master1
dev1
dev2
test3

```
执行git rebase --continue

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 1/2)
$ git add test.txt

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test|REBASE 1/2)
$ git rebase --continue
Applying: [test branch] add -test3- in test.txt
Applying: [test branch] add -test4- in test.txt

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test) //回到test
$
```
执行之后出现：
Applying: [test branch] add -test3- in test.txt
Applying: [test branch] add -test4- in test.txt
我们保留了test3的提交，test4就是比test3多了一次提交，直接就成功了。

查看文件只保留了test的提交：
```
$  cat test.txt
master1
dev1
dev2
test3
test4
```
test的日志：
![这里写图片描述](20170805212448530.png)

如果我们在dev分支执行merge test会执行fast forward：

```
Administrator@CeaserWang MINGW64 /e/Study/git_rebase (test)
$ git checkout dev
Switched to branch 'dev'

Administrator@CeaserWang MINGW64 /e/Study/git_rebase (dev)
$ git merge test
Updating 3d74c2e..9dcfcec
Fast-forward
 test.txt | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```
我们用gitk看一下提交历史：
他的整个提交历史是一条直线
![这里写图片描述](20170805213018895.png)
总的来说rebase的操作是将分叉的情况形成一条直线，但是会修改git的提交历史。

将test的提交应用到dev：
1、git checkout test
2、git rebase dev 以dev为基准将test的提交进行回放，挨个的应用到dev上去，然后test的那些提交就会废弃。
等价于git merge dev

git merge 和git rebase区别：
merge不会修改提交历史，rebase会修改提交历史。
rebase只应用于本地没有提交的代码，如果应用到已经提交到远程的分支不要应用，不然会非常的麻烦，get merge可以应用于远程分支。
