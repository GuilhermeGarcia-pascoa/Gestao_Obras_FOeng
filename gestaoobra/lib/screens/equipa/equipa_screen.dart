import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../widgets/search_bar_widget.dart';

class EquipaScreen extends StatefulWidget {
  const EquipaScreen({super.key});

  @override
  State<EquipaScreen> createState() => _EquipaScreenState();
}

class _EquipaScreenState extends State<EquipaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  List<dynamic> _pessoas = [];
  List<dynamic> _maquinas = [];
  List<dynamic> _viaturas = [];

  List<dynamic> _pessoasFiltradas = [];
  List<dynamic> _maquinasFiltradas = [];
  List<dynamic> _viaturasFiltradas = [];

  String _searchPessoas = '';
  String _searchMaquinas = '';
  String _searchViaturas = '';

  String _filtroEstadoPessoas = 'ativas';
  String _filtroEstadoMaquinas = 'ativas';
  String _filtroEstadoViaturas = 'ativas';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _ativo(dynamic item) => item['ativo'] == null || item['ativo'] == true || item['ativo'] == 1;

  String _normalizar(dynamic value) => (value ?? '').toString().trim().toLowerCase();

  bool _matchEstado(dynamic item, String filtro) => filtro == 'ativas' ? _ativo(item) : !_ativo(item);

  void _filtrarPessoas() {
    final termo = _searchPessoas.toLowerCase();
    setState(() {
      _pessoasFiltradas = _pessoas.where((p) {
        final nome = _normalizar(p['nome']);
        final cargo = _normalizar(p['cargo']);
        final pais = _normalizar(p['pais']);
        return _matchEstado(p, _filtroEstadoPessoas) &&
            (nome.contains(termo) || cargo.contains(termo) || pais.contains(termo));
      }).toList();
    });
  }

  void _filtrarMaquinas() {
    final termo = _searchMaquinas.toLowerCase();
    setState(() {
      _maquinasFiltradas = _maquinas.where((m) {
        final nome = _normalizar(m['nome']);
        final tipo = _normalizar(m['tipo']);
        final matricula = _normalizar(m['matricula']);
        return _matchEstado(m, _filtroEstadoMaquinas) &&
            (nome.contains(termo) || tipo.contains(termo) || matricula.contains(termo));
      }).toList();
    });
  }

  void _filtrarViaturas() {
    final termo = _searchViaturas.toLowerCase();
    setState(() {
      _viaturasFiltradas = _viaturas.where((v) {
        final modelo = _normalizar(v['modelo']);
        final matricula = _normalizar(v['matricula']);
        return _matchEstado(v, _filtroEstadoViaturas) &&
            (modelo.contains(termo) || matricula.contains(termo));
      }).toList();
    });
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.listarPessoas(estado: 'todas'),
        ApiService.listarMaquinas(estado: 'todas'),
        ApiService.listarViaturas(estado: 'todas'),
      ]);

      _pessoas = results[0];
      _maquinas = results[1];
      _viaturas = results[2];

      _filtrarPessoas();
      _filtrarMaquinas();
      _filtrarViaturas();
      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  void _adicionar() {
    final tab = _tabs.index;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormSheet(
        tipo: tab == 0 ? 'pessoa' : tab == 1 ? 'maquina' : 'viatura',
        onSalvo: _carregar,
      ),
    );
  }

  void _editar(dynamic item) {
    final tab = _tabs.index;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormSheet(
        tipo: tab == 0 ? 'pessoa' : tab == 1 ? 'maquina' : 'viatura',
        item: item,
        onSalvo: _carregar,
      ),
    );
  }

  Future<void> _apagar(dynamic item) async {
    if (_tabs.index == 0 || _tabs.index == 1 || _tabs.index == 2) {
      final tipoLabel = _tabs.index == 0
          ? 'trabalhadores'
          : _tabs.index == 1
              ? 'maquinas'
              : 'viaturas';
      await _mostrarAvisoNaoPodeApagar(tipoLabel);
      return;
    }

    final title = item['nome'] ?? item['modelo'] ?? 'registo';
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminação'),
        content: Text('Eliminar "$title"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (result != true) return;

    try {
      if (_tabs.index == 0) {
        await ApiService.apagarPessoa(item['id'] as int);
      } else if (_tabs.index == 1) {
        await ApiService.apagarMaquina(item['id'] as int);
      } else {
        await ApiService.apagarViatura(item['id'] as int);
      }
      await _carregar();
    } on ApiException catch (e) {
      if (mounted) {
        if (e.codigo == 403) {
          final tipoLabel = _tabs.index == 0
              ? 'trabalhadores'
              : _tabs.index == 1
                  ? 'maquinas'
                  : 'viaturas';
          await _mostrarAvisoNaoPodeApagar(tipoLabel, mensagem: e.mensagem);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
        }
      }
    }
  }

  Future<void> _mostrarAvisoNaoPodeApagar(String tipoLabel, {String? mensagem}) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Acao nao permitida'),
        content: Text(
          mensagem ??
              'Os $tipoLabel nao podem ser apagados porque isso compromete o historico e os graficos. Marque-os como inativos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Future<void> _alterarEstado(dynamic item, String tipo, bool ativo) async {
    try {
      if (tipo == 'pessoa') {
        await ApiService.editarPessoa(
          item['id'] as int,
          {
            'nome': item['nome'],
            'cargo': item['cargo'],
            'custo_hora': item['custo_hora'],
            'categoria_sindical': item['categoria_sindical'] ?? '',
            'pais': item['pais'] ?? '',
            'ativo': ativo,
          },
        );
      } else if (tipo == 'maquina') {
        await ApiService.editarMaquina(
          item['id'] as int,
          {
            'nome': item['nome'],
            'tipo': item['tipo'] ?? '',
            'matricula': item['matricula'] ?? '',
            'custo_hora': item['custo_hora'],
            'combustivel_hora': item['combustivel_hora'] ?? 0,
            'ativo': ativo,
          },
        );
      } else {
        await ApiService.editarViatura(
          item['id'] as int,
          {
            'modelo': item['modelo'],
            'matricula': item['matricula'] ?? '',
            'custo_km': item['custo_km'],
            'consumo_l100km': item['consumo_l100km'] ?? 0,
            'motorista_id': item['motorista_id'],
            'ativo': ativo,
          },
        );
      }
      await _carregar();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipa'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Pessoas'), Tab(text: 'Máquinas'), Tab(text: 'Viaturas')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _abaPessoas(),
                _abaMaquinas(),
                _abaViaturas(),
              ],
            ),
      floatingActionButton: FloatingActionButton(onPressed: _adicionar, child: const Icon(Icons.add)),
    );
  }

  Widget _abaPessoas() => _abaAdmin(
        hint: 'Pesquisar pessoas por nome, cargo ou pais...',
        filtroEstado: _filtroEstadoPessoas,
        onFiltroChanged: (value) {
          _filtroEstadoPessoas = value;
          _filtrarPessoas();
        },
        onSearchChanged: (value) {
          _searchPessoas = value;
          _filtrarPessoas();
        },
        listaOriginal: _pessoas,
        listaFiltrada: _pessoasFiltradas,
        emptyMessage: 'Nenhuma pessoa encontrada.',
        child: _listaPessoas(_pessoasFiltradas),
      );

  Widget _abaMaquinas() => _abaAdmin(
        hint: 'Pesquisar maquinas por nome, tipo ou matricula...',
        filtroEstado: _filtroEstadoMaquinas,
        onFiltroChanged: (value) {
          _filtroEstadoMaquinas = value;
          _filtrarMaquinas();
        },
        onSearchChanged: (value) {
          _searchMaquinas = value;
          _filtrarMaquinas();
        },
        listaOriginal: _maquinas,
        listaFiltrada: _maquinasFiltradas,
        emptyMessage: 'Nenhuma máquina encontrada.',
        child: _listaRecursos(
          lista: _maquinasFiltradas,
          tipo: 'maquina',
          nomeFn: (item) => item['nome'] ?? '',
          subtituloFn: (item) => '${item['tipo'] ?? ''} · €${item['custo_hora'] ?? 0}/h',
        ),
      );

  Widget _abaViaturas() => _abaAdmin(
        hint: 'Pesquisar viaturas por modelo ou matricula...',
        filtroEstado: _filtroEstadoViaturas,
        onFiltroChanged: (value) {
          _filtroEstadoViaturas = value;
          _filtrarViaturas();
        },
        onSearchChanged: (value) {
          _searchViaturas = value;
          _filtrarViaturas();
        },
        listaOriginal: _viaturas,
        listaFiltrada: _viaturasFiltradas,
        emptyMessage: 'Nenhuma viatura encontrada.',
        child: _listaRecursos(
          lista: _viaturasFiltradas,
          tipo: 'viatura',
          nomeFn: (item) => item['modelo'] ?? '',
          subtituloFn: (item) => '${item['matricula'] ?? ''} · €${item['custo_km'] ?? 0}/km',
        ),
      );

  Widget _abaAdmin({
    required String hint,
    required String filtroEstado,
    required ValueChanged<String> onFiltroChanged,
    required ValueChanged<String> onSearchChanged,
    required List<dynamic> listaOriginal,
    required List<dynamic> listaFiltrada,
    required String emptyMessage,
    required Widget child,
  }) {
    if (listaOriginal.isEmpty) return const Center(child: Text('Sem registos.'));

    return Column(
      children: [
        SearchBarWidget(hintText: hint, onChanged: onSearchChanged),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _segmentedEstado(filtroEstado, onFiltroChanged),
        ),
        Expanded(
          child: listaFiltrada.isEmpty
              ? Center(child: Text(emptyMessage))
              : RefreshIndicator(onRefresh: _carregar, child: child),
        ),
      ],
    );
  }

  Widget _segmentedEstado(String value, ValueChanged<String> onChanged) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF20252B) : const Color(0xFFF1F4F8);
    final selected = isDark ? const Color(0xFF2C7A7B) : const Color(0xFF185FA5);

    Widget item(String key, String label, IconData icon) {
      final ativo = value == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: ativo ? selected : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
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
                Text(
                  label,
                  style: TextStyle(
                    color: ativo ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          item('ativas', 'Ativos', Icons.check_circle_outline),
          const SizedBox(width: 6),
          item('inativas', 'Inativos', Icons.pause_circle_outline),
        ],
      ),
    );
  }

  Widget _listaPessoas(List<dynamic> lista) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = lista[i];
        final nome = item['nome'] ?? '';
        final pais = (item['pais'] ?? '').toString().trim();
        final local = pais.isEmpty ? '' : ' · $pais';

        return _cardRecurso(
          item: item,
          tipo: 'pessoa',
          nome: nome,
          subtitulo: '${item['cargo'] ?? ''}$local · €${item['custo_hora'] ?? 0}/h',
        );
      },
    );
  }

  Widget _listaRecursos({
    required List<dynamic> lista,
    required String tipo,
    required String Function(dynamic) nomeFn,
    required String Function(dynamic) subtituloFn,
  }) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = lista[i];
        return _cardRecurso(
          item: item,
          tipo: tipo,
          nome: nomeFn(item),
          subtitulo: subtituloFn(item),
        );
      },
    );
  }

  Widget _cardRecurso({
    required dynamic item,
    required String tipo,
    required String nome,
    required String subtitulo,
  }) {
    final ativo = _ativo(item);
    final badgeColor = ativo ? const Color(0xFF12836D) : const Color(0xFF7B8794);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _editar(item),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE6F1FB),
          child: Text(
            nome.isNotEmpty ? nome[0].toUpperCase() : '?',
            style: const TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(nome, style: const TextStyle(fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                ativo ? 'Ativo' : 'Inativo',
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitulo),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'editar') _editar(item);
            if (value == 'estado') _alterarEstado(item, tipo, !ativo);
            if (value == 'apagar') _apagar(item);
          },
          itemBuilder: (_) {
            final items = <PopupMenuEntry<String>>[
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              PopupMenuItem(value: 'estado', child: Text(ativo ? 'Marcar inativo' : 'Marcar ativo')),
            ];
            return items;
          },
        ),
      ),
    );
  }
}

class _FormSheet extends StatefulWidget {
  final String tipo;
  final Map<String, dynamic>? item;
  final VoidCallback onSalvo;

  const _FormSheet({required this.tipo, this.item, required this.onSalvo});

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _nomeCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();

  bool _ativo = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      if (widget.tipo == 'pessoa') {
        _nomeCtrl.text = item['nome']?.toString() ?? '';
        _cargoCtrl.text = item['cargo']?.toString() ?? '';
        _custoCtrl.text = item['custo_hora']?.toString() ?? '';
        _paisCtrl.text = item['pais']?.toString() ?? '';
      } else if (widget.tipo == 'maquina') {
        _nomeCtrl.text = item['nome']?.toString() ?? '';
        _cargoCtrl.text = item['tipo']?.toString() ?? '';
        _custoCtrl.text = item['custo_hora']?.toString() ?? '';
        _extraCtrl.text = item['combustivel_hora']?.toString() ?? '';
      } else {
        _nomeCtrl.text = item['modelo']?.toString() ?? '';
        _cargoCtrl.text = item['matricula']?.toString() ?? '';
        _custoCtrl.text = item['custo_km']?.toString() ?? '';
      }
      _ativo = item['ativo'] == null || item['ativo'] == true || item['ativo'] == 1;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cargoCtrl.dispose();
    _custoCtrl.dispose();
    _extraCtrl.dispose();
    _paisCtrl.dispose();
    super.dispose();
  }

  double? _parseNonNegative(TextEditingController ctrl) {
    final value = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return value;
  }

  String? _validar() {
    final nomeLabel = widget.tipo == 'viatura' ? 'Modelo' : 'Nome';
    if (_nomeCtrl.text.trim().isEmpty) return '$nomeLabel obrigatório';

    final custo = _parseNonNegative(_custoCtrl);
    if (custo == null) {
      return widget.tipo == 'viatura' ? 'Custo por km inválido' : 'Custo por hora inválido';
    }

    if (widget.tipo == 'maquina') {
      final extra = _parseNonNegative(_extraCtrl);
      if (extra == null) return 'Combustível por hora inválido';
    }

    return null;
  }

  Future<void> _guardar() async {
    final erro = _validar();
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
      return;
    }

    setState(() => _saving = true);

    final nome = _nomeCtrl.text.trim();
    final cargo = _cargoCtrl.text.trim();
    final custo = _parseNonNegative(_custoCtrl)!;

    try {
      if (widget.tipo == 'pessoa') {
        final body = {
          'nome': nome,
          'cargo': cargo,
          'custo_hora': custo,
          'categoria_sindical': widget.item?['categoria_sindical'] ?? '',
          'pais': _paisCtrl.text.trim(),
          'ativo': _ativo,
        };
        if (widget.item == null) {
          await ApiService.post('/equipa/pessoas', body);
        } else {
          await ApiService.editarPessoa(widget.item!['id'] as int, body);
        }
      } else if (widget.tipo == 'maquina') {
        final body = {
          'nome': nome,
          'tipo': cargo,
          'custo_hora': custo,
          'combustivel_hora': _parseNonNegative(_extraCtrl)!,
          'matricula': widget.item?['matricula'] ?? '',
          'ativo': _ativo,
        };
        if (widget.item == null) {
          await ApiService.post('/equipa/maquinas', body);
        } else {
          await ApiService.editarMaquina(widget.item!['id'] as int, body);
        }
      } else {
        final body = {
          'modelo': nome,
          'matricula': cargo,
          'custo_km': custo,
          'consumo_l100km': widget.item?['consumo_l100km'] ?? 0,
          'motorista_id': widget.item?['motorista_id'],
          'ativo': _ativo,
        };
        if (widget.item == null) {
          await ApiService.post('/equipa/viaturas', body);
        } else {
          await ApiService.editarViatura(widget.item!['id'] as int, body);
        }
      }

      widget.onSalvo();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPessoa = widget.tipo == 'pessoa';
    final isMaquina = widget.tipo == 'maquina';
    final numericFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final estadoLabel = isPessoa ? 'Pessoa ativa' : isMaquina ? 'Máquina ativa' : 'Viatura ativa';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.item == null ? 'Adicionar' : 'Editar'} ${widget.tipo}'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nomeCtrl,
                decoration: InputDecoration(
                  labelText: isPessoa ? 'Nome' : isMaquina ? 'Nome' : 'Modelo',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cargoCtrl,
                decoration: InputDecoration(
                  labelText: isPessoa ? 'Cargo' : isMaquina ? 'Tipo' : 'Matricula',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (isPessoa) ...[
                TextField(
                  controller: _paisCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pais (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _custoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: numericFormatters,
                decoration: InputDecoration(
                  labelText: isPessoa || isMaquina ? 'Custo por hora' : 'Custo por km',
                  border: const OutlineInputBorder(),
                  prefixText: '€ ',
                ),
              ),
              if (isMaquina) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _extraCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numericFormatters,
                  decoration: const InputDecoration(
                    labelText: 'Combustível por hora',
                    border: OutlineInputBorder(),
                    prefixText: '€ ',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _ativo,
                contentPadding: EdgeInsets.zero,
                title: Text(estadoLabel),
                subtitle: const Text('Os registos inativos ficam separados e deixam de aparecer nas listas operacionais.'),
                onChanged: (value) => setState(() => _ativo = value),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _guardar,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ),
    );
  }
}
