# Sistema de Importação de Excel - Documentação

## Visão Geral

O sistema de importação de Excel permite aos utilizadores de **gestor** importar dados de um ficheiro Excel (.xlsx ou .xlsm) para uma obra específica. O ficheiro deve conter:

- **Dias** (com datas relativas)
- **Pessoas** (responsáveis e mão de obra)
- **Máquinas**
- **Viaturas** (com KM)
- **Gastos** (estadias, refeições, materiais, diesel)

## Arquitetura

### 1. **api_service.dart**
Método `importarExcel()` - envia ficheiro via multipart/form-data para o backend:
```dart
static Future<Map<String, dynamic>> importarExcel({
  required int obraId,
  required String filePath,
  required int ano,
  required int mes,
}) async { ... }
```

### 2. **excel_service.dart**
Serviço de orquestração com:
- `selecionarFicheiro()` - usa `file_picker` para escolher ficheiro
- `importarExcel()` - executa a importação e retorna `ExcelUploadResult`
- `gerarResumo()` - cria mensagem amigável com resultados

### 3. **excel_upload_dialog.dart**
Widget modal com:
- Seleção de ano e mês (obrigatório para interpretação de datas do Excel)
- Seleção de ficheiro com drag & drop simulado
- Progresso da importação
- Exibição de resultados (dias importados, pessoas criadas, avisos, etc.)

## Como Usar

### A. Integração no ecrã de obra (já feita!)

No `obra_detail_screen.dart`, há um botão "Importar dados de Excel" que abre o modal:

```dart
FilledButton.icon(
  onPressed: () => _mostrarDialogoImportacao(context, obra),
  icon: const Icon(Icons.upload_file),
  label: const Text('Importar dados de Excel'),
)
```

### B. Uso standalone em outro lugar

```dart
import 'package:obras_app/widgets/excel_upload_dialog.dart';

// Abrir modal
final resultado = await showDialog<ExcelUploadResult>(
  context: context,
  builder: (_) => ExcelUploadDialog(
    obraId: 123,
    obraNome: 'Obra A',
    onImportSuccess: () {
      // Callback ao sucesso — por ex, recarregar dados
      print('Importação concluída!');
    },
  ),
);

if (resultado?.sucesso == true) {
  print('Importou: ${resultado!.diasImportados} dias');
}
```

## Dependências Adicionadas

Adicionar ao `pubspec.yaml`:
```yaml
dependencies:
  file_picker: ^6.1.1
```

## Fluxo de Dados

```
Utilizador seleciona ficheiro Excel
         ↓
Escolhe ano e mês (para interpretação de datas relativas)
         ↓
Clica "Importar"
         ↓
excel_service.importarExcel() é chamado
         ↓
Envia ficheiro via multipart para: POST /api/obras/:id/import-excel?ano=YYYY&mes=MM
         ↓
Backend parseia Excel e faz upsert de dados
         ↓
Retorna resumo: dias_importados, pessoas_criadas, máquinas, viaturas, erros/avisos
         ↓
Dialog exibe resultados
         ↓
Sucesso: Dialog fecha e callback executa (ex: recarregar calendário)
         ↓
Erro: Dialog exibe mensagem de erro
```

## Estrutura do Ficheiro Excel Esperado

O backend espera um ficheiro com a seguinte estrutura (ver `import_excel.js` do backend):

### Linha 1, Coluna G
Nome da obra

### Linha 7
Horas-base por dia (ex: 8h, 9h, etc.)

### Linha 8
Datas (seriais do Excel — dias 6-34 que representam dia 6 a dia 34 de Janeiro 1900)

### Linhas 9+
Secções de dados:
- **Responsáveis em obra** — pessoas internas
- **Mão de obra** — pessoas externas
- **Máquinas** — equipamento
- **Viaturas** — veículos (KM)
- **Refeições** — almoço/jantar
- **Resumo de custos** — estadias, materiais, diesel

## Tratamento de Erros

O sistema captura e trata:
- Ficheiro inválido (não é .xlsx/.xlsm)
- Erro de leitura do ficheiro (corrupção, etc.)
- Erro de rede (offline, timeout, etc.)
- Erro de validação (ano/mês inválido)
- Erros de base de dados (duplicatas, chaves estrangeiras, etc.)

Todos os erros são exibidos no modal com ícone ❌ e mensagem clara.

## Caso de Uso

1. **Gestor abre detalhe de uma obra**
2. **Clica em "Importar dados de Excel"**
3. **Seleciona ficheiro .xlsx com dados de um mês específico**
4. **Escolhe o ano e mês aos quais esses dados se referem**
5. **Sistema faz upload e processa**
6. **Modal exibe resultado:**
   - Se sucesso: "3 dias importados • 5 pessoas criadas • 2 máquinas criadas"
   - Se erro: mensagem de erro com sugestões

## Notas Importantes

- **Datas relativas**: O Excel usa datas seriais (6, 7, 8, ..., 34) que são interpretadas como dias do mês escolhido
- **Upsert**: Se um dia/pessoa/máquina já existe, os dados são atualizados, não duplicados
- **Acesso**: Apenas utilizadores com role "gestor" podem importar (middleware `soGestor`)
- **Log**: Todas as importações são registadas no log de ações do sistema

## Troubleshooting

| Problema | Solução |
|----------|---------|
| "Nenhuma data válida encontrada" | Verifica se o mês e ano estão corretos; as datas devem estar na linha 8 do Excel |
| "Ficheiro não é um Excel válido" | Usa .xlsx ou .xlsm; não .csv, .xls, etc. |
| "Erro ao ler o ficheiro" | O ficheiro pode estar corrompido; tenta abrir no Excel e guardar novamente |
| Importação lenta | Ficheiros muito grandes (>20 MB) podem ser lentos; tira dados antigos |
| Pessoas/Máquinas não aparecem | Verifica se estão nas secções corretas do Excel e com formato válido |
