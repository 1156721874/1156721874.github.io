---
title: jdk8-方法引用
date: 2018-10-04 10:32:39
tags: jdk8  method reference
categories: javaBase
---

**方法引用的形式**
方法引用的标准形式是:类名::方法名。（注意：只需要写方法名，不需要写括号）
<!-- more -->

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
