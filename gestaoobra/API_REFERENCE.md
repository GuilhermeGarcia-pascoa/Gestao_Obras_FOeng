# Quick Reference - API de Importação Excel

## 🎯 ExcelService

### Métodos

#### `selecionarFicheiro()`
Abre file picker para seleção de Excel.

```dart
final String? filePath = await ExcelService.selecionarFicheiro();
```

**Retorna:** Caminho absoluto do ficheiro, ou `null` se cancelado

**Válido para:** .xlsx, .xlsm

---

#### `importarExcel()`
Executa a importação de um ficheiro Excel para uma obra.

```dart
final ExcelUploadResult resultado = await ExcelService.importarExcel(
  obraId: 123,
  filePath: '/path/to/file.xlsx',
  ano: 2024,
  mes: 3,
);
```

**Parâmetros:**
- `obraId` (int) — ID da obra destino
- `filePath` (String) — Caminho do ficheiro no dispositivo
- `ano` (int) — Ano do período (2020-2100)
- `mes` (int) — Mês do período (1-12)

**Retorna:** `ExcelUploadResult` com detalhes da importação

**Exceções:** `ApiException` em caso de erro

---

#### `gerarResumo()`
Gera uma mensagem amigável com o resultado da importação.

```dart
final String resumo = ExcelService.gerarResumo(resultado);
// Output: "3 dias importados • 5 pessoas criadas • 2 máquinas criadas"
```

**Parâmetros:**
- `resultado` (ExcelUploadResult) — Resultado da importação

**Retorna:** String formatada com resumo

---

## 📦 ExcelUploadResult

Classe que representa o resultado de uma importação.

```dart
class ExcelUploadResult {
  bool sucesso;              // true se importação foi bem-sucedida
  String? mensagem;          // Mensagem de erro (se houver)
  int? diasImportados;       // Nº de dias criados
  int? diasAtualizados;      // Nº de dias atualizados
  int? pessoasCriadas;       // Nº de pessoas criadas
  int? maquinasCriadas;      // Nº de máquinas criadas
  int? viaturasCriadas;      // Nº de viaturas criadas
  List<String>? erros;       // Lista de avisos/erros adicionais
}
```

### Métodos Factory

#### `fromResponse()`
Constrói resultado a partir de resposta do servidor.

```dart
final resultado = ExcelUploadResult.fromResponse(responseMap);
```

#### `erro()`
Constrói resultado de erro.

```dart
final resultado = ExcelUploadResult.erro('Mensagem de erro');
```

---

## 🎨 ExcelUploadDialog

Modal pré-pronto para importação de Excel.

```dart
final resultado = await showDialog<ExcelUploadResult>(
  context: context,
  builder: (_) => ExcelUploadDialog(
    obraId: 123,
    obraNome: 'Obra A',
    onImportSuccess: () {
      print('Importação bem-sucedida!');
      // Recarregar dados, etc.
    },
  ),
);
```

### Parâmetros

| Parâmetro | Tipo | Obrigatório | Descrição |
|-----------|------|-------------|-----------|
| obraId | int | Sim | ID da obra |
| obraNome | String | Sim | Nome da obra (para exibição) |
| onImportSuccess | VoidCallback? | Não | Callback ao sucesso |

### Comportamento

1. Mostra seletor de ano e mês
2. Mostra área de seleção de ficheiro (clicável)
3. Mostra botão "Importar"
4. Durante upload: mostra spinner de progresso
5. Após upload:
   - Se sucesso: exibe resumo, fecha após 1.5s
   - Se erro: exibe mensagem de erro, permite tentar novamente

---

## 🔌 ApiService.importarExcel()

Método de baixo nível para enviar ficheiro.

```dart
final response = await ApiService.importarExcel(
  obraId: 123,
  filePath: '/path/file.xlsx',
  ano: 2024,
  mes: 3,
);
```

**Retorna:** Map com resposta do servidor:
```json
{
  "ok": true,
  "obra": { "id": 123, "codigo": "OBR01", "nome": "Obra A" },
  "periodo": { "ano": 2024, "mes": 3 },
  "resumo": {
    "dias_importados": 5,
    "dias_atualizados": 2,
    "pessoas_criadas": 3,
    "maquinas_criadas": 1,
    "viaturas_criadas": 0,
    "erros": ["Viatura X sem custo_km definido"]
  }
}
```

---

## 💡 Exemplos de Uso

### Uso Básico com Modal
```dart
ExcelUploadDialog(
  obraId: obra['id'],
  obraNome: obra['nome'],
  onImportSuccess: () => setState(() {
    _carregarMes(_focusedDay);
  }),
)
```

### Uso Programático
```dart
try {
  final filePath = await ExcelService.selecionarFicheiro();
  if (filePath != null) {
    final resultado = await ExcelService.importarExcel(
      obraId: 123,
      filePath: filePath,
      ano: 2024,
      mes: 3,
    );
    
    if (resultado.sucesso) {
      print('✅ ${ExcelService.gerarResumo(resultado)}');
    } else {
      print('❌ ${resultado.mensagem}');
    }
  }
} catch (e) {
  print('Erro: $e');
}
```

### Uso em Ecrã de Admin
```dart
ListView.builder(
  itemBuilder: (context, i) {
    final obra = obras[i];
    return ListTile(
      title: Text(obra['nome']),
      trailing: IconButton(
        icon: Icon(Icons.upload_file),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => ExcelUploadDialog(
            obraId: obra['id'],
            obraNome: obra['nome'],
          ),
        ),
      ),
    );
  },
)
```

---

## 🚨 Tratamento de Erros

```dart
try {
  final resultado = await ExcelService.importarExcel(
    obraId: obraId,
    filePath: filePath,
    ano: ano,
    mes: mes,
  );
  
  if (!resultado.sucesso) {
    // Erro de importação (mas request foi bem-sucedido)
    showErrorSnackBar(resultado.mensagem);
  }
} on ApiException catch (e) {
  // Erro de rede ou autenticação
  showErrorSnackBar('Erro API: ${e.mensagem}');
} catch (e) {
  // Erro geral
  showErrorSnackBar('Erro inesperado: $e');
}
```

---

## 📡 Endpoint Backend

### POST `/api/obras/:obra_id/import-excel`

**Query Parameters:**
- `ano` (int) — Ano do período (obrigatório)
- `mes` (int) — Mês do período (obrigatório)

**Body:** multipart/form-data
- `file` (binary) — Ficheiro Excel

**Headers Obrigatórios:**
- `Authorization: Bearer {token}`

**Validações:**
- Apenas utilizadores com role "gestor"
- Ficheiro deve ter tamanho ≤ 20 MB
- Período deve estar entre 2020-2100

**Respostas:**

✅ **200 OK — Sucesso**
```json
{
  "ok": true,
  "obra": { "id": 123, "codigo": "X", "nome": "Y" },
  "periodo": { "ano": 2024, "mes": 3 },
  "resumo": { ... }
}
```

❌ **400 Bad Request — Parâmetros inválidos**
```json
{ "erro": "Parâmetros 'ano' e 'mes' são obrigatórios" }
```

❌ **401 Unauthorized — Não autenticado**
```json
{ "erro": "Token inválido ou expirado" }
```

❌ **403 Forbidden — Não é gestor**
```json
{ "erro": "Apenas gestores podem importar" }
```

❌ **404 Not Found — Obra não existe**
```json
{ "erro": "Obra não encontrada" }
```

❌ **422 Unprocessable Entity — Erro na leitura do Excel**
```json
{ "erro": "Nenhuma data válida encontrada na linha 8" }
```

---

## 🔑 Constantes/Configuração

```dart
// Em excel_service.dart

// Extensões permitidas
const allowedExtensions = ['xlsx', 'xlsm'];

// Tamanho máximo (20 MB)
const maxFileSize = 20 * 1024 * 1024;

// Validação de período
const minYear = 2020;
const maxYear = 2100;
const minMonth = 1;
const maxMonth = 12;
```

---

## 📚 Relacionados

- Backend: `backend/src/routes/import_excel.js`
- Documentação: `IMPORT_EXCEL_DOCS.md`
- Exemplos: `EXCEL_INTEGRATION_EXAMPLES.dart`
- Guia: `IMPLEMENTATION_GUIDE.md`

---

**Última atualização:** April 29, 2026
**Versão:** 1.0.0
