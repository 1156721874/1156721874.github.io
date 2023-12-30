---
title: git(十四)-git subtree
date: 2018-10-04 13:56:43
tags: [git,subtree]
categories: git
---

git submodule弊端：
 这篇文章指出了submodule的一些问题： http://www.cocoachina.com/industry/20130509/6161.html
<!-- more -->
，还有就是submodule的删除git没有直接的命令操作，需要开发者自己使用若干命令组合完成删除，因此在git的后续版本出现了subtree。

subtree：
新建2个工程一个是parent，一个是subtree
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170803212211962.png)  
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170803212247520.png)  

在父级模块添加子模块作为subtree：
第一：$ git remote add subtree-origin https://github.com/1156721874/child.git
第二： git subtree add --prefix=subtree subtree-origin master --squash
解释：建立一个从master分支拉取的本地仓库subtree ，squash的意思是将子模块的多次提交汇总成一次提交拉取下来。携带此参数，在父级的模块的提交日志中不会出现subtree模块开发者的提交日志，都是父级模块开发者的提交日志。不携带squash参数，才会将subtree的开发者的提交日志一并拉取过来。squash属于merge操作的一个参数和subtree没有关系，这个参数**如果在关联subtree的时候使用了，那么后续的操作也要使用这个参数**，不然会出现问题，问题的原因可能是：我们在push的时候会进行一次merge，而merge操作需要三方协调，合并的2个节点必须要有公共的父亲，但是squash参数形成的节点不会存在它前一个节点的指针，即找不到公共的父亲，因此push的时候会失败。
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170803214030020.png)

子模块内容可以立刻出出现：
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170803214203016.png)

此时我们将parent 工程推送到远程：

```
$ git push
Counting objects: 5, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (3/3), done.
Writing objects: 100% (5/5), 592 bytes | 0 bytes/s, done.
Total 5 (delta 0), reused 0 (delta 0)
To https://github.com/1156721874/mygit.git
   33f9e75..9db9adb  master -> master

```
我们在远程看一下subtree的样子：
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170803220135609.png)
然后点进去：
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170803220205091.png)

可以看到他和submodule不同，submodule的子模块是另一个仓库的一个连接，点进去直接就去了另外一个仓库，而subtree不是这样的。

**接下来我们在子模块添加一个文件然后推送到远程，之后在父级模块更新下来这次修改：**
```
$ echo 'hello world ' > hello.txt

Administrator@CeaserWang MINGW64 /e/Study/child (master)
$ git add .
warning: LF will be replaced by CRLF in hello.txt.
The file will have its original line endings in your working directory.

Administrator@CeaserWang MINGW64 /e/Study/child (master)
$ git commit -m 'add helllo world'
[master 4be81af] add helllo world
 1 file changed, 1 insertion(+)
 create mode 100644 hello.txt

Administrator@CeaserWang MINGW64 /e/Study/child (master)
$ git push
fatal: TaskCanceledException encountered.
   ▒▒ȡ▒▒һ▒▒▒▒▒▒
Username for 'https://github.com': 1156721874@qq.com
Counting objects: 3, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (2/2), done.
Writing objects: 100% (3/3), 285 bytes | 0 bytes/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To https://github.com/1156721874/child.git
   2463028..4be81af  master -> master
```
然后在父级模块我们更新子模块：
执行：git subtree pull  --prefix=subtree subtree-origin master --squash
```
$ git subtree pull  --prefix=subtree subtree-origin master --squash
remote: Counting objects: 3, done.
remote: Compressing objects: 100% (2/2), done.
remote: Total 3 (delta 0), reused 3 (delta 0), pack-reused 0
Unpacking objects: 100% (3/3), done.
From https://github.com/1156721874/child
 * branch            master     -> FETCH_HEAD
   2463028..4be81af  master     -> subtree-origin/master
Merge made by the 'recursive' strategy.
 subtree/hello.txt | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 subtree/hello.txt

$ ls
parent.txt  README.md  subtree/

Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ ls subtree/
hello.txt  subtree.txt

```
可以看到hello.txt出现在子模块中。

**我们在做第二种入口的操作，在父级模块直接修改subtree子模块，然后在子模块仓库拉取所做的更新：**
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170803223143761.png)  
在远程的github，我们进入父级仓库的subtree查看刚才的修改：
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170803223258752.png)
可以看到修改被推送成功。

在subtree仓库我们pull拉取刚才的推送：
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170805101343339.png)
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170805101545364.png)

 **另外一个问题：**
 1、我们在subtree修改了一个文件hello.txt，然后提交推送到远程：


```
Administrator@CeaserWang MINGW64 /e/Study/child (master)
$ echo 'welcome git ' >> hello.txt

Administrator@CeaserWang MINGW64 /e/Study/child (master)
$ cat hello.txt
hello world
ok ok ok
welcome git
$ git add .
warning: LF will be replaced by CRLF in hello.txt.
The file will have its original line endings in your working directory.

Administrator@CeaserWang MINGW64 /e/Study/child (master)
$ git commit -m 'add welcome in hello.txt'
[master aa261fe] add welcome in hello.txt
 1 file changed, 1 insertion(+)

Administrator@CeaserWang MINGW64 /e/Study/child (master)
$ git push
Counting objects: 3, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (2/2), done.
Writing objects: 100% (3/3), 309 bytes | 0 bytes/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To https://github.com/1156721874/child.git
   66caa3a..aa261fe  master -> master

```
2、之后我们在subtree的父级仓库，pull拉取下来subtree的修改：

```
Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
nothing to commit, working tree clean

Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ git subtree pull  --prefix=subtree subtree-origin master --squash
remote: Counting objects: 3, done.
remote: Compressing objects: 100% (2/2), done.
remote: Total 3 (delta 0), reused 3 (delta 0), pack-reused 0
Unpacking objects: 100% (3/3), done.
From https://github.com/1156721874/child
 * branch            master     -> FETCH_HEAD
   66caa3a..aa261fe  master     -> subtree-origin/master
Auto-merging subtree/hello.txt
CONFLICT (content): Merge conflict in subtree/hello.txt
Automatic merge failed; fix conflicts and then commit the result.

```
出现了一个冲突：CONFLICT (content): Merge conflict in subtree/hello.txt
3、冲突的导致原因：
我们看一下冲突的文件内容：

```
$ cat subtree/hello.txt
hello world
ok ok ok
<<<<<<< HEAD
=======
welcome git
>>>>>>> 95b3323c6bb088bf8968982a5d592c38c1e2f889

```
我们看到HEAD的指向是空的，按照一般的逻辑，这个 git subtree pull可以fast forward，但是为什么会出现冲突，原因还是在于squash这个参数，pull需要进行fetch 和merge操作，而merge需要三方参与，但是squash把subtree的多次提交合并为一条新的commit，merge的两个节点没有共同的父亲，导致冲突。这就是squash在某些场景不会产生冲突，但是实际产生冲突的根本原因所在。所以还是那条准则，squash如果使用全部都是用，不使用，全部都不使用。

个人建议：使用subtree的时候不要使用squash参数。

在前边的subtree的时候使用squash，有一个场景就是 在subtree里边我们做了多次提交，然后在subtree的父级仓库里边subtree pull的时候会出现冲突，但是我们不使用squash同样流程的操作也会出现冲突，我们的解释是使用squash找不到共同的祖先节点导致冲突，看一下gitk：
![这里写图片描述](2018/10/04/git-十四-git-subtree/20170805115320028.png)

左右2条线一直往上追踪没有了交点，这是出现冲突的根本原因所在。追根到底是2个仓库导致的。
