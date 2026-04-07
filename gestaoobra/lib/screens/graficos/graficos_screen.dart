import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

final _eur  = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 0);
final _eur2 = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 2);

num _parseValor(dynamic v) {
  if (v is num) return v;
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

const _coresPizza = [
  Color(0xFF185FA5), Color(0xFF2E86AB), Color(0xFF4CAF82),
  Color(0xFFF4A261), Color(0xFFE76F51), Color(0xFF9C6ADE),
  Color(0xFF8E44AD),
];

class GraficosScreen extends StatefulWidget {
  const GraficosScreen({super.key});

  @override
  State<GraficosScreen> createState() => _GraficosScreenState();
}

class _GraficosScreenState extends State<GraficosScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _obras       = [];
  int?          _obraId;
  Map<String, dynamic>? _dados;
  Map<String, dynamic>? _dadosGlobal;

  bool _loadingObras  = true;
  bool _loadingDados  = false;
  bool _loadingGlobal = false;

  DateTimeRange? _intervalo;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 3 && _dadosGlobal == null && !_loadingGlobal) {
        _carregarGlobal();
      }
    });
    _carregarObras();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarObras() async {
    try {
      final obras = await ApiService.listarObras();
      setState(() { _obras = obras; _loadingObras = false; });
      if (obras.isNotEmpty) {
        final seletorValido = _obraId != null && obras.any((o) => o['id'] == _obraId);
        final id = seletorValido ? _obraId! : obras.first['id'] as int;
        _selecionarObra(id);
      }
    } on ApiException catch (e) {
      setState(() => _loadingObras = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _selecionarObra(int id) async {
    setState(() { _obraId = id; _loadingDados = true; });
    try {
      final extra = _intervalo != null
          ? '?dataInicio=${_fmtApi(_intervalo!.start)}&dataFim=${_fmtApi(_intervalo!.end)}'
          : '';
      final dados = await ApiService.get('/relatorios/graficos/$id$extra');
      setState(() { _dados = dados; _loadingDados = false; });
    } on ApiException catch (e) {
      setState(() => _loadingDados = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _carregarGlobal() async {
    setState(() => _loadingGlobal = true);
    try {
      final dados = await ApiService.getGraficosTodasObras();
      setState(() { _dadosGlobal = dados; _loadingGlobal = false; });
    } on ApiException catch (e) {
      setState(() => _loadingGlobal = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _escolherIntervalo() async {
    final hoje = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resultado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year + 1),
      initialDateRange: _intervalo ?? DateTimeRange(
        start: DateTime(hoje.year, hoje.month, 1), end: hoje),
      locale: const Locale('pt', 'PT'),
      helpText: 'Filtrar por intervalo',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (ctx, child) {
        final baseTheme = Theme.of(ctx);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: (isDark ? baseTheme.colorScheme : const ColorScheme.light(primary: Color(0xFF185FA5), onPrimary: Colors.white)),
          ),
          child: child!,
        );
      },
    );
    if (resultado != null) {
      setState(() => _intervalo = resultado);
      if (_obraId != null) _selecionarObra(_obraId!);
    }
  }

  void _limparFiltro() {
    setState(() => _intervalo = null);
    if (_obraId != null) _selecionarObra(_obraId!);
  }

  String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _accentColor => const Color(0xFFE76F51);
  Color get _progressBackground => Theme.of(context).colorScheme.onSurface.withOpacity(0.08);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráficos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar gráficos',
            onPressed: () async {
              await _carregarObras();
              if (_tabController.index == 3) {
                setState(() => _dadosGlobal = null);
                _carregarGlobal();
              } else if (_obraId != null) {
                _selecionarObra(_obraId!);
              }
            },
          ),
          if (_intervalo != null)
            IconButton(icon: const Icon(Icons.filter_alt_off), tooltip: 'Limpar filtro', onPressed: _limparFiltro),
          IconButton(
            icon: Icon(_intervalo != null ? Icons.date_range : Icons.date_range_outlined),
            tooltip: 'Filtrar por datas',
            onPressed: _escolherIntervalo,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Evolução'),
            Tab(text: 'Distribuição'),
            Tab(text: 'Comparação'),
            Tab(text: 'Todas as obras'),
          ],
        ),
      ),
      body: _loadingObras
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _tabController.index == 3
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (ctx) {
                                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                                  return DropdownButtonFormField<int>(
                                    initialValue: _obraId,
                                    decoration: InputDecoration(
                                      labelText: 'Obra',
                                      isDense: true,
                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
                                    ),
                                    items: _obras.map<DropdownMenuItem<int>>((o) =>
                                        DropdownMenuItem(value: o['id'] as int, child: Text(o['codigo'] ?? ''))).toList(),
                                    onChanged: (v) { if (v != null) _selecionarObra(v); },
                                  );
                                },
                              ),
                              if (_intervalo != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.filter_alt, size: 14, color: Color(0xFF185FA5)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${DateFormat('dd/MM/yy').format(_intervalo!.start)} — ${DateFormat('dd/MM/yy').format(_intervalo!.end)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF185FA5), fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _limparFiltro,
                                      child: const Text('limpar', style: TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.underline)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _loadingDados
                          ? const Center(child: CircularProgressIndicator())
                          : _dados == null
                              ? const Center(child: Text('Seleciona uma obra'))
                              : _tabEvolucao(),
                      _loadingDados
                          ? const Center(child: CircularProgressIndicator())
                          : _dados == null
                              ? const Center(child: Text('Seleciona uma obra'))
                              : _tabDistribuicao(),
                      _loadingDados
                          ? const Center(child: CircularProgressIndicator())
                          : _dados == null
                              ? const Center(child: Text('Seleciona uma obra'))
                              : _tabComparacao(),
                      _loadingGlobal
                          ? const Center(child: CircularProgressIndicator())
                          : _dadosGlobal == null
                              ? Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _carregarGlobal,
                                    icon: const Icon(Icons.bar_chart),
                                    label: const Text('Carregar resumo global'),
                                  ),
                                )
                              : _tabTodasObras(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Tab 1: Evolução ───────────────────────────────────────────────────────
  Widget _tabEvolucao() {
    final evolucao = List<Map<String, dynamic>>.from(_dados!['evolucao'] ?? []);
    final metricas = _dados!['metricas'] as Map<String, dynamic>? ?? {};
    final mp = metricas['pessoas']  as Map<String, dynamic>? ?? {};
    final mm = metricas['maquinas'] as Map<String, dynamic>? ?? {};
    final mv = metricas['viaturas'] as Map<String, dynamic>? ?? {};
    final totalGasto = _parseValor(_dados!['totalGasto']).toDouble();

    if (evolucao.isEmpty) {
      return const Center(child: Text('Sem dados.\nRegista dias primeiro.', textAlign: TextAlign.center));
    }

    final totalFaturado = _parseValor(evolucao.last['acumulado']).toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _metricCard('Faturado',    _eur.format(totalFaturado),  Icons.euro,           const Color(0xFF185FA5)),
          const SizedBox(width: 10),
          _metricCard('Total Gasto', _eur.format(totalGasto),     Icons.payments,       const Color(0xFFE76F51)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _metricCard('H. Pessoas',  '${_parseValor(mp['total_horas']).toStringAsFixed(1)}h', Icons.people,         const Color(0xFF4CAF82)),
          const SizedBox(width: 10),
          _metricCard('Km Viaturas', '${_parseValor(mv['total_km']).toStringAsFixed(1)}km',   Icons.directions_car, const Color(0xFFF4A261)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _metricCard('H. Máquinas', '${_parseValor(mm['total_horas']).toStringAsFixed(1)}h', Icons.construction,  const Color(0xFFE76F51)),
          const SizedBox(width: 10),
          _metricCard('Custo Pessoal', _eur.format(_parseValor(mp['total_custo'])),           Icons.person,        const Color(0xFF9C6ADE)),
        ]),

        const SizedBox(height: 24),
        const Text('Faturado por dia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: evolucao.map((e) => _parseValor(e['faturado']).toDouble()).fold(0.0, (a, b) => a > b ? a : b) * 1.25,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) =>
                    BarTooltipItem(_eur2.format(rod.toY), const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= evolucao.length) return const SizedBox();
                  final d = evolucao[idx]['data']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(d.length >= 10 ? d.substring(5) : d, style: const TextStyle(fontSize: 9)),
                  );
                },
              )),
              leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData:   const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: evolucao.asMap().entries.map((e) => BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(
                toY: _parseValor(e.value['faturado']).toDouble(),
                color: _primaryColor,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )],
            )).toList(),
          )),
        ),

        const SizedBox(height: 28),
        const Text('Faturado acumulado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            gridData:   const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= evolucao.length) return const SizedBox();
                  final d = evolucao[idx]['data']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(d.length >= 10 ? d.substring(5) : d, style: const TextStyle(fontSize: 9)),
                  );
                },
              )),
              leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [LineChartBarData(
              spots: evolucao.asMap().entries.map((e) =>
                  FlSpot(e.key.toDouble(), _parseValor(e.value['acumulado']).toDouble())).toList(),
              isCurved: true,
              color: _primaryColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: _primaryColor.withOpacity(0.08)),
            )],
          )),
        ),
      ],
    );
  }

  // ── Tab 2: Distribuição ───────────────────────────────────────────────────
  Widget _tabDistribuicao() {
    final distribuicao = List<Map<String, dynamic>>.from(_dados!['distribuicao'] ?? []);
    if (distribuicao.isEmpty) {
      return const Center(child: Text('Sem dados de custos.', textAlign: TextAlign.center));
    }
    final total = distribuicao.fold<double>(0, (s, d) => s + _parseValor(d['valor']).toDouble());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Distribuição de custos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 50,
            sections: distribuicao.asMap().entries.map((e) {
              final pct = total > 0 ? _parseValor(e.value['valor']).toDouble() / total * 100 : 0.0;
              return PieChartSectionData(
                value: _parseValor(e.value['valor']).toDouble(),
                color: _coresPizza[e.key % _coresPizza.length],
                title: '${pct.toStringAsFixed(1)}%',
                radius: 70,
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              );
            }).toList(),
          )),
        ),
        const SizedBox(height: 20),
        ...distribuicao.asMap().entries.map((entry) {
          final d   = entry.value;
          final cor = _coresPizza[entry.key % _coresPizza.length];
          final pct = total > 0 ? _parseValor(d['valor']).toDouble() / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d['categoria'] ?? '', style: const TextStyle(fontSize: 13))),
                  Text(_eur2.format(_parseValor(d['valor'])),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 6,
                    backgroundColor: _progressBackground,
                    valueColor: AlwaysStoppedAnimation(cor),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Tab 3: Comparação (top 5) ─────────────────────────────────────────────
  Widget _tabComparacao() {
    final comparacao = List<Map<String, dynamic>>.from(_dados!['comparacao'] ?? []);
    if (comparacao.isEmpty) return const Center(child: Text('Sem dados de comparação.'));

    final maxFaturado = comparacao
        .map((o) => _parseValor(o['total_faturado']).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Top obras por faturado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        ...comparacao.asMap().entries.map((entry) {
          final o   = entry.value;
          final cor = _coresPizza[entry.key % _coresPizza.length];
          final pct = maxFaturado > 0 ? _parseValor(o['total_faturado']).toDouble() / maxFaturado : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(o['codigo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Text(_eur.format(_parseValor(o['total_faturado'])),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 2),
                Text(o['nome'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 10,
                    backgroundColor: _progressBackground,
                    valueColor: AlwaysStoppedAnimation(cor),
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  _miniTag('${o['total_dias']} dias', Icons.calendar_today),
                  const SizedBox(width: 8),
                  _miniTag(_eur.format(_parseValor(o['total_materiais'])), Icons.inventory_2_outlined),
                ]),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Tab 4: Todas as obras — resumo global ─────────────────────────────────
  Widget _tabTodasObras() {
    final obras   = List<Map<String, dynamic>>.from(_dadosGlobal!['obras']   ?? []);
    final resumo  = _dadosGlobal!['resumo']  as Map<String, dynamic>? ?? {};

    final totalFaturado = _parseValor(resumo['total_faturado']).toDouble();
    final totalGasto    = _parseValor(resumo['total_gasto']).toDouble();
    final margem        = _parseValor(resumo['margem']).toDouble();
    final totalObras    = _parseValor(resumo['total_obras']).toInt();
    final margemPct     = totalFaturado > 0 ? (margem / totalFaturado * 100) : 0.0;

    if (obras.isEmpty) return const Center(child: Text('Sem obras com dados.'));

    final maxFaturado = obras.map((o) => _parseValor(o['total_faturado']).toDouble()).fold(0.0, (a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: _carregarGlobal,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            _metricCard('Faturado total', _eur.format(totalFaturado), Icons.euro,     const Color(0xFF185FA5)),
            const SizedBox(width: 10),
            _metricCard('Total obras',    '$totalObras',               Icons.business, const Color(0xFF2E86AB)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _metricCard('Gasto total',    _eur.format(totalGasto),     Icons.payments, const Color(0xFFE76F51)),
            const SizedBox(width: 10),
            _metricCard('Margem',
                '${_eur.format(margem)} (${margemPct.toStringAsFixed(1)}%)',
                Icons.trending_up,
                margem >= 0 ? const Color(0xFF4CAF82) : const Color(0xFFE76F51)),
          ]),

          const SizedBox(height: 24),

          const Text('Faturado vs Gasto por obra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Row(children: [
            _legendaDot(_primaryColor, 'Faturado'),
            const SizedBox(width: 16),
            _legendaDot(_accentColor, 'Gasto'),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: obras.map((o) => [
                _parseValor(o['total_faturado']).toDouble(),
                _parseValor(o['total_gastos']).toDouble(),
              ]).expand((x) => x).fold(0.0, (a, b) => a > b ? a : b) * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIdx, rod, rodIdx) {
                    final o = obras[groupIdx];
                    final label = rodIdx == 0 ? 'Faturado' : 'Gasto';
                    return BarTooltipItem(
                      '${o['codigo']}\n$label: ${_eur2.format(rod.toY)}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx >= obras.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(obras[idx]['codigo']?.toString().split('/').first ?? '',
                          style: const TextStyle(fontSize: 9)),
                    );
                  },
                )),
                leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData:   const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: obras.asMap().entries.map((e) => BarChartGroupData(
                x: e.key,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: _parseValor(e.value['total_faturado']).toDouble(),
                    color: _primaryColor,
                    width: 12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  BarChartRodData(
                    toY: _parseValor(e.value['total_gastos']).toDouble(),
                    color: _accentColor,
                    width: 12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              )).toList(),
            )),
          ),

          const SizedBox(height: 28),

          const Text('Detalhe por obra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),

          ...obras.map((o) {
            final faturado = _parseValor(o['total_faturado']).toDouble();
            final gasto    = _parseValor(o['total_gastos']).toDouble();
            final saldo    = faturado - gasto;
            final pct      = maxFaturado > 0 ? faturado / maxFaturado : 0.0;
            final positivo = saldo >= 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o['codigo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(o['nome'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        _badgeEstado(o['estado'] as String? ?? ''),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 6,
                        backgroundColor: _progressBackground,
                        valueColor: AlwaysStoppedAnimation(_primaryColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _infoCol('Faturado', _eur.format(faturado), const Color(0xFF185FA5)),
                        _infoCol('Gasto',    _eur.format(gasto),    const Color(0xFFE76F51)),
                        _infoCol('Margem',   _eur.format(saldo),
                            positivo ? const Color(0xFF4CAF82) : const Color(0xFFE76F51)),
                        _infoCol('Dias', '${o['total_dias']}', Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total faturado', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  Text(_eur.format(totalFaturado), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Margem global', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  Text('${margemPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: margem >= 0 ? const Color(0xFF4CAF82) : const Color(0xFFE76F51),
                        fontWeight: FontWeight.bold, fontSize: 16,
                      )),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _metricCard(String label, String value, IconData icon, Color cor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: cor.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: cor),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        )),
      ]),
    ),
  );

  Widget _miniTag(String texto, IconData icon) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: Colors.grey),
      const SizedBox(width: 3),
      Text(texto, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  );

  Widget _legendaDot(Color cor, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ],
  );

  Widget _infoCol(String label, String value, Color cor) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cor),
          overflow: TextOverflow.ellipsis),
    ]),
  );

  Widget _badgeEstado(String estado) {
    Color cor;
    String texto;
    switch (estado) {
      case 'em_curso':  cor = Colors.green; texto = 'Em curso';  break;
      case 'planeada':  cor = Colors.blue;  texto = 'Planeada';  break;
      case 'concluida': cor = Colors.grey;  texto = 'Concluída'; break;
      default:          cor = Colors.orange; texto = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.4)),
      ),
      child: Text(texto, style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.w600)),
    );
  }
}