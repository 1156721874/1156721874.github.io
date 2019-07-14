---
title: git(六)-标签与diff
date: 2018-10-04 12:02:49
tags: [git,标签,diff]
categories: git
---

新建标签，标签有两种：轻量量级标签（lightweight）与带有附注标签
（annotated）
• 创建⼀一个轻量量级标签
• git tag v1.0.1
• 创建⼀一个带有附注的标签
• git tag -a v1.0.2 -m ‘release version’
• 删除标签
• git tag -d tag_name

操作：

```
Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git tag v1.0

Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git tag
v1.0

Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git tag -a v1.2 -m 'v1.2 released'

Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git tag
v1.0
v1.2
```

查找：

```
$ git tag -l 'v1.0'
v1.0

```
删除：

```
Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git tag -d v1.0
Deleted tag 'v1.0' (was 080a6d7)

Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git tag
v1.2

```
标签不依赖特定的分支：

```
Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git tag
v1.2

Administrator@CeaserWang MINGW64 /e/Study/mygit (dev)
$ git checkout master
Switched to branch 'master'

Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ git tag
v1.2

```

**git blame命令：**

blame的作用是查看文件的修改是哪个作者操作的。

```
$ git blame test.txt
1806ac5e (ceaser 2017-07-30 11:57:14 +0800 1) first commit
1806ac5e (ceaser 2017-07-30 11:57:14 +0800 2) second commit
25db944e (ceaser 2017-07-30 11:57:56 +0800 3) third commit
821425dc (ceaser 2017-07-30 11:58:26 +0800 4) fourth commit
9b95dda7 (ceaser 2017-07-30 14:53:25 +0800 5) hello java
9b95dda7 (ceaser 2017-07-30 14:53:25 +0800 6) hello node
```

**git  diff命令：**
diff比较的是暂存区和工作区的内容的不同。
```
$ git diff
diff --git a/test.txt b/test.txt
index 4151b86..e304045 100644
--- a/test.txt  //暂存区文件
+++ b/test.txt  //工作区文件
@@ -4,3 +4,4 @@ third commit
 fourth commit
 hello java
 hello node
+hello python  //工作区比暂存区多了一行
```
git diff HEAD 比较的是最新的提交和工作区的差别，ＨＥＡＤ可以换成某一个提交ｉｄ

```
$ git diff HEAD
diff --git a/test.txt b/test.txt
index e304045..d18bc0f 100644
--- a/test.txt
+++ b/test.txt
@@ -2,6 +2,3 @@ first commit
 second commit
 third commit
 fourth commit
-hello java
-hello node
-hello python

```
　
git diff  --cached commit_id 比较的最新的提交和暂存区的差别。
![这里写图片描述](20170730170532741.png)
