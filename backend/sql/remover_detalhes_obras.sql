SET @coluna_existe := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'obras'
    AND COLUMN_NAME = 'subempreiteiro'
);
SET @sql_alter := IF(
  @coluna_existe > 0,
  "ALTER TABLE obras DROP COLUMN subempreiteiro",
  "SELECT 1"
);
PREPARE stmt FROM @sql_alter;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @coluna_existe := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'obras'
    AND COLUMN_NAME = 'zona'
);
SET @sql_alter := IF(
  @coluna_existe > 0,
  "ALTER TABLE obras DROP COLUMN zona",
  "SELECT 1"
);
PREPARE stmt FROM @sql_alter;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @coluna_existe := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'obras'
    AND COLUMN_NAME = 'responsavel'
);
SET @sql_alter := IF(
  @coluna_existe > 0,
  "ALTER TABLE obras DROP COLUMN responsavel",
  "SELECT 1"
);
PREPARE stmt FROM @sql_alter;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @coluna_existe := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'obras'
    AND COLUMN_NAME = 'cliente'
);
SET @sql_alter := IF(
  @coluna_existe > 0,
  "ALTER TABLE obras DROP COLUMN cliente",
  "SELECT 1"
);
PREPARE stmt FROM @sql_alter;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
