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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
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
    final obras  = List<Map<String, dynamic>>.from(_dados?['obras'] ?? []);

    final totalFaturado  = _toDouble(resumo['total_faturado']);
    final totalGasto     = _toDouble(resumo['total_gasto']);
    final margem         = _toDouble(resumo['margem']);
    final totalObras     = _toInt(resumo['total_obras']);
    final obrasEmCurso   = obras.where((o) => o['estado'] == 'em_curso').toList();
    final obrasConcluidas = obras.where((o) => o['estado'] == 'concluida').length;

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
            _heroCard(nome, totalObras, obrasEmCurso.length, margem),
            const SizedBox(height: 20),
            _sectionTitle('Resumo'),
            const SizedBox(height: 10),
            _kpiGrid(
              crossAxisCount: crossAxisCount,
              items: [
                _KpiData('Total obras',   '$totalObras',              Icons.apartment_rounded,      const Color(0xFF185FA5)),
                _KpiData('Em curso',      '${obrasEmCurso.length}',   Icons.construction_rounded,   const Color(0xFF0F9D8A)),
                _KpiData('Faturado',      Fmt.moeda0(totalFaturado),  Icons.euro_rounded,            const Color(0xFF2F6FED)),
                _KpiData('Margem',
                    Fmt.moeda0(margem),
                    margem >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    margem >= 0 ? const Color(0xFF0F9D8A) : const Color(0xFFE76F51)),
                _KpiData('Gasto total',   Fmt.moeda0(totalGasto),     Icons.receipt_long_rounded,    const Color(0xFFE6824D)),
                _KpiData('Concluídas',    '$obrasConcluidas',         Icons.verified_rounded,        const Color(0xFF6E7F92)),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle('Obras em curso'),
            const SizedBox(height: 10),
            if (obrasEmCurso.isEmpty)
              _emptyPanel()
            else
              ...obrasEmCurso.map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _cardObra(o),
                  )),
          ],
        );
      },
    );
  }

  Widget _heroCard(String nome, int totalObras, int emCurso, double margem) {
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
          Text(
            'Olá, $nome 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Fmt.dataLonga(DateTime.now()),
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(Icons.apartment_rounded,      '$totalObras obras'),
              _heroChip(Icons.play_circle_fill_rounded, '$emCurso ativas'),
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
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
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
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _kpiCard(item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _kpiCard(_KpiData item) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              color: item.color.withOpacity(isDark ? 0.2 : 0.10),
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

  Widget _cardObra(Map<String, dynamic> obra) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final faturado = _toDouble(obra['total_faturado']);
    final gasto    = _toDouble(obra['total_gastos']);
    final dias     = _toInt(obra['total_dias']);
    final margem   = faturado - gasto;
    final pos      = margem >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;

              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _obraTitle(obra, isDark),
                        const SizedBox(height: 10),
                        _statusBadge('Em curso', const Color(0xFF0F9D8A)),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _obraTitle(obra, isDark)),
                        const SizedBox(width: 12),
                        _statusBadge('Em curso', const Color(0xFF0F9D8A)),
                      ],
                    );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _miniInfo('Faturado', Fmt.moeda0(faturado), const Color(0xFF185FA5), isDark),
              _miniInfo('Gasto',    Fmt.moeda0(gasto),    const Color(0xFFE6824D), isDark),
              _miniInfo('Margem',   Fmt.moeda0(margem),
                  pos ? const Color(0xFF0F9D8A) : const Color(0xFFE76F51), isDark),
              _miniInfo('Dias', '$dias',
                  isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _obraTitle(Map<String, dynamic> obra, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          obra['codigo'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          obra['nome'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _miniInfo(String label, String value, Color color, bool isDark) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
          ),
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
        border: Border.all(color: isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED)),
      ),
      child: Column(
        children: [
          Icon(Icons.construction_outlined, size: 48,
              color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478)),
          const SizedBox(height: 12),
          Text(
            'Ainda não há obras registadas.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Quando a primeira obra entrar, este painel já fica pronto.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
            ),
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
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}
