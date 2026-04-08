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
    final obras = List<Map<String, dynamic>>.from(_dados?['obras'] ?? []);

    final totalFaturado = _toDouble(resumo['total_faturado']);
    final totalGasto = _toDouble(resumo['total_gasto']);
    final margem = _toDouble(resumo['margem']);
    final totalObras = _toInt(resumo['total_obras']);

    final obrasEmCurso = obras.where((o) => o['estado'] == 'em_curso').toList();
    final obrasConcluidas = obras.where((o) => o['estado'] == 'concluida').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final crossAxisCount = constraints.maxWidth >= 1250
            ? 4
            : constraints.maxWidth >= 820
                ? 3
                : 2;

        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 10, wide ? 28 : 16, 28),
          children: [
            _hero(nome, totalObras, obrasEmCurso.length, margem),
            const SizedBox(height: 20),
            _sectionTitle('Pulso do negócio', 'Leitura rápida do estado atual das obras.'),
            const SizedBox(height: 12),
            _kpiGrid(
              crossAxisCount: crossAxisCount,
              items: [
                _KpiData('Total obras', '$totalObras', Icons.apartment_rounded, const Color(0xFF185FA5)),
                _KpiData('Em curso', '${obrasEmCurso.length}', Icons.construction_rounded, const Color(0xFF12836D)),
                _KpiData('Faturado', Fmt.moeda0(totalFaturado), Icons.euro_rounded, const Color(0xFF2F6FED)),
                _KpiData(
                  'Margem total',
                  Fmt.moeda0(margem),
                  margem >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  margem >= 0 ? const Color(0xFF12836D) : const Color(0xFFE76F51),
                ),
                _KpiData('Gasto total', Fmt.moeda0(totalGasto), Icons.receipt_long_rounded, const Color(0xFFE6824D)),
                _KpiData('Concluídas', '$obrasConcluidas', Icons.verified_rounded, const Color(0xFF6E7F92)),
              ],
            ),
            const SizedBox(height: 28),
            _sectionTitle('Obras em curso', 'As frentes que mais importam para a operação de hoje.'),
            const SizedBox(height: 12),
            if (obrasEmCurso.isEmpty)
              _emptyPanel()
            else
              ...obrasEmCurso.map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _cardObra(o),
                  )),
          ],
        );
      },
    );
  }

  Widget _hero(String nome, int totalObras, int emCurso, double margem) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            Color.alphaBlend(
              theme.colorScheme.secondary.withOpacity(0.5),
              theme.colorScheme.primary,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(isDark ? 0.26 : 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Olá, $nome',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Fmt.dataLonga(DateTime.now()),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Resumo pronto para desktop, tablet e telemóvel sem perder legibilidade.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroChip(Icons.apartment_rounded, '$totalObras obras'),
              _heroChip(Icons.play_circle_fill_rounded, '$emCurso ativas'),
              _heroChip(
                margem >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                margem >= 0 ? 'Margem saudável' : 'Margem pressionada',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _kpiGrid({required int crossAxisCount, required List<_KpiData> items}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _kpiCard(items[index]),
    );
  }

  Widget _kpiCard(_KpiData item) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.12 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const Spacer(),
          Text(
            item.value,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardObra(Map<String, dynamic> obra) {
    final theme = Theme.of(context);
    final faturado = _toDouble(obra['total_faturado']);
    final gasto = _toDouble(obra['total_gastos']);
    final dias = _toInt(obra['total_dias']);
    final margem = faturado - gasto;
    final margemPos = margem >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obra['codigo'] ?? '',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      obra['nome'] ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge('Em curso', const Color(0xFF12836D)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _miniInfo('Faturado', Fmt.moeda0(faturado), const Color(0xFF185FA5)),
              _miniInfo('Gasto', Fmt.moeda0(gasto), const Color(0xFFE6824D)),
              _miniInfo('Margem', Fmt.moeda0(margem), margemPos ? const Color(0xFF12836D) : const Color(0xFFE76F51)),
              _miniInfo('Dias', '$dias', theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value, Color color) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _emptyPanel() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Icon(Icons.construction_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            'Ainda não há obras registadas.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Quando a primeira obra entrar, este painel já fica pronto para acompanhar produção, faturação e margem.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiData(this.label, this.value, this.icon, this.color);
}
