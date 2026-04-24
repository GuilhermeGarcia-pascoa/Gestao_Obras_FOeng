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
            tooltip: 'Atualizar',
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _heroCard(nome, totalObras, totalFaturado, margem),
            const SizedBox(height: 20),
            _sectionTitle('Resumo global'),
            const SizedBox(height: 10),
            _kpiGrid(
              crossAxisCount: crossAxisCount,
              items: [
                _KpiData('Total obras', '$totalObras', Icons.apartment_rounded, const Color(0xFF185FA5)),
                _KpiData('Em curso', '$emCurso', Icons.construction_rounded, const Color(0xFF0F9D8A)),
                _KpiData('Planeadas', '$planeadas', Icons.event_note_rounded, const Color(0xFF2F6FED)),
                _KpiData('Concluidas', '$concluidas', Icons.verified_rounded, const Color(0xFF6E7F92)),
                _KpiData('Faturado', Fmt.moeda0(totalFaturado), Icons.euro_rounded, const Color(0xFF185FA5)),
                _KpiData('Gasto total', Fmt.moeda0(totalGasto), Icons.receipt_long_rounded, const Color(0xFFE6824D)),
                _KpiData(
                  'Margem',
                  Fmt.moeda0(margem),
                  margem >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  margem >= 0 ? const Color(0xFF0F9D8A) : const Color(0xFFE76F51),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle('Graficos gerais'),
            const SizedBox(height: 10),
            _graficoBarrasTotais(totalFaturado, totalGasto, margem),
            const SizedBox(height: 14),
            if (obras.isEmpty) _emptyPanel() else _graficoEstados(emCurso, planeadas, concluidas),
            const SizedBox(height: 14),
            if (obras.isNotEmpty) _graficoTopObras(obras),
          ],
        );
      },
    );
  }

  Widget _heroCard(String nome, int totalObras, double totalFaturado, double margem) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B4E), Color(0xFF185FA5)],
        ),
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
                      'Ola, $nome',
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
              _heroChip(Icons.apartment_rounded, '$totalObras obras'),
              _heroChip(Icons.euro_rounded, Fmt.moeda0(totalFaturado)),
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

  Widget _sectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
      ),
    );
  }

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
            return SizedBox(
              width: itemWidth,
              child: _kpiCard(item),
            );
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

  Widget _graficoBarrasTotais(double totalFaturado, double totalGasto, double margem) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final maxY = [totalFaturado, totalGasto, margem.abs()].fold<double>(0, (a, b) => a > b ? a : b) * 1.25;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Totais globais',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Comparacao entre faturado, gasto total e margem global.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY == 0 ? 10 : maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Faturado', 'Gasto', 'Margem'];
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[index], style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                      toY: totalFaturado,
                      width: 26,
                      color: const Color(0xFF185FA5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                      toY: totalGasto,
                      width: 26,
                      color: const Color(0xFFE6824D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(
                      toY: margem.abs(),
                      width: 26,
                      color: margem >= 0 ? const Color(0xFF0F9D8A) : const Color(0xFFE76F51),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _graficoEstados(int emCurso, int planeadas, int concluidas) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final sections = [
      _EstadoSection('Em curso', emCurso.toDouble(), const Color(0xFF0F9D8A)),
      _EstadoSection('Planeadas', planeadas.toDouble(), const Color(0xFF185FA5)),
      _EstadoSection('Concluidas', concluidas.toDouble(), const Color(0xFF6E7F92)),
    ].where((item) => item.value > 0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribuicao de estados',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Leitura global do estado atual de todas as obras.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final chart = SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 48,
                    sections: sections.map((item) {
                      return PieChartSectionData(
                        value: item.value,
                        color: item.color,
                        radius: 52,
                        title: item.value.toInt().toString(),
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );

              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sections.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.label}: ${item.value.toInt()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
                            ),
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
                    const SizedBox(height: 12),
                    legend,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: chart),
                  const SizedBox(width: 20),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _graficoTopObras(List<Map<String, dynamic>> obras) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final ordenadas = [...obras]
      ..sort((a, b) => _toDouble(b['total_faturado']).compareTo(_toDouble(a['total_faturado'])));
    final top = ordenadas.take(5).toList();
    final maxFaturado = top.fold<double>(0, (a, b) => a > _toDouble(b['total_faturado']) ? a : _toDouble(b['total_faturado']));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top obras por faturado',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Ranking global das obras com maior faturacao acumulada.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
            ),
          ),
          const SizedBox(height: 16),
          ...top.map((obra) {
            final faturado = _toDouble(obra['total_faturado']);
            final progresso = maxFaturado > 0 ? faturado / maxFaturado : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF185FA5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    obra['nome'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progresso,
                      minHeight: 8,
                      backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFE8EEF7),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF185FA5)),
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

  Widget _emptyPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
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
            'Ainda nao ha dados para apresentar.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

  const _EstadoSection(this.label, this.value, this.color);
}
