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
        return const Color(0xFF0F9D8A);
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
        return 'Concluida';
      default:
        return estado ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  final isDesktop = constraints.maxWidth >= 960;
                  final maxContentWidth = isDesktop ? 1280.0 : 720.0;
                  final gridColumns = constraints.maxWidth >= 1440 ? 3 : 2;

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, isDesktop ? 32 : 96),
                        children: [
                          _resumoChips(total, emCurso, planeadas, concluidas, isDark),
                          const SizedBox(height: 12),
                          SearchBarWidget(
                            hintText: 'Pesquisar por codigo ou nome...',
                            onChanged: (v) {
                              _searchText = v;
                              _filtrarObras();
                            },
                          ),
                          const SizedBox(height: 8),
                          _filtrosEstado(isDark),
                          const SizedBox(height: 12),
                          if (_obras.isEmpty)
                            _emptyMessage(
                              icon: Icons.domain_disabled_outlined,
                              title: 'Sem obras registadas',
                              subtitle: 'Cria a primeira obra para comecar.',
                              isDark: isDark,
                            )
                          else if (_obrasFiltradas.isEmpty)
                            _emptyMessage(
                              icon: Icons.search_off_rounded,
                              title: 'Nenhuma obra encontrada',
                              subtitle: 'Ajusta a pesquisa ou o filtro.',
                              isDark: isDark,
                            )
                          else if (isDesktop)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridColumns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 168,
                              ),
                              itemCount: _obrasFiltradas.length,
                              itemBuilder: (context, i) => _obraCard(_obrasFiltradas[i], isDark),
                            )
                          else
                            ..._obrasFiltradas.map(
                              (obra) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _obraCard(obra, isDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _resumoChips(int total, int emCurso, int planeadas, int concluidas, bool isDark) {
    final bg = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Total: $total', Icons.apartment_rounded, const Color(0xFF185FA5), bg, border),
          const SizedBox(width: 8),
          _chip('Em curso: $emCurso', Icons.construction_rounded, const Color(0xFF0F9D8A), bg, border),
          const SizedBox(width: 8),
          _chip('Planeadas: $planeadas', Icons.event_note_rounded, const Color(0xFF185FA5), bg, border),
          const SizedBox(width: 8),
          _chip('Concluidas: $concluidas', Icons.verified_rounded, const Color(0xFF6E7F92), bg, border),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData icon, Color color, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _filtrosEstado(bool isDark) {
    final bg = isDark ? const Color(0xFF1E2530) : const Color(0xFFF0F4F8);
    const selected = Color(0xFF185FA5);

    Widget item(String key, String label, IconData icon) {
      final ativo = _filtroEstado == key;
      final color = ativo
          ? Colors.white
          : (isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478));

      return Expanded(
        child: GestureDetector(
          onTap: () async {
            _filtroEstado = key;
            await _carregar();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: ativo ? selected : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              children: [
                Row(
                  children: [
                    item('', 'Todas', Icons.dashboard_customize_outlined),
                    const SizedBox(width: 4),
                    item('em_curso', 'Em curso', Icons.play_circle_outline_rounded),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    item('planeada', 'Planeadas', Icons.edit_calendar_outlined),
                    const SizedBox(width: 4),
                    item('concluida', 'Concluidas', Icons.task_alt_rounded),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              item('', 'Todas', Icons.dashboard_customize_outlined),
              const SizedBox(width: 4),
              item('em_curso', 'Em curso', Icons.play_circle_outline_rounded),
              const SizedBox(width: 4),
              item('planeada', 'Planeadas', Icons.edit_calendar_outlined),
              const SizedBox(width: 4),
              item('concluida', 'Concluidas', Icons.task_alt_rounded),
            ],
          );
        },
      ),
    );
  }

  Widget _obraCard(dynamic obra, bool isDark) {
    final estadoCor = _corEstado(obra['estado']);
    final cardBg = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final titleColor = isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233);
    final subtitleColor = isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478);
    final orcamento = obra['orcamento'];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ObraDetailScreen(obra: obra)),
      ).then((_) => _carregar()),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: titleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        obra['nome'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: estadoCor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _textoEstado(obra['estado']),
                    style: TextStyle(color: estadoCor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (orcamento != null) ...[
              const SizedBox(height: 12),
              Text('Orcamento', style: TextStyle(fontSize: 11, color: subtitleColor)),
              const SizedBox(height: 2),
              Text(
                _eur.format(_parseOrcamento(orcamento)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF185FA5)),
                SizedBox(width: 5),
                Text(
                  'Ver detalhe',
                  style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w700, fontSize: 13),
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
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252D3A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478)),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478)),
          ),
        ],
      ),
    );
  }
}
