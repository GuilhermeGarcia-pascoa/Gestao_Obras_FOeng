import 'package:flutter/material.dart';
import '../services/excel_service.dart';

class ExcelUploadDialog extends StatefulWidget {
  final int obraId;
  final String obraNome;
  final VoidCallback? onImportSuccess;

  const ExcelUploadDialog({
    Key? key,
    required this.obraId,
    required this.obraNome,
    this.onImportSuccess,
  }) : super(key: key);

  @override
  State<ExcelUploadDialog> createState() => _ExcelUploadDialogState();
}

class _ExcelUploadDialogState extends State<ExcelUploadDialog> {
  int? selectedAno;
  int? selectedMes;
  String? selectedFilePath;
  String? selectedFileName;
  bool isLoading = false;
  String? errorMessage;
  ExcelUploadResult? lastResult;

  final List<int> anos = List.generate(
    10,
    (i) => DateTime.now().year - 5 + i,
  );

  final List<Map<String, dynamic>> meses = [
    {'num': 1, 'nome': 'Janeiro'},
    {'num': 2, 'nome': 'Fevereiro'},
    {'num': 3, 'nome': 'Março'},
    {'num': 4, 'nome': 'Abril'},
    {'num': 5, 'nome': 'Maio'},
    {'num': 6, 'nome': 'Junho'},
    {'num': 7, 'nome': 'Julho'},
    {'num': 8, 'nome': 'Agosto'},
    {'num': 9, 'nome': 'Setembro'},
    {'num': 10, 'nome': 'Outubro'},
    {'num': 11, 'nome': 'Novembro'},
    {'num': 12, 'nome': 'Dezembro'},
  ];

  @override
  void initState() {
    super.initState();
    selectedAno = DateTime.now().year;
    selectedMes = DateTime.now().month;
  }

  Future<void> _selecionarFicheiro() async {
    try {
      final path = await ExcelService.selecionarFicheiro();
      if (path != null) {
        setState(() {
          selectedFilePath = path;
          selectedFileName = path.split('/').last;
          errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _realizarImportacao() async {
    if (selectedFilePath == null || selectedAno == null || selectedMes == null) {
      setState(() {
        errorMessage = 'Preencha todos os campos: ficheiro, ano e mês';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ExcelService.importarExcel(
        obraId: widget.obraId,
        filePath: selectedFilePath!,
        ano: selectedAno!,
        mes: selectedMes!,
      );

      setState(() {
        lastResult = result;
        isLoading = false;
      });

      if (result.sucesso) {
        // Mostra sucesso durante 2 segundos e depois fecha
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          widget.onImportSuccess?.call();
          Navigator.of(context).pop(result);
        }
      } else {
        setState(() {
          errorMessage = result.mensagem;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erro: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar dados de Excel'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info da obra
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Obra: ${widget.obraNome}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Seleção de ano
              DropdownButtonFormField<int>(
                value: selectedAno,
                decoration: InputDecoration(
                  labelText: 'Ano',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: anos
                    .map((ano) => DropdownMenuItem(
                          value: ano,
                          child: Text(ano.toString()),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selectedAno = value),
              ),
              const SizedBox(height: 12),

              // Seleção de mês
              DropdownButtonFormField<int>(
                value: selectedMes,
                decoration: InputDecoration(
                  labelText: 'Mês',
                  prefixIcon: const Icon(Icons.calendar_month),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: meses
                    .map((mes) => DropdownMenuItem(
                          value: mes['num'],
                          child: Text(mes['nome']),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selectedMes = value),
              ),
              const SizedBox(height: 16),

              // Seleção de ficheiro
              GestureDetector(
                onTap: isLoading ? null : _selecionarFicheiro,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.file_upload,
                        size: 32,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      if (selectedFileName == null)
                        const Text(
                          'Clica para selecionar um ficheiro Excel\n(.xlsx ou .xlsm)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        )
                      else
                        Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedFileName!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Resultado da importação (se disponível)
              if (lastResult != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lastResult!.sucesso
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: lastResult!.sucesso
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            lastResult!.sucesso
                                ? Icons.check_circle
                                : Icons.error,
                            color: lastResult!.sucesso
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lastResult!.sucesso
                                  ? 'Importação com sucesso!'
                                  : 'Erro na importação',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: lastResult!.sucesso
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (lastResult!.sucesso) ...[
                        const SizedBox(height: 8),
                        Text(
                          ExcelService.gerarResumo(lastResult!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ] else if (lastResult!.mensagem != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          lastResult!.mensagem!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                      if ((lastResult!.erros ?? []).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Avisos:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...lastResult!.erros!.take(3).map(
                          (erro) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '• $erro',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        if (lastResult!.erros!.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '• +${lastResult!.erros!.length - 3} mais...',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ],
                  ),
                )
              else if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading || lastResult?.sucesso == true
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: isLoading ? null : _realizarImportacao,
          icon: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(Colors.blue.shade700),
                  ),
                )
              : const Icon(Icons.upload_file),
          label: Text(isLoading ? 'A importar...' : 'Importar'),
        ),
      ],
    );
  }
}
