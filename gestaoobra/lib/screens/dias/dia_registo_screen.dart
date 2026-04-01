import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

/// Ecrã de registo diário — abre um dia específico do calendário
class DiaRegistoScreen extends StatefulWidget {
  final int obraId;
  final String data;        // 'YYYY-MM-DD'
  final String obraCodigo;

  const DiaRegistoScreen({
    super.key,
    required this.obraId,
    required this.data,
    required this.obraCodigo,
  });

  @override
  State<DiaRegistoScreen> createState() => _DiaRegistoScreenState();
}

class _DiaRegistoScreenState extends State<DiaRegistoScreen> {
  int? _diaId;

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
  bool _temAlteracoes = false;

  // Guardar valores originais para comparação
  late String _faturadoOriginal;
  late String _toOriginal;
  late String _combustivelOriginal;
  late String _estadiasOriginal;
  late String _materiaisOriginal;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    for (final c in _horasP.values) {
      c.dispose();
    }
    for (final c in _horasM.values) {
      c.dispose();
    }
    _toCtrl.dispose();
    _combustivelCtrl.dispose();
    _estadiasCtrl.dispose();
    _materiaisCtrl.dispose();
    _faturadoCtrl.dispose();
    super.dispose();
  }

  // ── Formatação de datas ───────────────────────────────────────────────────
  String get _tituloDia {
    final d = DateTime.parse(widget.data);
    return DateFormat("EEEE, d MMM", 'pt_PT').format(d);
  }

  // ── Carregamento inicial ──────────────────────────────────────────────────
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getDiaPorData(widget.obraId, widget.data),
        ApiService.listarPessoas(),
        ApiService.listarMaquinas(),
      ]);

      final detalhe     = results[0] as Map<String, dynamic>;
      _todasPessoas     = results[1] as List<dynamic>;
      _todasMaquinas    = results[2] as List<dynamic>;

      final dia = detalhe['dia'] as Map<String, dynamic>;
      _diaId = dia['id'] as int;

      // Limpar controllers antigos
      for (final c in _horasP.values) {
        c.dispose();
      }
      for (final c in _horasM.values) {
        c.dispose();
      }
      _horasP.clear();
      _horasM.clear();

      // Carregar dados salvos
      _pessoas  = List<Map<String, dynamic>>.from(detalhe['horasPessoas']  ?? []);
      _maquinas = List<Map<String, dynamic>>.from(detalhe['horasMaquinas'] ?? []);

      // Criar controllers com valores salvos
      for (final p in _pessoas) {
        final id = p['pessoa_id'] as int;
        _horasP[id] = TextEditingController(text: (p['horas_total'] ?? 0).toString());
      }
      for (final m in _maquinas) {
        final id = m['maquina_id'] as int;
        _horasM[id] = TextEditingController(text: (m['horas_total'] ?? 0).toString());
      }

      // Carregar gastos guardados (faturado + gastos específicos)
      _faturadoCtrl.text = (dia['faturado'] ?? 0).toString();
      _toCtrl.text = (dia['valor_to'] ?? 0).toString();
      _combustivelCtrl.text = (dia['valor_combustivel'] ?? 0).toString();
      _estadiasCtrl.text = (dia['valor_estadias'] ?? 0).toString();
      _materiaisCtrl.text = (dia['valor_materiais'] ?? 0).toString();

      // Guardar valores originais para rastreamento de alterações
      _faturadoOriginal = _faturadoCtrl.text;
      _toOriginal = _toCtrl.text;
      _combustivelOriginal = _combustivelCtrl.text;
      _estadiasOriginal = _estadiasCtrl.text;
      _materiaisOriginal = _materiaisCtrl.text;

      // Adicionar listeners para detectar mudanças
      _faturadoCtrl.addListener(_verificarAlteracoes);
      _toCtrl.addListener(_verificarAlteracoes);
      _combustivelCtrl.addListener(_verificarAlteracoes);
      _estadiasCtrl.addListener(_verificarAlteracoes);
      _materiaisCtrl.addListener(_verificarAlteracoes);

      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro: ${e.mensagem}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Copiar dia anterior ───────────────────────────────────────────────────
  Future<void> _copiarAnterior() async {
    if (_diaId == null) return;
    try {
      final ant = await ApiService.getDiaAnterior(_diaId!);
      final pessoasAnt  = List<Map<String, dynamic>>.from(ant['horasPessoas']  ?? []);
      final maquinasAnt = List<Map<String, dynamic>>.from(ant['horasMaquinas'] ?? []);
      final gastosAnt = ant['gastos'] as Map<String, dynamic>? ?? {};

      // Limpar controllers antigos
      for (final c in _horasP.values) {
        c.dispose();
      }
      for (final c in _horasM.values) {
        c.dispose();
      }
      _horasP.clear();
      _horasM.clear();

      // Copiar dados com valores
      setState(() {
        _pessoas  = pessoasAnt;
        _maquinas = maquinasAnt;
        
        // Criar controllers com valores copiados
        for (final p in _pessoas) {
          final id = p['pessoa_id'] as int;
          final horas = (p['horas_total'] ?? 0).toString();
          _horasP[id] = TextEditingController(text: horas);
        }
        for (final m in _maquinas) {
          final id = m['maquina_id'] as int;
          final horas = (m['horas_total'] ?? 0).toString();
          _horasM[id] = TextEditingController(text: horas);
        }
        
        // Copiar gastos
        _toCtrl.text = _parseValue(gastosAnt['valor_to']).toString();
        _combustivelCtrl.text = _parseValue(gastosAnt['valor_combustivel']).toString();
        _estadiasCtrl.text = _parseValue(gastosAnt['valor_estadias']).toString();
        _materiaisCtrl.text = _parseValue(gastosAnt['valor_materiais']).toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Equipa, máquinas e gastos do dia anterior copiados!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro: ${e.mensagem}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Adicionar pessoa ──────────────────────────────────────────────────────
  Future<void> _adicionarPessoa() async {
    final jaIds = _pessoas.map((p) => p['pessoa_id']).toSet();
    final disp  = _todasPessoas.where((p) => !jaIds.contains(p['id'])).toList();
    if (disp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Todas as pessoas já foram adicionadas'), backgroundColor: Colors.orange),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Todas as máquinas já foram adicionadas'), backgroundColor: Colors.orange),
      );
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

  // ── Função auxiliar para converter valores de forma segura ────────────────
  double _parseValue(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.replaceAll(',', '.').trim()) ?? 0.0;
    }
    if (val is num) return val.toDouble();
    return 0.0;
  }

  // ── Verificar se há alterações ────────────────────────────────────────────
  void _verificarAlteracoes() {
    final houveMudancas =
        _faturadoCtrl.text != _faturadoOriginal ||
        _toCtrl.text != _toOriginal ||
        _combustivelCtrl.text != _combustivelOriginal ||
        _estadiasCtrl.text != _estadiasOriginal ||
        _materiaisCtrl.text != _materiaisOriginal;

    setState(() => _temAlteracoes = houveMudancas);
  }

  // Marcador direto para alterações em pessoas/máquinas
  void _marcarComoAlterado() {
    setState(() => _temAlteracoes = true);
  }

  // ── Aviso se tentar sair com alterações ──────────────────────────────────
  Future<bool> _aoTentarSair() async {
    if (!_temAlteracoes) {
      return true; // Permite sair sem aviso
    }

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Alterações não salvas'),
        content: const Text('Tem alterações que não foram guardadas. Deseja mesmo sair e perder tudo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar a editar', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair e descartar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return resultado ?? false;
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (_diaId == null) return;
    setState(() => _saving = true);

    try {
      // Construir lista de pessoas com validação segura
      final horasPessoas = <Map<String, dynamic>>[];
      for (final p in _pessoas) {
        final id = p['pessoa_id'] as int;
        final ctrl = _horasP[id];
        
        // Se o controller não existe, pula esta pessoa
        if (ctrl == null) continue;
        
        final horas = _parseValue(ctrl.text);
        if (horas <= 0) continue; // Ignora horas zeradas
        
        final pessoa = _todasPessoas.firstWhere(
          (tp) => tp['id'] == id,
          orElse: () => {'custo_hora': 0},
        );
        final custoH = _parseValue(pessoa['custo_hora']);
        
        horasPessoas.add({
          'pessoa_id': id,
          'horas_total': horas,
          'custo_total': horas * custoH,
        });
      }

      // Construir lista de máquinas com validação segura
      final horasMaquinas = <Map<String, dynamic>>[];
      for (final m in _maquinas) {
        final id = m['maquina_id'] as int;
        final ctrl = _horasM[id];
        
        // Se o controller não existe, pula esta máquina
        if (ctrl == null) continue;
        
        final horas = _parseValue(ctrl.text);
        if (horas <= 0) continue; // Ignora horas zeradas
        
        final maquina = _todasMaquinas.firstWhere(
          (tm) => tm['id'] == id,
          orElse: () => {'combustivel_hora': 0},
        );
        final combH = _parseValue(maquina['combustivel_hora']);
        
        horasMaquinas.add({
          'maquina_id': id,
          'horas_total': horas,
          'combustivel_total': horas * combH,
        });
      }

      final faturado = _parseValue(_faturadoCtrl.text);

      // Enviar para backend
      await ApiService.guardarDia(_diaId!, {
        'estado': 'aberta',
        'faturado': faturado,
        'horasPessoas': horasPessoas,
        'horasMaquinas': horasMaquinas,
        'gastos': {
          'valor_to': _parseValue(_toCtrl.text),
          'valor_combustivel': _parseValue(_combustivelCtrl.text),
          'valor_estadias': _parseValue(_estadiasCtrl.text),
          'valor_materiais': _parseValue(_materiaisCtrl.text),
        }
      });

      // Sair do loading ANTES de navegar
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Dia guardado com sucesso!'), backgroundColor: Colors.green),
        );
        
        // Limpar alterações e aguardar um pouco para a mensagem aparecer
        setState(() => _temAlteracoes = false);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro: ${e.mensagem}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro inesperado: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _aoTentarSair,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_tituloDia),
              Text(widget.obraCodigo, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
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
                      _temAlteracoes = true;
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
                    _vazioMsg('Sem máquinas registadas para este dia.'),
                  ..._maquinas.map((m) => _linhaHoras(
                    id: m['maquina_id'] as int,
                    lista: _todasMaquinas,
                    ctrl: _horasM,
                    onRemover: () => setState(() {
                      _maquinas.removeWhere((x) => x['maquina_id'] == m['maquina_id']);
                      _horasM.remove(m['maquina_id'])?.dispose();
                      _temAlteracoes = true;
                    }),
                    iconeBg: const Color(0xFFF1EFE8),
                    iconeColor: const Color(0xFF5F5E5A),
                  )),

                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Gastos ───────────────────────────────────────────────────
                  _cabecalho('Gastos do dia'),
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
                        : const Text('Guardar dia'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
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
