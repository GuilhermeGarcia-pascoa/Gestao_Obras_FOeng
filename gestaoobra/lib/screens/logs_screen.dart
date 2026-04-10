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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.listarLogs();
      setState(() {
        _logs = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensagem)),
        );
      }
    }
  }

  // ── Cores por action ──────────────────────────────────────────────────────

  Color _corAction(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return const Color(0xFF4CAF82);
      case 'UPDATE':
        return const Color(0xFF185FA5);
      case 'DELETE':
        return Colors.red;
      case 'LOGIN':
        return const Color(0xFF9C6ADE);
      default:
        return Colors.grey;
    }
  }

  IconData _iconAction(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Icons.add_circle_outline;
      case 'UPDATE':
        return Icons.edit_outlined;
      case 'DELETE':
        return Icons.delete_outline;
      case 'LOGIN':
        return Icons.login;
      default:
        return Icons.info_outline;
    }
  }

  // ── Formatação de data ────────────────────────────────────────────────────

  String _fmtData(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/${dt.year}  $h:$min';
    } catch (_) {
      return raw;
    }
  }

  // ── Dialog de detalhes ────────────────────────────────────────────────────

  void _verDetalhes(dynamic log) {
    final action   = (log['action']  ?? '').toString().toUpperCase();
    final entity   = log['entity']   ?? '';
    final details  = log['details'];
    final cor      = _corAction(action);

    // Tenta formatar o JSON de forma legível
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
                _detalheRow(Icons.person_outline,    'Utilizador',   '${log['user_id'] ?? '—'}'),
                _detalheRow(Icons.tag,               'Entidade ID',  '${log['entity_id'] ?? '—'}'),
                _detalheRow(Icons.wifi,              'IP',           log['ip'] ?? '—'),
                _detalheRow(Icons.http,              'Método',       log['method'] ?? '—'),
                _detalheRow(Icons.link,              'URL',          log['url'] ?? '—'),
                _detalheRow(Icons.calendar_today,    'Data',         _fmtData(log['created_at']?.toString())),
                const Divider(height: 24),
                const Text(
                  'Detalhes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
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
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de Auditoria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: _logs.isEmpty
                  ? const Center(child: Text('Nenhum log encontrado'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final log    = _logs[i];
                        final action = (log['action'] ?? '').toString().toUpperCase();
                        final entity = log['entity']?.toString() ?? '';
                        final cor    = _corAction(action);
                        
                        return Card(
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_iconAction(action), color: cor, size: 20),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: cor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    action,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: cor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entity,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // user_id + entity_id
                                  // ... dentro do itemBuilder
Row(children: [
  const Icon(Icons.person_outline, size: 12, color: Colors.grey),
  const SizedBox(width: 3),
  Text(
    // Alterado de log['user_id'] para log['user_nome']
    log['user_nome'] ?? 'Sistema/Desconhecido', 
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
  ),
  if (log['entity_id'] != null) ...[
    const SizedBox(width: 10),
    const Icon(Icons.tag, size: 12, color: Colors.grey),
    const SizedBox(width: 3),
    Text(
      'id ${log['entity_id']}',
      style: const TextStyle(fontSize: 11),
    ),
  ],
]),
                                  const SizedBox(height: 2),
                                  // method + url
                                  Row(children: [
                                    const Icon(Icons.link,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${log['method'] ?? ''} ${log['url'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ]),
                                  const SizedBox(height: 2),
                                  // IP + data
                                  Row(children: [
                                    const Icon(Icons.wifi,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 3),
                                    Text(
                                      log['ip'] ?? '—',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.calendar_today,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 3),
                                    Text(
                                      _fmtData(log['created_at']?.toString()),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new, size: 18),
                              tooltip: 'Ver detalhes',
                              onPressed: () => _verDetalhes(// ... dentro da função _verDetalhes, na Column do AlertDialog
_detalheRow(
  Icons.person_outline, 
  'Utilizador', 
  '${log['user_nome'] ?? 'Desconhecido'} (ID: ${log['user_id'] ?? '—'})'
),),
                            ),
                          ),
                        );
                        
                      },
                    ),
                    
            ),
    );
  }
}