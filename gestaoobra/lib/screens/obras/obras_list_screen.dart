import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'obra_detail_screen.dart';
import 'obra_form_screen.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

class ObrasListScreen extends StatefulWidget {
  const ObrasListScreen({super.key});

  @override
  State<ObrasListScreen> createState() => _ObrasListScreenState();
}

class _ObrasListScreenState extends State<ObrasListScreen> {
  List<dynamic> _obras = [];
  bool _loading = true;
  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.listarObras(estado: _filtroEstado);
      setState(() { _obras = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Color _corEstado(String? estado) {
    switch (estado) {
      case 'em_curso':   return Colors.green;
      case 'planeada':   return Colors.blue;
      case 'concluida':  return Colors.grey;
      default:           return Colors.orange;
    }
  }

  String _textoEstado(String? estado) {
    switch (estado) {
      case 'em_curso':  return 'Em curso';
      case 'planeada':  return 'Planeada';
      case 'concluida': return 'Concluída';
      default:          return estado ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obras'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) { _filtroEstado = v; _carregar(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null,        child: Text('Todas')),
              const PopupMenuItem(value: 'em_curso',  child: Text('Em curso')),
              const PopupMenuItem(value: 'planeada',  child: Text('Planeadas')),
              const PopupMenuItem(value: 'concluida', child: Text('Concluídas')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: _obras.isEmpty
                  ? const Center(child: Text('Sem obras. Cria a primeira!'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _obras.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final o = _obras[i];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: [
                                Expanded(child: Text(o['codigo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _corEstado(o['estado']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _corEstado(o['estado']).withOpacity(0.4)),
                                  ),
                                  child: Text(_textoEstado(o['estado']),
                                      style: TextStyle(fontSize: 11, color: _corEstado(o['estado']), fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(o['nome'] ?? ''),
                                if (o['orcamento'] != null)
                                  Text('Orçamento: ${_eur.format(o['orcamento'])}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ObraDetailScreen(obra: o)),
                            ).then((_) => _carregar()),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ObraFormScreen()),
        ).then((_) => _carregar()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
