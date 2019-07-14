---
title: git(九)-git refspec以及git别名
date: 2018-10-04 13:46:22
tags: [git,refspec以及git别名]
categories: git
---

**别名：**
我们在使用git命令的时候，有些命令使用的非常频繁，因此我们可以使用别名减少拼写，例如：

```
git config --global alias.br branch
```
![这里写图片描述](20170801193146297.png)
别名配置在~/.gitconfig（用户目录）里边

**refspec：**
新建三个分支：dev、test、master：
然后切换到dev，将devpush到远程仓库出现如下问题：
![这里写图片描述](20170801194728281.png)
原因：
表面意思是远程分支没有dev这个分支，命令提示：

```
 git push --set-upstream origin dev
```
引导我们将当前分支关联到远程的dev，同时新建一个远程的dev分支。

```
$ git push --set-upstream origin dev
Total 0 (delta 0), reused 0 (delta 0)
To https://github.com/1156721874/mygit.git
 * [new branch]      dev -> dev
Branch dev set up to track remote branch dev from origin.
```
PS：git push --set-upstream origin dev和git push  -u origin dev效果是一致的。
提示本地的分支和远程的分支进行了对应，接下来即可push操作:

```
$ git push
Everything up-to-date
```
然后我们去github的页面可以看到出现我们的dev分支。
![这里写图片描述](20170801195813246.png)  
通过命令我们可以看到多出来一个远程分支：

```
$ git branch  -av
* dev                   b76e551 modify
  master                b76e551 modify
  test                  b76e551 modify
  remotes/origin/dev    b76e551 modify
  remotes/origin/master b76e551 modify
```
此时如果另一个开发者执行git pull就可以将dev分支拉回到他的本地，名字是remote/origin/dev,但是这个只是一个远程分支的景象，
执行：

```
git checkout -b dev origin/dev
```
PS：git checkout -b dev origin/dev和git checkout --track  origin/test效果一致。
即可新建一个和远程镜像一致的dev分支。

**删除远程分支：**
第一种方式
首先说一下git push的完整写法：

```
git push origin src:desc
```
src是本地分支的名字，desc是远程分支的名字，因为他们的名字一样因此可以直接git push。
所以我们要删除一个远程分支可以将一个空的分支推送到远程，就是删除操作：
删除dev远程分支：
```
git push origin  :dev
```

第二种方式：

```
git push origin --delete develop
```

有些时候我们在本地的分支叫dev，而在远程分支的名字叫dev2，那么我们怎么处理呢？
写法：
git push --set-upstream origin dev:dev2

在推送的时候使用push的全写：git push origin dev:dev2，即显式指定远程分支的名字。

重命名远程分支：
只有一种方式，就是先删除远程分支，然后在本地重命名再提交到远程分支，即先删除后新增。
