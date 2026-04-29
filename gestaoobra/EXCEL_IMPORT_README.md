# 📊 Sistema de Importação de Excel - Documentação Completa

> **Status:** ✅ Implementação Completa | **Versão:** 1.0.0 | **Data:** April 29, 2026

## 🎯 Resumo Executivo

Sistema completo de importação de ficheiros Excel na app Flutter, integrado com o backend Express.js. Permite gestores importar dados de dias, pessoas, máquinas, viaturas e gastos diretamente para uma obra específica.

### ✨ Características

- ✅ **Modal reutilizável** — seleção de ano, mês e ficheiro
- ✅ **Validação completa** — ficheiros, período, dados
- ✅ **Feedback em tempo real** — progresso, resultados, erros
- ✅ **Tratamento de erros** — mensagens claras e úteis
- ✅ **Upsert de dados** — sem duplicação
- ✅ **Log de ações** — auditoria completa
- ✅ **Segurança** — autenticação e autorização

---

## 📦 Ficheiros Criados

### Core (Serviços & Widgets)

1. **`lib/services/excel_service.dart`**
   - Serviço de orquestração
   - Classe `ExcelUploadResult`
   - Métodos: `selecionarFicheiro()`, `importarExcel()`, `gerarResumo()`

2. **`lib/widgets/excel_upload_dialog.dart`**
   - Modal completo e reutilizável
   - UI com dropdown de ano/mês, seleção de ficheiro
   - Exibição de resultado com ícones e mensagens

3. **`lib/services/api_service.dart`** (expandido)
   - Novo método: `importarExcel()` com multipart/form-data

4. **`lib/screens/obras/obra_detail_screen.dart`** (atualizado)
   - Botão "Importar dados de Excel"
   - Integração do modal
   - Callback para recarregar dados

### Documentação

5. **`QUICK_START.md`** — Guia de 2 minutos ⭐ **COMEÇA AQUI**
6. **`IMPORT_EXCEL_DOCS.md`** — Documentação detalhada do sistema
7. **`IMPLEMENTATION_GUIDE.md`** — Guia de implementação e teste
8. **`API_REFERENCE.md`** — Referência rápida de APIs
9. **`ARCHITECTURE.md`** — Diagramas e arquitetura
10. **`TESTING_CHECKLIST.md`** — Checklist de testes
11. **`EXCEL_INTEGRATION_EXAMPLES.dart`** — Exemplos de integração

### Configuração

12. **`pubspec.yaml`** (atualizado) — Adicionado `file_picker: ^6.1.1`

---

## 🚀 Como Começar

### 1. Setup

```bash
cd gestaoobra
flutter pub get
```

### 2. Compilar

```bash
flutter run
```

### 3. Testar

1. Abre uma obra na app
2. Clica em "Importar dados de Excel" (botão amarelo)
3. Seleciona um ficheiro Excel com dados válidos
4. Escolhe o ano e mês
5. Clica "Importar"

### 4. Resultado

Dados importados aparecem no calendário da obra! ✅

---

## 📖 Documentação por Caso de Uso

### Utilizador Final
- **Lê:** [QUICK_START.md](QUICK_START.md)
- **Tempo:** 2 minutos

### Programador (Integração)
- **Lê:** [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
- **Depois:** [EXCEL_INTEGRATION_EXAMPLES.dart](EXCEL_INTEGRATION_EXAMPLES.dart)
- **Tempo:** 15 minutos

### Arquiteto / Review Técnico
- **Lê:** [ARCHITECTURE.md](ARCHITECTURE.md)
- **Depois:** [IMPORT_EXCEL_DOCS.md](IMPORT_EXCEL_DOCS.md)
- **Tempo:** 30 minutos

### Tester / QA
- **Usa:** [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)
- **Referência:** [API_REFERENCE.md](API_REFERENCE.md)
- **Tempo:** Depende dos testes

---

## 🔄 Fluxo de Dados

```
User → App (Flutter) → Modal → File Picker → Backend → Database → App UI
                                   ↓              ↓          ↓
                            Validação    Parser Excel   Log Ações
```

### Detalhado

1. **User abre obra** → Calendário carrega
2. **User clica "Importar"** → Modal abre
3. **User seleciona ficheiro** → Valida extensão (.xlsx/.xlsm)
4. **User escolhe ano/mês** → Valida período (2020-2100, 1-12)
5. **User clica "Importar"** → Envia multipart form-data
6. **Backend recebe** → Valida autenticação (Bearer token)
7. **Backend valida autorização** → Apenas "gestor"
8. **Backend parseia Excel** → Extrai dados de secções
9. **Backend faz upsert** → INSERT/UPDATE sem duplicação
10. **Backend retorna resumo** → Estatísticas de importação
11. **App exibe resultado** → Sucesso ou erro
12. **App recarrega dados** → Calendário atualiza
13. **User vê novos dados** → Pronto! ✅

---

## 🔐 Segurança

- ✅ **Autenticação:** Bearer token obrigatório
- ✅ **Autorização:** Apenas utilizadores com role "gestor"
- ✅ **Validação:** Ficheiro, período, dados
- ✅ **Limite de tamanho:** 20 MB máximo
- ✅ **Log:** Todas as importações registadas para auditoria

---

## 🎨 UI/UX

### Modal de Importação

```
┌─────────────────────────────────────────────┐
│  Importar dados de Excel                    │
├─────────────────────────────────────────────┤
│                                             │
│  📋 Obra: Minha Obra                        │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ 📅 Ano          ▼                     │  │
│  │     [2024                           ]│  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ 📅 Mês          ▼                     │  │
│  │     [Abril                          ]│  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ 📁 Seleciona ficheiro                │  │
│  │    (clica para selecionar)           │  │
│  │    arquivo.xlsx ✅                   │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ✅ Importação com sucesso!                │
│  3 dias importados • 5 pessoas criadas     │
│                                             │
│              [Cancelar] [Importar]         │
└─────────────────────────────────────────────┘
```

---

## 🧪 Testes

Antes de usar em produção:

```bash
# Checklist em TESTING_CHECKLIST.md
- [ ] Teste de seleção de ficheiro
- [ ] Teste de validação de período
- [ ] Teste de importação bem-sucedida
- [ ] Teste de erros (ficheiro inválido, sem dados, etc.)
- [ ] Teste de UI/responsividade
- [ ] Teste em Android/iOS/Web
- [ ] Teste de stress (ficheiros grandes)
```

---

## 🐛 Troubleshooting

| Problema | Solução |
|----------|---------|
| "Ficheiro não é um Excel válido" | Usa `.xlsx` ou `.xlsm` (não `.csv`, `.xls`) |
| "Nenhuma data válida encontrada" | Verifica linha 8 do Excel (datas seriais 6-34) |
| Modal não abre | Verifica se estás logado como **gestor** |
| Dados não aparecem | Recarrega app (pull-to-refresh calendário) |
| Erro "Token inválido" | Faz logout/login de novo |
| Upload lento | Ficheiro pode ser muito grande; tira dados antigos |

---

## 🔧 Configuração (Customização)

### Alterar tamanho máximo de ficheiro

**Em `api_service.dart`:**
```dart
// Mudar fileSize
limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB
```

### Alterar validação de anos

**Em `excel_service.dart`:**
```dart
const minYear = 2015; // De 2020 para 2015
const maxYear = 2050; // De 2100 para 2050
```

### Alterar cor do botão

**Em `obra_detail_screen.dart`:**
```dart
backgroundColor: Colors.blue.shade700, // De amber para blue
```

---

## 📊 Estrutura do Excel Esperado

```
┌─────────┬─────────┬─────────┬─────────┬─────────┐
│ Col A   │ Col B   │ ...     │ Col G   │ Col H   │
├─────────┼─────────┼─────────┼─────────┼─────────┤
│ Row 1   │         │         │ OBRA:   │ Minha Obra
│ Row 7   │         │         │ Horas   │ 8, 8, 8...
│ Row 8   │         │         │ Datas   │ 6, 7, 8...
│ Row 9+  │ Dados   │         │         │
└─────────┴─────────┴─────────┴─────────┴─────────┘

Secções esperadas (a partir da Row 9):
• Responsáveis em obra (pessoas internas)
• Mão de obra (pessoas externas)
• Máquinas
• Viaturas (com KM)
• Refeições (almoço/jantar)
• Resumo de custos (estadias, materiais, diesel)
```

---

## 📞 Suporte & Contacto

### Documentação
- Ver ficheiros `.md` inclusos neste repositório

### Exemplos de Código
- Ver `EXCEL_INTEGRATION_EXAMPLES.dart`

### API Reference
- Ver `API_REFERENCE.md`

### Troubleshooting
- Ver secção "Troubleshooting" acima
- Ver `TESTING_CHECKLIST.md` para debug

---

## 📈 Próximos Passos (Futura)

### Curto Prazo
- [ ] Testes em staging
- [ ] Feedback de utilizadores
- [ ] Bug fixes

### Médio Prazo
- [ ] Preview dos dados antes de importar
- [ ] Drag-and-drop automático
- [ ] Barra de progresso com %

### Longo Prazo
- [ ] Importação em batch (múltiplos ficheiros)
- [ ] Agendamento de importações
- [ ] Histórico de importações
- [ ] Desfazer importações

---

## 📝 Histórico de Mudanças

### v1.0.0 (April 29, 2026)
- ✅ Implementação inicial completa
- ✅ Modal de importação com validação
- ✅ Integração no `obra_detail_screen`
- ✅ Documentação completa

---

## ✅ Checklist Final

Antes de fazer deploy:

- [ ] Todos os ficheiros criados estão no repositório
- [ ] `pubspec.yaml` foi atualizado com `file_picker`
- [ ] `flutter pub get` foi executado
- [ ] App compila sem erros
- [ ] Testes básicos passaram
- [ ] Documentação foi revisada
- [ ] Exemplos de código foram testados

---

**Desenvolvido com ❤️ para Gestão de Obras**

---

## 📚 Índice de Ficheiros

- [QUICK_START.md](QUICK_START.md) — Guia rápido (2 min)
- [IMPORT_EXCEL_DOCS.md](IMPORT_EXCEL_DOCS.md) — Documentação completa
- [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) — Guia de implementação
- [API_REFERENCE.md](API_REFERENCE.md) — Referência de API
- [ARCHITECTURE.md](ARCHITECTURE.md) — Diagramas técnicos
- [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md) — Checklist de testes
- [EXCEL_INTEGRATION_EXAMPLES.dart](EXCEL_INTEGRATION_EXAMPLES.dart) — Exemplos
- [README.md](README.md) ← **Este ficheiro**
