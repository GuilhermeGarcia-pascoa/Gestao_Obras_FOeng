import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../widgets/search_bar_widget.dart';
import 'obra_detail_screen.dart';
import 'obra_form_screen.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

num _parseOrcamento(dynamic value) {
  if (value is num) return value;
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class ObrasListScreen extends StatefulWidget {
  const ObrasListScreen({super.key});

  @override
  State<ObrasListScreen> createState() => _ObrasListScreenState();
}

class _ObrasListScreenState extends State<ObrasListScreen> {
  List<dynamic> _obras = [];
  List<dynamic> _obrasFiltradas = [];
  bool _loading = true;
  String _filtroEstado = '';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final estado = _filtroEstado.isEmpty ? null : _filtroEstado;
      final data = await ApiService.listarObras(estado: estado);
      setState(() {
        _obras = data;
        _loading = false;
        _filtrarObras();
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  void _filtrarObras() {
    final search = _searchText.toLowerCase();
    setState(() {
      _obrasFiltradas = _obras.where((obra) {
        final codigo = (obra['codigo'] ?? '').toString().toLowerCase();
        final nome = (obra['nome'] ?? '').toString().toLowerCase();
        return codigo.contains(search) || nome.contains(search);
      }).toList();
    });
  }

  Color _corEstado(String? estado) {
    switch (estado) {
      case 'em_curso':
        return const Color(0xFF12836D);
      case 'planeada':
        return const Color(0xFF185FA5);
      case 'concluida':
        return const Color(0xFF6E7F92);
      default:
        return const Color(0xFFE6824D);
    }
  }

  String _textoEstado(String? estado) {
    switch (estado) {
      case 'em_curso':
        return 'Em curso';
      case 'planeada':
        return 'Planeada';
      case 'concluida':
        return 'Concluída';
      default:
        return estado ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _obras.length;
    final emCurso = _obras.where((o) => o['estado'] == 'em_curso').length;
    final planeadas = _obras.where((o) => o['estado'] == 'planeada').length;
    final concluidas = _obras.where((o) => o['estado'] == 'concluida').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ObraFormScreen()),
        ).then((_) => _carregar()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova obra'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final grid = constraints.maxWidth >= 960;

                  return ListView(
                    padding: EdgeInsets.fromLTRB(grid ? 28 : 16, 10, grid ? 28 : 16, 96),
                    children: [
                      _hero(total, emCurso, planeadas, concluidas),
                      const SizedBox(height: 14),
                      SearchBarWidget(
                        hintText: 'Pesquisar por código ou nome...',
                        onChanged: (value) {
                          _searchText = value;
                          _filtrarObras();
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: _filtrosEstado(),
                      ),
                      const SizedBox(height: 10),
                      if (_obras.isEmpty)
                        _emptyMessage(
                          icon: Icons.domain_disabled_outlined,
                          title: 'Sem obras registadas',
                          subtitle: 'Cria a primeira obra para começar a acompanhar custos, dias e produção.',
                        )
                      else if (_obrasFiltradas.isEmpty)
                        _emptyMessage(
                          icon: Icons.search_off_rounded,
                          title: 'Nenhuma obra encontrada',
                          subtitle: 'Ajusta a pesquisa ou o estado para ver outros resultados.',
                        )
                      else if (grid)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.7,
                          ),
                          itemCount: _obrasFiltradas.length,
                          itemBuilder: (context, i) => _obraCard(_obrasFiltradas[i]),
                        )
                      else
                        ..._obrasFiltradas.map(
                          (obra) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _obraCard(obra),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _hero(int total, int emCurso, int planeadas, int concluidas) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(isDark ? 0.38 : 0.16),
            theme.colorScheme.secondary.withOpacity(isDark ? 0.2 : 0.1),
          ],
        ),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Portefólio de obras', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Uma lista mais clara para trabalhar bem em ecrã pequeno e também em escritório.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryChip('Total', '$total', Icons.apartment_rounded),
              _summaryChip('Em curso', '$emCurso', Icons.construction_rounded),
              _summaryChip('Planeadas', '$planeadas', Icons.event_note_rounded),
              _summaryChip('Concluídas', '$concluidas', Icons.verified_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _filtrosEstado() {
    final theme = Theme.of(context);
    final bg = theme.brightness == Brightness.dark ? const Color(0xFF20252B) : const Color(0xFFF1F4F8);
    final selected = theme.colorScheme.primary;

    Widget item(String key, String label, IconData icon) {
      final ativo = _filtroEstado == key;
      return Expanded(
        child: GestureDetector(
          onTap: () async {
            _filtroEstado = key;
            await _carregar();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: ativo ? selected : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ativo
                  ? [
                      BoxShadow(
                        color: selected.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: ativo ? Colors.white : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ativo ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          item('', 'Todas', Icons.dashboard_customize_outlined),
          const SizedBox(width: 6),
          item('em_curso', 'Em curso', Icons.play_circle_outline_rounded),
          const SizedBox(width: 6),
          item('planeada', 'Planeadas', Icons.edit_calendar_outlined),
          const SizedBox(width: 6),
          item('concluida', 'Concluídas', Icons.task_alt_rounded),
        ],
      ),
    );
  }

  Widget _obraCard(dynamic obra) {
    final theme = Theme.of(context);
    final estadoCor = _corEstado(obra['estado']);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ObraDetailScreen(obra: obra)),
      ).then((_) => _carregar()),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.75)),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obra['codigo'] ?? '',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        obra['nome'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: estadoCor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _textoEstado(obra['estado']),
                    style: TextStyle(
                      color: estadoCor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (obra['orcamento'] != null) ...[
              Text(
                'Orçamento',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _eur.format(_parseOrcamento(obra['orcamento'])),
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Icon(Icons.arrow_forward_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Abrir detalhe da obra',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.75)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
