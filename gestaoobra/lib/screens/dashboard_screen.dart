import 'package:fl_chart/fl_chart.dart';
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

  // ── Paleta de cores consistente em toda a dashboard ──────────────────────
  static const _azul = Color(0xFF185FA5);
  static const _azulEscuro = Color(0xFF0D2B4E);
  static const _verde = Color(0xFF0F9D8A);
  static const _laranja = Color(0xFFE6824D);
  static const _vermelho = Color(0xFFE76F51);
  static const _cinza = Color(0xFF6E7F92);
  static const _roxo = Color(0xFF7C5CBF);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final global = await ApiService.getGraficosTodasObras();
      setState(() {
        _dados = global;
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
    final user = context.watch<AuthProvider>().utilizador;
    final nome = (user?['nome'] as String? ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar dados',
            onPressed: _carregar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: _buildBody(nome),
            ),
    );
  }

  Widget _buildBody(String nome) {
    final resumo = (_dados?['resumo'] as Map<String, dynamic>?) ?? {};
    final obras = List<Map<String, dynamic>>.from(_dados?['obras'] ?? []);

    final totalFaturado = _toDouble(resumo['total_faturado']);
    final totalGasto = _toDouble(resumo['total_gasto']);
    final margem = _toDouble(resumo['margem']);
    final totalObras = _toInt(resumo['total_obras']);
    final emCurso = obras.where((o) => o['estado'] == 'em_curso').length;
    final planeadas = obras.where((o) => o['estado'] == 'planeada').length;
    final concluidas = obras.where((o) => o['estado'] == 'concluida').length;
    final atrasadas = obras.where((o) => o['estado'] == 'atrasada').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 720
                ? 3
                : constraints.maxWidth >= 460
                    ? 2
                    : 1;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Hero card ────────────────────────────────────────────────
            _heroCard(nome, totalObras, totalFaturado, margem),
            const SizedBox(height: 24),

            // ── KPIs ─────────────────────────────────────────────────────
            _sectionTitle('Resumo global', Icons.bar_chart_rounded),
            const SizedBox(height: 10),
            _kpiGrid(
              crossAxisCount: crossAxisCount,
              items: [
                _KpiData('Total de obras', '$totalObras', Icons.apartment_rounded, _azul),
                _KpiData('Em curso', '$emCurso', Icons.construction_rounded, _verde),
                _KpiData('Planeadas', '$planeadas', Icons.event_note_rounded, _roxo),
                _KpiData('Concluídas', '$concluidas', Icons.verified_rounded, _cinza),
                if (atrasadas > 0)
                  _KpiData('Atrasadas', '$atrasadas', Icons.warning_amber_rounded, _vermelho),
                _KpiData('Faturado', Fmt.moeda0(totalFaturado), Icons.euro_rounded, _azul),
                _KpiData('Gasto total', Fmt.moeda0(totalGasto), Icons.receipt_long_rounded, _laranja),
                _KpiData(
                  'Margem',
                  Fmt.moeda0(margem),
                  margem >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  margem >= 0 ? _verde : _vermelho,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Gráfico financeiro ────────────────────────────────────────
            _sectionTitle('Análise financeira global', Icons.account_balance_wallet_rounded),
            const SizedBox(height: 10),
            _graficoBarrasTotais(totalFaturado, totalGasto, margem),
            const SizedBox(height: 14),

            // ── Progresso financeiro ──────────────────────────────────────
            _graficoProgressoFinanceiro(totalFaturado, totalGasto, margem),
            const SizedBox(height: 28),

            // ── Estados ───────────────────────────────────────────────────
            _sectionTitle('Estado das obras', Icons.pie_chart_rounded),
            const SizedBox(height: 10),
            if (obras.isEmpty)
              _emptyPanel()
            else
              _graficoEstados(emCurso, planeadas, concluidas, atrasadas),
            const SizedBox(height: 14),

            // ── Top obras ─────────────────────────────────────────────────
            if (obras.isNotEmpty) ...[
              _sectionTitle('Top 5 obras por faturação', Icons.leaderboard_rounded),
              const SizedBox(height: 10),
              _graficoTopObras(obras),
            ],
          ],
        );
      },
    );
  }

  // ── Hero card ────────────────────────────────────────────────────────────
  Widget _heroCard(String nome, int totalObras, double totalFaturado, double margem) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_azulEscuro, _azul],
        ),
        boxShadow: [
          BoxShadow(
            color: _azul.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, $nome!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.dataLonga(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 92,
                width: 92,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.business_rounded,
                    color: Colors.white70,
                    size: 42,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(Icons.apartment_rounded, '$totalObras obras ativas'),
              _heroChip(Icons.euro_rounded, Fmt.moeda0(totalFaturado) + ' faturados'),
              _heroChip(
                margem >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                margem >= 0 ? 'Margem positiva' : 'Margem negativa',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section title ────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _azul.withOpacity(isDark ? 0.22 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _azul),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
          ),
        ),
      ],
    );
  }

  // ── KPI grid ─────────────────────────────────────────────────────────────
  Widget _kpiGrid({required int crossAxisCount, required List<_KpiData> items}) {
    const spacing = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (crossAxisCount - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(width: itemWidth, child: _kpiCard(item));
          }).toList(),
        );
      },
    );
  }

  Widget _kpiCard(_KpiData item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 118),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252D3A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 19),
          ),
          const SizedBox(height: 18),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gráfico de barras: Faturado vs Gasto vs Margem ───────────────────────
  Widget _graficoBarrasTotais(double totalFaturado, double totalGasto, double margem) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final labelColor = isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478);
    final maxY = [totalFaturado, totalGasto, margem.abs()].fold<double>(0, (a, b) => a > b ? a : b) * 1.35;
    final margemColor = margem >= 0 ? _verde : _vermelho;

    final barItems = [
      _BarItem('Faturado', totalFaturado, _azul),
      _BarItem('Gasto', totalGasto, _laranja),
      _BarItem('Margem', margem.abs(), margemColor),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + subtítulo
          const Text(
            'Resumo financeiro global',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Comparação entre faturado total, gasto acumulado e margem gerada.',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
          const SizedBox(height: 16),

          // Legenda de cores
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: barItems.map((item) => _legendaItem(item.label, item.color, isDark)).toList(),
          ),
          const SizedBox(height: 16),

          // Gráfico
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY == 0 ? 10 : maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY == 0 ? 5 : maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFEEF2F8),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          Fmt.moeda0(value),
                          style: TextStyle(fontSize: 10, color: labelColor),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= barItems.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            barItems[index].label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = barItems[groupIndex].label;
                      return BarTooltipItem(
                        '$label\n${Fmt.moeda0(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: List.generate(barItems.length, (i) {
                  final item = barItems[i];
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: item.value,
                      width: 32,
                      color: item.color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY == 0 ? 10 : maxY,
                        color: isDark ? const Color(0xFF2E3846) : const Color(0xFFF5F7FC),
                      ),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Progresso financeiro: barras horizontais ──────────────────────────────
  Widget _graficoProgressoFinanceiro(double totalFaturado, double totalGasto, double margem) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final labelColor = isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478);
    final margemColor = margem >= 0 ? _verde : _vermelho;
    final max = [totalFaturado, totalGasto, margem.abs()].fold<double>(0, (a, b) => a > b ? a : b);

    final items = [
      _BarItem('Faturado total', totalFaturado, _azul),
      _BarItem('Gasto acumulado', totalGasto, _laranja),
      _BarItem(margem >= 0 ? 'Margem positiva' : 'Margem negativa', margem.abs(), margemColor),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribuição financeira',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Proporção relativa entre faturado, gasto e margem.',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
          const SizedBox(height: 18),
          ...items.map((item) {
            final ratio = max > 0 ? item.value / max : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            Fmt.moeda0(item.value),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: item.color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${(ratio * 100).toStringAsFixed(0)}%)',
                            style: TextStyle(fontSize: 11, color: labelColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFEEF2F8),
                      valueColor: AlwaysStoppedAnimation(item.color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Gráfico de estados: donut + legenda ───────────────────────────────────
  Widget _graficoEstados(int emCurso, int planeadas, int concluidas, int atrasadas) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final labelColor = isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478);

    final total = emCurso + planeadas + concluidas + atrasadas;

    final sections = [
      _EstadoSection('Em curso', emCurso.toDouble(), _verde, Icons.construction_rounded),
      _EstadoSection('Planeadas', planeadas.toDouble(), _roxo, Icons.event_note_rounded),
      _EstadoSection('Concluídas', concluidas.toDouble(), _cinza, Icons.verified_rounded),
      if (atrasadas > 0)
        _EstadoSection('Atrasadas', atrasadas.toDouble(), _vermelho, Icons.warning_amber_rounded),
    ].where((item) => item.value > 0).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribuição por estado',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Proporção de obras em cada fase do ciclo de vida.',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;

              final chart = SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 56,
                        startDegreeOffset: -90,
                        sections: sections.map((item) {
                          final pct = total > 0 ? (item.value / total * 100).toStringAsFixed(0) : '0';
                          return PieChartSectionData(
                            value: item.value,
                            color: item.color,
                            radius: 50,
                            title: '$pct%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Rótulo central
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
                          ),
                        ),
                        Text(
                          'obras',
                          style: TextStyle(fontSize: 12, color: labelColor),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sections.map((item) {
                  final pct = total > 0 ? (item.value / total * 100).toStringAsFixed(1) : '0';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(item.icon, size: 16, color: item.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
                                ),
                              ),
                              Text(
                                '${item.value.toInt()} obras · $pct%',
                                style: TextStyle(fontSize: 11, color: labelColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              if (compact) {
                return Column(
                  children: [
                    chart,
                    const SizedBox(height: 16),
                    legend,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: chart),
                  const SizedBox(width: 24),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Top 5 obras por faturação ─────────────────────────────────────────────
  Widget _graficoTopObras(List<Map<String, dynamic>> obras) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final labelColor = isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478);

    final ordenadas = [...obras]
      ..sort((a, b) => _toDouble(b['total_faturado']).compareTo(_toDouble(a['total_faturado'])));
    final top = ordenadas.take(5).toList();
    final maxFaturado = top.fold<double>(
      0,
      (a, b) => a > _toDouble(b['total_faturado']) ? a : _toDouble(b['total_faturado']),
    );

    // Cores escalonadas para o ranking
    const rankColors = [_azul, _verde, _roxo, _laranja, _cinza];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 obras por faturação',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Obras com maior faturação acumulada — do 1.º ao 5.º lugar.',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
          const SizedBox(height: 18),
          ...top.asMap().entries.map((entry) {
            final rank = entry.key;
            final obra = entry.value;
            final faturado = _toDouble(obra['total_faturado']);
            final gasto = _toDouble(obra['total_gasto']);
            final progresso = maxFaturado > 0 ? faturado / maxFaturado : 0.0;
            final cor = rankColors[rank % rankColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nº do ranking
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cor.withOpacity(isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${rank + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: cor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                obra['codigo'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
                                ),
                              ),
                            ),
                            Text(
                              Fmt.moeda0(faturado),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: cor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                obra['nome'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: labelColor),
                              ),
                            ),
                            Text(
                              'Gasto: ${Fmt.moeda0(gasto)}',
                              style: TextStyle(fontSize: 11, color: labelColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progresso.clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFEEF2F8),
                            valueColor: AlwaysStoppedAnimation(cor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _emptyPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252D3A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 48,
            color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
          ),
          const SizedBox(height: 12),
          Text(
            'Ainda não há dados para apresentar.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Assim que existirem obras registadas, os gráficos serão apresentados aqui.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Helper: legenda de cor ─────────────────────────────────────────────────
  Widget _legendaItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
          ),
        ),
      ],
    );
  }

  // ── Conversores ────────────────────────────────────────────────────────────
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

// ── Modelos de dados internos ─────────────────────────────────────────────────

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

class _EstadoSection {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _EstadoSection(this.label, this.value, this.color, this.icon);
}

class _BarItem {
  final String label;
  final double value;
  final Color color;
  const _BarItem(this.label, this.value, this.color);
}