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

// Paleta de cores para o gráfico de pizza
const _coresPizza = [
  Color(0xFF1A1A2E),
  Color(0xFF185FA5),
  Color(0xFF2E86AB),
  Color(0xFF4CAF82),
  Color(0xFFF4A261),
  Color(0xFFE76F51),
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
  bool _loadingObras = true;
  bool _loadingDados = false;

  // Filtro de datas
  DateTimeRange? _intervalo;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      if (obras.isNotEmpty) _selecionarObra(obras.first['id']);
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

  Future<void> _escolherIntervalo() async {
    final hoje = DateTime.now();
    final resultado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year + 1),
      initialDateRange: _intervalo ?? DateTimeRange(
        start: DateTime(hoje.year, hoje.month, 1),
        end: hoje,
      ),
      locale: const Locale('pt', 'PT'),
      helpText: 'Filtrar por intervalo',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF185FA5),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
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
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráficos'),
        actions: [
          // Botão filtro de datas
          if (_intervalo != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Limpar filtro',
              onPressed: _limparFiltro,
            ),
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
          tabs: const [
            Tab(text: 'Evolução'),
            Tab(text: 'Distribuição'),
            Tab(text: 'Comparação'),
          ],
        ),
      ),
      body: _loadingObras
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Seletor de obra + indicador de filtro
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _obraId,
                        decoration: const InputDecoration(labelText: 'Obra', isDense: true),
                        items: _obras.map<DropdownMenuItem<int>>((o) =>
                            DropdownMenuItem(value: o['id'] as int, child: Text(o['codigo'] ?? ''))).toList(),
                        onChanged: (v) { if (v != null) _selecionarObra(v); },
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
                const SizedBox(height: 8),
                Expanded(
                  child: _loadingDados
                      ? const Center(child: CircularProgressIndicator())
                      : _dados == null
                          ? const Center(child: Text('Seleciona uma obra'))
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _tabEvolucao(),
                                _tabDistribuicao(),
                                _tabComparacao(),
                              ],
                            ),
                ),
              ],
            ),
    );
  }

  // ── Tab 1: Evolução ──────────────────────────────────────────────
  Widget _tabEvolucao() {
    final evolucao = List<Map<String, dynamic>>.from(_dados!['evolucao'] ?? []);
    final metricas = _dados!['metricas'] as Map<String, dynamic>? ?? {};
    final mp = metricas['pessoas']  as Map<String, dynamic>? ?? {};
    final mm = metricas['maquinas'] as Map<String, dynamic>? ?? {};
    final mv = metricas['viaturas'] as Map<String, dynamic>? ?? {};

    if (evolucao.isEmpty) {
      return const Center(child: Text('Sem dados para esta obra.\nRegista dias primeiro.', textAlign: TextAlign.center));
    }

    final totalFaturado = evolucao.isNotEmpty ? _parseValor(evolucao.last['acumulado']).toDouble() : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cards de métricas — linha 1
        Row(children: [
          _metricCard('Faturado',    _eur.format(totalFaturado),         Icons.euro,             const Color(0xFF185FA5)),
          const SizedBox(width: 10),
          _metricCard('Dias',        '${evolucao.length}',               Icons.calendar_today,   const Color(0xFF2E86AB)),
        ]),
        const SizedBox(height: 10),
        // Cards de métricas — linha 2
        Row(children: [
          _metricCard('H. Pessoas',  '${_parseValor(mp['total_horas']).toStringAsFixed(1)} h', Icons.people,  const Color(0xFF4CAF82)),
          const SizedBox(width: 10),
          _metricCard('Km Viaturas', '${_parseValor(mv['total_km']).toStringAsFixed(1)} km',   Icons.directions_car, const Color(0xFFF4A261)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _metricCard('H. Máquinas', '${_parseValor(mm['total_horas']).toStringAsFixed(1)} h',          Icons.construction, const Color(0xFFE76F51)),
          const SizedBox(width: 10),
          _metricCard('Custo Pessoal', _eur.format(_parseValor(mp['total_custo'])), Icons.person,       const Color(0xFF9C6ADE)),
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
                  final data = evolucao[idx]['data']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(data.length >= 10 ? data.substring(5) : data, style: const TextStyle(fontSize: 9)),
                  );
                },
              )),
              leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData:   const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: evolucao.asMap().entries.map((e) => BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(
                toY: _parseValor(e.value['faturado']).toDouble(),
                color: const Color(0xFF1A1A2E),
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
                  final data = evolucao[idx]['data']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(data.length >= 10 ? data.substring(5) : data, style: const TextStyle(fontSize: 9)),
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
              color: const Color(0xFF185FA5),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF185FA5).withOpacity(0.08),
              ),
            )],
          )),
        ),
      ],
    );
  }

  // ── Tab 2: Distribuição (pizza) ──────────────────────────────────
  Widget _tabDistribuicao() {
    final distribuicao = List<Map<String, dynamic>>.from(_dados!['distribuicao'] ?? []);

    if (distribuicao.isEmpty) {
      return const Center(child: Text('Sem dados de custos para esta obra.', textAlign: TextAlign.center));
    }

    final total = distribuicao.fold<double>(0, (s, d) => s + _parseValor(d['valor']).toDouble());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Distribuição de custos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),

        // Gráfico de pizza
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

        // Legenda + barras
        ...distribuicao.asMap().entries.map((entry) {
          final d   = entry.value;
          final cor = _coresPizza[entry.key % _coresPizza.length];
          final pct = total > 0 ? _parseValor(d['valor']).toDouble() / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d['categoria'] ?? '', style: const TextStyle(fontSize: 13))),
                    Text(_eur2.format(_parseValor(d['valor'])),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1EFE8),
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

  // ── Tab 3: Comparação entre obras ────────────────────────────────
  Widget _tabComparacao() {
    final comparacao = List<Map<String, dynamic>>.from(_dados!['comparacao'] ?? []);

    if (comparacao.isEmpty) {
      return const Center(child: Text('Sem dados de comparação.'));
    }

    final maxFaturado = comparacao
        .map((o) => _parseValor(o['total_faturado']).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Top obras por faturado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),

        // Gráfico de barras horizontais
        ...comparacao.asMap().entries.map((entry) {
          final o   = entry.value;
          final cor = _coresPizza[entry.key % _coresPizza.length];
          final pct = maxFaturado > 0 ? _parseValor(o['total_faturado']).toDouble() / maxFaturado : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(o['codigo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Text(_eur.format(_parseValor(o['total_faturado'])),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(o['nome'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFF1EFE8),
                    valueColor: AlwaysStoppedAnimation(cor),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniTag('${o['total_dias']} dias', Icons.calendar_today),
                    const SizedBox(width: 8),
                    _miniTag(_eur.format(_parseValor(o['total_materiais'])) + ' mat.', Icons.inventory_2_outlined),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _metricCard(String label, String value, IconData icon, Color cor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cor.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: cor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
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
}