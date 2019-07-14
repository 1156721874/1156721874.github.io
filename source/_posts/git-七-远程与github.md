---
title: git(七)-远程与github
date: 2018-10-04 13:44:36
tags: [git,远程]
categories: git
---

本地创建一个新的仓库，然后在github也创建一个新的仓库。
此时需要在本地关联github的远程仓库的url地址之后，将本地仓库提交到github。
命令：
一、https的方式
git remote add origin https://github.com/user/gitrespory.git
git push -u origin master

二、ssh的方式
ssh的方式需要在本地机器生成公钥和私钥，然后将公钥设置到github的远程仓库，设置方式：
![这里写图片描述](20170730201503950.png)

然后执行：
git remote add origin git@github.com:1156721874/CrazyCode.git
git push -u origin master
输入用户名和密码之后即可建立关联，此后所有的提交的push都会提交到github的远程仓库。

查看远程仓库信息：
git remote show
查看远程某个版本库详情：
git remote show origin
查看所有分支，会显示远程分支：
git branch -a
查看所有分支以及最近提交情况：

```
$ git branch -av
  dev    080a6d7 delete
* master a4ed124 commit

```
git clone：
将远程仓库克隆岛本地：
git clone https://github.com/google/protobuf.git
克隆到目录myprotobuf下
git clone https://github.com/google/protobuf.git myprotobuf

git add . 和 git add *的区别：
git add .  ： 将当前目录的修改以及新增的文件放进暂存区，同时考虑".gitignore"文件的配置
git add * ：将当前目录的修改以及新增的文件放进暂存区，不考虑".gitignore"文件的配置

git add的三个作用：
1、将未追踪的文件纳入到缓存区。
2、将已追踪但是又修改的文件纳入到缓存区。
3、标示冲突的文件被解决掉。

git pull操作组成：
git pull = git fetch + git merge
