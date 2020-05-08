---
title: spring_boot_cloud(7)SpringBoot整合jsp详解
date: 2019-7-28 10:53:32
tags: [SpringBoot jsp]
categories: spring_boot_cloud
---

### Thymeleaf
类似于freemarker的模板引擎
<!-- more -->

### jsp demo
#### 编写controller代码：
```
@Controller
public class JspController {

    @GetMapping("/jsp")
    public String jsp(Map<String,Object> model){
        model.put("date",new Date());
        model.put("message", "hello world");
        return "result";
    }

    @GetMapping("/jspError")
    public String jspError(Map<String,Object> model){
        throw new RuntimeException("jsp error");
    }

}
```
在工程main目录下边新建webapp目录，在webapp下边新建WEB-INF目录,WEB-INF下边新建jsp文件夹；
#### 在jsp下边新建result.jsp文件：
```
<html>

<body>

    Date: ${date} <br/>
    Message: ${message}

</body>

</html>
```
#### 新建error.jsp文件：
```
<html>

<body>

error occured : ${status}, ${error}

</body>

</html>
```
#### application.yml配置
在spring结构下增加：
```
mvc:
  view:
    prefix: /WEB-INF/jsp
    suffix: .jsp
```

#### 浏览器访问
http://127.0.0.1:9090/jsp
得到的页面：
![Whitelabel-Error-Page.png](Whitelabel-Error-Page.png)
这个页面是spring的默认错误页面

错误的原因是我们的 application.yml配置没有配置正确，重新修改：
```
mvc:
  view:
    prefix: /WEB-INF/jsp/
    suffix: .jsp
```
然后gradle配置文件引入servlet的相关配置：
```
"javax.servlet:jstl",
"org.apache.tomcat.embed:tomcat-embed-jasper"
```
在/WEB-INF/jsp加了“/”，重启然后再次访问：
http://127.0.0.1:9090/jsp
