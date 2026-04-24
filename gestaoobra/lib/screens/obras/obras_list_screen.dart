import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../widgets/search_bar_widget.dart';
import 'obra_detail_screen.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

num _parseOrcamento(dynamic value) {
  if (value is num) return value;
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

const List<String> _tiposObra = [
  'AC',
  'DC',
  'AC/DC',
  'Mecânica',
  'Inst. Elétrica',
  'Remodelação',
  'Construção Nova',
];

class _FiltrosObras {
  final List<String> tipos;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final String orcamentoMin;
  final String orcamentoMax;

  const _FiltrosObras({
    this.tipos = const [],
    this.dataInicio,
    this.dataFim,
    this.orcamentoMin = '',
    this.orcamentoMax = '',
  });

  bool get hasActiveFilters =>
      tipos.isNotEmpty ||
      dataInicio != null ||
      dataFim != null ||
      orcamentoMin.trim().isNotEmpty ||
      orcamentoMax.trim().isNotEmpty;

  int get activeCount {
    var count = 0;
    if (tipos.isNotEmpty) count++;
    if (dataInicio != null || dataFim != null) count++;
    if (orcamentoMin.trim().isNotEmpty || orcamentoMax.trim().isNotEmpty) count++;
    return count;
  }
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
  bool _mostrarFiltros = false;
  _FiltrosObras _filtrosAplicados = const _FiltrosObras();

  final Set<String> _tiposSelecionados = <String>{};
  DateTime? _dataInicioSelecionada;
  DateTime? _dataFimSelecionada;
  final TextEditingController _orcamentoMinCtrl = TextEditingController();
  final TextEditingController _orcamentoMaxCtrl = TextEditingController();

  static const int _obrasPorPagina = 20;
  int _paginaAtual = 0;

  // Scroll controller para voltar ao topo ao mudar de página
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _orcamentoMinCtrl.dispose();
    _orcamentoMaxCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sincronizarDraftComAplicados();
    _carregar();
  }

  bool get _temFiltrosServidorAtivos =>
      _filtroEstado.isNotEmpty || _filtrosAplicados.hasActiveFilters;

  void _sincronizarDraftComAplicados() {
    _tiposSelecionados
      ..clear()
      ..addAll(_filtrosAplicados.tipos);
    _dataInicioSelecionada = _filtrosAplicados.dataInicio;
    _dataFimSelecionada = _filtrosAplicados.dataFim;
    _orcamentoMinCtrl.text = _filtrosAplicados.orcamentoMin;
    _orcamentoMaxCtrl.text = _filtrosAplicados.orcamentoMax;
  }

  String? _normalizarNumero(String value) {
    final trimmed = value.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < 0) return null;
    return parsed.toString();
  }

  String? _fmtApiDate(DateTime? value) =>
      value == null ? null : DateFormat('yyyy-MM-dd').format(value);

  String _fmtUiDate(DateTime? value) =>
      value == null ? 'Selecionar' : DateFormat('dd/MM/yyyy').format(value);

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.listarObras(
        estado: _filtroEstado.isEmpty ? null : _filtroEstado,
        tipos: _filtrosAplicados.tipos,
        dataInicio: _fmtApiDate(_filtrosAplicados.dataInicio),
        dataFim: _fmtApiDate(_filtrosAplicados.dataFim),
        orcamentoMin: _filtrosAplicados.orcamentoMin,
        orcamentoMax: _filtrosAplicados.orcamentoMax,
      );
      _obras = data;
      _loading = false;
      _filtrarObras();
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  void _filtrarObras() {
  final search = _searchText.toLowerCase();
  final minVal = double.tryParse(_filtrosAplicados.orcamentoMin);
  final maxVal = double.tryParse(_filtrosAplicados.orcamentoMax);

  setState(() {
    _paginaAtual = 0;
    _obrasFiltradas = _obras.where((obra) {
      final codigo = (obra['codigo'] ?? '').toString().toLowerCase();
      final nome = (obra['nome'] ?? '').toString().toLowerCase();
      final matchSearch = codigo.contains(search) || nome.contains(search);

      // Filtro de orçamento
      final orc = _parseOrcamento(obra['orcamento']).toDouble();
      final matchMin = minVal == null || orc >= minVal;
      final matchMax = maxVal == null || orc <= maxVal;

      return matchSearch && matchMin && matchMax;
    }).toList();
  });
}

  void _toggleFiltros() {
    setState(() {
      _mostrarFiltros = !_mostrarFiltros;
      if (_mostrarFiltros) _sincronizarDraftComAplicados();
    });
  }

  Future<void> _selecionarData({required bool isInicio}) async {
    final atual = isInicio ? _dataInicioSelecionada : _dataFimSelecionada;
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      if (isInicio) {
        _dataInicioSelecionada = picked;
        if (_dataFimSelecionada != null && picked.isAfter(_dataFimSelecionada!)) {
          _dataFimSelecionada = picked;
        }
      } else {
        _dataFimSelecionada = picked;
        if (_dataInicioSelecionada != null && picked.isBefore(_dataInicioSelecionada!)) {
          _dataInicioSelecionada = picked;
        }
      }
    });
  }

  Future<void> _aplicarFiltrosAvancados() async {
    final min = _normalizarNumero(_orcamentoMinCtrl.text);
    final max = _normalizarNumero(_orcamentoMaxCtrl.text);

    if (_orcamentoMinCtrl.text.trim().isNotEmpty && min == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orçamento mínimo inválido')),
      );
      return;
    }
    if (_orcamentoMaxCtrl.text.trim().isNotEmpty && max == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orçamento máximo inválido')),
      );
      return;
    }
    if (min != null && max != null && double.parse(min) > double.parse(max)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O orçamento mínimo não pode ser superior ao máximo')),
      );
      return;
    }

    _filtrosAplicados = _FiltrosObras(
      tipos: _tiposSelecionados.toList()..sort(),
      dataInicio: _dataInicioSelecionada,
      dataFim: _dataFimSelecionada,
      orcamentoMin: min ?? '',
      orcamentoMax: max ?? '',
    );

    setState(() => _mostrarFiltros = false);
    await _carregar();
  }

  Future<void> _limparFiltrosAvancados() async {
    _filtrosAplicados = const _FiltrosObras();
    _tiposSelecionados.clear();
    _dataInicioSelecionada = null;
    _dataFimSelecionada = null;
    _orcamentoMinCtrl.clear();
    _orcamentoMaxCtrl.clear();

    setState(() => _mostrarFiltros = false);
    await _carregar();
  }

  // Obras apenas da página atual
  List<dynamic> get _obrasPaginaAtual {
    final inicio = _paginaAtual * _obrasPorPagina;
    final fim = (inicio + _obrasPorPagina).clamp(0, _obrasFiltradas.length);
    return _obrasFiltradas.sublist(inicio, fim);
  }

  int get _totalPaginas => (_obrasFiltradas.length / _obrasPorPagina).ceil();

  void _irParaPagina(int pagina) {
    if (pagina < 0 || pagina >= _totalPaginas) return;
    setState(() => _paginaAtual = pagina);
    // Scroll para o topo
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(16, 12, 16, isDesktop ? 32 : 24),
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
                          const SizedBox(height: 8),
                          _filtrosToolbar(isDark),
                          if (_mostrarFiltros) ...[
                            const SizedBox(height: 10),
                            _painelFiltrosAvancados(isDark),
                          ],
                          const SizedBox(height: 12),
                          if (_obras.isEmpty && !_temFiltrosServidorAtivos)
                            _emptyMessage(
                              icon: Icons.domain_disabled_outlined,
                              title: 'Sem obras registadas',
                              subtitle: 'Cria a primeira obra para comecar.',
                              isDark: isDark,
                            )
                          else if (_obras.isEmpty || _obrasFiltradas.isEmpty)
                            _emptyMessage(
                              icon: Icons.search_off_rounded,
                              title: 'Nenhuma obra encontrada',
                              subtitle: 'Ajusta a pesquisa ou os filtros aplicados.',
                              isDark: isDark,
                            )
                          else ...[
                            // Indicador de resultados e página atual
                            _paginacaoInfo(isDark),
                            const SizedBox(height: 10),

                            // Grid ou lista de obras da página atual
                            if (isDesktop)
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridColumns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 168,
                                ),
                                itemCount: _obrasPaginaAtual.length,
                                itemBuilder: (context, i) => _obraCard(_obrasPaginaAtual[i], isDark),
                              )
                            else
                              ..._obrasPaginaAtual.map(
                                (obra) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _obraCard(obra, isDark),
                                ),
                              ),

                            // Controlos de paginação
                            if (_totalPaginas > 1) ...[
                              const SizedBox(height: 20),
                              _paginacaoControlos(isDark),
                            ],
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  /// Linha de info: "A mostrar 1–50 de 234 obras"
  Widget _paginacaoInfo(bool isDark) {
    final inicio = _paginaAtual * _obrasPorPagina + 1;
    final fim = ((_paginaAtual + 1) * _obrasPorPagina).clamp(0, _obrasFiltradas.length);
    final textColor = isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478);

    return Text(
      'A mostrar $inicio–$fim de ${_obrasFiltradas.length} obras',
      style: TextStyle(fontSize: 12, color: textColor),
    );
  }

  /// Botões de navegação entre páginas
  Widget _paginacaoControlos(bool isDark) {
    final bg = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final textColor = isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233);
    const accent = Color(0xFF185FA5);

    // Calcula quais páginas mostrar (máximo 5 botões visíveis)
    final paginas = _paginasVisiveis();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botão anterior
          _botaoPagina(
            icon: Icons.chevron_left_rounded,
            onTap: _paginaAtual > 0 ? () => _irParaPagina(_paginaAtual - 1) : null,
            isDark: isDark,
          ),
          const SizedBox(width: 6),

          // Números de página
          ...paginas.map((p) {
            if (p == -1) {
              // Reticências
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              );
            }
            final isAtiva = p == _paginaAtual;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: isAtiva ? null : () => _irParaPagina(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isAtiva ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isAtiva ? null : Border.all(color: border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${p + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isAtiva ? Colors.white : textColor,
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(width: 6),
          // Botão seguinte
          _botaoPagina(
            icon: Icons.chevron_right_rounded,
            onTap: _paginaAtual < _totalPaginas - 1 ? () => _irParaPagina(_paginaAtual + 1) : null,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _botaoPagina({required IconData icon, VoidCallback? onTap, required bool isDark}) {
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final color = onTap == null
        ? (isDark ? const Color(0xFF374151) : const Color(0xFFB0BCC8))
        : (isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  /// Gera a lista de índices de página a mostrar, com -1 para reticências
  List<int> _paginasVisiveis() {
    if (_totalPaginas <= 7) {
      return List.generate(_totalPaginas, (i) => i);
    }

    final paginas = <int>[];
    // Sempre mostra a primeira
    paginas.add(0);

    if (_paginaAtual > 2) paginas.add(-1); // reticências à esquerda

    // Páginas à volta da atual
    final inicio = (_paginaAtual - 1).clamp(1, _totalPaginas - 2);
    final fim = (_paginaAtual + 1).clamp(1, _totalPaginas - 2);
    for (int i = inicio; i <= fim; i++) {
      paginas.add(i);
    }

    if (_paginaAtual < _totalPaginas - 3) paginas.add(-1); // reticências à direita

    // Sempre mostra a última
    paginas.add(_totalPaginas - 1);

    return paginas;
  }

  Widget _filtrosToolbar(bool isDark) {
    final bg = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final textColor = isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233);
    final count = _filtrosAplicados.activeCount;
    final destaque = _filtrosAplicados.hasActiveFilters ? const Color(0xFF185FA5) : textColor;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _toggleFiltros,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _filtrosAplicados.hasActiveFilters ? const Color(0xFF185FA5) : border,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: destaque),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Filtros',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: destaque,
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF185FA5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _mostrarFiltros ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: destaque,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${_obrasFiltradas.length} resultado(s)',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _painelFiltrosAvancados(bool isDark) {
    final bg = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secaoTitulo('Tipo de Obra'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tiposObra.map((tipo) {
              final ativo = _tiposSelecionados.contains(tipo);
              return FilterChip(
                label: Text(tipo),
                selected: ativo,
                onSelected: (_) {
                  setState(() {
                    if (ativo) {
                      _tiposSelecionados.remove(tipo);
                    } else {
                      _tiposSelecionados.add(tipo);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _secaoTitulo('Intervalo de Datas'),
          Row(
            children: [
              Expanded(
                child: _campoData(
                  label: 'Data de início',
                  value: _fmtUiDate(_dataInicioSelecionada),
                  onTap: () => _selecionarData(isInicio: true),
                  onClear: _dataInicioSelecionada == null
                      ? null
                      : () => setState(() => _dataInicioSelecionada = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _campoData(
                  label: 'Data de fim',
                  value: _fmtUiDate(_dataFimSelecionada),
                  onTap: () => _selecionarData(isInicio: false),
                  onClear: _dataFimSelecionada == null
                      ? null
                      : () => setState(() => _dataFimSelecionada = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _secaoTitulo('Valor do Orçamento'),
          Row(
            children: [
              Expanded(
                child: _campoTexto(
                  controller: _orcamentoMinCtrl,
                  label: 'Mínimo',
                  hint: '€ 0',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _campoTexto(
                  controller: _orcamentoMaxCtrl,
                  label: 'Máximo',
                  hint: '€ 50000',
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _limparFiltrosAvancados,
                  child: const Text('Limpar Filtros'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _aplicarFiltrosAvancados,
                  child: const Text('Aplicar Filtros'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _secaoTitulo(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _campoData({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today_rounded, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(value),
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
            const Row(
              children: [
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
