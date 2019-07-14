---
title: linux下python3.5+pip安装
date: 2018-10-04 10:22:11
tags: python pip jupyter
categories: python
---

安装包;
![这里写图片描述](20161201220019448.png)

python依赖环境安装：
yum install openssl-devel -y

yum groupinstall 'Development Tools'

yum install zlib-devel bzip2-devel  openssl-devel ncurses-devel

A：解压python:
解压：tar jxvf Python-*
进入文件目录，运行以下命令：
1）./configure
2）make
3）sudo make install

重新指向（默认是2.6）
ln -s /usr/local/bin/python3.3 /usr/bin/python

B: 安装setuptools软件包

(1)解压setuptools包
tar zxvf setuptools-2.0.tar.gz
cd setuptools-2.0
(2)编译setuptools
 python setup.py build
(3)开始执行setuptools安装
python setup.py install

验证;
![这里写图片描述](20161128214730486.png)

ok可以正常安装软件

C:安装pip：
python setup.py install

D:安装ipython
https://github.com/ipython/ipython/archive/5.1.0.tar.gz

pip install ipython
pip install “ipython[notebook]”
ipython notebook
 pip install jupyter
浏览器会打开下面这个页面：
![这里写图片描述](20161203200608554.png)
点击要打开的文件比如Computer_Sketchy_score.ipynb，就可以打开了
