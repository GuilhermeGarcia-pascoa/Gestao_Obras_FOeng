import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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
                _listaRecursos(_pessoas,  (p) => '${p['cargo'] ?? ''} · €${p['custo_hora'] ?? 0}/h'),
                _listaRecursos(_maquinas, (m) => '${m['tipo'] ?? ''}  · €${m['custo_hora'] ?? 0}/h'),
                _listaRecursos(_viaturas, (v) => '${v['matricula'] ?? ''} · €${v['custo_km'] ?? 0}/km'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionar,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _listaRecursos(List<dynamic> lista, String Function(dynamic) subtitulo) {
    if (lista.isEmpty) return const Center(child: Text('Sem registos.'));
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
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
      ),
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
  final _nomeCtrl     = TextEditingController();
  final _cargoCtrl    = TextEditingController();
  final _custoCtrl    = TextEditingController();
  final _extraCtrl    = TextEditingController();
  bool _saving        = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      if (widget.tipo == 'pessoa') {
        _nomeCtrl.text  = item['nome']?.toString() ?? '';
        _cargoCtrl.text = item['cargo']?.toString() ?? '';
        _custoCtrl.text = item['custo_hora']?.toString() ?? '';
      } else if (widget.tipo == 'maquina') {
        _nomeCtrl.text  = item['nome']?.toString() ?? '';
        _cargoCtrl.text = item['tipo']?.toString() ?? '';
        _custoCtrl.text = item['custo_hora']?.toString() ?? '';
        _extraCtrl.text = item['combustivel_hora']?.toString() ?? '';
      } else {
        _nomeCtrl.text  = item['modelo']?.toString() ?? '';
        _cargoCtrl.text = item['matricula']?.toString() ?? '';
        _custoCtrl.text = item['custo_km']?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cargoCtrl.dispose();
    _custoCtrl.dispose();
    _extraCtrl.dispose();
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
          'categoria_sindical': widget.item?['categoria_sindical'],
          'nif': widget.item?['nif'],
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
          'consumo_l100km': widget.item?['consumo_l100km'],
          'motorista_id': widget.item?['motorista_id'],
        };
        if (widget.item == null) {
          await ApiService.post('/equipa/viaturas', {
            'modelo': nome,
            'matricula': cargo,
            'custo_km': custo,
          });
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item == null
                ? isPessoa
                    ? 'Nova pessoa'
                    : isMaquina
                        ? 'Nova máquina'
                        : 'Nova viatura'
                : isPessoa
                    ? 'Editar pessoa'
                    : isMaquina
                        ? 'Editar máquina'
                        : 'Editar viatura',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nomeCtrl,  decoration: InputDecoration(labelText: isPessoa ? 'Nome' : isMaquina ? 'Nome da máquina' : 'Modelo')),
          const SizedBox(height: 10),
          TextField(controller: _cargoCtrl, decoration: InputDecoration(labelText: isPessoa ? 'Cargo' : isMaquina ? 'Tipo' : 'Matrícula')),
          const SizedBox(height: 10),
          TextField(controller: _custoCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: isPessoa || isMaquina ? 'Custo/hora (€)' : 'Custo/km (€)', prefixText: '€ ')),
          if (isMaquina) ...[
            const SizedBox(height: 10),
            TextField(controller: _extraCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Combustível/hora (L)', prefixText: 'L ')),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _guardar,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
