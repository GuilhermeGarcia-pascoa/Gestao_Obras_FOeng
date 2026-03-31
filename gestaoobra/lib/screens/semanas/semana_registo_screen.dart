import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

/// Ecrã de registo semanal — abre directamente com semanaId
/// (wrapper simples sobre SemanaDetailScreen que carrega os dados)
class SemanaRegistoScreen extends StatefulWidget {
  final int semanaId;
  final int obraId;
  final int numSemana;

  const SemanaRegistoScreen({
    super.key,
    required this.semanaId,
    required this.obraId,
    required this.numSemana,
  });

  @override
  State<SemanaRegistoScreen> createState() => _SemanaRegistoScreenState();
}

class _SemanaRegistoScreenState extends State<SemanaRegistoScreen> {
  // ── Estado ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _pessoas   = [];
  List<Map<String, dynamic>> _maquinas  = [];
  List<dynamic> _todasPessoas           = [];
  List<dynamic> _todasMaquinas          = [];

  final Map<int, TextEditingController> _horasP = {};   // pessoa_id → horas
  final Map<int, TextEditingController> _horasM = {};   // maquina_id → horas

  final _toCtrl          = TextEditingController();
  final _combustivelCtrl = TextEditingController();
  final _estadiasCtrl    = TextEditingController();
  final _materiaisCtrl   = TextEditingController();
  final _faturadoCtrl    = TextEditingController();

  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    for (final c in _horasP.values) c.dispose();
    for (final c in _horasM.values) c.dispose();
    _toCtrl.dispose(); _combustivelCtrl.dispose();
    _estadiasCtrl.dispose(); _materiaisCtrl.dispose();
    _faturadoCtrl.dispose();
    super.dispose();
  }

  // ── Carregamento inicial ──────────────────────────────────────────────────
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getSemanaSemana(widget.semanaId),
        ApiService.listarPessoas(),
        ApiService.listarMaquinas(),
      ]);

      final detalhe     = results[0] as Map<String, dynamic>;
      _todasPessoas     = results[1] as List<dynamic>;
      _todasMaquinas    = results[2] as List<dynamic>;

      _pessoas  = List<Map<String, dynamic>>.from(detalhe['horasPessoas']  ?? []);
      _maquinas = List<Map<String, dynamic>>.from(detalhe['horasMaquinas'] ?? []);

      for (final p in _pessoas) {
        final id = p['pessoa_id'] as int;
        _horasP[id] = TextEditingController(text: p['horas_total']?.toString() ?? '8');
      }
      for (final m in _maquinas) {
        final id = m['maquina_id'] as int;
        _horasM[id] = TextEditingController(text: m['horas_total']?.toString() ?? '0');
      }

      // Gastos guardados
      final semana = detalhe['semana'] as Map<String, dynamic>;
      _faturadoCtrl.text = semana['faturado']?.toString() ?? '';

      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  // ── Copiar semana anterior ────────────────────────────────────────────────
  Future<void> _copiarAnterior() async {
    try {
      final ant = await ApiService.getSemanaAnterior(widget.semanaId);
      final pessoasAnt  = List<Map<String, dynamic>>.from(ant['horasPessoas']  ?? []);
      final maquinasAnt = List<Map<String, dynamic>>.from(ant['horasMaquinas'] ?? []);

      for (final c in _horasP.values) c.dispose();
      for (final c in _horasM.values) c.dispose();
      _horasP.clear(); _horasM.clear();

      setState(() {
        _pessoas  = pessoasAnt;
        _maquinas = maquinasAnt;
        for (final p in _pessoas) {
          final id = p['pessoa_id'] as int;
          _horasP[id] = TextEditingController(text: p['horas_total']?.toString() ?? '8');
        }
        for (final m in _maquinas) {
          final id = m['maquina_id'] as int;
          _horasM[id] = TextEditingController(text: m['horas_total']?.toString() ?? '0');
        }
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Dados da semana anterior copiados'), backgroundColor: Colors.green));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  // ── Adicionar pessoa ──────────────────────────────────────────────────────
  Future<void> _adicionarPessoa() async {
    final jaIds = _pessoas.map((p) => p['pessoa_id']).toSet();
    final disp  = _todasPessoas.where((p) => !jaIds.contains(p['id'])).toList();
    if (disp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todas as pessoas já foram adicionadas')));
      return;
    }
    final escolhida = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Selecionar pessoa'),
        children: disp.map((p) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, p as Map<String, dynamic>),
          child: ListTile(
            leading: CircleAvatar(child: Text((p['nome'] as String)[0])),
            title: Text(p['nome']),
            subtitle: Text(p['cargo'] ?? ''),
          ),
        )).toList(),
      ),
    );
    if (escolhida == null) return;
    final id = escolhida['id'] as int;
    setState(() {
      _pessoas.add({'pessoa_id': id, 'horas_total': 8, 'custo_total': 0});
      _horasP[id] = TextEditingController(text: '8');
    });
  }

  // ── Adicionar máquina ─────────────────────────────────────────────────────
  Future<void> _adicionarMaquina() async {
    final jaIds = _maquinas.map((m) => m['maquina_id']).toSet();
    final disp  = _todasMaquinas.where((m) => !jaIds.contains(m['id'])).toList();
    if (disp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todas as máquinas já foram adicionadas')));
      return;
    }
    final escolhida = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Selecionar máquina'),
        children: disp.map((m) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, m as Map<String, dynamic>),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.construction)),
            title: Text(m['nome']),
            subtitle: Text(m['tipo'] ?? ''),
          ),
        )).toList(),
      ),
    );
    if (escolhida == null) return;
    final id = escolhida['id'] as int;
    setState(() {
      _maquinas.add({'maquina_id': id, 'horas_total': 0, 'combustivel_total': 0});
      _horasM[id] = TextEditingController(text: '0');
    });
  }

  // ── Total gastos ──────────────────────────────────────────────────────────
  double get _totalGastos =>
    (double.tryParse(_toCtrl.text)          ?? 0) +
    (double.tryParse(_combustivelCtrl.text) ?? 0) +
    (double.tryParse(_estadiasCtrl.text)    ?? 0) +
    (double.tryParse(_materiaisCtrl.text)   ?? 0);

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    setState(() => _saving = true);

    final horasPessoas = _pessoas.map((p) {
      final id       = p['pessoa_id'] as int;
      final horas    = double.tryParse(_horasP[id]?.text ?? '0') ?? 0;
      final custoH   = (_todasPessoas.firstWhere(
            (tp) => tp['id'] == id, orElse: () => {'custo_hora': 0})['custo_hora'] as num).toDouble();
      return {'pessoa_id': id, 'horas_total': horas, 'custo_total': horas * custoH};
    }).toList();

    final horasMaquinas = _maquinas.map((m) {
      final id    = m['maquina_id'] as int;
      final horas = double.tryParse(_horasM[id]?.text ?? '0') ?? 0;
      final combH = (_todasMaquinas.firstWhere(
            (tm) => tm['id'] == id, orElse: () => {'combustivel_hora': 0})['combustivel_hora'] as num).toDouble();
      return {'maquina_id': id, 'horas_total': horas, 'combustivel_total': horas * combH};
    }).toList();

    try {
      await ApiService.guardarSemana(widget.semanaId, {
        'estado':        'aberta',
        'faturado':      double.tryParse(_faturadoCtrl.text) ?? 0,
        'horasPessoas':  horasPessoas,
        'horasMaquinas': horasMaquinas,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semana guardada!'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensagem), backgroundColor: Colors.red));
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Semana ${widget.numSemana}'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _copiarAnterior,
            icon: const Icon(Icons.copy_all, color: Colors.white, size: 18),
            label: const Text('Copiar anterior', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Pessoas ──────────────────────────────────────────────────
                _cabecalho('Equipa — horas do dia', trailing: TextButton.icon(
                  onPressed: _adicionarPessoa,
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Adicionar'),
                )),
                if (_pessoas.isEmpty)
                  _vazioMsg('Sem pessoas. Carrega em "Adicionar".'),
                ..._pessoas.map((p) => _linhaHoras(
                  id: p['pessoa_id'] as int,
                  lista: _todasPessoas,
                  ctrl: _horasP,
                  onRemover: () => setState(() {
                    _pessoas.removeWhere((x) => x['pessoa_id'] == p['pessoa_id']);
                    _horasP.remove(p['pessoa_id'])?.dispose();
                  }),
                  iconeBg: const Color(0xFFE6F1FB),
                  iconeColor: const Color(0xFF185FA5),
                )),

                const SizedBox(height: 16),
                const Divider(),

                // ── Máquinas ─────────────────────────────────────────────────
                _cabecalho('Máquinas — horas', trailing: TextButton.icon(
                  onPressed: _adicionarMaquina,
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Adicionar'),
                )),
                if (_maquinas.isEmpty)
                  _vazioMsg('Sem máquinas registadas para esta semana.'),
                ..._maquinas.map((m) => _linhaHoras(
                  id: m['maquina_id'] as int,
                  lista: _todasMaquinas,
                  ctrl: _horasM,
                  onRemover: () => setState(() {
                    _maquinas.removeWhere((x) => x['maquina_id'] == m['maquina_id']);
                    _horasM.remove(m['maquina_id'])?.dispose();
                  }),
                  iconeBg: const Color(0xFFF1EFE8),
                  iconeColor: const Color(0xFF5F5E5A),
                )),

                const SizedBox(height: 16),
                const Divider(),

                // ── Gastos ───────────────────────────────────────────────────
                _cabecalho('Gastos da semana'),
                const SizedBox(height: 8),
                _campo('T.O. (€)',               _toCtrl),
                _campo('Combustível (€)',         _combustivelCtrl),
                _campo('Estadias (€)',            _estadiasCtrl),
                _campo('Materiais / outros (€)',  _materiaisCtrl),
                const SizedBox(height: 4),
                _totalBox('Total gastos', _totalGastos),

                const SizedBox(height: 16),
                const Divider(),

                // ── Faturação ────────────────────────────────────────────────
                _cabecalho('Faturação ao cliente'),
                const SizedBox(height: 8),
                _campo('Valor faturado (€)', _faturadoCtrl),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _guardar,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar semana'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _cabecalho(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget _vazioMsg(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 13)),
  );

  Widget _linhaHoras({
    required int id,
    required List<dynamic> lista,
    required Map<int, TextEditingController> ctrl,
    required VoidCallback onRemover,
    required Color iconeBg,
    required Color iconeColor,
  }) {
    final item = lista.firstWhere((x) => x['id'] == id, orElse: () => {'nome': 'Desconhecido'});
    final nome = (item['nome'] ?? item['modelo'] ?? '') as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: iconeBg,
            child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 13, color: iconeColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(nome, style: const TextStyle(fontSize: 14))),
          SizedBox(
            width: 66,
            child: TextField(
              controller: ctrl[id],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                suffixText: 'h',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: onRemover,
          ),
        ],
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: '€ '),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _totalBox(String label, double valor) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF1EFE8),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(_eur.format(valor), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    ),
  );
}
