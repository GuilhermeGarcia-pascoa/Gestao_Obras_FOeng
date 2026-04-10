import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic> _logs = [];
  List<dynamic> _logsFiltrados = [];
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  String _filtroAction = 'TODOS';
  DateTime? _dataInicio;
  DateTime? _dataFim;

  final List<String> _actions = ['TODOS', 'CREATE', 'UPDATE', 'DELETE', 'LOGIN'];

  @override
  void initState() {
    super.initState();
    _carregar();
    _searchController.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.listarLogs();
      setState(() {
        _logs = data;
        _loading = false;
      });
      _aplicarFiltros();
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensagem)),
        );
      }
    }
  }

  void _aplicarFiltros() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _logsFiltrados = _logs.where((log) {
        // Filtro por texto (entidade ou utilizador)
        final entity    = (log['entity']    ?? '').toString().toLowerCase();
        final userName  = (log['user_nome'] ?? '').toString().toLowerCase();
        final matchText = query.isEmpty || entity.contains(query) || userName.contains(query);

        // Filtro por action
        final action      = (log['action'] ?? '').toString().toUpperCase();
        final matchAction = _filtroAction == 'TODOS' || action == _filtroAction;

        // Filtro por data
        bool matchData = true;
        final rawDate = log['created_at']?.toString();
        if (rawDate != null && (_dataInicio != null || _dataFim != null)) {
          try {
            final dt = DateTime.parse(rawDate).toLocal();
            if (_dataInicio != null && dt.isBefore(_dataInicio!)) matchData = false;
            if (_dataFim != null && dt.isAfter(_dataFim!.add(const Duration(days: 1)))) matchData = false;
          } catch (_) {}
        }

        return matchText && matchAction && matchData;
      }).toList();
    });
  }

  Future<void> _selecionarData({required bool isInicio}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = picked;
        } else {
          _dataFim = picked;
        }
      });
      _aplicarFiltros();
    }
  }

  void _limparFiltros() {
    _searchController.clear();
    setState(() {
      _filtroAction = 'TODOS';
      _dataInicio   = null;
      _dataFim      = null;
    });
    _aplicarFiltros();
  }

  String _fmtDataCurta(DateTime? dt) {
    if (dt == null) return 'Selecionar';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Color _corAction(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE': return const Color(0xFF4CAF82);
      case 'UPDATE': return const Color(0xFF185FA5);
      case 'DELETE': return Colors.red;
      case 'LOGIN':  return const Color(0xFF9C6ADE);
      default:       return Colors.grey;
    }
  }

  IconData _iconAction(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE': return Icons.add_circle_outline;
      case 'UPDATE': return Icons.edit_outlined;
      case 'DELETE': return Icons.delete_outline;
      case 'LOGIN':  return Icons.login;
      default:       return Icons.info_outline;
    }
  }

  String _fmtData(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt  = DateTime.parse(raw).toLocal();
      final d   = dt.day.toString().padLeft(2, '0');
      final m   = dt.month.toString().padLeft(2, '0');
      final h   = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/${dt.year}  $h:$min';
    } catch (_) {
      return raw;
    }
  }

  void _verDetalhes(dynamic log) {
    final action  = (log['action'] ?? '').toString().toUpperCase();
    final entity  = log['entity'] ?? '';
    final details = log['details'];
    final cor     = _corAction(action);

    String detalhesFormatados;
    if (details == null || details.toString().trim().isEmpty) {
      detalhesFormatados = 'Sem detalhes registados.';
    } else {
      try {
        final decoded = details is String ? jsonDecode(details) : details;
        const encoder = JsonEncoder.withIndent('  ');
        detalhesFormatados = encoder.convert(decoded);
      } catch (_) {
        detalhesFormatados = details.toString();
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(_iconAction(action), color: cor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$action  $entity',
                style: TextStyle(fontSize: 16, color: cor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detalheRow(Icons.person_outline, 'Utilizador',
                    '${log['user_nome'] ?? 'Desconhecido'} (ID: ${log['user_id'] ?? '—'})'),
                _detalheRow(Icons.tag,           'Entidade ID', '${log['entity_id'] ?? '—'}'),
                _detalheRow(Icons.wifi,          'IP',          log['ip']     ?? '—'),
                _detalheRow(Icons.http,          'Método',      log['method'] ?? '—'),
                _detalheRow(Icons.link,          'URL',         log['url']    ?? '—'),
                _detalheRow(Icons.calendar_today,'Data',        _fmtData(log['created_at']?.toString())),
                const Divider(height: 24),
                const Text('Detalhes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: SelectableText(
                    detalhesFormatados,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Widget _detalheRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: Colors.grey),
            const SizedBox(width: 6),
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final temFiltrosAtivos = _filtroAction != 'TODOS' ||
        _dataInicio != null ||
        _dataFim != null ||
        _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de Auditoria'),
        actions: [
          if (temFiltrosAtivos)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Limpar filtros',
              onPressed: _limparFiltros,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de pesquisa ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar entidade, utilizador…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _aplicarFiltros();
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // ── Chips de action ────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _actions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final a       = _actions[i];
                final ativo   = _filtroAction == a;
                final cor     = a == 'TODOS' ? Colors.blueGrey : _corAction(a);
                return ChoiceChip(
                  label: Text(a, style: const TextStyle(fontSize: 11)),
                  selected: ativo,
                  selectedColor: cor.withOpacity(0.18),
                  onSelected: (_) {
                    setState(() => _filtroAction = a);
                    _aplicarFiltros();
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // ── Filtro de datas ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                _datePicker('De', _dataInicio, () => _selecionarData(isInicio: true)),
                const SizedBox(width: 8),
                _datePicker('Até', _dataFim, () => _selecionarData(isInicio: false)),
                if (_dataInicio != null || _dataFim != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() { _dataInicio = null; _dataFim = null; });
                      _aplicarFiltros();
                    },
                    child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── Contador de resultados ─────────────────────────────────────
          if (!_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_logsFiltrados.length} resultado${_logsFiltrados.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),

          const SizedBox(height: 4),

          // ── Lista ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: _logsFiltrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text('Nenhum log encontrado'),
                                if (temFiltrosAtivos)
                                  TextButton(
                                    onPressed: _limparFiltros,
                                    child: const Text('Limpar filtros'),
                                  ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _logsFiltrados.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final log    = _logsFiltrados[i];
                              final action = (log['action'] ?? '').toString().toUpperCase();
                              final entity = log['entity']?.toString() ?? '';
                              final cor    = _corAction(action);

                              return Card(
                                child: ListTile(
                                  leading: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: cor.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(_iconAction(action), color: cor, size: 20),
                                  ),
                                  title: Text(entity,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.person_outline, size: 12, color: Colors.grey),
                                        const SizedBox(width: 3),
                                        Text(log['user_nome'] ?? 'Sistema',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ]),
                                      Text(_fmtData(log['created_at']?.toString()),
                                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.open_in_new, size: 18),
                                    onPressed: () => _verDetalhes(log),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime? valor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              _fmtDataCurta(valor),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: valor != null ? Colors.blueAccent : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}