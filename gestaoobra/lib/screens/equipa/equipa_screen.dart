import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/search_bar_widget.dart';

class EquipaScreen extends StatefulWidget {
  const EquipaScreen({super.key});

  @override
  State<EquipaScreen> createState() => _EquipaScreenState();
}

class _EquipaScreenState extends State<EquipaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _pessoas  = [];
  List<dynamic> _maquinas = [];
  List<dynamic> _viaturas = [];
  
  List<dynamic> _pessoasFiltradas = [];
  List<dynamic> _maquinasFiltradas = [];
  List<dynamic> _viaturasFiltradas = [];
  
  String _searchPessoas = '';
  String _searchMaquinas = '';
  String _searchViaturas = '';
  
  bool _loading = true;

  void _filtrarPessoas() {
    setState(() {
      _pessoasFiltradas = _pessoas.where((p) {
        final nome = (p['nome'] ?? '').toString().toLowerCase();
        final cargo = (p['cargo'] ?? '').toString().toLowerCase();
        final search = _searchPessoas.toLowerCase();
        return nome.contains(search) || cargo.contains(search);
      }).toList();
    });
  }

  void _filtrarMaquinas() {
    setState(() {
      _maquinasFiltradas = _maquinas.where((m) {
        final nome = (m['nome'] ?? '').toString().toLowerCase();
        final tipo = (m['tipo'] ?? '').toString().toLowerCase();
        final search = _searchMaquinas.toLowerCase();
        return nome.contains(search) || tipo.contains(search);
      }).toList();
    });
  }

  void _filtrarViaturas() {
    setState(() {
      _viaturasFiltradas = _viaturas.where((v) {
        final modelo = (v['modelo'] ?? '').toString().toLowerCase();
        final matricula = (v['matricula'] ?? '').toString().toLowerCase();
        final search = _searchViaturas.toLowerCase();
        return modelo.contains(search) || matricula.contains(search);
      }).toList();
    });
  }

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

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.listarPessoas(),
        ApiService.listarMaquinas(),
        ApiService.listarViaturas(),
      ]);
      setState(() {
        _pessoas  = results[0];
        _maquinas = results[1];
        _viaturas = results[2];
        _loading  = false;
        _filtrarPessoas();
        _filtrarMaquinas();
        _filtrarViaturas();
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  void _adicionar() {
    final tab = _tabs.index;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
      builder: (_) => _FormSheet(
        tipo: tab == 0 ? 'pessoa' : tab == 1 ? 'maquina' : 'viatura',
        item: item,
        onSalvo: _carregar,
      ),
    );
  }

  Future<void> _apagar(dynamic item) async {
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
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
          tabs: const [
            Tab(text: 'Pessoas'),
            Tab(text: 'Máquinas'),
            Tab(text: 'Viaturas'),
          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionar,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _abaPessoas() {
    if (_pessoas.isEmpty) return const Center(child: Text('Sem registos.'));
    return Column(
      children: [
        SearchBarWidget(
          hintText: 'Pesquisar pessoas...',
          onChanged: (value) {
            _searchPessoas = value;
            _filtrarPessoas();
          },
        ),
        Expanded(
          child: _pessoasFiltradas.isEmpty
              ? const Center(child: Text('Nenhuma pessoa encontrada.'))
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: _listaRecursos(_pessoasFiltradas, (p) => '${p['cargo'] ?? ''} · €${p['custo_hora'] ?? 0}/h'),
                ),
        ),
      ],
    );
  }

  Widget _abaMaquinas() {
    if (_maquinas.isEmpty) return const Center(child: Text('Sem registos.'));
    return Column(
      children: [
        SearchBarWidget(
          hintText: 'Pesquisar máquinas...',
          onChanged: (value) {
            _searchMaquinas = value;
            _filtrarMaquinas();
          },
        ),
        Expanded(
          child: _maquinasFiltradas.isEmpty
              ? const Center(child: Text('Nenhuma máquina encontrada.'))
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: _listaRecursos(_maquinasFiltradas, (m) => '${m['tipo'] ?? ''}  · €${m['custo_hora'] ?? 0}/h'),
                ),
        ),
      ],
    );
  }

  Widget _abaViaturas() {
    if (_viaturas.isEmpty) return const Center(child: Text('Sem registos.'));
    return Column(
      children: [
        SearchBarWidget(
          hintText: 'Pesquisar viaturas...',
          onChanged: (value) {
            _searchViaturas = value;
            _filtrarViaturas();
          },
        ),
        Expanded(
          child: _viaturasFiltradas.isEmpty
              ? const Center(child: Text('Nenhuma viatura encontrada.'))
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: _listaRecursos(_viaturasFiltradas, (v) => '${v['matricula'] ?? ''} · €${v['custo_km'] ?? 0}/km'),
                ),
        ),
      ],
    );
  }

  Widget _listaRecursos(List<dynamic> lista, String Function(dynamic) subtitulo) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = lista[i];
        final nome = item['nome'] ?? item['modelo'] ?? '';
        return Card(
          child: ListTile(
            onTap: () => _editar(item),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE6F1FB),
              child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                  style: const TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.bold)),
            ),
            title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitulo(item)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editar(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                  onPressed: () => _apagar(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Bottom sheet para adicionar pessoa/máquina/viatura ───────────────────────
class _FormSheet extends StatefulWidget {
  final String tipo;
  final Map<String, dynamic>? item;
  final VoidCallback onSalvo;
  const _FormSheet({required this.tipo, this.item, required this.onSalvo});

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _nomeCtrl       = TextEditingController();
  final _cargoCtrl      = TextEditingController();
  final _matriculaCtrl  = TextEditingController();
  final _custoCtrl      = TextEditingController();
  final _extraCtrl      = TextEditingController();
  final _categoriaCtrl  = TextEditingController();
  final _nifCtrl        = TextEditingController();
  bool _saving          = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      if (widget.tipo == 'pessoa') {
        _nomeCtrl.text      = item['nome']?.toString() ?? '';
        _cargoCtrl.text     = item['cargo']?.toString() ?? '';
        _custoCtrl.text     = item['custo_hora']?.toString() ?? '';
        _categoriaCtrl.text = item['categoria_sindical']?.toString() ?? '';
        _nifCtrl.text       = item['nif']?.toString() ?? '';
      } else if (widget.tipo == 'maquina') {
        _nomeCtrl.text      = item['nome']?.toString() ?? '';
        _cargoCtrl.text     = item['tipo']?.toString() ?? '';
        _matriculaCtrl.text = item['matricula']?.toString() ?? '';
        _custoCtrl.text     = item['custo_hora']?.toString() ?? '';
        _extraCtrl.text     = item['combustivel_hora']?.toString() ?? '';
      } else {
        _nomeCtrl.text      = item['modelo']?.toString() ?? '';
        _cargoCtrl.text     = item['matricula']?.toString() ?? '';
        _custoCtrl.text     = item['custo_km']?.toString() ?? '';
        _extraCtrl.text     = item['consumo_l100km']?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cargoCtrl.dispose();
    _matriculaCtrl.dispose();
    _custoCtrl.dispose();
    _extraCtrl.dispose();
    _categoriaCtrl.dispose();
    _nifCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nomeCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final nome = _nomeCtrl.text.trim();
    final cargo = _cargoCtrl.text.trim();
    final custo = double.tryParse(_custoCtrl.text) ?? 0;

    try {
      if (widget.tipo == 'pessoa') {
        final body = {
          'nome': nome,
          'cargo': cargo,
          'custo_hora': custo,
          'categoria_sindical': _categoriaCtrl.text.trim(),
          'nif': _nifCtrl.text.trim(),
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
          'matricula': _matriculaCtrl.text.trim(),
          'custo_hora': custo,
          'combustivel_hora': double.tryParse(_extraCtrl.text) ?? 0,
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
          'consumo_l100km': double.tryParse(_extraCtrl.text) ?? 0,
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPessoa  = widget.tipo == 'pessoa';
    final isMaquina = widget.tipo == 'maquina';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16, right: 16, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.item == null ? 'Adicionar' : 'Editar'} ${widget.tipo}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nomeCtrl,
            decoration: InputDecoration(
              labelText: isPessoa ? 'Nome' : isMaquina ? 'Nome' : 'Modelo',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cargoCtrl,
            decoration: InputDecoration(
              labelText: isPessoa ? 'Cargo' : isMaquina ? 'Tipo' : 'Matrícula',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (isMaquina) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _matriculaCtrl,
              decoration: const InputDecoration(
                labelText: 'Matrícula',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _custoCtrl,
            decoration: InputDecoration(
              labelText: isPessoa ? 'Custo por hora' : isMaquina ? 'Custo por hora' : 'Custo por km',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          if (isMaquina || widget.tipo == 'viatura') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _extraCtrl,
              decoration: InputDecoration(
                labelText: isMaquina ? 'Combustível por hora' : 'Consumo L/100km',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          if (widget.tipo == 'pessoa') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _categoriaCtrl,
              decoration: const InputDecoration(
                labelText: 'Categoria sindical',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nifCtrl,
              decoration: const InputDecoration(
                labelText: 'NIF',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saving ? null : _guardar,
                child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
