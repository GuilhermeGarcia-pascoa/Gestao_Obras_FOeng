import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

class SemanaDetailScreen extends StatefulWidget {
  final Map<String, dynamic> semana;
  final int obraId;
  const SemanaDetailScreen({super.key, required this.semana, required this.obraId});

  @override
  State<SemanaDetailScreen> createState() => _SemanaDetailScreenState();
}

class _SemanaDetailScreenState extends State<SemanaDetailScreen> {
  // Listas com dados actuais
  List<Map<String, dynamic>> _pessoas   = [];
  List<Map<String, dynamic>> _maquinas  = [];
  List<Map<String, dynamic>> _viaturas  = [];

  // Todas as pessoas/máquinas/viaturas disponíveis
  List<dynamic> _todasPessoas  = [];
  List<dynamic> _todasMaquinas = [];
  List<dynamic> _todasViaturas = [];

  // Horas editáveis por pessoa (pessoa_id -> horas)
  final Map<int, TextEditingController> _horasCtrl = {};

  // Gastos gerais da semana
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
    for (final c in _horasCtrl.values) {
      c.dispose();
    }
    _toCtrl.dispose();
    _combustivelCtrl.dispose();
    _estadiasCtrl.dispose();
    _materiaisCtrl.dispose();
    _faturadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final semanaId = widget.semana['id'];
      final results = await Future.wait([
        ApiService.getSemanaSemana(semanaId),
        ApiService.listarPessoas(),
        ApiService.listarMaquinas(),
        ApiService.listarViaturas(),
      ]);

      final detalhe      = results[0] as Map<String, dynamic>;
      _todasPessoas  = results[1] as List<dynamic>;
      _todasMaquinas = results[2] as List<dynamic>;
      _todasViaturas = results[3] as List<dynamic>;

      _pessoas  = List<Map<String, dynamic>>.from(detalhe['horasPessoas']  ?? []);
      _maquinas = List<Map<String, dynamic>>.from(detalhe['horasMaquinas'] ?? []);
      _viaturas = List<Map<String, dynamic>>.from(detalhe['horasViaturas'] ?? []);

      // Cria controllers de horas para cada pessoa já na semana
      for (final p in _pessoas) {
        final id = p['pessoa_id'] as int;
        _horasCtrl[id] = TextEditingController(text: p['horas_total']?.toString() ?? '0');
      }

      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  // Copia dados da semana anterior
  Future<void> _copiarAnterior() async {
    try {
      final ant = await ApiService.getSemanaAnterior(widget.semana['id']);
      final pessoasAnt = List<Map<String, dynamic>>.from(ant['horasPessoas'] ?? []);

      setState(() {
        _pessoas = pessoasAnt;
        for (final p in _pessoas) {
          final id = p['pessoa_id'] as int;
          _horasCtrl[id] = TextEditingController(text: p['horas_total']?.toString() ?? '0');
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados copiados da semana anterior')));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  // Adiciona pessoa à semana
  void _adicionarPessoa() async {
    final jaIds = _pessoas.map((p) => p['pessoa_id']).toSet();
    final disponiveis = _todasPessoas.where((p) => !jaIds.contains(p['id'])).toList();

    if (disponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todas as pessoas já estão adicionadas')));
      return;
    }

    final escolhida = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Adicionar pessoa'),
        children: disponiveis.map((p) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, p),
          child: Text(p['nome'] ?? ''),
        )).toList(),
      ),
    );

    if (escolhida == null) return;
    setState(() {
      final id = escolhida['id'] as int;
      _pessoas.add({'pessoa_id': id, 'nome': escolhida['nome'], 'horas_total': 8, 'custo_total': 0});
      _horasCtrl[id] = TextEditingController(text: '8');
    });
  }

  double get _totalGastos {
    final to          = double.tryParse(_toCtrl.text)          ?? 0;
    final combustivel = double.tryParse(_combustivelCtrl.text) ?? 0;
    final estadias    = double.tryParse(_estadiasCtrl.text)    ?? 0;
    final materiais   = double.tryParse(_materiaisCtrl.text)   ?? 0;
    return to + combustivel + estadias + materiais;
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);

    // Constrói payload de horas de pessoas
    final horasPessoas = _pessoas.map((p) {
      final id    = p['pessoa_id'] as int;
      final horas = double.tryParse(_horasCtrl[id]?.text ?? '0') ?? 0;
      // Custo = horas × custo_hora (simplificado; o backend pode recalcular)
      final custoHora = (_todasPessoas.firstWhere(
            (tp) => tp['id'] == id, orElse: () => {'custo_hora': 0})['custo_hora'] as num).toDouble();
      return {'pessoa_id': id, 'horas_total': horas, 'custo_total': horas * custoHora};
    }).toList();

    try {
      await ApiService.guardarSemana(widget.semana['id'], {
        'estado':    'aberta',
        'faturado':  double.tryParse(_faturadoCtrl.text) ?? 0,
        'horasPessoas': horasPessoas,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semana guardada!'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensagem), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semana = widget.semana;
    return Scaffold(
      appBar: AppBar(
        title: Text('Semana ${semana['numero_semana']}'),
        actions: [
          TextButton.icon(
            onPressed: _copiarAnterior,
            icon: const Icon(Icons.copy, color: Colors.white, size: 18),
            label: const Text('Copiar ant.', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Equipa ──────────────────────────────────────────────────
                _sectionHeader('Equipa — horas trabalhadas', trailing:
                  TextButton.icon(
                    onPressed: _adicionarPessoa,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Adicionar'),
                  ),
                ),
                if (_pessoas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Sem pessoas. Carrega em "Adicionar".', style: TextStyle(color: Colors.grey)),
                  ),
                ..._pessoas.map((p) {
                  final id   = p['pessoa_id'] as int;
                  final nome = _todasPessoas.firstWhere(
                      (tp) => tp['id'] == id, orElse: () => {'nome': 'Desconhecido'})['nome'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE6F1FB),
                          child: Text(
                            (nome as String).substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF185FA5), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(nome, style: const TextStyle(fontSize: 14))),
                        SizedBox(
                          width: 64,
                          child: TextField(
                            controller: _horasCtrl[id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              suffixText: 'h',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: () => setState(() {
                            _pessoas.removeWhere((x) => x['pessoa_id'] == id);
                            _horasCtrl.remove(id)?.dispose();
                          }),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 20),
                const Divider(),

                // ── Gastos ──────────────────────────────────────────────────
                _sectionHeader('Gastos da semana'),
                const SizedBox(height: 8),
                _gastoField('T.O. (€)', _toCtrl),
                _gastoField('Combustível (€)', _combustivelCtrl),
                _gastoField('Estadias (€)', _estadiasCtrl),
                _gastoField('Materiais / outros (€)', _materiaisCtrl),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFE8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total gastos', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_eur.format(_totalGastos), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),

                // ── Faturação ───────────────────────────────────────────────
                _sectionHeader('Faturação'),
                const SizedBox(height: 8),
                _gastoField('Valor faturado ao cliente (€)', _faturadoCtrl),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _guardar,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar semana'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget _gastoField(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: '€ '),
      onChanged: (_) => setState(() {}),
    ),
  );
}
