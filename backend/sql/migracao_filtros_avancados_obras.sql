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

SET @coluna_existe := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'obras'
    AND COLUMN_NAME = 'subempreiteiro'
);
SET @sql_alter := IF(
  @coluna_existe = 0,
  "ALTER TABLE obras ADD COLUMN subempreiteiro VARCHAR(255) NULL AFTER orcamento",
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
  @coluna_existe = 0,
  "ALTER TABLE obras ADD COLUMN zona VARCHAR(255) NULL AFTER subempreiteiro",
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
  @coluna_existe = 0,
  "ALTER TABLE obras ADD COLUMN responsavel VARCHAR(255) NULL AFTER zona",
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
  @coluna_existe = 0,
  "ALTER TABLE obras ADD COLUMN cliente VARCHAR(255) NULL AFTER responsavel",
  "SELECT 1"
);
PREPARE stmt FROM @sql_alter;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE obras
SET cliente = COALESCE(cliente, fo_panel_cliente)
WHERE cliente IS NULL
  AND fo_panel_cliente IS NOT NULL;
