import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:table_calendar/table_calendar.dart';
 
import '../../services/api_service.dart';
import '../../services/excel_service.dart';
import '../../widgets/excel_upload_dialog.dart';
import '../dias/dia_registo_screen.dart';
import '../graficos/graficos_screen.dart';
import 'obra_form_screen.dart';

// Import condicional — só compila dart:html na web
import '../config_screen_download_stub.dart'
    if (dart.library.html) '../config_screen_download_web.dart';
 
final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
 
num _parseOrcamento(dynamic value) {
  if (value is num) return value;
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
 
class ObraDetailScreen extends StatefulWidget {
  final Map<String, dynamic> obra;
 
  const ObraDetailScreen({super.key, required this.obra});
 
  @override
  State<ObraDetailScreen> createState() => _ObraDetailScreenState();
}
 
class _ObraDetailScreenState extends State<ObraDetailScreen> {
  late Map<String, dynamic> _obra;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<String> _diasComDados = {};
  bool _loading = true;
 
  @override
  void initState() {
    super.initState();
    _obra = Map.from(widget.obra);
    _carregarMes(_focusedDay);
  }
 
  String _formatMes(DateTime d) => DateFormat('yyyy-MM').format(d);
  String _formatData(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
 
  Future<void> _carregarMes(DateTime mes) async {
    setState(() => _loading = true);
    try {
      final lista = await ApiService.getDiasMes(_obra['id'], _formatMes(mes));
      setState(() {
        _diasComDados = Set<String>.from(lista.map((d) => d['data'] as String));
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }
 
  Future<void> _abrirDia(DateTime dia) async {
    final dataStr = _formatData(dia);
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaRegistoScreen(
          obraId: _obra['id'],
          data: dataStr,
          obraCodigo: _obra['codigo'] ?? '',
        ),
      ),
    );
    if (resultado == true) _carregarMes(_focusedDay);
  }
 
  Future<void> _recarregarObra() async {
    try {
      final obraAtualizada = await ApiService.getObra(_obra['id']);
      setState(() {
        _obra = obraAtualizada;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final obra = _obra;
 
    return Scaffold(
      appBar: AppBar(
        title: Text(obra['codigo'] ?? ''),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final maxContentWidth = isDesktop ? 1080.0 : 720.0;
          final selectedDateText = _selectedDay == null
              ? null
              : DateFormat("d 'de' MMMM yyyy", 'pt_PT').format(_selectedDay!);
          final selectedLabel = selectedDateText == null
              ? 'Seleciona um dia para abrir ou preencher o registo.'
              : 'Dia selecionado: $selectedDateText';
 
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.fromLTRB(16, 16, 16, isDesktop ? 12 : 0),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(isDesktop ? 20 : 0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obra['nome'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${obra['tipo'] ?? 'N/D'}  |  ${obra['estado'] ?? ''}',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        if (obra['orcamento'] != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Orcamento: ${_eur.format(_parseOrcamento(obra['orcamento']))}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          spacing: 10,
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GraficosScreen(
                                      obraId: obra['id'] as int,
                                      obraCodigo: obra['codigo']?.toString(),
                                      obraNome: obra['nome']?.toString(),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.insights_rounded),
                                label: const Text('Ver Graficos'),
                              ),
                            ),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final resultado = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ObraFormScreen(obra: obra),
                                    ),
                                  );
                                  if (resultado == true && mounted) {
                                    _recarregarObra();
                                  }
                                },
                                icon: const Icon(Icons.edit_rounded),
                                label: const Text('Editar Obra'),
                              ),
                            ),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _exportarExcel(context, obra),
                                icon: const Icon(Icons.table_chart_outlined),
                                label: const Text('Exportar Excel'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _mostrarDialogoImportacao(context, obra),
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Importar dados de Excel'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _carregarMes(_focusedDay),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            Container(
                              padding: EdgeInsets.all(isDesktop ? 20 : 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF252D3A) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Calendario da obra',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TableCalendar(
                                    locale: 'pt_PT',
                                    firstDay: DateTime(2020),
                                    lastDay: DateTime(2030),
                                    focusedDay: _focusedDay,
                                    rowHeight: isDesktop ? 64 : 52,
                                    daysOfWeekHeight: isDesktop ? 28 : 22,
                                    availableGestures: AvailableGestures.horizontalSwipe,
                                    selectedDayPredicate: (d) => _selectedDay != null && isSameDay(d, _selectedDay!),
                                    onDaySelected: (selected, focused) {
                                      setState(() {
                                        _selectedDay = selected;
                                        _focusedDay = focused;
                                      });
                                      _abrirDia(selected);
                                    },
                                    onPageChanged: (focused) {
                                      _focusedDay = focused;
                                      _carregarMes(focused);
                                    },
                                    calendarBuilders: CalendarBuilders(
                                      markerBuilder: (context, day, events) {
                                        final str = _formatData(day);
                                        if (_diasComDados.contains(str)) {
                                          return Positioned(
                                            bottom: 6,
                                            child: Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    headerStyle: HeaderStyle(
                                      formatButtonVisible: false,
                                      titleCentered: true,
                                      headerPadding: EdgeInsets.symmetric(vertical: isDesktop ? 8 : 4),
                                      titleTextStyle: TextStyle(
                                        fontSize: isDesktop ? 18 : 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                      leftChevronIcon: Icon(
                                        Icons.arrow_back_ios,
                                        size: 16,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                      rightChevronIcon: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    daysOfWeekStyle: DaysOfWeekStyle(
                                      weekdayStyle: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      weekendStyle: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    calendarStyle: CalendarStyle(
                                      outsideDaysVisible: false,
                                      cellMargin: const EdgeInsets.all(4),
                                      cellPadding: EdgeInsets.zero,
                                      markerSize: 7,
                                      todayDecoration: BoxDecoration(
                                        color: const Color(0x331A1A2E),
                                        border: Border.all(color: const Color(0xFF1A1A2E).withOpacity(0.18)),
                                        shape: BoxShape.circle,
                                      ),
                                      selectedDecoration: const BoxDecoration(
                                        color: Color(0xFF1A1A2E),
                                        shape: BoxShape.circle,
                                      ),
                                      defaultDecoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      weekendDecoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      defaultTextStyle: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      weekendTextStyle: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      outsideTextStyle: TextStyle(
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                      todayTextStyle: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      selectedTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      _legendDot('Dia com registo', const Color(0xFF1A1A2E)),
                                      _legendOutline('Hoje'),
                                      _legendFill('Dia selecionado', const Color(0xFF1A1A2E)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
 
  Widget _legendDot(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
 
  Widget _legendOutline(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1A1A2E).withOpacity(0.35)),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
 
  Widget _legendFill(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ── Export helpers ────────────────────────────────────────────────────────

  Future<void> _exportarExcel(BuildContext context, Map<String, dynamic> obra) async {
    try {
      final obraId = int.parse(obra['id'].toString());
      final codigo = obra['codigo'] ?? 'obra';

      await _descarregarFicheiro(
        context: context,
        bytes: () => ApiService.downloadExcel(obraId),
        nomeFicheiro: 'excel_${codigo}_${_fmtApi(DateTime.now())}.xlsx',
        successMsg: 'Excel descarregado com sucesso!',
      );
    } on ApiException catch (e) {
      if (context.mounted) _snackError(context, e.mensagem);
    }
  }

  Future<void> _descarregarFicheiro({
    required BuildContext context,
    required Future<List<int>> Function() bytes,
    required String nomeFicheiro,
    required String successMsg,
  }) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A descarregar ficheiro…'), duration: Duration(seconds: 60)),
      );
    }

    try {
      final data = await bytes();

      if (kIsWeb) {
        // ── WEB: força download via browser ─────────────────────────────
        downloadBytesWeb(data, nomeFicheiro);
      } else {
        // ── NATIVO: guarda no sistema de ficheiros ───────────────────────
        Directory dir;
        try {
          if (Platform.isAndroid) {
            dir = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
          } else {
            dir = await getApplicationDocumentsDirectory();
          }
        } catch (_) {
          dir = await getTemporaryDirectory();
        }
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/$nomeFicheiro');
        await file.writeAsBytes(data, flush: true);

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(successMsg),
            backgroundColor: const Color(0xFF0F9D8A),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copiar caminho',
              textColor: Colors.white,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: file.path));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caminho copiado!')));
                }
              },
            ),
          ));
          return;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMsg),
          backgroundColor: const Color(0xFF0F9D8A),
          duration: const Duration(seconds: 4),
        ));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _snackError(context, e.mensagem);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _snackError(context, 'Erro ao descarregar ficheiro');
      }
    }
  }

  void _snackError(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE53935)));

  Future<void> _mostrarDialogoImportacao(BuildContext context, Map<String, dynamic> obra) async {
    final resultado = await showDialog<ExcelUploadResult>(
      context: context,
      builder: (_) => ExcelUploadDialog(
        obraId: obra['id'] as int,
        obraNome: obra['nome']?.toString() ?? 'Obra desconhecida',
        onImportSuccess: () {
          if (mounted) {
            _carregarMes(_focusedDay);
          }
        },
      ),
    );

    if (resultado != null && resultado.sucesso && context.mounted) {
      final resumo = ExcelService.gerarResumo(resultado);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importação concluída! $resumo'),
          backgroundColor: const Color(0xFF0F9D8A),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
 
 