---
title: spring_boot_cloud(2)Spring_Boot打包文件结构深入分析源码讲解
date: 2019-06-07 15:56:32
tags: [打包文件]
categories: spring_boot_cloud
---

### gradle 的打包task
在使用gradle构建springboot的项目时，可以查看当前项目由那些gradle的任务，我们在[springboot的初始化页面](https://start.spring.io/) 构建一个简单的springboot项目，然后在本地我们用vscode打开，执行./gradlew task得到如下输出：
```
> Task :tasks

------------------------------------------------------------
Tasks runnable from root project
------------------------------------------------------------

Application tasks
-----------------
bootRun - Runs this project as a Spring Boot application.

Build tasks
-----------
assemble - Assembles the outputs of this project.
bootJar - Assembles an executable jar archive containing the main classes and their dependencies.
build - Assembles and tests this project.
buildDependents - Assembles and tests this project and all projects that depend on it.
buildNeeded - Assembles and tests this project and all projects it depends on.
classes - Assembles main classes.
clean - Deletes the build directory.
jar - Assembles a jar archive containing the main classes.
testClasses - Assembles test classes.

Build Setup tasks
-----------------
init - Initializes a new Gradle build.
wrapper - Generates Gradle wrapper files.

Documentation tasks
-------------------
javadoc - Generates Javadoc API documentation for the main source code.

Help tasks
----------
buildEnvironment - Displays all buildscript dependencies declared in root project 'spring-lecture'.
components - Displays the components produced by root project 'spring-lecture'. [incubating]
dependencies - Displays all dependencies declared in root project 'spring-lecture'.
dependencyInsight - Displays the insight into a specific dependency in root project 'spring-lecture'.
dependencyManagement - Displays the dependency management declared in root project 'spring-lecture'.
dependentComponents - Displays the dependent components of components in root project 'spring-lecture'. [incubating]
help - Displays a help message.
model - Displays the configuration model of root project 'spring-lecture'. [incubating]
projects - Displays the sub-projects of root project 'spring-lecture'.
properties - Displays the properties of root project 'spring-lecture'.
tasks - Displays the tasks runnable from root project 'spring-lecture'.

Verification tasks
------------------
check - Runs all checks.
test - Runs the unit tests.

Rules
-----
Pattern: clean<TaskName>: Cleans the output files of a task.
Pattern: build<ConfigurationName>: Assembles the artifacts of a configuration.
Pattern: upload<ConfigurationName>: Assembles and uploads the artifacts belonging to a configuration.

To see all tasks and more detail, run gradlew tasks --all

To see more detail about a task, run gradlew help --task <task>

BUILD SUCCESSFUL in 2s
1 actionable task: 1 executed
```
【bootJar - Assembles an executable jar archive containing the main classes and their dependencies.】
这里就是将整个工程打包，生成一个自包含的jar包。
我们可以将当前工程下的build/libs下的jar包删除，然后执行： ./gradlew  bootJar
就会重新生成jar包。jar包名字：工程名字-版本号.jar,这个jar包我们可以直接用java运行：
![bootjar.png](bootjar.png)

这个jar是一个自包含的，里边包含了运行的所有依赖，使用jar命令对其解压，查看内部有哪些内容：
```
jar -xvf spring-lecture-0.0.1-SNAPSHOT.jar
 BOOT-INF
 META-INF
 org
```

### jar包目录结构
解压后有三个目录： BOOT-INF、 META-INF、org

 BOOT-INF/classes里边是我们自己的工程的代码以及配置文件， BOOT-INF/lib里边是所有的依赖：
 ![bootjar1.png](bootjar1.png)
META-INF下面有一个MANIFEST.MF文件，里边的内容如下：
```
Manifest-Version: 1.0
Start-Class: com.tdl.springlecture.SpringLectureApplication
Spring-Boot-Classes: BOOT-INF/classes/
Spring-Boot-Lib: BOOT-INF/lib/
Spring-Boot-Version: 2.1.5.RELEASE
Main-Class: org.springframework.boot.loader.JarLauncher
```

此文件指定了入口文件，Main-Class是开始启动的类，Start-Class是我们自己写的包含main方法的全称。
库依赖路径，class文件路径，Spring-Boot的版本，Manifest的版本。Main-Class和Start-Class之间的关系后续介绍。
PS：Main-Class: org.springframework.boot.loader.JarLauncher在文件的结尾处又要换行，不然无法启动。

org目录是spring提供的一些class文件。
 ![bootjar2.png](bootjar2.png)
其中就有Main-Class: org.springframework.boot.loader.JarLauncher。

这里有个疑问，就是org目录下JarLauncher这些class文件是从哪里来的，我们在工程里边搜索压根搜索不到，如果想看这些类的源码其实可以引入相关的依赖【org.springframework.boot:spring-boot-loader】
 ![bootjar3.png](bootjar3.png)

在JarLauncher的源码中我们看到了BOOT-INF/classes/、BOOT-INF/lib/这些熟悉的路径，源码面前无虚假。

Launcher for JAR based archives. This launcher assumes that dependency jars are included inside a /BOOT-INF/lib directory and that application classes are included inside a /BOOT-INF/classes directory.

基于jar的启动器，启动器假设jar包的依赖在 /BOOT-INF/lib目录下，应用的class在/BOOT-INF/classes目录内。

### JarLauncher的继承体系结构与源码分析：
 ![bootjar4.png](bootjar4.png)
ExecutableArchiveLauncher下面有JarLauncher和WarLauncher，我们只看JarLauncher。
JarLauncher由于是启动类，肯定有main方法：
```
public static void main(String[] args) throws Exception {
  new JarLauncher().launch(args);
}
```
这里记事本实例化了一个JarLauncher的实例，然后调了父类 Launcher 的launch方法：
```
/**
 * Launch the application. This method is the initial entry point that should be
 * called by a subclass {@code public static void main(String[] args)} method.
 * @param args the incoming arguments
 * @throws Exception if the application fails to launch
 */
 启动一个应用，这个方法应该被初始的入口点，这个入口点应该是一个Launcher的子类的 public static void main(String[] args)这样的方法调用
protected void launch(String[] args) throws Exception {
  JarFile.registerUrlProtocolHandler();//不重要略过，只是注册一些关于url的属性
  //构建一个类加载器，我么先看一下getClassPathArchives方法做了什么
  ClassLoader classLoader = createClassLoader(getClassPathArchives());
  launch(args, getMainClass(), classLoader);
}
```
getClassPathArchives()：
```
/**
 * Returns the archives that will be used to construct the class path.
 * @return the class path archives
 * @throws Exception if the class path archives cannot be obtained
 */
 Launcher的一个抽象方法，返回用来构建class path的归档文件
protected abstract List<Archive> getClassPathArchives() throws Exception;
```

getClassPathArchives的子类实现位于ExecutableArchiveLauncher：
```
	@Override
	protected List<Archive> getClassPathArchives() throws Exception {
		List<Archive> archives = new ArrayList<>(
				this.archive.getNestedArchives(this::isNestedArchive));
		postProcessClassPathArchives(archives);
		return archives;
	}
```
	this.archive位于ExecutableArchiveLauncher的构造器当中：
  ```
  public ExecutableArchiveLauncher() {
		try {
			this.archive = createArchive();
		}
		catch (Exception ex) {
			throw new IllegalStateException(ex);
		}
	}
  //createArchive方法的作用是返回我们要执行的jar文件的绝对路径(java -jar xxx.jar中 xxx.jar的绝对路径)：
  protected final Archive createArchive() throws Exception {
  ProtectionDomain protectionDomain = getClass().getProtectionDomain();
  CodeSource codeSource = protectionDomain.getCodeSource();
  URI location = (codeSource != null) ? codeSource.getLocation().toURI() : null;
  String path = (location != null) ? location.getSchemeSpecificPart() : null;
  if (path == null) {
    throw new IllegalStateException("Unable to determine code source archive");
  }
  File root = new File(path);
  if (!root.exists()) {
    throw new IllegalStateException(
        "Unable to determine code source archive from " + root);
  }
  return (root.isDirectory() ? new ExplodedArchive(root)
      : new JarFileArchive(root));
}
  ```

然后【this.archive.getNestedArchives】是做的什么事情呢？
它Archive类里边
```
/**
 * Returns nested {@link Archive}s for entries that match the specified filter.
 * @param filter the filter used to limit entries
 * @return nested archives
 * @throws IOException if nested archives cannot be read
 */
 根据过滤器filter返回嵌套的归档文件
List<Archive> getNestedArchives(EntryFilter filter) throws IOException;
```
getNestedArchives实现类JarFileArchive：
```
@Override
	public List<Archive> getNestedArchives(EntryFilter filter) throws IOException {
		List<Archive> nestedArchives = new ArrayList<>();
    // JarFileArchive实现了 Iterable<Archive.Entry>
		for (Entry entry : this) {
			if (filter.matches(entry)) {
				nestedArchives.add(getNestedArchive(entry));
			}
		}
		return Collections.unmodifiableList(nestedArchives);
	}
```
这里我们就要看一下过滤器是过滤的那些归档，切到ExecutableArchiveLauncher的isNestedArchive：
```
ExecutableArchiveLauncher的对isNestedArchive的抽象：
/**
 * Determine if the specified {@link JarEntry} is a nested item that should be added
 * to the classpath. The method is called once for each entry.
 * @param entry the jar entry
 * @return {@code true} if the entry is a nested item (jar or folder)
 */
 判断指定的JarEntry是不是一个嵌套的，如果是嵌套的需要添加到classpath下边，这个方法对于每个entry只被调用一次。
protected abstract boolean isNestedArchive(Archive.Entry entry);

JarLauncher的实现：
@Override
protected boolean isNestedArchive(Archive.Entry entry) {
  //如果是目录判断是不是BOOT-INF/classes/目录
  if (entry.isDirectory()) {
    return entry.getName().equals(BOOT_INF_CLASSES);
  }
  //如果是文件判断文件的前缀是不是BOOT-INF/lib/开头
  return entry.getName().startsWith(BOOT_INF_LIB);
}
```

这里做一下补充：规范要求，jar文件的里边的启动类，必须是位于目录的顶层结构中，启动类不能位于嵌套的jar里边。
我们看到jar包的org目录下边的JarLauncher是在顶层目录的结构里边，是可以被加载的，而BOOT-INF/lib/里边的jar属于嵌套的（FatJar），同样BOOT-INF/classes/里边的类
没有在jar目录的顶层结构同样无法加载执行，spring要想加载执行他们需要做一些工作，后续我们会介绍，其实是spring自定义了自己的类加载器去加载。
回到Launcher的launch方法
```
protected void launch(String[] args) throws Exception {
		JarFile.registerUrlProtocolHandler();
		ClassLoader classLoader = createClassLoader(getClassPathArchives());
		launch(args, getMainClass(), classLoader);
	}
```
getClassPathArchives()得到集合要么是BOOT-INF/classes/或者BOOT-INF/lib/的目录或者是他们下边的class文件或者jar依赖文件，
紧接着我们进入createClassLoader方法：
```
/**
 * Create a classloader for the specified archives.
 * @param archives the archives
 * @return the classloader
 * @throws Exception if the classloader cannot be created
 */
// 为指定为归档文件创建类加载器，archives是我们拿到的所有的要加载的归档，返回一个spring定义的一个自定义加载器
protected ClassLoader createClassLoader(List<Archive> archives) throws Exception {
  List<URL> urls = new ArrayList<>(archives.size());
  for (Archive archive : archives) {
    urls.add(archive.getUrl());
  }
  //将所有归档文件的url统一放在一个集合里边
  return createClassLoader(urls.toArray(new URL[0]));
}

/**
	 * Create a classloader for the specified URLs.
	 * @param urls the URLs
	 * @return the classloader
	 * @throws Exception if the classloader cannot be created
	 */
   //为指定的url创建一个类加载器
	protected ClassLoader createClassLoader(URL[] urls) throws Exception {
    //自定义类加载器需要指定父加载器，getClass()是Launcher.clas 得到Launcher类的类加载器，即appClassLoader，系统类加载器
		return new LaunchedURLClassLoader(urls, getClass().getClassLoader());
	}

```

LaunchedURLClassLoader继承了URLClassLoader：
```
	/**
	 * Create a new {@link LaunchedURLClassLoader} instance.
	 * @param urls the URLs from which to load classes and resources
	 * @param parent the parent class loader for delegation
	 */
	public LaunchedURLClassLoader(URL[] urls, ClassLoader parent) {
    //直接调用了URLClassLoader的构造器
		super(urls, parent);
	}

```
URLClassLoader的说明：
This class loader is used to load classes and resources from a search path of URLs referring to both JAR files and directories. Any URL that ends with a '/' is assumed to refer to a directory. Otherwise, the URL is assumed to refer to a JAR file which will be opened as needed.
The AccessControlContext of the thread that created the instance of URLClassLoader will be used when subsequently loading classes and resources.
The classes that are loaded are by default granted permission only to access the URLs specified when the URLClassLoader was created.
这个类加载器用来加载类和资源，这些资源是通过搜索一个jar文件或者一个目录，任何一个以“/”结尾的会认为是一个目录，否则会认为是一个jar文件。

到现在【	ClassLoader classLoader = createClassLoader(getClassPathArchives());】得到了自定义的类加载器，接下来的【launch(args, getMainClass(), classLoader);】
进行加载，getMainClass()是用来找到我们自定义的含有main方法的class的名字，即com.twodragonlake.boot.MyApplication
我们看一下在ExecutableArchiveLauncher里边的实现：
```
@Override
protected String getMainClass() throws Exception {
  //得到Manifest的封装
  Manifest manifest = this.archive.getManifest();
  String mainClass = null;
  if (manifest != null) {
    //我们知道，在我们解压的bootJar出来的jar包里边有一个目录里是/META-INF/下边的文件是MANIFEST.MF，里边是key-value对，
    // manifest.getMainAttributes()就是拿到所有的key-value对，这里取的是Start-Class，即“com.twodragonlake.boot.MyApplication”这个字符串
    mainClass = manifest.getMainAttributes().getValue("Start-Class");
  }
  if (mainClass == null) {
    throw new IllegalStateException(
        "No 'Start-Class' manifest entry specified in " + this);
  }
  return mainClass;
}
```
返回到我们的主流承诺，进入到Launcher.launch()方法的实现：
```
/**
 * Launch the application given the archive file and a fully configured classloader.
 * @param args the incoming arguments
 * @param mainClass the main class to run
 * @param classLoader the classloader
 * @throws Exception if the launch fails
 */
protected void launch(String[] args, String mainClass, ClassLoader classLoader)
    throws Exception {
      //当前线程的上下文类加载器模式是系统类加载器，此处将线程山下文类加载器设置为spring自定义的LaunchedURLClassLoader
      //此处是set了LaunchedURLClassLoader，后边在某个时刻一定会get出来使用，去加载类，惯用套路
  Thread.currentThread().setContextClassLoader(classLoader);
  createMainMethodRunner(mainClass, args, classLoader).run();
}

/**
 * Create the {@code MainMethodRunner} used to launch the application.
 * @param mainClass the main class
 * @param args the incoming arguments
 * @param classLoader the classloader
 * @return the main method runner
 */
 //创建一个MainMethodRunner用来驱动运用
protected MainMethodRunner createMainMethodRunner(String mainClass, String[] args,
    ClassLoader classLoader) {
  return new MainMethodRunner(mainClass, args);
}

```

MainMethodRunner的doc：
  Utility class that is used by Launchers to call a main method. The class containing the main method is loaded using the thread context class loader.
  工具类，用来执行一个main方法，包含main方法的类是由线程上下文类加载器加载（线程山下文类加载器是LaunchedURLClassLoader）

构造函数：
```
public MainMethodRunner(String mainClass, String[] args) {
  //我们应用的含有main方法的启动类的权限定名，即，com.twodragonlake.boot.MyApplication
  this.mainClassName = mainClass;
  //参数
  this.args = (args != null) ? args.clone() : null;
}
```

接下来是重点，我们创建了一个MainMethodRunner，之后执行的是它的run方法：
```

	public void run() throws Exception {
    //获取线程上下文类加载（LaunchedURLClassLoader），然后执行LaunchedURLClassLoader的loadClass方法，参数this.mainClassName是com.twodragonlake.boot.MyApplication
    //即有自定义的类加载器LaunchedURLClassLoader加载我们自定义的启动类com.twodragonlake.boot.MyApplication。
		Class<?> mainClass = Thread.currentThread().getContextClassLoader()
				.loadClass(this.mainClassName);
        //得到com.twodragonlake.boot.MyApplication的main方法
		Method mainMethod = mainClass.getDeclaredMethod("main", String[].class);
    //执行com.twodragonlake.boot.MyApplication的main方法。invoke方法之所以传递的第一个参数是null，是因为main方法是一个static的，不属于某个对象。
		mainMethod.invoke(null, new Object[] { this.args });
	}
```

这里有个点就是 其实我们的com.twodragonlake.boot.MyApplication的main方法，不用非得名字是main，只不过是spring规定的是main，因为spring的代码里边写死是main，spring之所以规定方法名字必须是main的原因
是我们可能使用idea直接右单击运行我们的应用，，所以2者结合进行兼容，规定名字必须是main。

### 验证
我们修改MyApplication的main方法加入一行打印MyApplication的加载器的代码；
```
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
      //打印MyApplication的类加载器
        System.out.println("MyApplication classloader: "+MyApplication.class.getClassLoader());
        SpringApplication.run(MyApplication.class,args);
    }
}
```
使用如下两种方式运行：
- 直接用idea右单击运行main方法
- 使用gradle bootJar打成jar包，然后使用 java -jar spring_lecture-1.0-SNAPSHOT.jar 运行

他们打印的结果是一样的吗？
使用idea打印的结果是：
MyApplication classloader: sun.misc.Launcher$AppClassLoader@18b4aac2
即使用应用类加载器加载的。
使用java -jar spring_lecture-1.0-SNAPSHOT.jar运行的结果是:
MyApplication classloader: org.springframework.boot.loader.LaunchedURLClassLoader@5197848c
使用LaunchedURLClassLoader加载的。

辅助同类理解：https://incoder.org/2019/07/05/springboot2/#.XSIEKB259cQ.wechat
