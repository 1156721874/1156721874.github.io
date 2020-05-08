---
title: jvm原理（24）通过JDBC驱动加载深刻理解线程上下文类加载器机制
date: 2018-10-04 16:39:36
tags: JDBC驱动 线程上下文类加载器
categories: jvm
---

首先写一段加载jdbc驱动的代码：
```
<!-- more -->
public class MyTest27 {
    public static void main(String[] args) throws Exception {
        Class.forName("com.mysql.jdbc.Driver");
        Connection connection = DriverManager.getConnection("jdbc://localhost:3306/mytestdb","username","password");
    }
}
```
这段程序是加载jdbc驱动的惯用写法，第一行代码【 Class.forName("com.mysql.jdbc.Driver");】是将mysql的驱动【com.mysql.jdbc.Driver】注册到jdk的DriverManager上边去，我们跟进一下代码：

```
    public static Class<?> forName(String className)
                throws ClassNotFoundException {
        Class<?> caller = Reflection.getCallerClass();
        return forName0(className, true, ClassLoader.getClassLoader(caller), caller);
    }
```
这会引起【com.mysql.jdbc.Driver】的主动调用，因此会初始化com.mysql.jdbc.Driver：

```
public class Driver extends NonRegisteringDriver implements java.sql.Driver {
    //
    // Register ourselves with the DriverManager
    //
    static {
        try {
            //将当前mysql的com.mysql.jdbc.Driver 注册到jdk的java.sql.DriverManager里边去
            java.sql.DriverManager.registerDriver(new Driver());
        } catch (SQLException E) {
            throw new RuntimeException("Can't register driver!");
        }
    }
    .....略.....
```
这个时候会引起java.sql.DriverManager的主动调动，导致java.sql.DriverManager初始化（赋予静态变量正确的初始值），因此这个时候java.sql.DriverManager的静态代码块会被执行，我们到java.sql.DriverManager里边看一下：

```
public class DriverManager {
.....略....
    /**
     * Load the initial JDBC drivers by checking the System property
     * jdbc.properties and then use the {@code ServiceLoader} mechanism
     */
    static {
    调用loadInitialDrivers方法，继续往里跟进。
        loadInitialDrivers();
        println("JDBC DriverManager initialized");
    }
    .....略....
```
loadInitialDrivers方法：
```
    private static void loadInitialDrivers() {
        String drivers;
        try {
        //寻找系统属性jdbc.drivers有没有值，jdbc.drivers是加载jdbc驱动的另一种方式，了解即可
            drivers = AccessController.doPrivileged(new PrivilegedAction<String>() {
                public String run() {
                    return System.getProperty("jdbc.drivers");
                }
            });
        } catch (Exception ex) {
            drivers = null;
        }
        // If the driver is packaged as a Service Provider, load it.
        // Get all the drivers through the classloader
        // exposed as a java.sql.Driver.class service.
        // ServiceLoader.load() replaces the sun.misc.Providers()

        AccessController.doPrivileged(new PrivilegedAction<Void>() {
            public Void run() {
				这个地方是我们之前篇章介绍的,将所有java.sql.Driver驱动的实现全部加载。
                ServiceLoader<Driver> loadedDrivers = ServiceLoader.load(Driver.class);
                Iterator<Driver> driversIterator = loadedDrivers.iterator();

                /* Load these drivers, so that they can be instantiated.
                 * It may be the case that the driver class may not be there
                 * i.e. there may be a packaged driver with the service class
                 * as implementation of java.sql.Driver but the actual class
                 * may be missing. In that case a java.util.ServiceConfigurationError
                 * will be thrown at runtime by the VM trying to locate
                 * and load the service.
                 *
                 * Adding a try catch block to catch those runtime errors
                 * if driver not available in classpath but it's
                 * packaged as service and that service is there in classpath.
                 */
                try{
                    while(driversIterator.hasNext()) {
                        driversIterator.next();
                    }
                } catch(Throwable t) {
                // Do nothing
                }
                return null;
            }
        });

        println("DriverManager.initialize: jdbc.drivers = " + drivers);
		//如果drivers 是空的，直接返回，在当前我们的程序没有配置【jdbc.drivers】在运行的时候到了这里会直接返回。
        if (drivers == null || drivers.equals("")) {
            return;
        }
        String[] driversList = drivers.split(":");
        println("number of Drivers:" + driversList.length);
        for (String aDriver : driversList) {
            try {
                println("DriverManager.Initialize: loading " + aDriver);
                Class.forName(aDriver, true,
                        ClassLoader.getSystemClassLoader());
            } catch (Exception ex) {
                println("DriverManager.Initialize: load failed: " + ex);
            }
        }
    }
```
到了这里做了一件事就是讲jdbc驱动进行了加载（并没有初始化），接下来看一下DriverManager 的registerDriver：

```
    public static synchronized void registerDriver(java.sql.Driver driver,
            DriverAction da)
        throws SQLException {

        /* Register the driver if it has not already been added to our list */
        if(driver != null) {
            registeredDrivers.addIfAbsent(new DriverInfo(driver, da));
        } else {
            // This is for compatibility with the original DriverManager
            throw new NullPointerException();
        }

        println("registerDriver: " + driver);

    }
```
即，将driver封装成DriverInfo放到registeredDrivers里边，registeredDrivers是一个写时复制的集合：
```
    private final static CopyOnWriteArrayList<DriverInfo> registeredDrivers = new CopyOnWriteArrayList<>();
```
到此为止我们的com.mysql.jdbc.Driver放到了一个集合里边了。
我们再来看我们的程序：
```
        Class.forName("com.mysql.jdbc.Driver");
        Connection connection = DriverManager.getConnection("jdbc://localhost:3306/mytestdb","username","password");
```
第一行是加载com.mysql.jdbc.Driver，然而第二行却没有和com.mysql.jdbc.Driver有丝毫的关系，从表面上看，如果是初学者可能会感到很迷惑，我们就进入getConnection方法：

```
  public static Connection getConnection(String url,
        String user, String password) throws SQLException {
        java.util.Properties info = new java.util.Properties();

        if (user != null) {
            info.put("user", user);
        }
        if (password != null) {
            info.put("password", password);
        }

        return (getConnection(url, info, Reflection.getCallerClass()));
    }
```
前边是一些判空逻辑，之后调了重载的getConnection,注意第三个参数【Reflection.getCallerClass()】,得到调用者的类，，在我们的程序里边是【com.twodragonlake.jvm.classloader.MyTest27】：

```
    private static Connection getConnection( String url, java.util.Properties info, Class<?> caller) throws SQLException {
        /*
         * When callerCl is null, we should check the application's
         * (which is invoking this class indirectly)
         * classloader, so that the JDBC driver class outside rt.jar
         * can be loaded from here.
         */
         //如果调用者的类加载器不是null，就用调用者的类加载器加载驱动的实现，否则使用当前线程的上下文类加载器，
         //我们的程序得到的callerCL是系统类加载器。因此synchronized里边的if不会进入执行。
        ClassLoader callerCL = caller != null ? caller.getClassLoader() : null;
        synchronized(DriverManager.class) {
            // synchronize loading of the correct classloader.
            if (callerCL == null) {
                callerCL = Thread.currentThread().getContextClassLoader();
            }
        }

        if(url == null) {
            throw new SQLException("The url cannot be null", "08001");
        }

        println("DriverManager.getConnection(\"" + url + "\")");

        // Walk through the loaded registeredDrivers attempting to make a connection.
        // Remember the first exception that gets raised so we can reraise it.
        SQLException reason = null;
		//registeredDrivers是我们刚刚分析的，将当前classPath下的com.sql.Driver实现类的集合，当前的程序有2个mysql的驱动实现类。
        for(DriverInfo aDriver : registeredDrivers) {
            // If the caller does not have permission to load the driver then
            // skip it.
            //这个方法很重要，我们进去看一下，即callerCL带进去，即将系统类加载器带进去
            if(isDriverAllowed(aDriver.driver, callerCL)) {
                try {
                    println("    trying " + aDriver.driver.getClass().getName());
                    Connection con = aDriver.driver.connect(url, info);
                    //如果某一个连接返回的不是null，证明这个驱动就是我们要的驱动，就可以返回了。
                    if (con != null) {
                        // Success!
                        println("getConnection returning " + aDriver.driver.getClass().getName());
                        return (con);
                    }
                } catch (SQLException ex) {
                    if (reason == null) {
                        reason = ex;
                    }
                }

            } else {
                println("    skipping: " + aDriver.getClass().getName());
            }

        }

        // if we got here nobody could connect.
        if (reason != null)    {
            println("getConnection failed: " + reason);
            throw reason;
        }

        println("getConnection: no suitable driver found for "+ url);
        throw new SQLException("No suitable driver found for "+ url, "08001");
    }
```
isDriverAllowed方法：
```
    private static boolean isDriverAllowed(Driver driver, ClassLoader classLoader) {
        boolean result = false;
        if(driver != null) {
            Class<?> aClass = null;
            try {
	            //在之前分析知道，在com.mysql.jdbc.Driver初始化的时候，调用了DriverManager的注册方法，
	            //会加载java.sql.Driver的实现到DriverManager里边的registeredDrivers集合中;
	            //在这里又进行了一次加载，但是不同的是进行了初始化。
                aClass =  Class.forName(driver.getClass().getName(), true, classLoader);
            } catch (Exception ex) {
                result = false;
            }
			//这行代码是核心，为什么要进行一次"=="判断呢，这主要是为了避免类加载命名空间的问题，即aClass 和 driver.getClass()是由同一个类加载器加载的，
			//不同的加载器可能出现的情况是程序里边使用线程上下文加载器设置的加载器去加载（比如设置了用户自定义的加载器），和原始的加载器命名空间不一样。
			//之前的文章介绍过，也举过例子，即便是2个名字完全一样的类，由于类加载器不一样后边使用的时候一定会出现CastException
             result = ( aClass == driver.getClass() ) ? true : false;
        }

        return result;
    }
```
