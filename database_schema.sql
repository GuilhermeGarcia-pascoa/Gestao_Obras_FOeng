-- ====================================================================
-- SCRIPT DE CRIAÇÃO DO SCHEMA DA BASE DE DADOS
-- Execute este script no seu MySQL para criar todas as tabelas
-- ====================================================================

-- Utilizadores (login)
CREATE TABLE IF NOT EXISTS utilizadores (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  nome          VARCHAR(100) NOT NULL,
  email         VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('admin','gestor','utilizador') DEFAULT 'utilizador',
  criado_em     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Obras
CREATE TABLE IF NOT EXISTS obras (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  codigo      VARCHAR(50) NOT NULL UNIQUE,
  nome        VARCHAR(200) NOT NULL,
  tipo        VARCHAR(50),
  estado      ENUM('planeada','em_curso','concluida') DEFAULT 'planeada',
  orcamento   DECIMAL(10,2),
  criado_por  INT,
  criado_em   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (criado_por) REFERENCES utilizadores(id)
);

-- Operadores / Pessoas
CREATE TABLE IF NOT EXISTS operadores (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  nome                VARCHAR(100) NOT NULL,
  cargo               VARCHAR(100),
  categoria_sindical  VARCHAR(100),
  custo_hora          DECIMAL(8,2),
  nif                 VARCHAR(20)
);

-- Máquinas
CREATE TABLE IF NOT EXISTS maquinas (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  nome             VARCHAR(100) NOT NULL,
  tipo             VARCHAR(50),
  matricula        VARCHAR(20),
  custo_hora       DECIMAL(8,2),
  combustivel_hora DECIMAL(8,2)
);

-- Viaturas
CREATE TABLE IF NOT EXISTS viaturas (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  modelo         VARCHAR(100) NOT NULL,
  matricula      VARCHAR(20),
  custo_km       DECIMAL(8,2),
  consumo_l100km DECIMAL(5,2),
  motorista_id   INT,
  FOREIGN KEY (motorista_id) REFERENCES operadores(id)
);

-- ====================================================================
-- NOVA ESTRUTURA: DIAS (em vez de SEMANAS)
-- ====================================================================

-- Dias de trabalho
CREATE TABLE IF NOT EXISTS dias (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  obra_id     INT NOT NULL,
  data        DATE NOT NULL,
  estado      ENUM('aberta','fechada') DEFAULT 'aberta',
  faturado    TINYINT(1) DEFAULT 0,
  criado_em   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (obra_id) REFERENCES obras(id),
  UNIQUE KEY unique_dia (obra_id, data)
);

-- Horas de pessoas por dia
CREATE TABLE IF NOT EXISTS dia_pessoas (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  dia_id      INT NOT NULL,
  pessoa_id   INT NOT NULL,
  horas_total DECIMAL(6,2),
  custo_total DECIMAL(10,2),
  FOREIGN KEY (dia_id) REFERENCES dias(id) ON DELETE CASCADE,
  FOREIGN KEY (pessoa_id) REFERENCES operadores(id)
);

-- Horas de máquinas por dia
CREATE TABLE IF NOT EXISTS dia_maquinas (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  dia_id            INT NOT NULL,
  maquina_id        INT NOT NULL,
  horas_total       DECIMAL(6,2),
  combustivel_total DECIMAL(10,2),
  FOREIGN KEY (dia_id) REFERENCES dias(id) ON DELETE CASCADE,
  FOREIGN KEY (maquina_id) REFERENCES maquinas(id)
);

-- Km de viaturas por dia
CREATE TABLE IF NOT EXISTS dia_viaturas (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  dia_id      INT NOT NULL,
  viatura_id  INT NOT NULL,
  km_total    DECIMAL(8,2),
  custo_total DECIMAL(10,2),
  FOREIGN KEY (dia_id) REFERENCES dias(id) ON DELETE CASCADE,
  FOREIGN KEY (viatura_id) REFERENCES viaturas(id)
);

-- ====================================================================
-- TABELAS DE SEMANAS (legado - manter para compatibilidade)
-- ====================================================================

-- Semanas
CREATE TABLE IF NOT EXISTS semanas (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  obra_id        INT NOT NULL,
  numero_semana  INT NOT NULL,
  data_inicio    DATE,
  data_fim       DATE,
  estado         ENUM('aberta','fechada') DEFAULT 'aberta',
  faturado       DECIMAL(10,2) DEFAULT 0,
  FOREIGN KEY (obra_id) REFERENCES obras(id)
);

-- Horas de pessoas por semana
CREATE TABLE IF NOT EXISTS semana_pessoas (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  semana_id   INT NOT NULL,
  pessoa_id   INT NOT NULL,
  horas_total DECIMAL(6,2),
  custo_total DECIMAL(10,2),
  FOREIGN KEY (semana_id) REFERENCES semanas(id) ON DELETE CASCADE,
  FOREIGN KEY (pessoa_id) REFERENCES operadores(id)
);

-- Horas de máquinas por semana
CREATE TABLE IF NOT EXISTS semana_maquinas (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  semana_id         INT NOT NULL,
  maquina_id        INT NOT NULL,
  horas_total       DECIMAL(6,2),
  combustivel_total DECIMAL(10,2),
  FOREIGN KEY (semana_id) REFERENCES semanas(id) ON DELETE CASCADE,
  FOREIGN KEY (maquina_id) REFERENCES maquinas(id)
);

-- Km de viaturas por semana
CREATE TABLE IF NOT EXISTS semana_viaturas (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  semana_id   INT NOT NULL,
  viatura_id  INT NOT NULL,
  km_total    DECIMAL(8,2),
  custo_total DECIMAL(10,2),
  FOREIGN KEY (semana_id) REFERENCES semanas(id) ON DELETE CASCADE,
  FOREIGN KEY (viatura_id) REFERENCES viaturas(id)
);

-- ====================================================================
-- FIM DO SCHEMA
-- ====================================================================
