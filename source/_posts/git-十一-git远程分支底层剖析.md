---
title: git(十一)-git远程分支底层剖析
date: 2018-10-04 13:50:38
tags: [git,远程分支]
categories: git
---

标签的删除：
git push origin :refs/tags/v1.0
<!-- more -->
git push origin --delete tag v5.0
删除本地标签：
git tag -d v1.0
标签推送的完整的写法：
git push origin refs/tags/v1.0:refs/tags/v1.0

单独从远程拉取某个标签：
git fetch origin tag v1.0

游离的分支可以通过git remote prune origin删除掉，所谓的游离分支指的是：开发者A执行git push origin --delete dev删除一个远程分支，然后开发者B执行git pull的时候，B所在的分支dev就是游离的。

在缺省情况下，refspec会被git remote add命令所自动生成，git会获取远端上refs/heads下的所有引用，并将它们写到本地的refs/remote/origin目录下，所以，如果远端上有一个master分支，你在本地就可以通过下面几种方式访问它们的历史记录：
git log origin/master
git log remotes/origin/master
git log refs/remotes/origin/master

将远程的master分支拉取到本地对应myaster：
git fetch origin master:refs/remotes/origin/mymaster

在.git目录下进入config文件：
![这里写图片描述](20170801224506574.png)
可以看到本地和远程的对应关系。
在.git/refs/下边有三个目录：
heads/  remotes/  tags/
分别是本地的指针、远程的分支指针，以及标签的指针，指向的都是当前分支指向的提交id：
![这里写图片描述](20170801224804261.png)

 标签里边的内容：


```
Administrator@CeaserWang MINGW64 /e/Study/mygit/.git/refs/tags (GIT_DIR!)
$ cat v1.0
b76e5510bdde8e3e0209b16037865eeecca890ff

Administrator@CeaserWang MINGW64 /e/Study/mygit/.git/refs/tags (GIT_DIR!)
$ cat v2.0
0b1af7c771e8de24167e97caf7af6448d33370c4

```
如果是轻量级标签，里边的id是commitid，如果是带有注释的标签，里边的id是tag自身的id，这个id指向其所对应的commitid，因为带有注释的标签除了存储指向commitid之外，还要存储注释。
