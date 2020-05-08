---
title: hive原理与源码分析-UDxF、优化器及执行引擎（五）
date: 2018-10-04 11:16:24
tags:
---

**什么是UDF？**
UDF的全称是User-Defined-Functions
Hive中一共有三种UDF
<!-- more -->
UDF（User-Defined Function）：输入一行，输入一行，1->1
UDAF（User-Defined Aggregation Function）：输入N行，输出一行，N->1
UDTF（User-Defined Table-generating Function)：输入一行，输出N行，1->N

**一切都是UDxF**
内置操作符（本质上是一个UDF）
加、减、乘、除、等号、大于、小于……
内置UDF
常用数学操作，常用内符串操作……
常用日期操作……
内置UDAF
Count, sum , avg …
内置UDTF
Explode
自定义UDxF
https://cwiki.apache.org/confluence/display/Hive/LanguageManual+UDF

**UDF源码举例**
一个简单的加号 1+2.5
	https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/udf/generic/GenericUDFOPPlus.java
类型转换 cast(1.5 as string)
	https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/udf/UDFToString.java?line=120
返回字符串长度 length(s)
	https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/udf/UDFLength.java

**PTF是一种特殊的UDF**
https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/udf/generic/GenericUDFLead.java
https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/udf/generic/GenericUDFLeadLag.java?line=35
用于窗口函数的计算

**UDF存在下列Operator中**
![这里写图片描述](20170514170358457.png)

**演示**
https://cwiki.apache.org/confluence/display/Hive/HivePlugins#HivePlugins-CreatingCustomUDFs

**UDAF**
UDAF用于聚合
存在于GroupByOperator -> GenericUDAFEvaluator
	思考：为什么Group By Operator即有ExprNodeEvaluator又月GenericUDAFEvaluator?
	https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/exec/GroupByOperator.java

**UDAF源码举例**
通用接口
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/udf/generic/GenericUDAFEvaluator.java?line=70
当中有四种模式：
```
  /**
   * Mode.
   *
   */
  public static enum Mode {
    /**
     * PARTIAL1: from original data to partial aggregation data: iterate() and
     * terminatePartial() will be called.
     */
    PARTIAL1,
        /**
     * PARTIAL2: from partial aggregation data to partial aggregation data:
     * merge() and terminatePartial() will be called.
     */
    PARTIAL2,
        /**
     * FINAL: from partial aggregation to full aggregation: merge() and
     * terminate() will be called.
     */
    FINAL,
        /**
     * COMPLETE: from original data directly to full aggregation: iterate() and
     * terminate() will be called.
     */
    COMPLETE
  };
```

Sum
https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/udf/generic/GenericUDAFSum.java

**回忆一下Group By执行的四种模式**
![这里写图片描述](20170514195921527.png)

https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/parse/SemanticAnalyzer.java?line=9749

**对应一下UDAF四种模式**
![这里写图片描述](2017051420054406.png)  

**自定义UDAF**
https://cwiki.apache.org/confluence/display/Hive/GenericUDAFCaseStudy
写Resolver
写Evaluator
	getNewAggregationBuffer()
	iterate()
	terminatePartial()
	merge()
	terminate()

**UDTF**
UDTF用于行转列、拆分行、生成小表
存在于UDTFOperator
https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/exec/UDTFOperator.java


```
  @Override
  public void process(Object row, int tag) throws HiveException {
  //输入一行数据
    // The UDTF expects arguments in an object[]
    StructObjectInspector soi = (StructObjectInspector) inputObjInspectors[tag];
    List<? extends StructField> fields = soi.getAllStructFieldRefs();

    for (int i = 0; i < fields.size(); i++) {
      objToSendToUDTF[i] = soi.getStructFieldData(row, fields.get(i));
    }
//对输出的多个数据处理
    genericUDTF.process(objToSendToUDTF);
    if (conf.isOuterLV() && collector.getCounter() == 0) {
      collector.collect(outerObj);
    }
    collector.reset();
  }
```

https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/udf/generic/GenericUDTF.java?line=81

```
  /**
   * Give a set of arguments for the UDTF to process.
   *
   * @param args
   *          object array of arguments
   */
  public abstract void process(Object[] args) throws HiveException;
```

经常会与LateralView一起使用
	为什么？单独生成小表是无意义的
	会将生成的小表和原来的表进行join

**Lateral View**
把某一列拆分成一个小表
把拆出来的小表作为一个视图
用这个视图和原表作Join (Map Join)
https://cwiki.apache.org/confluence/display/Hive/LanguageManual+LateralView

**Lateral View源码和执行计划**
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/exec/LateralViewJoinOperator.java?line=43

逻辑执行计划：
![这里写图片描述](20170514202109291.png)

**UDTF源码举例**
https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/udf/generic/GenericUDTFExplode.java

```
  @Override
  public void process(Object[] o) throws HiveException {
  //输入一行数据
    switch (inputOI.getCategory()) {
    case LIST:
      ListObjectInspector listOI = (ListObjectInspector)inputOI;
      List<?> list = listOI.getList(o[0]);
      if (list == null) {
        return;
      }
      for (Object r : list) {
        forwardListObj[0] = r;
        //处理
        forward(forwardListObj);
      }
      break;
    case MAP:
      MapObjectInspector mapOI = (MapObjectInspector)inputOI;
      Map<?,?> map = mapOI.getMap(o[0]);
      if (map == null) {
        return;
      }
      for (Entry<?,?> r : map.entrySet()) {
        forwardMapObj[0] = r.getKey();
        forwardMapObj[1] = r.getValue();
        forward(forwardMapObj);
      }
      break;
    default:
      throw new TaskExecutionException("explode() can only operate on an array or a map");
    }
  }
```

如，一些价格，以逗号分隔，存储在一个字段中

**自定义UDTF**
https://cwiki.apache.org/confluence/display/Hive/DeveloperGuide+UDTF
比UDAF要简单很多

**Transform**
与UDTF类似，只是以自定义脚本的形式，编写
适合语言控，比如我特别喜欢Python或者特别喜欢Ruby，但并不推荐
https://cwiki.apache.org/confluence/display/Hive/LanguageManual+Transform

为什么不推荐呢看源码
**Transform源码分析**
https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/exec/ScriptOperator.java

hive默认的分隔符是"ctra+a"，倘若每行数据里边有tab分隔符，那么数据就会错乱，线程也会错乱。所以我们要在数据之中没有类似tab这样的分隔符的时候才能使用Transform不会出错。
```
。。。。。。。。。。。略
  public void process(Object row, int tag) throws HiveException {
  。。。。。。。。。。略
  //启动2个线程，
  outThread.start();
  errThread.start();

```

**Hive流程 – 回顾**
![这里写图片描述](20170514205734778.png)  

Optimizer其实优化器的调用者：
![这里写图片描述](20170514205912937.png)

**基于规则的优化的执行**
根据配置初始化一个规则列表，然后一条规则一条规则地执行
把根据QB生成的逻辑执行计划改写成新的逻辑执行计划
https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/optimizer/Optimizer.java?line=240

```
  /**
   * Invoke all the transformations one-by-one, and alter the query plan.
   *
   * @return ParseContext
   * @throws SemanticException
   */
  public ParseContext optimize() throws SemanticException {
    for (Transform t : transformations) {
      t.beginPerfLogging();
      pctx = t.transform(pctx);
      t.endPerfLogging(t.toString());
    }
    return pctx;
  }
```

**基于规则的优化的执行**
![这里写图片描述](20170514215438866.png)

**demo 1： 简单谓词下推优化器**
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/ppd/SimplePredicatePushDown.java?line=55

![这里写图片描述](20170514220105056.png)

**demo 2： ReduceSinkDeDuplication**
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/optimizer/correlation/ReduceSinkDeDuplication.java?line=94
去重优化器，减少map作业数
```
    // If multiple rules can be matched with same cost, last rule will be choosen as a processor
    // see DefaultRuleDispatcher#dispatch()
    Map<Rule, NodeProcessor> opRules = new LinkedHashMap<Rule, NodeProcessor>();
    //reduce sink后边有reduce sink 执行ReduceSinkDeduplicateProcFactory.getReducerReducerProc()优化
    opRules.put(new RuleRegExp("R1", RS + "%.*%" + RS + "%"),
        ReduceSinkDeduplicateProcFactory.getReducerReducerProc());
        //reduce sink后边有group by + reduce sink执行ReduceSinkDeduplicateProcFactory.getGroupbyReducerProc()优化
    opRules.put(new RuleRegExp("R2", RS + "%" + GBY + "%.*%" + RS + "%"),
        ReduceSinkDeduplicateProcFactory.getGroupbyReducerProc());
    if (mergeJoins) {
    //jion 后边有reduce sink执行ReduceSinkDeduplicateProcFactory.getJoinReducerProc()优化
      opRules.put(new RuleRegExp("R3", JOIN + "%.*%" + RS + "%"),
          ReduceSinkDeduplicateProcFactory.getJoinReducerProc());
    }
```
![这里写图片描述](20170514220833201.png)

**demo 3： JoinReorder**
我们建议小表放在左边，大表放在右边，但是没有这种情况下，
虽然大表要放右边，有了JoinReorder，大表就可以放左边了JoinReorder可以改写成这样的形式来优化。这种优化需要打开开关。
为什么？看代码
	https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/optimizer/JoinReorder.java?line=40
只能是大表，不能是大的子查询
	思考：为什么？
所以，打开这个开关时，简单查询是不需要小表放左边的
![这里写图片描述](20170514221850831.png)
我们看一下这个开关：
https://insight.io/github.com/apache/hive/blob/master/ql/src/java/org/apache/hadoop/hive/ql/optimizer/Optimizer.java?line=186

```
    if (HiveConf.getBoolVar(hiveConf, HiveConf.ConfVars.NWAYJOINREORDER)) {
      transformations.add(new JoinReorder());
    }
```
https://insight.io/github.com/apache/hive/blob/master/common/src/java/org/apache/hadoop/hive/conf/HiveConf.java?line=3353
![这里写图片描述](20170514222441553.png)
默认情况是开发，但是只能是表，不能是子查询。

**更多优化器**
更多优化器请根据Optimizer的代码自行阅读
如果作为一个用户，只需要知道优化器的作用即可
如果是源码程序员，可尝试手动写一个优化器

**Hive流程 – 回顾**
![这里写图片描述](20170514222707054.png)

**Hive执行引擎**
![这里写图片描述](20170514222926367.png)


**执行引擎**
四种执行引擎
Local
MapReduce
Spark
	https://cwiki.apache.org/confluence/display/Hive/Hive+on+Spark%3A+Getting+Started
Tez
	https://cwiki.apache.org/confluence/display/Hive/Hive+on+Tez
Tez + LLAP

**代码部分**
![这里写图片描述](20170514223227098.png)
物理执行引擎生成一个TaskCompiler，TaskCompiler会对不同的执行引擎，比如spark，tez、mr等执行不同的物理计划编译器，local是mapreduce（四个线程做map，一个线程做reduce）。
https://www.codatlas.com/github.com/apache/hive/master/ql/src/java/org/apache/hadoop/hive/ql/parse/TaskCompiler.java?line=87

**Hive流程 – 我们还没介绍的**
![这里写图片描述](20170514223655980.png)
逻辑执行计划生成物理执行计划，而物理执行计划是如何调整的。
