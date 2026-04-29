# Arquitetura do Sistema de Importação Excel

## 📐 Diagrama de Componentes

```
┌────────────────────────────────────────────────────────────────┐
│                     FLUTTER APP                                │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │         ObraDetailScreen                                │  │
│  │  (ecrã de detalhe de obra)                              │  │
│  │                                                          │  │
│  │  [Ver Gráficos] [Editar] [Exportar] [Importar] ◄──────┤  │
│  │                                   ▲                      │  │
│  └──────────────────────────┬────────┼──────────────────────┘  │
│                             │        │                         │
│                             │        └──► _mostrarDialogoImportacao()
│                             │                                   │
│  ┌─────────────────────────▼──────────────────────────────┐   │
│  │         ExcelUploadDialog                              │   │
│  │  ┌──────────────────────────────────────────────────┐  │   │
│  │  │ • Dropdown Ano                                   │  │   │
│  │  │ • Dropdown Mês                                   │  │   │
│  │  │ • Seleção de Ficheiro (FilePicker)              │  │   │
│  │  │ • [Importar]                                     │  │   │
│  │  │ • Resultado (status, resumo, erros)             │  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  └─────────┬────────────────────────────────────────────────┘  │
│            │                                                    │
│            │ ExcelService.importarExcel()                      │
│            │                                                    │
│  ┌─────────▼───────────────────────────────────────────────┐   │
│  │         ExcelService                                   │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │ • selecionarFicheiro()                          │   │   │
│  │  │ • importarExcel()                               │   │   │
│  │  │ • gerarResumo()                                 │   │   │
│  │  │ • _validarFicheiro()                            │   │   │
│  │  │ • _validarPeriodo()                             │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └─────────┬────────────────────────────────────────────────┘  │
│            │                                                    │
│            │ ApiService.importarExcel()                        │
│            │                                                    │
│  ┌─────────▼───────────────────────────────────────────────┐   │
│  │         ApiService                                    │   │
│  │  Multipart Form-Data Upload                           │   │
│  │  POST /obras/:id/import-excel?ano=YYYY&mes=MM         │   │
│  └─────────┬────────────────────────────────────────────────┘  │
│            │                                                    │
└────────────┼────────────────────────────────────────────────────┘
             │
             │ HTTP Multipart
             │
┌────────────▼────────────────────────────────────────────────────┐
│                     EXPRESS BACKEND                             │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  POST /api/obras/:obra_id/import-excel                 │  │
│  │  (route handler)                                        │  │
│  └────────────────────┬──────────────────────────────────────┘  │
│                       │                                         │
│  ┌────────────────────▼──────────────────────────────────────┐  │
│  │  Middleware                                             │  │
│  │  • auth (validar token)                                 │  │
│  │  • soGestor (apenas gestores)                           │  │
│  └────────────────────┬──────────────────────────────────────┘  │
│                       │                                         │
│  ┌────────────────────▼──────────────────────────────────────┐  │
│  │  parseExcel()                                           │  │
│  │  • Ler workbook                                         │  │
│  │  • Encontrar sheet "C custo"                            │  │
│  │  • Parse datas (serial → YYYY-MM-DD)                   │  │
│  │  • Parse pessoas (responsáveis + mão de obra)          │  │
│  │  • Parse máquinas                                       │  │
│  │  • Parse viaturas (km)                                 │  │
│  │  • Parse gastos (estadias, refeições, materiais, etc.) │  │
│  └────────────────────┬──────────────────────────────────────┘  │
│                       │                                         │
│  ┌────────────────────▼──────────────────────────────────────┐  │
│  │  Database Operations (Upsert)                           │  │
│  │  • INSERT/UPDATE dias                                   │  │
│  │  • INSERT/UPDATE operadores                             │  │
│  │  • INSERT/UPDATE dia_pessoas                            │  │
│  │  • INSERT/UPDATE maquinas                               │  │
│  │  • INSERT/UPDATE dia_maquinas                           │  │
│  │  • INSERT/UPDATE viaturas                               │  │
│  │  • INSERT/UPDATE dia_viaturas                           │  │
│  │  Transaction (commit/rollback)                          │  │
│  └────────────────────┬──────────────────────────────────────┘  │
│                       │                                         │
│  ┌────────────────────▼──────────────────────────────────────┐  │
│  │  Log Action                                             │  │
│  │  • Registar importação no histórico                     │  │
│  │  • Metadados (utilizador, ficheiro, estatísticas)      │  │
│  └────────────────────┬──────────────────────────────────────┘  │
│                       │                                         │
│  ┌────────────────────▼──────────────────────────────────────┐  │
│  │  Response                                               │  │
│  │  {                                                      │  │
│  │    "ok": true,                                          │  │
│  │    "obra": { "id", "codigo", "nome" },                 │  │
│  │    "periodo": { "ano", "mes" },                         │  │
│  │    "resumo": {                                          │  │
│  │      "dias_importados": N,                              │  │
│  │      "dias_atualizados": N,                             │  │
│  │      "pessoas_criadas": N,                              │  │
│  │      "maquinas_criadas": N,                             │  │
│  │      "viaturas_criadas": N,                             │  │
│  │      "erros": [...]                                     │  │
│  │    }                                                    │  │
│  │  }                                                      │  │
│  └────────────────────┬──────────────────────────────────────┘  │
│                       │                                         │
└───────────────────────┼──────────────────────────────────────────┘
                        │
                        │ HTTP Response (JSON)
                        │
┌───────────────────────▼──────────────────────────────────────────┐
│                     FLUTTER APP (cont.)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ExcelUploadResult.fromResponse()                        │  │
│  │  (parse resposta e cria objeto resultado)                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                       │                                         │
│  ┌────────────────────▼──────────────────────────────────────┐  │
│  │  ExcelUploadDialog                                      │  │
│  │  • Exibir resultado (sucesso/erro)                      │  │
│  │  • Mostrar resumo de estatísticas                       │  │
│  │  • Fechar dialog após 1.5s                              │  │
│  └────────────────────┬──────────────────────────────────────┘  │
│                       │                                         │
│  ┌────────────────────▼──────────────────────────────────────┐  │
│  │  onImportSuccess Callback                               │  │
│  │  • Recarregar calendário da obra                        │  │
│  │  • Mostrar SnackBar com sucesso                         │  │
│  │  • Atualizar UI                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Fluxo de Dados (Sequência)

```
1. User abre ecrã de obra
   └─► Load calendário com dias existentes

2. User clica "Importar dados de Excel"
   └─► _mostrarDialogoImportacao(context, obra)
       └─► showDialog(ExcelUploadDialog)

3. Modal abre
   └─► Pré-seleciona ano/mês atual
   └─► Mostra área de seleção de ficheiro

4. User seleciona ficheiro
   └─► ExcelService.selecionarFicheiro()
       └─► FilePicker abre
       └─► User escolhe ficheiro .xlsx/.xlsm
       └─► State atualiza para mostrar ficheiro

5. User clica "Importar"
   └─► _realizarImportacao()
       └─► Valida campos obrigatórios
       └─► ExcelService.importarExcel()
           └─► ApiService.importarExcel()
               └─► POST multipart para backend
           └─► Backend parseia Excel
           └─► Backend faz upsert de dados
           └─► Backend retorna resumo
       └─► ExcelUploadResult.fromResponse()

6. Modal exibe resultado
   ├─ Se sucesso:
   │  └─► Mostra ✅ "Importação com sucesso!"
   │  └─► Mostra resumo estatísticas
   │  └─► Aguarda 1.5s
   │  └─► Modal fecha
   │  └─► onImportSuccess callback executa
   │      └─► _carregarMes(_focusedDay)
   │      └─► Calendário recarrega
   │      └─► SnackBar mostra mensagem
   │
   └─ Se erro:
      └─► Mostra ❌ "Erro na importação"
      └─► Mostra mensagem de erro
      └─► Permite "Importar" novamente ou "Cancelar"

7. User vê dados importados
   └─► Calendário mostra pontos nos dias com dados
   └─► Clica num dia → vê pessoas, máquinas, viaturas
   └─► Dados aparecem em gráficos, relatórios, etc.
```

---

## 📦 Estrutura de Classes

```
ExcelUploadResult
├── sucesso: bool
├── mensagem: String?
├── diasImportados: int?
├── diasAtualizados: int?
├── pessoasCriadas: int?
├── maquinasCriadas: int?
├── viaturasCriadas: int?
├── erros: List<String>?
├── factory fromResponse(Map<String, dynamic>)
└── factory erro(String)

ExcelService
├── selecionarFicheiro(): Future<String?>
├── importarExcel(): Future<ExcelUploadResult>
├── gerarResumo(): String
├── _validarFicheiro(): bool
└── _validarPeriodo(): bool

ExcelUploadDialog extends StatefulWidget
├── obraId: int
├── obraNome: String
├── onImportSuccess: VoidCallback?
├── selectedAno: int?
├── selectedMes: int?
├── selectedFilePath: String?
├── selectedFileName: String?
├── isLoading: bool
├── errorMessage: String?
├── lastResult: ExcelUploadResult?
├── _selecionarFicheiro(): Future<void>
└── _realizarImportacao(): Future<void>
```

---

## 🔐 Autenticação e Autorização

```
┌─────────────────────────────────────────┐
│  Request com Bearer Token                │
│  Authorization: Bearer {token}          │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  auth middleware                         │
│  • Valida token                         │
│  • Extrai user ID                       │
│  • Passa para próxima route             │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  soGestor middleware                    │
│  • Verifica role = "gestor"             │
│  • Se OK → permite importação           │
│  • Se NOT → retorna 403 Forbidden       │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  Route handler                          │
│  (parseExcel e database ops)            │
└─────────────────────────────────────────┘
```

---

## 💾 Schema de Base de Dados (Tabelas Afetadas)

```
dias
├── id (PK)
├── obra_id (FK)
├── data (DATE)
├── valor_estadias
├── valor_refeicoes
├── valor_materiais
├── valor_combustivel
└── ... outras colunas

operadores
├── id (PK)
├── nome
├── custo_hora
├── tipo_vinculo (interno/externo)
└── ativo

dia_pessoas
├── id (PK)
├── dia_id (FK)
├── pessoa_id (FK)
├── horas_total
├── custo_total
├── custo_hora_snapshot
└── ... outras colunas

maquinas
├── id (PK)
├── nome
├── custo_hora
├── combustivel_hora
└── ativo

dia_maquinas
├── id (PK)
├── dia_id (FK)
├── maquina_id (FK)
├── horas_total
├── custo_total
├── custo_hora_snapshot
└── ... outras colunas

viaturas
├── id (PK)
├── modelo
├── matricula
├── custo_km
├── consumo_l100km
└── ativo

dia_viaturas
├── id (PK)
├── dia_id (FK)
├── viatura_id (FK)
├── km_total
├── custo_km_snapshot
└── ... outras colunas
```

---

## 🌐 Endpoints HTTP

```
Request:
────────
POST /api/obras/:obra_id/import-excel?ano=2024&mes=3 HTTP/1.1
Authorization: Bearer {token}
Content-Type: multipart/form-data

[binary file data]

Response (Success):
───────────────────
HTTP/1.1 200 OK
Content-Type: application/json

{
  "ok": true,
  "obra": { "id": 123, "codigo": "OBR01", "nome": "Obra A" },
  "periodo": { "ano": 2024, "mes": 3 },
  "resumo": {
    "dias_importados": 5,
    "dias_atualizados": 2,
    "pessoas_criadas": 3,
    "pessoas_encontradas": 2,
    "maquinas_criadas": 1,
    "maquinas_encontradas": 0,
    "viaturas_criadas": 0,
    "viaturas_encontradas": 1,
    "erros": ["Viatura X sem custo_km definido"]
  }
}

Response (Error):
────────────────
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "erro": "Parâmetros 'ano' e 'mes' são obrigatórios e devem ser válidos."
}
```

---

**Diagrama gerado:** April 29, 2026
**Versão:** 1.0.0
