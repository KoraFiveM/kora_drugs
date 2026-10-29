CREATE TABLE IF NOT EXISTS `dealers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '0',
  `coords` longtext DEFAULT NULL,
  `time` longtext DEFAULT NULL,
  `createdby` varchar(50) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `qbdrugs_deliveries` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `active_citizenid` varchar(50) DEFAULT NULL,
  `status` varchar(16) NOT NULL,
  `data` longtext NOT NULL,
  `settlement` longtext DEFAULT NULL,
  `created_at` bigint NOT NULL,
  `completed_at` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `one_active_delivery` (`active_citizenid`),
  KEY `delivery_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
