---
title: spring_boot_cloud(10)Apache-Kafka相关介绍
date: 2019-7-28 19:13:32
tags: [Apache Kafka SpringBoot]
categories: spring_boot_cloud
---

本片不对kafak原理做过多解释，只是介绍一下kafka和spring boot耦合的方式。

### 依赖引入
在gradle依赖配置当中引入以下依赖:
```
"org.springframework.kafka:spring-kafka",
"com.google.code.gson:gson:2.8.5"
```

### 编写生产者
生产者代码第一要使用`@Component`注册到spring容器当中:
```
@Component
public class KafkaProducer {

    @Autowired
    private KafkaTemplate<String,String> kafkaTemplate;

    public void sendKafkaMessage(KafkaMessage kafkaMessage){
        this.kafkaTemplate.send("myTopic", new Gson().toJson(kafkaMessage));
    }

}
```

### 编写消费者
和生产者一样，消费者也需要注册到spring 容器当中,并且要用`KafkaListener`表示监听的方法：
```
@Component
public class KafkaConsumer {

    @KafkaListener(topics = "myTopic",groupId = "myGroup")
    public void obtainMessage(ConsumerRecord<String, String> consumerRecord){
        System.out.println("ontainMessage invoked!");
        String topic =consumerRecord.topic();
        String key = consumerRecord.key();
        String value = consumerRecord.value();
        int partition = consumerRecord.partition();
        long timeStamp = consumerRecord.timestamp();

        System.out.println("topic: " + topic);
        System.out.println("key: " + key);
        System.out.println("value: " + value);
        System.out.println("partition: " + partition);
        System.out.println("timeStamp: " + timeStamp);

    }

}
```

### kafka配置信息

在application.yml文件当中配置相应的broker地址、序列化方式等信息：
```
kafka:
  producer:
    bootstrap-servers: localhost:9092
    key-serializer: org.apache.kafka.common.serialization.StringSerializer
    value-serializer: org.apache.kafka.common.serialization.StringSerializer
  consumer:
    bootstrap-servers: localhost:9092
    key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
    value-deserializer: org.apache.kafka.common.serialization.StringDeserializer

```

### 对外提供webapi

新建一个controller，实现在web端发送消息的功能：
```
@RestController
@RequestMapping(value = "/kafka", produces =  MediaType.APPLICATION_JSON_UTF8_VALUE)
public class KafkaController {

    @Autowired
    private KafkaProducer kafkaProducer;

    @RequestMapping(value = "message", method = RequestMethod.GET)
    public KafkaMessage sendKafkaMessages(@RequestParam(name = "id") long id,
                                          @RequestParam(name = "username") String username,
                                          @RequestParam(name = "password") String password){
        System.out.println("send kafka message invoked!");
        KafkaMessage kafkaMessage = new KafkaMessage();
        kafkaMessage.setId(id);;
        kafkaMessage.setUsername(username);
        kafkaMessage.setPasseord(password);
        kafkaMessage.setDate(new Date());
        kafkaProducer.sendKafkaMessage(kafkaMessage);
        return kafkaMessage;
    }

    @RequestMapping(value = "sendMessage2", method = RequestMethod.POST)
    public KafkaMessage sendMessage2(@RequestBody KafkaMessage kafkaMessage){
        System.out.println("send kafka message2 invoked!");
        kafkaMessage.setDate(new Date());
        this.kafkaProducer.sendKafkaMessage(kafkaMessage);
        return kafkaMessage;
    }

}

```
