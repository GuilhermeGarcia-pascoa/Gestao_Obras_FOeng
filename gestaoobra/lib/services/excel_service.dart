import 'package:file_picker/file_picker.dart';
import 'api_service.dart';

class ExcelUploadResult {
  final bool sucesso;
  final String? mensagem;
  final int? diasImportados;
  final int? diasAtualizados;
  final int? pessoasCriadas;
  final int? maquinasCriadas;
  final int? viaturasCriadas;
  final List<String>? erros;

  ExcelUploadResult({
    required this.sucesso,
    this.mensagem,
    this.diasImportados,
    this.diasAtualizados,
    this.pessoasCriadas,
    this.maquinasCriadas,
    this.viaturasCriadas,
    this.erros,
  });

  factory ExcelUploadResult.fromResponse(Map<String, dynamic> response) {
    final resumo = response['resumo'] as Map<String, dynamic>?;
    return ExcelUploadResult(
      sucesso: response['ok'] == true,
      diasImportados: resumo?['dias_importados'] as int?,
      diasAtualizados: resumo?['dias_atualizados'] as int?,
      pessoasCriadas: resumo?['pessoas_criadas'] as int?,
      maquinasCriadas: resumo?['maquinas_criadas'] as int?,
      viaturasCriadas: resumo?['viaturas_criadas'] as int?,
      erros: (resumo?['erros'] as List?)?.cast<String>() ?? [],
    );
  }

  factory ExcelUploadResult.erro(String mensagem) {
    return ExcelUploadResult(
      sucesso: false,
      mensagem: mensagem,
      erros: [mensagem],
    );
  }
}

class ExcelService {
  /// Seleciona um ficheiro Excel (.xlsx ou .xlsm)
  /// Retorna o caminho do ficheiro ou null se cancelado
  static Future<String?> selecionarFicheiro() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm'],
        dialogTitle: 'Seleciona ficheiro Excel',
        lockParentWindow: true,
      );

      return result?.files.single.path;
    } catch (e) {
      throw Exception('Erro ao selecionar ficheiro: $e');
    }
  }

  /// Importa um ficheiro Excel para uma obra
  static Future<ExcelUploadResult> importarExcel({
    required int obraId,
    required String filePath,
    required int ano,
    required int mes,
  }) async {
    try {
      if (!_validarFicheiro(filePath)) {
        return ExcelUploadResult.erro('Ficheiro não é um Excel válido (.xlsx ou .xlsm)');
      }

      if (!_validarPeriodo(ano, mes)) {
        return ExcelUploadResult.erro('Ano ou mês inválido');
      }

      // Envia para o backend
      final response = await ApiService.importarExcel(
        obraId: obraId,
        filePath: filePath,
        ano: ano,
        mes: mes,
      );

      return ExcelUploadResult.fromResponse(response);
    } on ApiException catch (e) {
      return ExcelUploadResult.erro(e.mensagem);
    } catch (e) {
      return ExcelUploadResult.erro('Erro inesperado: $e');
    }
  }

  static bool _validarFicheiro(String path) {
    return path.toLowerCase().endsWith('.xlsx') || 
           path.toLowerCase().endsWith('.xlsm');
  }

  static bool _validarPeriodo(int ano, int mes) {
    return ano >= 2020 && 
           ano <= 2100 && 
           mes >= 1 && 
           mes <= 12;
  }

  /// Gera uma descrição amigável do resultado da importação
  static String gerarResumo(ExcelUploadResult result) {
    if (!result.sucesso) {
      return 'Erro: ${result.mensagem}';
    }

    final parts = <String>[];
    
    if (result.diasImportados != null && result.diasImportados! > 0) {
      parts.add('${result.diasImportados} dias importados');
    }
    
    if (result.diasAtualizados != null && result.diasAtualizados! > 0) {
      parts.add('${result.diasAtualizados} dias atualizados');
    }
    
    if (result.pessoasCriadas != null && result.pessoasCriadas! > 0) {
      parts.add('${result.pessoasCriadas} pessoas criadas');
    }
    
    if (result.maquinasCriadas != null && result.maquinasCriadas! > 0) {
      parts.add('${result.maquinasCriadas} máquinas criadas');
    }
    
    if (result.viaturasCriadas != null && result.viaturasCriadas! > 0) {
      parts.add('${result.viaturasCriadas} viaturas criadas');
    }

    return parts.isNotEmpty ? parts.join(' • ') : 'Importação concluída';
  }
}
