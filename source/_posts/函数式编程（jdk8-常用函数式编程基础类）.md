---
title: 函数式编程（jdk8-常用函数式编程基础类）
date: 2018-10-04 10:25:22
tags: jdk8 lambda FunctionalInterface
categories: javaBase
---

在jdk8中什么是函数式接口：
1、被@FunctionalInterface注解修饰的。
2、接口里边只有一个非default的方法。
满足以上2个条件的即为函数式接口，ps：即使一个接口没有被@FunctionalInterface修饰，但是满足2，那么这样的接口也会是函数式接口。
**Supplier**
概要：不接受参数，返回一个值。
jdk源码：

```
 */
@FunctionalInterface
public interface Supplier<T> {

    /**
     * Gets a result.
     *
     * @return a result
     */
    T get();
}
```
即：Supplier不接受参数，返回一个值。
example：

```
public class SupplierTest {
    public static void main(String[] args) {
        Supplier<Student> supplier = Student::new;//这里使用了方法引用（后续解释）生成了一个对象。
        System.out.println(supplier.get().getName());
    }
}
```

**Function**
概要：接受一个参数返回一个值
jdk源码：

```
//类型T入参，类型R是返回值的类型
@FunctionalInterface
public interface Function<T, R> {

    /**
		接受一个参数，返回一个结果
     */
    R apply(T t);

    /**
     * 默认方法是讲的课8新加入的一种类型，入参before是一个Function（接受参数V类型，输出T类型），从实现来看其首先调用before的行为得到输出T，
     * 随后T作为当前Function的入参，最后当前Function输入R类型。即：compose函数传入的函数首先被调用，得到的结果作为当前Function的入参使用
     */
    default <V> Function<V, R> compose(Function<? super V, ? extends T> before) {
        Objects.requireNonNull(before);
        return (V v) -> apply(before.apply(v));
    }

    /**
     * andThen是和compose相反的操作，当前Function首先被调用，得到的结果作为参数after的入参，调用after。
     */
    default <V> Function<T, V> andThen(Function<? super R, ? extends V> after) {
        Objects.requireNonNull(after);
        return (T t) -> after.apply(apply(t));
    }

    /**
     * 对接受的元素，不做处理
     */
    static <T> Function<T, T> identity() {
        return t -> t;
    }
}
```

**BiFunction**
概要：接受2个参数，返回一个值。
jdk源码：

```
//T和U类型是参数，R类型是返回值。
@FunctionalInterface
public interface BiFunction<T, U, R> {

    /**
     * BiFunction的主方法，接受2个参数，返回一个结果
     */
    R apply(T t, U u);

    /**
     * 先执行当前BiFunction的行为，得到结果R类型，R类型最后作为Function的实例after的入参（泛型“? super R”即“？”是R类型或者是R类型的
     * 父级）返回V类型的结果。PS：考虑为什么andThen的入参是一个Function，而不是一个BiFunction？
     */
    default <V> BiFunction<T, U, V> andThen(Function<? super R, ? extends V> after) {
        Objects.requireNonNull(after);
        return (T t, U u) -> after.apply(apply(t, u));
    }
}
```
example:

```
/**
 * Created by CeaserWang on 2017/1/8.
 */
public class FunctionATest {

    public static void main(String[] args) {
        FunctionATest functionTestA = new FunctionATest();
       // functionTestA.testfunction1();
        System.out.println(functionTestA.computeA(3,value -> value = value * 3,value -> value+1));

        System.out.println(functionTestA.computeB(3,value -> value = value * 3,value -> value+1));

        System.out.println(functionTestA.computeC(3,4,(value1,value2) -> {return value1+value2;},value -> value*value));
    }

    public void testfunction1(){
        List<String> list = Arrays.asList("zhangsan","lisi","wangwu");
         Collections.sort(list,(o1,o2) -> {return o1.compareTo(o2); });
        Collections.sort(list,(o1,o2) ->  o1.compareTo(o2));

        list.forEach((item) -> System.out.println(item));
         list.forEach(String::toUpperCase);
         list.stream().map(String::toUpperCase).forEach(item -> System.out.println(item));


    }

    public int  computeA(int a, Function<Integer,Integer> function,Function<Integer,Integer> befor ){
        return  function.compose(befor).apply(a);
    }

    public int  computeB(int a, Function<Integer,Integer> function,Function<Integer,Integer> after ){
        return  function.andThen(after).apply(a);
    }

    public int  computeC(int a,int b, BiFunction<Integer, Integer,Integer> bifunction, Function<Integer,Integer> function ){
        return  bifunction.andThen(function).apply(a,b);
    }

}
```


**BinaryOperator**
概要：继承了BiFunction新加了2个求最大值和最小值的方法。
jdk源码：

```
//继承了BiFunction，入参和返回值都是同一种类型T，因为2中相同类型的元素做大小比较，返回的是其中一个，即还是原来入参的类型。
@FunctionalInterface
public interface BinaryOperator<T> extends BiFunction<T,T,T> {
    /**
     * 根据比较器comparator求最小值
     */
    public static <T> BinaryOperator<T> minBy(Comparator<? super T> comparator) {
        Objects.requireNonNull(comparator);
        return (a, b) -> comparator.compare(a, b) <= 0 ? a : b;
    }

    /**
     * 根据比较器comparator求最大值
     */
    public static <T> BinaryOperator<T> maxBy(Comparator<? super T> comparator) {
        Objects.requireNonNull(comparator);
        return (a, b) -> comparator.compare(a, b) >= 0 ? a : b;
    }
}
```

example:

```
/**
 * Created by Administrator on 2017/1/8.
 */
public class BinaryOperatorTest {

    public static void main(String[] args) {
        BinaryOperatorTest  BinaryOperatorTest = new BinaryOperatorTest();
        Integer rnum =   BinaryOperatorTest.compute(2,3,(num1,num2) -> {return num1 * num2;},value -> 2*value);
        System.out.println(rnum);
        System.out.println("-------------------------------------");
        Integer rnum2 =   BinaryOperatorTest.compute(2,3,(num1,num2) -> {return num1 * num2;});
        System.out.println(rnum2);
        System.out.println("-------------------------------------");
        Integer rnum3 =   BinaryOperatorTest.computeA(2,3,(num1,num2) ->   num1.compareTo(num2));
        System.out.println(rnum3);
    }

    public Integer compute(Integer a, Integer b, BinaryOperator<Integer> binaryoperator, Function<Integer,Integer> function) {
        return binaryoperator.andThen(function).apply(a,b);
    }


    public Integer compute(Integer a, Integer b, BinaryOperator<Integer> binaryoperator) {
        return binaryoperator.apply(a,b);
    }


    public Integer computeA(Integer a, Integer b, Comparator<Integer> comparator){
        return BinaryOperator.minBy(comparator).apply(a,b);
    }
}
```

**Predicate**
概要：接受一个参数返回boolean类型，常用语filter过滤条件使用。
jdk源码：

```
@FunctionalInterface
public interface Predicate<T> {

    /**
     * 接受一个参数返回一个boolean值
     */
    boolean test(T t);

    /**
     *与操作，支持短路与
     */
    default Predicate<T> and(Predicate<? super T> other) {
        Objects.requireNonNull(other);
        return (t) -> test(t) && other.test(t);
    }

    /**
     * 取反操作
     */
    default Predicate<T> negate() {
        return (t) -> !test(t);
    }

    /**
     * 或操作，支持短路或
     */
    default Predicate<T> or(Predicate<? super T> other) {
        Objects.requireNonNull(other);
        return (t) -> test(t) || other.test(t);
    }

    /**
     * 比较2个对象是否相同
     */
    static <T> Predicate<T> isEqual(Object targetRef) {
        return (null == targetRef)
                ? Objects::isNull
                : object -> targetRef.equals(object);
    }
}
```

example:

```
/**
 * Created by CeaserWang on 2017/1/8.
 */
public class PredicateTest {
    public static void main(String[] args) {
        Predicate<String> mypredicate = value -> value.length()>5;
        System.out.println(mypredicate.test("hello55s"));

        List<Integer> nums = Arrays.asList(1,2,3,4,5,6,7,8,9);
        PredicateTest predicatetest = new PredicateTest();
        predicatetest.condationA(nums,value -> value>5);
        System.out.println("\n---------------------------");
        predicatetest.condationA(nums,value -> value % 2 ==0);
        System.out.println("\n---------------------------");

        System.out.println(predicatetest.condationEqual("test").test("test"));
    }

    public void condationA(List<Integer> list, Predicate<Integer> predate){
        for(Integer item : list){
            if(predate.test(item)){
                System.out.print(item);
            }
        }
    }

    public Predicate<String> condationEqual(Object obj){
        return Predicate.isEqual(obj) ;
    }

}
```

**Optional**
概要：jdk8为了解决NPE问题提供的解决方案。
在jdk7中业务中很多代码都是这样：

```
if(null!=XXX){
	doSomeThing();
}
```

开发人员需要警惕NPE问题，给开发带来了一些不便，现在我们不想用这三行固定的语句，为此jdk8有了Optional。
Optional内部维护了一个value的成员变量，为此Optional提供了诸多针对于此成员变量的方法。
Optional中的其中一个方法：

```
	//空对象
    private static final Optional<?> EMPTY = new Optional<>();

	//Optional维护的值
	 private final T value;
	//是否是空值
    public boolean isPresent() {
        return value != null;
    }
    //如果不是空值，那么执行针对于value的行为。
        public void ifPresent(Consumer<? super T> consumer) {
        if (value != null)
            consumer.accept(value);
    }
    //构造一个值为value的Optional对象，value不能为空，否则报错。
    public static <T> Optional<T> of(T value) {
        return new Optional<>(value);
    }
    //返回一个空值
    public static<T> Optional<T> empty() {
        @SuppressWarnings("unchecked")
        Optional<T> t = (Optional<T>) EMPTY;
        return t;
    }
    //创建一个允许空值的Optional对象
       public static <T> Optional<T> ofNullable(T value) {
        return value == null ? empty() : of(value);
    }
```
example：

```
/**
 * Created by CeaserWang on 2017/1/8.
 * optional 不要作为成员变量或者参数，optional只是为了应对null异常而来的
 */
public class OptionalTest {
    public static void main(String[] args) {
        OptionalTest OptionalTest = new OptionalTest();
        OptionalTest.optionalA();
        OptionalTest.optionalB();
    }


    public void optionalA(){
        //Optional optional = Optional.of("hello");
        Optional optional = Optional.ofNullable(null);//创建一个空的对象
        optional.ifPresent(item -> System.out.println(item));//如果为空此行代码不会报错。

        System.out.println(optional.orElse("world"));//如果为空输出word
        System.out.println(optional.orElseGet(() -> "opop"));//如果为空，取Supplier提供的值
    }


    public void optionalB(){
        Company company = new Company();
        Employee e1 = new Employee();
        Employee e2 = new Employee();
        company.setEmployyee(Arrays.asList(e1,e2));

        Optional<Company> optional = Optional.ofNullable(company);
        System.out.println(optional.map(icompany -> icompany.getEmployyee()).orElse(Collections.emptyList()));

    }
}
```
函数式编程和以往的面向对象的方式有一定的区别，函数式编程方法的参数可以传递行为，这些行为包括但不限于以上介绍的这些，jdk8提供的函数式编程的辅助类在java.util.function包下边：
![这里写图片描述](20170326140327392.png)

这些针对于函数式编程的辅助类，对以后的收集器，流是基础，后续的jdk新加的框架都是使用这些基类展开的。

**jdk8新加入的default方法**
default方法的加入是为了兼容jdk8以前的版本的需要。
（1）当前有两个接口MyInterface和MyInterface1，它们都有相同名字的default方法，之后实现类Myclass同时implements了MyInterface和MyInterface1，同时Myclass实现了default方法，此时Myclass调用default调的是谁的？
（2）一个接口I有一个default方法，另一个实现类A实现了了此接口，并且重写了default方法，之后另一个类B继承了实现类A并且实现了接口I，那么在这种情况下，实现类B调用的default方法又是谁的呢？针对这两种情况编写测试代码：

接口MyInterface
```
/**
 * Created by CeaserWang on 2017/1/16.
 */
public interface MyInterface {
default void  meyhod(){
    System.out.println("MyInterface");
}
}
```
接口MyInterface1
```
public interface MyInterface1 {
    default void  meyhod(){
        System.out.println("MyInterface1");
    }
}
```
实现类ExtendsClass
```
public class ExtendsClass implements  MyInterface {

    public void  meyhod(){
        System.out.println("ExtendsClass");
    }
}
```

实现类FixClass
```
public class FixClass extends  ExtendsClass implements  MyInterface1 {

}
```
测试类Myclass
```
public class Myclass implements  MyInterface,MyInterface1 {

  public  void  meyhod(){
       System.out.println("Myclass");
      //MyInterface1.super.meyhod();
    }

    public static void main(String[] args) {
        Myclass myclass = new Myclass();
        myclass.meyhod();

        FixClass fixClass = new FixClass();
        fixClass.meyhod();
    }

}
```

运行Myclass 结果：

```
Myclass
ExtendsClass
```

结论:
针对于第一种情况，default方法调用的是自身的实现的default方法。
针对于第二种情况，default方法调用的是“就近原则”，ExtendsClass 首先被实现，那么首选是ExtendsClass 的default方法，因此输出“ExtendsClass”。

**jdk8-方法引用**

**方法引用的形式**
方法引用的标准形式是:类名::方法名。（注意：只需要写方法名，不需要写括号）

有以下四种形式的方法引用:

类型	示例
引用静态方法	ContainingClass::staticMethodName
引用某个对象的实例方法	containingObject::instanceMethodName
引用某个类型的任意对象的实例方法	ContainingType::methodName
引用构造方法	ClassName::new

下面我们通过一个小Demo来分别学习这几种形式的方法引用:
Student 类：
```
public class Student {
    private String name;
    private int score;

    public Student(String name, int score) {
        this.name = name;
        this.score = score;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getScore() {
        return score;
    }

    public void setScore(int score) {
        this.score = score;
    }


    public static int coompareStudentByScore(Student student1,Student student2){
        return student1.getScore() - student2.getScore();
    }


    public static int coompareStudentByName(Student student1,Student student2){
        return student1.getName().compareToIgnoreCase(student2.getName());
    }

    public int compareScore(Student student){
        return this.score-student.getScore();
    }

}
```
StudentComparator 比较器：
```
public class StudentComparator {

    public  int coompareStudentByScore(Student student1,Student student2){
        return student1.getScore() - student2.getScore();
    }

    public  int coompareStudentByName(Student student1,Student student2){
        return student1.getName().compareToIgnoreCase(student2.getName());
    }

}
```
测试类：MethodReferenceTest
```
 * Created by CeaserWang on 2017/1/15.
 */
public class MethodReferenceTest {

    public String toString(Supplier<String> supplier){
        return supplier.get()+"test";
    }

    public String toString2(String str, Function<String,String> function){
        return function.apply(str);
    }


    public static void main(String[] args) {
        Student student1   = new Student("zhangsan",20);
        Student student2   = new Student("lisi",90);
        Student student3   = new Student("wangwu",50);
        Student student4   = new Student("zhaoliu",60);

        List<Student> students = Arrays.asList(student1,student2,student3,student4);
		//lambda形式
       students.sort((studentparam1,studentparam2) -> Student.coompareStudentByName(studentparam1,studentparam2));
        students.forEach(student -> System.out.println(student.getName()));*/
       // 引用静态方法
       /* students.sort( Student::coompareStudentByName);
        students.forEach(student -> System.out.println(student.getName()));

        System.out.println("----------------------------------------------");

		//引用某个对象的实例方法
        StudentComparator studentComparator = new StudentComparator();
        students.sort(studentComparator::coompareStudentByScore);
        students.forEach(student -> System.out.println(student.getScore()));

        System.out.println("----------------------------------------------");

        //引用某个类型的任意对象的实例方法
        students.sort(Student::compareScore);
        students.forEach(student -> System.out.println(student.getScore()));
        MethodReferenceTest methodReferenceTest =  new MethodReferenceTest();
        //引用构造方法
        System.out.println( methodReferenceTest.toString(String::new));
        System.out.println( methodReferenceTest.toString2("hello",String::new));
    }
}

```
