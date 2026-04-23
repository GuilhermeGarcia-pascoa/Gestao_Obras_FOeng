SET @coluna_existe := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'obras'
    AND COLUMN_NAME = 'data_inicio'
);
SET @sql_alter := IF(
  @coluna_existe = 0,
  "ALTER TABLE obras ADD COLUMN data_inicio DATE NULL AFTER estado",
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
    AND COLUMN_NAME = 'data_fim'
);
SET @sql_alter := IF(
  @coluna_existe = 0,
  "ALTER TABLE obras ADD COLUMN data_fim DATE NULL AFTER data_inicio",
  "SELECT 1"
);
PREPARE stmt FROM @sql_alter;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
