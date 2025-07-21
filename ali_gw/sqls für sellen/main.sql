CREATE TABLE `ali_gwmain` (
  `faction_name` varchar(50) NOT NULL,
  `points` int(11) NOT NULL DEFAULT 0,
  `wins` int(11) NOT NULL DEFAULT 0,
  `loses` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`faction_name`)
);


CREATE TABLE `ali_gwplayers` (
  `identifier` varchar(60) NOT NULL,
  `kills` int(11) NOT NULL DEFAULT 0,
  `deaths` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`identifier`)
);