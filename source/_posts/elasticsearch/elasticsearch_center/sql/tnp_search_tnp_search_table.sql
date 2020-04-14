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
-- Table structure for table `tnp_search_table`
--

DROP TABLE IF EXISTS `tnp_search_table`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `tnp_search_table` (
  `id` varchar(64) COLLATE utf8_bin NOT NULL,
  `database_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '数据库id',
  `table_name` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT 'table的名称',
  `index_name` varchar(64) CHARACTER SET latin1 DEFAULT NULL COMMENT '索引名称',
  `index_type` varchar(64) CHARACTER SET latin1 DEFAULT NULL COMMENT '索引类型',
  `index_alias` varchar(64) CHARACTER SET latin1 DEFAULT NULL COMMENT '索引别名',
  `index_version` int(11) DEFAULT NULL COMMENT '索引的版本',
  `t_status` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT '状态:available/changing/unavailable/history,changing值得是正在升级索引版本中',
  `parent_index_type` varchar(64) CHARACTER SET latin1 DEFAULT NULL COMMENT '父级索引类型，用于孩子索引构建parent-child索引关系',
  `parent_index_column_name` varchar(64) CHARACTER SET latin1 DEFAULT NULL COMMENT 'parent-child索引关系，子表用来关联父表的字段名称',
  `daily_check_column` varchar(64) CHARACTER SET latin1 DEFAULT NULL COMMENT '每天增量检查的时间依据字段，每张被同步的表必须配置一个modify_time或者update_time字段用于每天增量数据检查',
  `bucket_column` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '分桶字段',
  `error_desc` varchar(512) CHARACTER SET latin1 DEFAULT NULL COMMENT '同步失败原因和日志',
  `to_copy` varchar(128) CHARACTER SET latin1 DEFAULT NULL COMMENT '子表或者字段的copy_to指向的值',
  `is_delay_effect` varchar(45) COLLATE utf8_bin DEFAULT NULL COMMENT '是否延迟生效:yes/no',
  `create_time` datetime DEFAULT NULL,
  `modify_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `search_table_database_id_index` (`database_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='表格表';
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
