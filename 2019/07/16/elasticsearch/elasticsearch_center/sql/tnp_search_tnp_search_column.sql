-- MySQL dump 10.13  Distrib 8.0.16, for Win64 (x86_64)
--
-- Host: 192.168.120.17    Database: tnp_search
-- ------------------------------------------------------
-- Server version	5.6.41-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
 SET NAMES utf8 ;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `tnp_search_column`
--

DROP TABLE IF EXISTS `tnp_search_column`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `tnp_search_column` (
  `id` varchar(64) COLLATE utf8_bin NOT NULL,
  `table_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '表格名称',
  `column_name` varchar(64) CHARACTER SET latin1 DEFAULT NULL COMMENT 'mysql字段名称',
  `column_type` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT 'mysql字段数据类型',
  `es_data_type` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT 'mqsql的数据库字段类型映射到es上的字段类型。',
  `is_key` varchar(4) CHARACTER SET latin1 DEFAULT NULL COMMENT '是否是主键,yes/no,用于设置索引的id',
  `extend_name` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT '扩展属性的名字，作为构建索引的嵌套对象名称',
  `keyword` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT '索引里边当做关键字来搜索',
  `copy_to` varchar(128) CHARACTER SET latin1 DEFAULT NULL COMMENT 'https://www.elastic.co/guide/en/elasticsearch/reference/current/copy-to.html#copy-to',
  `create_time` datetime DEFAULT NULL,
  `analyzer` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT '分词器',
  `modify_time` datetime DEFAULT NULL,
  `extend_is_nest` varchar(4) CHARACTER SET latin1 DEFAULT NULL COMMENT '针对于扩展的子表是否是嵌套的:yes/no',
  PRIMARY KEY (`id`),
  KEY `search_column_table_id_index` (`table_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='字段表';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2020-03-20 17:34:32
