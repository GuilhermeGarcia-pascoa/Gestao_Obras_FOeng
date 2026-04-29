# ⚡ Quick Start - 2 Minutos

## O que é?
Sistema para importar dados de um Excel diretamente para a app Flutter, sincronizando com o backend.

## Como Usar? (3 passos)

### 1️⃣ Abre a Obra
Toca numa obra na lista → abre ecrã de detalhes

### 2️⃣ Clica "Importar dados de Excel"
Botão amarelo no topo do ecrã

### 3️⃣ Preenche a Form
- **Ano:** Escolhe o ano dos dados (ex: 2024)
- **Mês:** Escolhe o mês dos dados (ex: Março)
- **Ficheiro:** Clica para selecionar o Excel (.xlsx ou .xlsm)
- Clica **"Importar"**

## Pronto! ✅
Os dados aparecem automaticamente no calendário.

---

## O que o Sistema Importa?

| O quê | De onde |
|-------|---------|
| Dias | Linha 8 do Excel (datas seriais) |
| Pessoas | Secção "Responsáveis em obra" + "Mão de obra" |
| Máquinas | Secção "Máquinas" |
| Viaturas | Secção "Viaturas" (com KM) |
| Gastos | Secção "Resumo de custos" (estadias, materiais, diesel, refeições) |

---

## Requisitos do Excel

Ficheiro deve ter:
- ✅ Extensão `.xlsx` ou `.xlsm`
- ✅ Tamanho máximo 20 MB
- ✅ Sheet principal chamada "C custo" (ou primeira sheet)
- ✅ Estrutura com secções mencionadas acima

---

## O que Acontece?

```
Clicas "Importar"
        ↓
System valida tudo
        ↓
Envia para backend
        ↓
Backend parseia Excel
        ↓
Backend cria/atualiza dados na BD
        ↓
App mostra resultado (ex: "3 dias • 5 pessoas")
        ↓
Calendário atualiza automaticamente
        ↓
Dados aparecem na app (gráficos, relatórios, etc.)
```

---

## Erros Comuns & Soluções

| Erro | Solução |
|------|---------|
| "Ficheiro não é um Excel válido" | Usa .xlsx ou .xlsm (não .csv) |
| "Nenhuma data válida encontrada" | Verifica se as datas estão na linha 8 do Excel |
| "Parâmetros inválidos" | Preenche ano e mês corretamente |
| "Token inválido" | Faz logout/login de novo |
| Nada acontece | Verifica se estás logado como **gestor** |

---

## Exemplos de Ficheiros

### ❌ ERRADO
```
Ficheiro CSV → Usa Excel!
Ficheiro XLS antigo → Usa .xlsx!
Excel sem linha 8 → Adiciona datas!
Excel sem secções → Estrutura corretamente!
```

### ✅ CORRETO
```
Excel 2024 (arquivo.xlsx)
Com secções bem nomeadas
Datas na linha 8
Dados a partir da linha 9
```

---

## Depois da Importação

- ✅ Dados aparecem no **Calendário** (pontos nos dias)
- ✅ Dados aparecem em **Gráficos**
- ✅ Dados aparecem em **Relatórios**
- ✅ Dados podem ser **editados** manualmente
- ✅ Dados podem ser **exportados** novamente

---

## Preciso de Ajuda?

- 📖 Documentação completa: `IMPORT_EXCEL_DOCS.md`
- 🔧 Guia técnico: `IMPLEMENTATION_GUIDE.md`
- 🏗️ Arquitetura: `ARCHITECTURE.md`
- 📚 Referência de API: `API_REFERENCE.md`
- ✅ Testes: `TESTING_CHECKLIST.md`

---

**Pronto! Isso é tudo o que precisas saber para usar. 🚀**
