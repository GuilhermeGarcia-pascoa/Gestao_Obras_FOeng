import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../utils/formatters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      // Carrega dados globais das obras
      final global = await ApiService.getGraficosTodasObras();
      setState(() {
        _dados   = global;
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

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().utilizador;
    final nome  = (user?['nome'] as String? ?? '').split(' ').first;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
              child: _buildBody(nome, isDark),
            ),
    );
  }

  Widget _buildBody(String nome, bool isDark) {
    final resumo  = (_dados?['resumo']  as Map<String, dynamic>?) ?? {};
    final obras   = List<Map<String, dynamic>>.from(_dados?['obras'] ?? []);

    final totalFaturado = _toDouble(resumo['total_faturado']);
    final totalGasto    = _toDouble(resumo['total_gasto']);
    final margem        = _toDouble(resumo['margem']);
    final totalObras    = _toInt(resumo['total_obras']);

    final obrasEmCurso  = obras.where((o) => o['estado'] == 'em_curso').toList();
    final obrasConcluidas = obras.where((o) => o['estado'] == 'concluida').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Saudação ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, $nome 👋',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                Fmt.dataLonga(DateTime.now()),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),

        // ── KPIs globais ────────────────────────────────────────────────────
        Row(children: [
          _kpiCard('Total obras',  '$totalObras',         Icons.business,       const Color(0xFF185FA5)),
          const SizedBox(width: 10),
          _kpiCard('Em curso',     '${obrasEmCurso.length}', Icons.construction, const Color(0xFF4CAF82)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _kpiCard('Faturado',     Fmt.moeda0(totalFaturado), Icons.euro,        const Color(0xFF185FA5)),
          const SizedBox(width: 10),
          _kpiCard('Margem total', Fmt.moeda0(margem),
              margem >= 0 ? Icons.trending_up : Icons.trending_down,
              margem >= 0 ? const Color(0xFF4CAF82) : Colors.red),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _kpiCard('Gasto total',  Fmt.moeda0(totalGasto),   Icons.payments,    const Color(0xFFE76F51)),
          const SizedBox(width: 10),
          _kpiCard('Concluídas',   '$obrasConcluidas',        Icons.check_circle, Colors.grey),
        ]),

        const SizedBox(height: 24),

        // ── Obras em curso ──────────────────────────────────────────────────
        if (obrasEmCurso.isNotEmpty) ...[
          Row(children: [
            Container(
              width:  4,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF185FA5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Obras em curso',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(height: 12),
          ...obrasEmCurso.map((o) => _cardObra(o)),
        ],

        // ── Mensagem se não há obras ─────────────────────────────────────────
        if (obras.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.construction_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Sem obras registadas.\nCria a primeira na aba Obras.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _kpiCard(String label, String valor, IconData icon, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: cor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cardObra(Map<String, dynamic> obra) {
    final faturado = _toDouble(obra['total_faturado']);
    final gasto    = _toDouble(obra['total_gastos']);
    final dias     = _toInt(obra['total_dias']);
    final margem   = faturado - gasto;
    final margemPos = margem >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                '${obra['codigo'] ?? ''} — ${obra['nome'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF82).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4CAF82).withOpacity(0.4)),
              ),
              child: const Text(
                'Em curso',
                style: TextStyle(fontSize: 10, color: Color(0xFF4CAF82), fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _miniInfo('Faturado',  Fmt.moeda0(faturado), const Color(0xFF185FA5)),
            _miniInfo('Gasto',     Fmt.moeda0(gasto),    const Color(0xFFE76F51)),
            _miniInfo('Margem',    Fmt.moeda0(margem),   margemPos ? const Color(0xFF4CAF82) : Colors.red),
            _miniInfo('Dias',      '$dias',               Colors.grey),
          ]),
        ]),
      ),
    );
  }

  Widget _miniInfo(String label, String valor, Color cor) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(valor,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cor),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}