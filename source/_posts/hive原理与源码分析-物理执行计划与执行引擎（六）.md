---
title: hive原理与源码分析-物理执行计划与执行引擎（六）
date: 2018-10-04 11:21:43
tags: hive
categories: cloud
---

![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516204226246.png)  

<!-- more -->
**Hive执行**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516204330223.png)

**相关配置**
hive.execution.engine - Hive执行引擎
	mr - 在MapReduce上执行
	tez - 在Tez上执行
	spark - 在Spark上执行
hive.execution.mode – Hive执行模式
	container - 在Yarn Container内执行Query Fragments
	llap – 在LLAP内执行Query Fragments
https://insight.io/github.com/apache/hive/blob/master/common/src/java/org/apache/hadoop/hive/conf/HiveConf.java?line=2635

**物理执行计划和逻辑执行计划的区别**
逻辑执行计划是一个Operator图
物理执行计划是一个Task图
物理执行计划是把逻辑执行计划切分成子图
物理执行计划图的每个Task结点内是一个Operator结点的子图

**举个例子**
SELECT * FROM a JOIN b ON a.id=b.id;
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516204932273.png)

**物理执行计划的Task类型**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516205328150.png)  

**逻辑层和物理层的分界**
逻辑优化的最后一步
Optimizer的最后一步
SimpleFetchOptimzer
看代码
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/optimizer/Optimizer.java?line=228

```
    if (!HiveConf.getVar(hiveConf, HiveConf.ConfVars.HIVEFETCHTASKCONVERSION).equals("none")) {
      transformations.add(new SimpleFetchOptimizer()); // must be called last
    }

```
**SemanticAnalyzer第七步**
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/parse/SemanticAnalyzer.java?line=11356

```
    if (LOG.isDebugEnabled()) {
      LOG.debug("Before logical optimization\n" + Operator.toString(pCtx.getTopOps().values()));
    }
    Optimizer optm = new Optimizer();
    optm.setPctx(pCtx);
    optm.initialize(conf);
    pCtx = optm.optimize();//fetchTask在逻辑执行计划最后一步生成
    if (pCtx.getColumnAccessInfo() != null) {
      // set ColumnAccessInfo for view column authorization
      setColumnAccessInfo(pCtx.getColumnAccessInfo());
    }
    FetchTask origFetchTask = pCtx.getFetchTask();//fetchTask是物理执行计划的开始
    if (LOG.isDebugEnabled()) {
      LOG.debug("After logical optimization\n" + Operator.toString(pCtx.getTopOps().values()));
    }
```
**开始搞物理执行计划**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516210713670.png)  
TaskCompilerFactory是编译器的工厂类
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/parse/TaskCompilerFactory.java?line=38

```
  /**
   * Returns the appropriate compiler to translate the operator tree
   * into executable units.
   */
  public static TaskCompiler getCompiler(HiveConf conf, ParseContext parseContext) {
    if (HiveConf.getVar(conf, HiveConf.ConfVars.HIVE_EXECUTION_ENGINE).equals("tez")) {
      return new TezCompiler();
    } else if (HiveConf.getVar(conf, HiveConf.ConfVars.HIVE_EXECUTION_ENGINE).equals("spark")) {
      return new SparkCompiler();
    } else {
      return new MapReduceCompiler();
    }
  }
```
支持tez、spark、和mr方式。
途中rootTask就是生成的有向无环图的指针。

**TaskCompiler**
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/parse/TaskCompiler.java?line=87

```
//生成物理执行计划
    generateTaskTree(rootTasks, pCtx, mvTask, inputs, outputs);

    // For each task, set the key descriptor for the reducer
    for (Task<? extends Serializable> rootTask : rootTasks) {
      GenMapRedUtils.setKeyAndValueDescForTaskTree(rootTask);
    }

    // If a task contains an operator which instructs bucketizedhiveinputformat
    // to be used, please do so
    for (Task<? extends Serializable> rootTask : rootTasks) {
      setInputFormat(rootTask);
    }
//物理优化
    optimizeTaskPlan(rootTasks, pCtx, ctx);
```
TaskCompiler.generateTaskTree()
MapReduceCompler.generateTaskTree()
SparkCompler.generateTaskTree()
TezCompler.generateTaskTree()

**不同的引擎有不同的物理优化**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516211729545.png)

**MapReduceCompiler 生成物理执行计划**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516212355116.png)
这个过程就是讲逻辑执行计划切分成物理执行计划。

**如何切割逻辑执行计划？**
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/optimizer/GenMapRedUtils.java?line=405

```
/**
   * Met cRS in pOP(parentTask with RS)-cRS-cOP(noTask) case
   * Create new child task for cRS-cOP and link two tasks by temporary file : pOP-FS / TS-cRS-cOP
   *
   * @param cRS
   *          the reduce sink operator encountered
   * @param opProcCtx
   *          processing context
   */
  static void splitPlan(ReduceSinkOperator cRS, GenMRProcContext opProcCtx)
      throws SemanticException {
    // Generate a new task
    ParseContext parseCtx = opProcCtx.getParseCtx();
    Task<? extends Serializable> parentTask = opProcCtx.getCurrTask();

    MapredWork childPlan = getMapRedWork(parseCtx);
    Task<? extends Serializable> childTask = TaskFactory.get(childPlan, parseCtx
        .getConf());
    Operator<? extends OperatorDesc> reducer = cRS.getChildOperators().get(0);

    // Add the reducer
    ReduceWork rWork = new ReduceWork();
    childPlan.setReduceWork(rWork);
    rWork.setReducer(reducer);
    ReduceSinkDesc desc = cRS.getConf();
    childPlan.getReduceWork().setNumReduceTasks(new Integer(desc.getNumReducers()));

    opProcCtx.getOpTaskMap().put(reducer, childTask);

    splitTasks(cRS, parentTask, childTask, opProcCtx);
  }

```

**MR物理优化器**
spark物理执行计划、tez物理执行计划、mr物理执行计划之后会有物理优化器，下列是一些优化器
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/optimizer/physical/PhysicalOptimizer.java?line=47

![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516213606789.png)
这些优化器是为mr专用的，而spark和tez是不用这些优化器的。
奇怪的是mr物理优化器的名字是PhysicalOptimizer，而逻辑优化器就是Optimizer。

hive-on-MR vs hive-on-tez
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516214307582.png)  
从图中可以看出，加入mr的方式中间有一些机器死掉了，但是他们计算的中间结果会写到磁盘，下一次会接着执行，数据不会丢失，但是tez的形式中间数据没有落盘，只要死掉数据就会有问题。这就是mr和tez的区别，mr更稳定一些，tez比较快。

![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516214916963.png)
 shuffle的区别
 ![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516215059945.png)  

**TezCompiler**
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/parse/TezCompiler.java?line=457
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516220031494.png)  

**SparkCompiler**
基本上和TezCompiler一致
代码注释上直接写着：
Cloned from TezCompiler
优化器和逻辑执行计划的切分在一起
生成Spark作业
https://issues.apache.org/jira/secure/attachment/12652517/Hive-on-Spark.pdf
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516220341279.png)  
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170516220542813.png)  

**很有意思**
Spark编译时直接拷贝了Tez代码
命名时加上了Spark前缀
进一步可见：Spark和Tez在执行机制上非常类似

**基于路径规则优化总结**
Optimizer会根据规则优化逻辑执行计划，并修改逻辑执行计划为优化后的逻辑执行计划
TaskCompiler（无论哪种）会根据规则来切分逻辑执行计划
Hive中对Operator图的修改基本上都是基于深度优先路径规则的

**深度优先递规下降遍历**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170520094123424.png)  

**提交不同引擎的作业MR**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170520094939458.png)  

**提交不同引擎作业Spark**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170520095018693.png)  

**提交不同引擎的作业Tez**
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170520095057366.png)  

Driver的 launchTask方法：
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/Driver.java?line=2130

**广度优先，并发提交**
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/Driver.java?line=1830
![这里写图片描述](2018/10/04/hive原理与源码分析-物理执行计划与执行引擎（六）/20170520095808761.png)  
