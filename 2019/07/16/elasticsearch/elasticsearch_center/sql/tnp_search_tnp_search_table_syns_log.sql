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
-- Table structure for table `tnp_search_table_syns_log`
--

DROP TABLE IF EXISTS `tnp_search_table_syns_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `tnp_search_table_syns_log` (
  `id` varchar(64) COLLATE utf8_bin NOT NULL,
  `table_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '表格id',
  `table_name` varchar(45) COLLATE utf8_bin DEFAULT NULL COMMENT '表格名称',
  `table_version` int(32) DEFAULT NULL COMMENT '表格版本',
  `params` varchar(1024) COLLATE utf8_bin DEFAULT NULL COMMENT '当前同步上下文参数',
  `syns_status` varchar(128) COLLATE utf8_bin DEFAULT NULL COMMENT '当前同步状态',
  `es_mapping` varchar(1024) COLLATE utf8_bin DEFAULT NULL COMMENT 'es映射',
  `es_error_msg` varchar(1024) COLLATE utf8_bin DEFAULT NULL COMMENT 'es异常信息',
  `create_time` datetime DEFAULT NULL,
  `modify_time` datetime DEFAULT NULL,
  `es_params` varchar(1024) CHARACTER SET latin1 DEFAULT NULL COMMENT 'es索引类型创建参数',
  PRIMARY KEY (`id`),
  KEY `table_syns_log_table_id_index` (`table_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='版本切换日志记录表';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2020-03-20 17:34:33
