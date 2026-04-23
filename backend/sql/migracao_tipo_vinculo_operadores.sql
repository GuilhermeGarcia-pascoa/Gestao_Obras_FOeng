SET @coluna_existe := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'operadores'
    AND COLUMN_NAME = 'tipo_vinculo'
);

SET @sql_alter := IF(
  @coluna_existe = 0,
  "ALTER TABLE operadores ADD COLUMN tipo_vinculo ENUM('interno','externo') NOT NULL DEFAULT 'interno' AFTER nome",
  "SELECT 1"
);

PREPARE stmt FROM @sql_alter;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE operadores
SET tipo_vinculo = 'interno'
WHERE tipo_vinculo IS NULL
   OR tipo_vinculo NOT IN ('interno', 'externo');
