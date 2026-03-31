import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../semanas/semana_detail_screen.dart';
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
  List<dynamic> _semanas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.listarSemanas(widget.obra['id']);
      setState(() { _semanas = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _novaSemana() async {
    final proxNumero = _semanas.isEmpty ? 1 : (_semanas.first['numero_semana'] as int) + 1;
    try {
      final result = await ApiService.criarSemana({
        'obra_id': widget.obra['id'],
        'numero_semana': proxNumero,
      });
      if (!mounted) return;
      final semana = await ApiService.getSemanaSemana(result['id']);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SemanaDetailScreen(semana: semana['semana'], obraId: widget.obra['id'])),
      ).then((_) => _carregar());
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final obra = widget.obra;
    return Scaffold(
      appBar: AppBar(
        title: Text(obra['codigo'] ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ObraFormScreen(obra: obra)),
            ).then((_) => _carregar()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Cabeçalho da obra
          Container(
            width: double.infinity,
            color: const Color(0xFF1A1A2E),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(obra['nome'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Tipo: ${obra['tipo'] ?? 'N/D'}  ·  Estado: ${obra['estado'] ?? ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (obra['orcamento'] != null) ...[
                  const SizedBox(height: 4),
                  Text('Orçamento: ${_eur.format(_parseOrcamento(obra['orcamento']))}',
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ],
            ),
          ),

          // Lista de semanas
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: _semanas.isEmpty
                        ? const Center(child: Text('Sem semanas. Cria a primeira!'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _semanas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final s = _semanas[i];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF1A1A2E),
                                    child: Text('S${s['numero_semana']}',
                                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                  title: Text('Semana ${s['numero_semana']}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(s['estado'] ?? ''),
                                  trailing: s['faturado'] != null
                                      ? Text(_eur.format(_parseOrcamento(s['faturado'])),
                                            style: const TextStyle(fontWeight: FontWeight.bold))
                                      : null,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SemanaDetailScreen(semana: s, obraId: obra['id']),
                                    ),
                                  ).then((_) => _carregar()),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novaSemana,
        icon: const Icon(Icons.add),
        label: const Text('Nova semana'),
      ),
    );
  }
}
