---
title: git(十二)-git gc
date: 2018-10-04 13:52:13
tags: [git,gitgc]
categories: git
---

在执行git gc之前我们看一下.git目录的一些信息：
refs目录下边有三个文件夹：
![这里写图片描述](20170802195110448.png)
此三个文件夹下边都存在一些本地、远程分支的信息，以及标签的 信息。

执行git gc：
执行完毕之后，heads、remotes、tags下边的内容消失，git并不是删除了这些信息，而是存放在 .git/packed-refs文件里边，即进行了压缩。
![这里写图片描述](20170802195304125.png)
通过里边的内容我们还可以验证带有注释标签的一些信息，v1.0只有一个id指向的就是一个commitid，而带有注释的v2.0有两个id第一id是其本身，第二个是指向的commitid，可以看到id前边有个“^”符号。

此时我们如果在进行一次提交和推送，那么又会在.git/refs/下边出现新的内容记录git的信息：
![这里写图片描述](20170802200643650.png)
如图我们对test.txt进行了提交，在.git/refs/heads和.git/refs/remotes下边出现了新的内容，而不是放在.git/packed-refs文件里边。

此外git gc还会对每次提交的文件进行压缩，我们知道git和svn的区别就是git是全量记录文件的提交，而svn是记录变化量，既然git 记录的是全量的文件，那是不是会很大，占用空间，并且是怎么存放的呢？
其实所有的提交文件记录都在.git/objects/里边：
![这里写图片描述](20170802202341094.png)
执行git gc之后文件都会=消失，转而放在pack目录下：

```
$ git gc
Counting objects: 18, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (10/10), done.
Writing objects: 100% (18/18), done.
Total 18 (delta 4), reused 15 (delta 4)

Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ ls .git/objects/
info/  pack/
Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ ls .git/objects/pack/
pack-94d0a6b4da258363c6f774e525a8615469b64e03.idx  pack-94d0a6b4da258363c6f774e525a8615469b64e03.pack
```

复习：
将一个文件从暂存区删除，但是保存在工作区：
git rm --cached test.txt
重命名文件：
git mv  test.txt test2.txt = git rm test.txt  + git add  test2.txt
重命名远程仓库：
git remote rename origin origin2
删除远程仓库:
git remote rm origin
