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
-- Table structure for table `tnp_search_column_table`
--

DROP TABLE IF EXISTS `tnp_search_column_table`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `tnp_search_column_table` (
  `id` varchar(64) COLLATE utf8_bin NOT NULL,
  `search_column_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '字段的id',
  `search_column_name` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT '字段的名称(冗余用)',
  `relation_table_database_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '表格的数据库id',
  `relation_table_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '关联表的id',
  `relation_table_name` varchar(45) CHARACTER SET latin1 DEFAULT NULL COMMENT '字段关联的表名(版本号最大的)',
  `relation_table_columns` varchar(512) CHARACTER SET latin1 DEFAULT NULL COMMENT '字段关联的表要加载的字段,逗号隔开',
  `relation_table_column` varchar(64) CHARACTER SET latin1 DEFAULT NULL COMMENT '当前字段d的search_column_name和关联表的relation_table_column发生关联',
  `parent_id` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT '父级id，这个数据不允许是空字符串',
  `extend_is_nest` varchar(4) CHARACTER SET latin1 DEFAULT NULL COMMENT '针对于扩展的子表是否是嵌套的:yes/no',
  `extend_name` varchar(64) CHARACTER SET latin1 DEFAULT NULL,
  `refreshParent` varchar(6) COLLATE utf8_bin DEFAULT NULL COMMENT '是否刷新父级',
  `free_sql` varchar(256) COLLATE utf8_bin DEFAULT NULL COMMENT '自由sql',
  `t_distinct` varchar(45) COLLATE utf8_bin DEFAULT NULL COMMENT '是否去重，即sql加入distinct关键字。yes:加入distinct; no:不加入distinct',
  `area_update` varchar(45) COLLATE utf8_bin DEFAULT NULL COMMENT '是否区域更新父级索引文档:yes/no',
  `create_time` datetime DEFAULT NULL,
  `modify_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `search_column_table_column_id_index` (`search_column_id`),
  KEY `search_column_table_database_id_index` (`relation_table_database_id`),
  KEY `search_column_table_table_id_index` (`relation_table_id`),
  KEY `search_column_table_parent_id_index` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='多层嵌套关系，维护字段到子表的映射,因为table的版本在不断变化，此表不冗余table的id';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2020-03-20 17:34:37
