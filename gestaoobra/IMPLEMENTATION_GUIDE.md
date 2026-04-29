# Sistema de Importação Excel - Guia de Implementação ✅

## 📋 Resumo do que foi feito

### 1. Backend (já existente)
- ✅ Endpoint: `POST /api/obras/:obra_id/import-excel?ano=YYYY&mes=MM`
- ✅ Parser Excel com suporte a seriais de datas
- ✅ Upsert de dias, pessoas, máquinas, viaturas
- ✅ Log de ações

### 2. Frontend Flutter (criado)

#### Dependências adicionadas
- ✅ `file_picker: ^6.1.1` — para seleção de ficheiros

#### Ficheiros criados
1. **`lib/services/excel_service.dart`**
   - Serviço de orquestração para importação
   - Métodos: `selecionarFicheiro()`, `importarExcel()`, `gerarResumo()`
   - Classe `ExcelUploadResult` para resultados

2. **`lib/widgets/excel_upload_dialog.dart`**
   - Modal reutilizável com:
     - Seleção de ano e mês
     - Seleção de ficheiro com validação
     - Indicador de progresso
     - Exibição de resultados (dias, pessoas, máquinas, avisos)

3. **`lib/services/api_service.dart`** (expandido)
   - Novo método: `importarExcel()` com suporte a multipart/form-data

4. **`lib/screens/obras/obra_detail_screen.dart`** (atualizado)
   - Botão "Importar dados de Excel" (cor âmbar)
   - Integração do modal
   - Callback para recarregar dados após sucesso

#### Documentação
- ✅ `IMPORT_EXCEL_DOCS.md` — documentação completa
- ✅ `EXCEL_INTEGRATION_EXAMPLES.dart` — exemplos de integração

---

## 🚀 Como Testar

### Pré-requisitos
1. Backend a correr (Express.js na porta definida em `api_config.dart`)
2. App Flutter compilada
3. Utilizador logado com role **"gestor"** (obrigatório)
4. Ficheiro Excel de teste com formato correto

### Passos para Testar

1. **Na app Flutter:**
   - Acede a uma obra (ecrã `ObraDetailScreen`)
   - Clica no botão **"Importar dados de Excel"** (cor âmbar)

2. **No modal que abre:**
   - ✅ Seleciona o **ano** (ex: 2024)
   - ✅ Seleciona o **mês** (ex: Março)
   - ✅ Clica na área de ficheiro para selecionar um Excel
   - ✅ Clica **"Importar"**

3. **Resultado:**
   - Se sucesso:
     - Modal exibe: "✅ Importação com sucesso!"
     - Mostra resumo (dias importados, pessoas criadas, etc.)
     - Fecha-se automaticamente após 1.5s
     - Calendário é recarregado com novos dados
   
   - Se erro:
     - Modal exibe: "❌ Erro na importação"
     - Mensagem detalhada do erro
     - Pode tentar novamente

### Teste Manual de Ficheiro

**Estrutura esperada do Excel:**

```
Linha 1, Col G: Nome da obra
Linha 7: Horas-base (8, 9, etc.)
Linha 8: Datas (seriais 6-34 para dias 6-31 do mês)
Linha 9+: Dados de pessoas, máquinas, viaturas, gastos
```

**Secções esperadas:**
- "Responsáveis em obra"
- "Mão de obra"
- "Máquinas"
- "Viaturas"
- "Refeições"
- "Resumo de custos"

---

## 🔧 Configuração Rápida

### 1. Adicionar dependência (se ainda não fez)
```bash
cd gestaoobra
flutter pub get
```

### 2. Compilar app
```bash
flutter run
```

### 3. Testar
- Acede a uma obra
- Clica "Importar dados de Excel"
- Segue os passos acima

---

## 📊 Fluxo de Dados

```
┌─────────────────────────────────────┐
│  User clica "Importar Excel"        │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│  ExcelUploadDialog abre             │
│  - Seleciona ano, mês               │
│  - Seleciona ficheiro               │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│  ExcelService.importarExcel()       │
│  - Valida ficheiro e período        │
│  - Envia via multipart form-data    │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│  Backend: POST /obras/:id/...       │
│  - Parseia Excel                    │
│  - Faz upsert de dados              │
│  - Retorna resumo                   │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│  Dialog exibe resultados            │
│  - Sucesso: recarrega dados         │
│  - Erro: exibe mensagem             │
└─────────────────────────────────────┘
```

---

## 🛡️ Segurança

- ✅ Autenticação obrigatória (Bearer token)
- ✅ Autorização: apenas "gestor" pode importar
- ✅ Validação de ficheiro (.xlsx/.xlsm)
- ✅ Validação de período (ano/mês)
- ✅ Limite de tamanho de ficheiro (20 MB)
- ✅ Log de todas as importações

---

## 🐛 Troubleshooting

### Erro: "Ficheiro não é um Excel válido"
→ Usa .xlsx ou .xlsm (não .xls, .csv, etc.)

### Erro: "Nenhuma data válida encontrada"
→ Verifica se as datas estão na linha 8
→ Verifica se o ano/mês estão corretos

### Modal não abre
→ Verifica se estás logado como gestor
→ Verifica se a obra ID é válida

### Dados não aparecem após importação
→ Recarrega o app (pull-to-refresh no calendário)
→ Verifica os logs do backend

---

## 📝 Próximos Passos (Opcional)

1. **Melhorias de UX:**
   - Adicionar preview dos dados antes de importar
   - Suporte a drag-and-drop automático
   - Barra de progresso com percentagem

2. **Melhorias de funcionalidade:**
   - Importação em batch (múltiplos ficheiros)
   - Agendamento de importações
   - Histórico de importações

3. **Integração com admin:**
   - Criar ecrã de administração para gerenciar importações
   - Visualizar histórico
   - Desfazer importações

---

## 📚 Ficheiros Criados/Alterados

### Criados (novos)
- `lib/services/excel_service.dart`
- `lib/widgets/excel_upload_dialog.dart`
- `IMPORT_EXCEL_DOCS.md`
- `EXCEL_INTEGRATION_EXAMPLES.dart`
- `IMPLEMENTATION_GUIDE.md` ← este ficheiro

### Alterados
- `pubspec.yaml` — adicionado `file_picker`
- `lib/services/api_service.dart` — adicionado método `importarExcel()`
- `lib/screens/obras/obra_detail_screen.dart` — adicionado botão e integração

---

## ✅ Checklist de Verificação

- [ ] `pubspec.yaml` atualizado com `file_picker`
- [ ] `flutter pub get` executado
- [ ] `excel_service.dart` criado e sem erros
- [ ] `excel_upload_dialog.dart` criado e sem erros
- [ ] `api_service.dart` expandido com `importarExcel()`
- [ ] `obra_detail_screen.dart` atualizado com botão
- [ ] App compila sem erros
- [ ] Modal abre ao clicar no botão
- [ ] Ficheiro Excel pode ser selecionado
- [ ] Upload funciona e retorna resultado
- [ ] Calendário atualiza após sucesso

---

**Pronto para usar! 🎉**

Se tiveres dúvidas ou encontrares problemas, refere os exemplos em `EXCEL_INTEGRATION_EXAMPLES.dart` ou a documentação em `IMPORT_EXCEL_DOCS.md`.
