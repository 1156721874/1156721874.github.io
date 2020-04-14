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
-- Table structure for table `tnp_search_change_snapshot`
--

DROP TABLE IF EXISTS `tnp_search_change_snapshot`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `tnp_search_change_snapshot` (
  `id` varchar(64) COLLATE utf8_bin NOT NULL,
  `database_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '数据库id',
  `table_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '表id',
  `c_table_name` varchar(45) COLLATE utf8_bin DEFAULT NULL COMMENT '表名称',
  `operation_type` varchar(45) COLLATE utf8_bin DEFAULT NULL COMMENT '操作类型(update/delete)',
  `business_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '业务id',
  `change_datas` varchar(4096) COLLATE utf8_bin DEFAULT NULL COMMENT '发生变化的数据，用于删除额情况',
  `c_status` varchar(45) COLLATE utf8_bin DEFAULT NULL COMMENT '状态：init,running,error,done',
  `attach_date` date DEFAULT NULL COMMENT '数据进入搜索系统的时间',
  `create_time` datetime DEFAULT NULL,
  `modify_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unit_index` (`database_id`,`table_id`,`operation_type`,`business_id`,`c_status`,`attach_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='案发现场快照表';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2020-03-20 17:34:36
