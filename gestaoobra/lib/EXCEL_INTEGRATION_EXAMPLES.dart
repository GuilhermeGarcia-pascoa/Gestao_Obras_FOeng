// EXEMPLO DE USO DO SISTEMA DE IMPORTAÇÃO EXCEL

// ═══════════════════════════════════════════════════════════════════════════

// 1️⃣  INTEGRAÇÃO NO ECRÃ DE DETALHE DE OBRA (JÁ FEITA)
// ────────────────────────────────────────────────────────────────────────────

// No `obra_detail_screen.dart`:
// 
// Importações no topo:
//   import '../../services/excel_service.dart';
//   import '../../widgets/excel_upload_dialog.dart';
//
// No build do widget:
//   FilledButton.icon(
//     onPressed: () => _mostrarDialogoImportacao(context, obra),
//     icon: const Icon(Icons.upload_file),
//     label: const Text('Importar dados de Excel'),
//   )
//
// Função auxiliar:
//   Future<void> _mostrarDialogoImportacao(
//     BuildContext context, 
//     Map<String, dynamic> obra
//   ) async {
//     final resultado = await showDialog<ExcelUploadResult>(
//       context: context,
//       builder: (_) => ExcelUploadDialog(
//         obraId: obra['id'] as int,
//         obraNome: obra['nome']?.toString() ?? 'Obra desconhecida',
//         onImportSuccess: () {
//           if (mounted) _carregarMes(_focusedDay);
//         },
//       ),
//     );
//   }

// ═══════════════════════════════════════════════════════════════════════════

// 2️⃣  INTEGRAÇÃO NUM ECRÃ DE ADMINISTRAÇÃO
// ────────────────────────────────────────────────────────────────────────────

/*
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/excel_service.dart';
import '../../widgets/excel_upload_dialog.dart';

class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({Key? key}) : super(key: key);

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  List<Map<String, dynamic>> obras = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _carregarObras();
  }

  Future<void> _carregarObras() async {
    try {
      final lista = await ApiService.listarObras();
      setState(() {
        obras = lista.map((o) => Map<String, dynamic>.from(o)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _mostrarErro('Erro ao carregar obras: $e');
    }
  }

  Future<void> _abrirImportacao(Map<String, dynamic> obra) async {
    final resultado = await showDialog<ExcelUploadResult>(
      context: context,
      builder: (_) => ExcelUploadDialog(
        obraId: obra['id'] as int,
        obraNome: obra['nome']?.toString() ?? 'Obra',
        onImportSuccess: () {
          // Recarregar após sucesso
          _carregarObras();
        },
      ),
    );

    if (resultado?.sucesso == true && mounted) {
      final msg = ExcelService.gerarResumo(resultado!);
      _mostrarSucesso('Importação: $msg');
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _mostrarSucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        appBar: AppBar(title: Text('Importar Excel')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Importar Excel por Obra')),
      body: ListView.builder(
        itemCount: obras.length,
        itemBuilder: (context, i) {
          final obra = obras[i];
          return ListTile(
            title: Text(obra['nome'] ?? ''),
            subtitle: Text(obra['codigo'] ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () => _abrirImportacao(obra),
            ),
          );
        },
      ),
    );
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════

// 3️⃣  USO STANDALONE SEM DIALOG
// ────────────────────────────────────────────────────────────────────────────

/*
import 'package:obras_app/services/excel_service.dart';

Future<void> importarExcelDiretamente() async {
  try {
    // 1. Selecionar ficheiro
    final filePath = await ExcelService.selecionarFicheiro();
    if (filePath == null) {
      print('Importação cancelada');
      return;
    }

    // 2. Importar
    final resultado = await ExcelService.importarExcel(
      obraId: 123,
      filePath: filePath,
      ano: 2024,
      mes: 3,
    );

    // 3. Tratar resultado
    if (resultado.sucesso) {
      print('Sucesso!');
      print('Dias importados: ${resultado.diasImportados}');
      print('Pessoas criadas: ${resultado.pessoasCriadas}');
    } else {
      print('Erro: ${resultado.mensagem}');
      for (final erro in resultado.erros ?? []) {
        print('  - $erro');
      }
    }
  } catch (e) {
    print('Erro geral: $e');
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════

// 4️⃣  FLUXO CUSTOMIZADO COM VALIDAÇÕES
// ────────────────────────────────────────────────────────────────────────────

/*
Future<void> importarComValidacao(int obraId) async {
  // 1. Pedir confirmação
  if (!await _confirmarImportacao()) return;

  // 2. Selecionar ficheiro
  final filePath = await ExcelService.selecionarFicheiro();
  if (filePath == null) return;

  // 3. Pedir período
  final periodo = await _selecionarPeriodo();
  if (periodo == null) return;

  // 4. Mostrar progresso
  _mostrarProgress('A importar... isto pode levar alguns segundos');

  try {
    final resultado = await ExcelService.importarExcel(
      obraId: obraId,
      filePath: filePath,
      ano: periodo['ano'],
      mes: periodo['mes'],
    );

    if (resultado.sucesso) {
      // Sucesso
      _mostrarSucesso(ExcelService.gerarResumo(resultado));
      
      // Recarregar dados
      onImportSuccess?.call();
    } else {
      // Erro
      _mostrarErro(resultado.mensagem ?? 'Erro desconhecido');
    }
  } catch (e) {
    _mostrarErro('Erro: $e');
  }
}

Future<bool> _confirmarImportacao() async {
  // Implementar dialog de confirmação
  return true;
}

Future<Map<String, int>?> _selecionarPeriodo() async {
  // Implementar seleção de ano e mês
  return {'ano': 2024, 'mes': 3};
}

void _mostrarProgress(String msg) {
  // Implementar progress
}

void _mostrarSucesso(String msg) {
  // Implementar sucesso
}

void _mostrarErro(String msg) {
  // Implementar erro
}

VoidCallback? onImportSuccess;
*/

// ═══════════════════════════════════════════════════════════════════════════

// 5️⃣  CLASSE CUSTOMIZADA DE MODAL
// ────────────────────────────────────────────────────────────────────────────

/*
class CustomExcelImportDialog extends StatefulWidget {
  final int obraId;
  final VoidCallback? onSuccess;

  const CustomExcelImportDialog({
    required this.obraId,
    this.onSuccess,
  });

  @override
  State<CustomExcelImportDialog> createState() =>
      _CustomExcelImportDialogState();
}

class _CustomExcelImportDialogState extends State<CustomExcelImportDialog> {
  late DateTime _selectedDate = DateTime.now();
  String? _selectedFile;
  bool _importing = false;

  Future<void> _importar() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleciona um ficheiro primeiro')),
      );
      return;
    }

    setState(() => _importing = true);

    try {
      final resultado = await ExcelService.importarExcel(
        obraId: widget.obraId,
        filePath: _selectedFile!,
        ano: _selectedDate.year,
        mes: _selectedDate.month,
      );

      if (resultado.sucesso) {
        widget.onSuccess?.call();
        Navigator.pop(context, resultado);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resultado.mensagem ?? 'Erro')),
        );
      }
    } finally {
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Implementar UI customizada
    return Container();
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════

print('Exemplos de integração do sistema de importação Excel');
print('Ver comentários acima para diferentes casos de uso');
