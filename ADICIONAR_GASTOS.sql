-- Adicionar colunas de gastos à tabela dias
-- Se der erro que a coluna já existe, é normal - significa que já foi adicionada antes

ALTER TABLE dias ADD COLUMN valor_to DECIMAL(10,2) DEFAULT 0;
ALTER TABLE dias ADD COLUMN valor_combustivel DECIMAL(10,2) DEFAULT 0;
ALTER TABLE dias ADD COLUMN valor_estadias DECIMAL(10,2) DEFAULT 0;
ALTER TABLE dias ADD COLUMN valor_materiais DECIMAL(10,2) DEFAULT 0;

-- Verificar
DESCRIBE dias;
SELECT COUNT(*) as total_colunas FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'dias';
