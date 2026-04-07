import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../dias/dia_registo_screen.dart';
import 'obra_form_screen.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

// Função auxiliar para garantir que o orçamento é sempre um num válido
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
  DateTime _focusedDay   = DateTime.now();
  DateTime? _selectedDay;
  Set<String> _diasComDados = {};   // datas no formato 'YYYY-MM-DD'
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregarMes(_focusedDay);
  }

  String _formatMes(DateTime d) => DateFormat('yyyy-MM').format(d);
  String _formatData(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _carregarMes(DateTime mes) async {
    setState(() => _loading = true);
    try {
      final lista = await ApiService.getDiasMes(
        widget.obra['id'], _formatMes(mes));
      setState(() {
        _diasComDados = Set<String>.from(lista.map((d) => d['data'] as String));
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _abrirDia(DateTime dia) async {
    final dataStr = _formatData(dia);
    // Abre o ecrã de registo; o backend cria o dia automaticamente se não existir
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaRegistoScreen(
          obraId:      widget.obra['id'],
          data:        dataStr,
          obraCodigo:  widget.obra['codigo'] ?? '',
        ),
      ),
    );
    if (resultado == true) _carregarMes(_focusedDay);
  }

  Future<void> _deletarObra(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar obra'),
        content: const Text('Tens a certeza que queres apagar esta obra? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await ApiService.apagarObra(widget.obra['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obra apagada com sucesso'), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.mensagem}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final obra = widget.obra;
    final role = context.watch<AuthProvider>().utilizador?['role'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text(obra['codigo'] ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ObraFormScreen(obra: obra)),
            ).then((_) => _carregarMes(_focusedDay)),
          ),
          if (role == 'admin')
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Apagar obra',
              onPressed: () => _deletarObra(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            color: const Color(0xFF1A1A2E),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(obra['nome'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('${obra['tipo'] ?? 'N/D'}  ·  ${obra['estado'] ?? ''}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
                if (obra['orcamento'] != null) ...[
                  const SizedBox(height: 3),
                  Text('Orçamento: ${_eur.format(_parseOrcamento(obra['orcamento']))}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ],
            ),
          ),

          // Calendário
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _carregarMes(_focusedDay),
                child: ListView(
                  children: [
                    TableCalendar(
                      firstDay:  DateTime(2020),
                      lastDay:   DateTime(2030),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (d) => _selectedDay != null && isSameDay(d, _selectedDay!),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay  = selected;
                          _focusedDay   = focused;
                        });
                        _abrirDia(selected);
                      },
                      onPageChanged: (focused) {
                        _focusedDay = focused;
                        _carregarMes(focused);
                      },
                      calendarBuilders: CalendarBuilders(
                        // Ponto verde nos dias com dados
                        markerBuilder: (context, day, events) {
                          final str = _formatData(day);
                          if (_diasComDados.contains(str)) {
                            return Positioned(
                              bottom: 4,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A1A2E),
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
                        titleTextStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                        leftChevronIcon: Icon(Icons.arrow_back_ios, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                        rightChevronIcon: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        weekendStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: const BoxDecoration(
                          color: Color(0x331A1A2E),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFF1A1A2E),
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                        weekendTextStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                        ),
                        outsideTextStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38,
                        ),
                        todayTextStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    // Legenda
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A2E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Dia com registo',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
