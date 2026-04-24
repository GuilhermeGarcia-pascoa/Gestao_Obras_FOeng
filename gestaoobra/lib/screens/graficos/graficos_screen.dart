import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 0);

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class GraficosScreen extends StatefulWidget {
  final int? obraId;
  final String? obraCodigo;
  final String? obraNome;

  const GraficosScreen({
    super.key,
    this.obraId,
    this.obraCodigo,
    this.obraNome,
  });

  @override
  State<GraficosScreen> createState() => _GraficosScreenState();
}

class _GraficosScreenState extends State<GraficosScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  DateTimeRange? _intervalo;
  late final TabController _tabController;

  int get _obraId => widget.obraId ?? 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (_obraId == 0) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final extra = _intervalo != null
          ? '?dataInicio=${_fmtApi(_intervalo!.start)}&dataFim=${_fmtApi(_intervalo!.end)}'
          : '';
      final dados = await ApiService.get('/relatorios/graficos/$_obraId$extra');
      setState(() {
        _dados = dados as Map<String, dynamic>;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  Future<void> _escolherIntervalo() async {
    final hoje = DateTime.now();
    final resultado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year + 1),
      initialDateRange: _intervalo ??
          DateTimeRange(
            start: DateTime(hoje.year, hoje.month, 1),
            end: hoje,
          ),
      locale: const Locale('pt', 'PT'),
      helpText: 'Filtrar por intervalo',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );

    if (resultado == null) return;
    setState(() => _intervalo = resultado);
    await _carregar();
  }

  void _limparFiltro() {
    setState(() => _intervalo = null);
    _carregar();
  }

  String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.obraCodigo ?? 'Graficos da obra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
          if (_intervalo != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Limpar filtro',
              onPressed: _limparFiltro,
            ),
          IconButton(
            icon: Icon(_intervalo == null ? Icons.date_range_outlined : Icons.date_range),
            tooltip: 'Filtrar por datas',
            onPressed: _escolherIntervalo,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Progresso'),
            Tab(text: 'Custos e metricas'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dados == null
              ? const Center(child: Text('Sem dados para a obra selecionada'))
              : Column(
                  children: [
                    _cabecalhoObra(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _tabProgresso(),
                          _tabCustosMetricas(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _cabecalhoObra() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.obraCodigo ?? 'Obra',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              widget.obraNome ?? 'Visualizacao especifica da obra selecionada',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (_intervalo != null) ...[
              const SizedBox(height: 8),
              Text(
                '${DateFormat('dd/MM/yy').format(_intervalo!.start)} - ${DateFormat('dd/MM/yy').format(_intervalo!.end)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF185FA5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tabProgresso() {
    final evolucao = List<Map<String, dynamic>>.from(_dados!['evolucao'] ?? []);
    final totalFaturado = _toDouble(_dados!['totalFaturado']);
    final totalGasto = _toDouble(_dados!['totalGasto']);
    final margem = totalFaturado - totalGasto;

    if (evolucao.isEmpty) {
      return const Center(child: Text('Sem registos suficientes para mostrar progresso.'));
    }

    final faturadoAcumulado =
        evolucao.map((e) => _toDouble(e['acumulado_faturado'])).toList();
    final gastoAcumulado =
        evolucao.map((e) => _toDouble(e['acumulado_gasto'])).toList();
    final maxY = [...faturadoAcumulado, ...gastoAcumulado].fold<double>(0, (a, b) => a > b ? a : b) * 1.15;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metricasResumo(totalFaturado, totalGasto, margem),
        const SizedBox(height: 14),
        _card(
          title: 'Evolucao acumulada',
          subtitle: 'Comparacao da progressao de faturacao e gastos da obra.',
          child: SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY == 0 ? 10 : maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      faturadoAcumulado.length,
                      (i) => FlSpot(i.toDouble(), faturadoAcumulado[i]),
                    ),
                    isCurved: true,
                    color: const Color(0xFF185FA5),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                      gastoAcumulado.length,
                      (i) => FlSpot(i.toDouble(), gastoAcumulado[i]),
                    ),
                    isCurved: true,
                    color: const Color(0xFFE6824D),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabCustosMetricas() {
    final totalFaturado = _toDouble(_dados!['totalFaturado']);
    final totalGasto = _toDouble(_dados!['totalGasto']);
    final saldo = totalFaturado - totalGasto;
    final margemPct = totalFaturado > 0 ? (saldo / totalFaturado) * 100 : 0.0;
    final distribuicao = [
      _GraficoItem('Faturado', totalFaturado, const Color(0xFF185FA5)),
      _GraficoItem('Gasto', totalGasto, const Color(0xFFE6824D)),
      _GraficoItem('Margem', saldo.abs(), saldo >= 0 ? const Color(0xFF0F9D8A) : const Color(0xFFE76F51)),
    ].where((item) => item.value > 0).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          title: 'Distribuicao financeira',
          subtitle: 'Leitura dos principais valores financeiros da obra.',
          child: SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 44,
                sections: distribuicao.map((item) {
                  return PieChartSectionData(
                    value: item.value,
                    color: item.color,
                    radius: 56,
                    title: item.label,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _card(
          title: 'Metricas especificas',
          subtitle: 'Resumo rapido da performance da obra atual.',
          child: Column(
            children: [
              _metricRow('Faturado total', _eur.format(totalFaturado), const Color(0xFF185FA5)),
              _metricRow('Gasto total', _eur.format(totalGasto), const Color(0xFFE6824D)),
              _metricRow('Margem', _eur.format(saldo), saldo >= 0 ? const Color(0xFF0F9D8A) : const Color(0xFFE76F51)),
              _metricRow('Margem %', '${margemPct.toStringAsFixed(1)}%', saldo >= 0 ? const Color(0xFF0F9D8A) : const Color(0xFFE76F51)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricasResumo(double totalFaturado, double totalGasto, double margem) {
    return Row(
      children: [
        Expanded(child: _miniCard('Faturado', _eur.format(totalFaturado), const Color(0xFF185FA5))),
        const SizedBox(width: 10),
        Expanded(child: _miniCard('Gasto', _eur.format(totalGasto), const Color(0xFFE6824D))),
        const SizedBox(width: 10),
        Expanded(child: _miniCard('Margem', _eur.format(margem), margem >= 0 ? const Color(0xFF0F9D8A) : const Color(0xFFE76F51))),
      ],
    );
  }

  Widget _miniCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _GraficoItem {
  final String label;
  final double value;
  final Color color;

  const _GraficoItem(this.label, this.value, this.color);
}
