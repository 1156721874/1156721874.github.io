---
title: git(十三)-git裸库与submodule
date: 2018-10-04 13:53:55
tags: [git,裸库,submodule]
categories: git
---

**创建裸库：**
girl init --bare
<!-- more -->

```
$ git init --bare
Initialized empty Git repository in E:/Study/git_bare/

Administrator@CeaserWang MINGW64 /e/Study/git_bare (BARE:master)
$ ll -a
total 19
drwxr-xr-x 1 Administrator 197121   0 8月   2 20:52 ./
drwxr-xr-x 1 Administrator 197121   0 8月   2 20:51 ../
-rw-r--r-- 1 Administrator 197121 104 8月   2 20:52 config
-rw-r--r-- 1 Administrator 197121  73 8月   2 20:52 description
-rw-r--r-- 1 Administrator 197121  23 8月   2 20:52 HEAD
drwxr-xr-x 1 Administrator 197121   0 8月   2 20:52 hooks/
drwxr-xr-x 1 Administrator 197121   0 8月   2 20:52 info/
drwxr-xr-x 1 Administrator 197121   0 8月   2 20:52 objects/
drwxr-xr-x 1 Administrator 197121   0 8月   2 20:52 refs/

```
可以看到裸库没有工作区，直接就是之前非裸库的.git下边的内容。

**submodule：**
用于在开发过程中一个模块依赖于另外一个模块的情况。
比如A模块需要使用B模块的代码，我们之前可以这样做，将B的代码打包成jar文件，然后上床到nexus之类的远端服务仓库，然后在其他开发者的机器上再maven upload下来，我们看到的B的只是class文件，这样没有问题，大部分也在使用这种模式，但是当B模块需要频繁的修改时，这就显得不合适了，需要频繁的上传下载，我们可以使用git子模块的方式submodule，A项目是一个git仓库，我们在A仓库里边在建立一个仓库B，注意A里边的B是B的源代码。

准备2个仓库，即2个项目：
子仓库：
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802211927985.png)
父仓库：
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802212123602.png)

**将子仓库纳入到父仓库：**
git submodule add https://github.com/1156721874/child.git mymodule
mymodule必须是一个不存在的目录，否则git会报错。
```
$ git submodule add https://github.com/1156721874/child.git mymodule
Cloning into 'E:/Study/mygit/mymodule'...
remote: Counting objects: 3, done.
remote: Total 3 (delta 0), reused 3 (delta 0), pack-reused 0
Unpacking objects: 100% (3/3), done.
warning: LF will be replaced by CRLF in .gitmodules.
The file will have its original line endings in your working directory.
```
子模块出现在mygit中：
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802212522296.png)；
当前mygit多出来mudule的配置文件夹：

```
$ ll -a
total 19
drwxr-xr-x 1 Administrator 197121  0 8月   2 21:23 ./
drwxr-xr-x 1 Administrator 197121  0 8月   2 21:12 ../
drwxr-xr-x 1 Administrator 197121  0 8月   2 21:23 .git/
-rw-r--r-- 1 Administrator 197121 87 8月   2 21:23 .gitmodules
drwxr-xr-x 1 Administrator 197121  0 8月   2 21:23 mymodule/
-rw-r--r-- 1 Administrator 197121 54 7月  31 20:57 README.md
-rw-r--r-- 1 Administrator 197121 44 8月   2 20:04 test.txt
```
接下来我们在mygit里边将版本库提交到远程，然后在远程可以看到：

```
$ git add .
warning: LF will be replaced by CRLF in .gitmodules.
The file will have its original line endings in your working directory.

Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ git commit -m 'commit mymodule'
[master 9f82bed] commit mymodule
 2 files changed, 4 insertions(+)
 create mode 100644 .gitmodules
 create mode 160000 mymodule

Administrator@CeaserWang MINGW64 /e/Study/mygit (master)
$ git push
Counting objects: 3, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 415 bytes | 0 bytes/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To https://github.com/1156721874/mygit.git
   8004460..9f82bed  master -> master

```
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802213041221.png)  

我们验证下在child下添加一个文件在mygit仓库的mymodule同步出现：
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802213719567.png)

如果我们引用了很多的子模块我们是不是需要进入每一个子模块执行git pull呢？这样做显然是麻烦的，所以git提供了批量的方式：
git submodule foreach git pull

命令很明显，就是每个仓库执行git pull

这时候如果另外一个开发者加入进来，需要执行clone mygit操作：
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802215333635.png)

我们虽然讲父级模块克隆下来，但是内容是空的，需要使用【 git submodule init】初始化子模块，然后【 git submodule update --recursive
】递归更新子模块内容。

其实我跟在座的读者兜了一个圈子，哈哈，我们完全可以使用一条命令将所有的子模块下载下来：

```
git submodule add https://github.com/1156721874/child.git mymodule --recursive
```
克隆的时候加上参数 --recursive即可。

此时在父级模块mygit里边的.git目录下出现modules文件件，进入modules是一个完整的仓库的配合格局：
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802220455849.png)

mymodule的删除，git没有提供直接的命令删除submodule，但是我们可以使用一系列命令组合完成删除：
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802221743396.png)
即：
第一： git rm --cached mymodule/ 删除暂存区文件
第二：rm -rf mymodule/ 删除工作区文件
第三：提交删除：
第四：推送到远程仓库：
第五：抓状态恢复正常。

远程仓库的当然也会删除掉：
![这里写图片描述](2018/10/04/git-十三-git裸库与submodule/20170802222005477.png)

最后说一下这种submodule的项目管理方式和jar嵌入的方式的不同点就是，jar包的形式是子模块很少发生代码的变化，而submodule的方式是用在依赖的子模块变动非常大的情况。
