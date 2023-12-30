---
title: git(十)-git refspec以及远程标签
date: 2018-10-04 13:48:29
tags: [git,refspec,远程标签]
categories: git
---

HEAD标记：HEAD文件是一个指向你当前所在分支的引用标示符，该文件内部并不包含SHA-1值，而是指向另外一个引用的指针。
![这里写图片描述](2018/10/04/git-十-git-refspec以及远程标签/20170801210357580.png)
<!-- more -->

当执行git commit命令时，git会创建一个commit对象，并且将这个commit对象的parent指针设置为HEAD所指向的引用的ＳＨＡ－１值。
另外凡是只要修改了ＨＥＡＤ的ｇｉｔ操作都会计入reflog。
实际上我们可以通过底层命令symbolic-ref来实现对HEAD文件的修改

```
Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git symbolic-ref HEAD
refs/heads/dev

Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git symbolic-ref HEAD refs/heads/test

Administrator@CeaserWang MINGW64 /e/Study/mygit (test)
$

```
其他形式不按照准则的会报错：

```
$ git symbolic-ref HEAD askj/ajkaj/ll
fatal: Refusing to point HEAD outside of refs/
```

**标签：**
创建标签：
![这里写图片描述](2018/10/04/git-十-git-refspec以及远程标签/20170801212627322.png)  

**git show v1.0**
```
$ git show v1.0
commit b76e5510bdde8e3e0209b16037865eeecca890ff (HEAD -> test, tag: v2.0, tag: v1.0, origin/test, origin/master, origin/dev, master, dev)
Author: ceaserwang <ceaserwang@outlook.com>
Date:   Tue Aug 1 19:44:50 2017 +0800

    modify

diff --git a/test.txt b/test.txt
index c46f196..dfdd12d 100644
--- a/test.txt
+++ b/test.txt
@@ -1,2 +1,3 @@
 hello java
 hello python
+hello C++

```
**git show v2.0**
```
$ git show v2.0
tag v2.0
Tagger: ceaserwang <ceaserwang@outlook.com>
Date:   Tue Aug 1 21:25:52 2017 +0800

v2.0released

commit b76e5510bdde8e3e0209b16037865eeecca890ff (HEAD -> test, tag: v2.0, tag: v1.0, origin/test, origin/master, origin/dev, master, dev)
Author: ceaserwang <ceaserwang@outlook.com>
Date:   Tue Aug 1 19:44:50 2017 +0800

    modify

diff --git a/test.txt b/test.txt
index c46f196..dfdd12d 100644
--- a/test.txt
+++ b/test.txt
@@ -1,2 +1,3 @@
 hello java
 hello python
+hello C++

```
git show v2.0  显示的详细明显比v1.0多。

将标签推送到远程：
git push的时候默认不会将标签也推送到远程，需要执行:

```
$ git push origin v1.0
Total 0 (delta 0), reused 0 (delta 0)
To https://github.com/1156721874/mygit.git
 * [new tag]         v1.0 -> v1.0

```
在github上面可以看到提交的标签:
![这里写图片描述](2018/10/04/git-十-git-refspec以及远程标签/20170801213504510.png)

将所有本地未推送的标签推送到远程：

```
$ git push origin --tags
Counting objects: 5, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (5/5), done.
Writing objects: 100% (5/5), 349 bytes | 0 bytes/s, done.
Total 5 (delta 4), reused 0 (delta 0)
remote: Resolving deltas: 100% (4/4), done.
To https://github.com/1156721874/mygit.git
 * [new tag]         v1.0 -> v1.0
 * [new tag]         v2.0 -> v2.0
 * [new tag]         v3.0 -> v3.0
 * [new tag]         v4.0 -> v4.0
 * [new tag]         v5.0 -> v5.0
 * [new tag]         v6.0 -> v6.0

```

此时另外一个开发者执行git pull将会把所有的标签拉取下来。
PS：标签和每一次提交时一一对应的，提交的id是一个SHA-1值，不便于记忆，tag是对这次提交的一个别名，可以这么理解。
