---
title: spring_boot_cloud(9)Spring_Boot开发者工具与单元测试详解
date: 2019-7-28 18:13:32
tags: [单元测试 开发者工具 SpringBoot]
categories: spring_boot_cloud
---

### devtools准备

gradle加入依赖：
 "org.springframework.boot:spring-boot-devtools:2.1.3.RELEASE",

devtools可以在不重启应用的情况下使修改的代码生效，也就是热部署。
然后对idea进行一下设置：
![idea-devtools.png](idea-devtools.png)
勾选这个选项。
执行快捷键：ctrl + alt + shift + /
![idea-devtools1.png](idea-devtools1.png)
选择registry.
勾选这个选项：
![idea-devtools2.png](idea-devtools2.png)
此时我们修改的代码会及时编译和生效。

### devtools原理
devtools使用了2个不同的加载器，一个加载第三方jar包的classloader，另一个只加载当前工程里边的源代码的classloader，这样就加快了加载速度，而我们自己去重启会加载所有的类进行重启。


### 单元测试准备
添加gradle依赖：
  "org.springframework.boot:spring-boot-starter-test:2.1.3.RELEASE"

#### 编写测试类
```
@RunWith(SpringRunner.class)
@SpringBootTest
public class MyControllerTest {

    @Autowired
    private WebApplicationContext webApplicationContext;

    private MockMvc mockMvc;

    @Before
    public void setupMockMvc(){
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).build();
    }

    @Test
    public void testGetPerson() throws  Exception{
        mockMvc.perform(MockMvcRequestBuilders.get("/person/getPerson").
                contentType(MediaType.APPLICATION_JSON_UTF8).
                accept(MediaType.APPLICATION_JSON_UTF8)).
                andExpect(MockMvcResultMatchers.status().isOk()).
                andDo(MockMvcResultHandlers.print());
    }

}
```
@RunWith(SpringRunner.class)
@SpringBootTest
这两个是必须写的。
MockMvc是对mvc的一种请求的mock，通过实例我们可以看到MockMvc为我们提供了丰富的mock api。
