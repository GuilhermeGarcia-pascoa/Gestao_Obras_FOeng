# ObrasApp — Setup Completo

Stack: **Flutter** (mobile + web) + **Node.js/Express** + **MySQL**

---

## 1. BASE DE DADOS — confirma as tabelas

O backend espera estas tabelas. Adapta os nomes se os teus forem diferentes:

```sql
-- Utilizadores (login)
CREATE TABLE utilizadores (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  nome          VARCHAR(100) NOT NULL,
  email         VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('admin','gestor','utilizador') DEFAULT 'utilizador',
  criado_em     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Obras
CREATE TABLE obras (
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

-- Semanas
CREATE TABLE semanas (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  obra_id        INT NOT NULL,
  numero_semana  INT NOT NULL,
  data_inicio    DATE,
  data_fim       DATE,
  estado         ENUM('aberta','fechada') DEFAULT 'aberta',
  faturado       DECIMAL(10,2) DEFAULT 0,
  FOREIGN KEY (obra_id) REFERENCES obras(id)
);

-- Operadores / Pessoas
CREATE TABLE operadores (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  nome                VARCHAR(100) NOT NULL,
  tipo_vinculo        ENUM('interno','externo') NOT NULL DEFAULT 'interno',
  cargo               VARCHAR(100),
  categoria_sindical  VARCHAR(100),
  custo_hora          DECIMAL(8,2),
  nif                 VARCHAR(20)
);

-- Máquinas
CREATE TABLE maquinas (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  nome             VARCHAR(100) NOT NULL,
  tipo             VARCHAR(50),
  matricula        VARCHAR(20),
  custo_hora       DECIMAL(8,2),
  combustivel_hora DECIMAL(8,2)
);

-- Viaturas
CREATE TABLE viaturas (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  modelo         VARCHAR(100) NOT NULL,
  matricula      VARCHAR(20),
  custo_km       DECIMAL(8,2),
  consumo_l100km DECIMAL(5,2),
  motorista_id   INT,
  FOREIGN KEY (motorista_id) REFERENCES operadores(id)
);

-- Horas de pessoas por semana
CREATE TABLE semana_pessoas (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  semana_id   INT NOT NULL,
  pessoa_id   INT NOT NULL,
  horas_total DECIMAL(6,2),
  custo_total DECIMAL(10,2),
  FOREIGN KEY (semana_id) REFERENCES semanas(id),
  FOREIGN KEY (pessoa_id) REFERENCES operadores(id)
);

-- Horas de máquinas por semana
CREATE TABLE semana_maquinas (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  semana_id         INT NOT NULL,
  maquina_id        INT NOT NULL,
  horas_total       DECIMAL(6,2),
  combustivel_total DECIMAL(10,2),
  FOREIGN KEY (semana_id) REFERENCES semanas(id),
  FOREIGN KEY (maquina_id) REFERENCES maquinas(id)
);

-- Km de viaturas por semana
CREATE TABLE semana_viaturas (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  semana_id   INT NOT NULL,
  viatura_id  INT NOT NULL,
  km_total    DECIMAL(8,2),
  custo_total DECIMAL(10,2),
  FOREIGN KEY (semana_id) REFERENCES semanas(id),
  FOREIGN KEY (viatura_id) REFERENCES viaturas(id)
);
```

---

## 2. BACKEND — Node.js

```bash
cd obras-app/backend
cp .env.example .env       # edita com os teus dados MySQL
npm install
npm run dev                # arranca em http://localhost:3000
```

### MigraÃ§Ã£o para histÃ³rico de custos
Para guardar o custo usado em cada dia, sem alterar obras antigas quando mudares preÃ§os base, corre tambÃ©m:

```sql
SOURCE backend/sql/migracao_historico_custos.sql;
```

### Migracao do vinculo das pessoas
Para distinguir trabalhadores internos e externos sem tocar em maquinas ou viaturas:

```sql
SOURCE backend/sql/migracao_tipo_vinculo_operadores.sql;
```

### Criar o primeiro utilizador admin
```bash
# Chama a rota de registo uma vez (depois podes removê-la ou protegê-la)
curl -X POST http://localhost:3000/api/auth/registar \
  -H "Content-Type: application/json" \
  -d '{"nome":"Admin","email":"admin@empresa.pt","password":"password123","role":"admin"}'
```

### Rotas disponíveis
| Método | Rota | Descrição |
|--------|------|-----------|
| POST | /api/auth/login | Login |
| GET  | /api/obras | Listar obras |
| POST | /api/obras | Criar obra |
| PUT  | /api/obras/:id | Editar obra |
| GET  | /api/semanas?obra_id=X | Semanas de uma obra |
| PUT  | /api/semanas/:id | Guardar horas e gastos |
| GET  | /api/semanas/:id/anterior | Dados da semana anterior |
| GET  | /api/equipa/pessoas | Listar pessoas |
| GET  | /api/equipa/maquinas | Listar máquinas |
| GET  | /api/equipa/viaturas | Listar viaturas |
| GET  | /api/relatorios/excel/:obra_id | Download Excel |
| GET  | /api/relatorios/pdf/:semana_id | Download PDF |
| GET  | /api/relatorios/graficos/:obra_id | Dados para gráficos |

---

## 3. FLUTTER

```bash
cd obras-app/flutter
flutter pub get

# Emulador Android:
flutter run

# iOS (Mac necessário):
flutter run -d iphone

# Web (browser):
flutter run -d chrome
```

### Configurar o IP do backend
Edita `lib/services/api_service.dart`:
```dart
// Emulador Android  →  10.0.2.2
// Emulador iOS      →  127.0.0.1
// Telemóvel físico  →  IP local da tua máquina (ex: 192.168.1.100)
const String _baseUrl = 'http://10.0.2.2:3000/api';
```

---

## Estrutura de ficheiros

```
obras-app/
├── backend/
│   ├── .env.example
│   ├── package.json
│   └── src/
│       ├── index.js              ← servidor Express
│       ├── db/pool.js            ← ligação MySQL
│       ├── middleware/auth.js    ← JWT
│       └── routes/
│           ├── auth.js           ← login/registo
│           ├── obras.js          ← CRUD obras
│           ├── semanas.js        ← registo semanal
│           ├── equipa.js         ← pessoas/máquinas/viaturas
│           └── relatorios.js     ← Excel, PDF, gráficos
└── flutter/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart             ← entrada + tema
        ├── services/
        │   ├── api_service.dart  ← todos os pedidos HTTP
        │   └── auth_provider.dart← estado de login
        └── screens/
            ├── login_screen.dart
            ├── main_shell.dart   ← navegação inferior
            ├── obras/            ← lista, detalhe, formulário
            ├── semanas/          ← registo semanal com horas
            ├── equipa/           ← pessoas, máquinas, viaturas
            ├── graficos/         ← gráficos de barras e linha
            └── config_screen.dart← exportação e logout
```
For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
