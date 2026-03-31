import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 0);

// Função auxiliar para garantir que os valores são sempre num válido
num _parseValor(dynamic value) {
  if (value is num) return value;
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class GraficosScreen extends StatefulWidget {
  const GraficosScreen({super.key});

  @override
  State<GraficosScreen> createState() => _GraficosScreenState();
}

class _GraficosScreenState extends State<GraficosScreen> {
  List<dynamic> _obras     = [];
  int? _obraIdSelecionada;
  Map<String, dynamic>? _dados;
  bool _loadingObras = true;
  bool _loadingDados = false;

  @override
  void initState() {
    super.initState();
    _carregarObras();
  }

  Future<void> _carregarObras() async {
    try {
      final obras = await ApiService.listarObras();
      setState(() { _obras = obras; _loadingObras = false; });
      if (obras.isNotEmpty) _selecionarObra(obras.first['id']);
    } on ApiException catch (e) {
      setState(() => _loadingObras = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _selecionarObra(int id) async {
    setState(() { _obraIdSelecionada = id; _loadingDados = true; });
    try {
      final dados = await ApiService.getGraficos(id);
      setState(() { _dados = dados; _loadingDados = false; });
    } on ApiException catch (e) {
      setState(() => _loadingDados = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gráficos')),
      body: _loadingObras
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Seletor de obra
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: DropdownButtonFormField<int>(
                    initialValue: _obraIdSelecionada,
                    decoration: const InputDecoration(labelText: 'Obra', isDense: true),
                    items: _obras.map<DropdownMenuItem<int>>((o) =>
                        DropdownMenuItem(value: o['id'] as int, child: Text(o['codigo'] ?? ''))).toList(),
                    onChanged: (v) { if (v != null) _selecionarObra(v); },
                  ),
                ),
                Expanded(
                  child: _loadingDados
                      ? const Center(child: CircularProgressIndicator())
                      : _dados == null
                          ? const Center(child: Text('Seleciona uma obra'))
                          : _buildGraficos(),
                ),
              ],
            ),
    );
  }

  Widget _buildGraficos() {
    final evolucao     = List<Map<String, dynamic>>.from(_dados!['evolucao'] ?? []);
    final distribuicao = List<Map<String, dynamic>>.from(_dados!['distribuicao'] ?? []);

    if (evolucao.isEmpty) {
      return const Center(child: Text('Sem dados para esta obra.\nRegista semanas primeiro.', textAlign: TextAlign.center));
    }

    // Totais para os cards de métricas
    final totalFaturado   = evolucao.isNotEmpty ? (evolucao.last['acumulado'] as num).toDouble() : 0.0;
    final totalSemanas    = evolucao.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Cards de métricas ─────────────────────────────────────────────
        Row(
          children: [
            _metricCard('Faturado total', _eur.format(totalFaturado), Icons.euro),
            const SizedBox(width: 10),
            _metricCard('Semanas', '$totalSemanas', Icons.calendar_today),
          ],
        ),
        const SizedBox(height: 24),

        // ── Gráfico de evolução semanal ───────────────────────────────────
        const Text('Faturado por semana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: evolucao.map((e) => (e['faturado'] as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b) * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) =>
                      BarTooltipItem(_eur.format(rod.toY), const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx >= evolucao.length) return const SizedBox();
                      return Text(evolucao[idx]['semana'] ?? '', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: evolucao.asMap().entries.map((e) => BarChartGroupData(
                x: e.key,
                barRods: [BarChartRodData(
                  toY: (e.value['faturado'] as num).toDouble(),
                  color: const Color(0xFF1A1A2E),
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                )],
              )).toList(),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Gráfico acumulado ─────────────────────────────────────────────
        const Text('Faturado acumulado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx >= evolucao.length) return const SizedBox();
                      return Text(evolucao[idx]['semana'] ?? '', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: evolucao.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), (e.value['acumulado'] as num).toDouble())).toList(),
                  isCurved: true,
                  color: const Color(0xFF1A1A2E),
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF1A1A2E).withOpacity(0.08),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Distribuição de custos ────────────────────────────────────────
        if (distribuicao.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text('Distribuição de custos (última semana)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ...distribuicao.map((d) {
            final total = distribuicao.fold<double>(0, (a, b) => a + (b['valor'] as num).toDouble());
            final pct   = total > 0 ? (d['valor'] as num).toDouble() / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(d['categoria'] ?? '', style: const TextStyle(fontSize: 13)),
                      Text(_eur.format(_parseValor(d['valor'])), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1EFE8),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF1A1A2E)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFE8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    ),
  );
}
