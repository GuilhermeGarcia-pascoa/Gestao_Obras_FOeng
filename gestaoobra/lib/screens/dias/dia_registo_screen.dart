import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

final _eur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

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

  // ── Listas ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _pessoas  = [];
  List<Map<String, dynamic>> _maquinas = [];
  List<Map<String, dynamic>> _viaturas = [];

  List<dynamic> _todasPessoas  = [];
  List<dynamic> _todasMaquinas = [];
  List<dynamic> _todasViaturas = [];

  // horas por pessoa/máquina; km por viatura
  final Map<int, TextEditingController> _horasP = {};
  final Map<int, TextEditingController> _horasM = {};
  final Map<int, TextEditingController> _kmV    = {};

  // custo extra editável por pessoa (valor neste dia)
  final Map<int, TextEditingController> _custoExtraP = {};

  // override do custo/hora base para este dia (null = usa o valor base do operador)
  final Map<int, double> _custoHoraOverride = {};

  // Gastos gerais
  final _moCtrl         = TextEditingController(); // Mão de obra
  final _combustivelCtrl = TextEditingController();
  final _estadiasCtrl   = TextEditingController();
  final _materiaisCtrl  = TextEditingController();
  final _refeicoesCtrl  = TextEditingController();
  final _faturadoCtrl   = TextEditingController();

  bool _loading       = true;
  bool _saving        = false;
  bool _temAlteracoes = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
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
    for (final c in _kmV.values) {
      c.dispose();
    }
    for (final c in _custoExtraP.values) {
      c.dispose();
    }
    _moCtrl.dispose(); _combustivelCtrl.dispose();
    _estadiasCtrl.dispose(); _materiaisCtrl.dispose();
    _refeicoesCtrl.dispose(); _faturadoCtrl.dispose();
    super.dispose();
  }

  // ── Título formatado ──────────────────────────────────────────────────────
  String get _tituloDia {
    final d = DateTime.parse(widget.data);
    return DateFormat("EEEE, d MMM", 'pt_PT').format(d);
  }

  // ── Carregar ──────────────────────────────────────────────────────────────
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getDiaPorData(widget.obraId, widget.data),
        ApiService.listarPessoas(),
        ApiService.listarMaquinas(),
        ApiService.listarViaturas(),
      ]);

      final detalhe      = results[0] as Map<String, dynamic>;
      _todasPessoas  = results[1] as List<dynamic>;
      _todasMaquinas = results[2] as List<dynamic>;
      _todasViaturas = results[3] as List<dynamic>;

      final dia = detalhe['dia'] as Map<String, dynamic>;
      _diaId = dia['id'] as int;

      _limparControllers();

      _pessoas  = List<Map<String, dynamic>>.from(detalhe['horasPessoas']  ?? []);
      _maquinas = List<Map<String, dynamic>>.from(detalhe['horasMaquinas'] ?? []);
      _viaturas = List<Map<String, dynamic>>.from(detalhe['horasViaturas'] ?? []);

      for (final p in _pessoas) {
        final id = p['pessoa_id'] as int;
        _horasP[id]      = TextEditingController(text: (p['horas_total'] ?? 0).toString());
        _custoExtraP[id] = TextEditingController(text: (p['custo_extra']  ?? 0).toString());
        // carrega override do custo/hora se existir
        if (p['custo_hora_override'] != null && _p(p['custo_hora_override']) > 0) {
          _custoHoraOverride[id] = _p(p['custo_hora_override']);
        }
      }
      for (final m in _maquinas) {
        final id = m['maquina_id'] as int;
        _horasM[id] = TextEditingController(text: (m['horas_total'] ?? 0).toString());
      }
      for (final v in _viaturas) {
        final id = v['viatura_id'] as int;
        _kmV[id] = TextEditingController(text: (v['km_total'] ?? 0).toString());
      }

      _moCtrl.text          = _v(dia['valor_to']);
      _combustivelCtrl.text = _v(dia['valor_combustivel']);
      _estadiasCtrl.text    = _v(dia['valor_estadias']);
      _materiaisCtrl.text   = _v(dia['valor_materiais']);
      _refeicoesCtrl.text   = _v(dia['valor_refeicoes']);
      _faturadoCtrl.text    = _v(dia['faturado']);

      for (final c in [_moCtrl, _combustivelCtrl, _estadiasCtrl, _materiaisCtrl, _refeicoesCtrl, _faturadoCtrl]) {
        c.addListener(() => setState(() => _temAlteracoes = true));
      }

      setState(() { _loading = false; _temAlteracoes = false; });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) _snack('❌ ${e.mensagem}', Colors.red);
    }
  }

  void _limparControllers() {
    for (final c in _horasP.values) {
      c.dispose();
    }
    for (final c in _horasM.values) {
      c.dispose();
    }
    for (final c in _kmV.values) {
      c.dispose();
    }
    for (final c in _custoExtraP.values) {
      c.dispose();
    }
    _horasP.clear(); _horasM.clear(); _kmV.clear(); _custoExtraP.clear(); _custoHoraOverride.clear();
  }

  // ── Copiar anterior (dia mais recente) ────────────────────────────────────
  Future<void> _copiarAnterior() async {
    if (_diaId == null) return;
    try {
      final ant = await ApiService.getDiaAnterior(_diaId!);
      _aplicarCopia(ant);
      _snack('✓ Dados do dia anterior copiados!', Colors.green);
    } on ApiException catch (e) {
      _snack('❌ ${e.mensagem}', Colors.red);
    }
  }

  // ── Copiar de dia específico ──────────────────────────────────────────────
  Future<void> _copiarDeDia() async {
    if (_diaId == null) return;
    try {
      final lista = await ApiService.listarDiasObra(widget.obraId);
      // Remove o dia atual da lista
      final opcoes = lista.where((d) => d['id'] != _diaId).toList();
      if (opcoes.isEmpty) { _snack('Sem outros dias para copiar', Colors.orange); return; }

      if (!mounted) return;
      final escolhido = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Copiar dados de qual dia?'),
          children: opcoes.map<Widget>((d) {
            final dt = DateTime.tryParse(d['data'] ?? '');
            final label = dt != null ? DateFormat('EEEE, d MMM yyyy', 'pt_PT').format(dt) : d['data'];
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(label, style: const TextStyle(fontSize: 14)),
              ),
            );
          }).toList(),
        ),
      );
      if (escolhido == null) return;

      final dados = await ApiService.copiarDe(_diaId!, escolhido['id'] as int);
      _aplicarCopia(dados);
      _snack('✓ Dados copiados!', Colors.green);
    } on ApiException catch (e) {
      _snack('❌ ${e.mensagem}', Colors.red);
    }
  }

  void _aplicarCopia(Map<String, dynamic> dados) {
    final pessoasAnt  = List<Map<String, dynamic>>.from(dados['horasPessoas']  ?? []);
    final maquinasAnt = List<Map<String, dynamic>>.from(dados['horasMaquinas'] ?? []);
    final viaturasAnt = List<Map<String, dynamic>>.from(dados['horasViaturas'] ?? []);
    final gastosAnt   = dados['gastos'] as Map<String, dynamic>? ?? {};

    _limparControllers();
    setState(() {
      _pessoas  = pessoasAnt;
      _maquinas = maquinasAnt;
      _viaturas = viaturasAnt;

      for (final p in _pessoas) {
        final id = p['pessoa_id'] as int;
        _horasP[id]      = TextEditingController(text: _v(p['horas_total']));
        _custoExtraP[id] = TextEditingController(text: _v(p['custo_extra']));
      }
      for (final m in _maquinas) {
        final id = m['maquina_id'] as int;
        _horasM[id] = TextEditingController(text: _v(m['horas_total']));
      }
      for (final v in _viaturas) {
        final id = v['viatura_id'] as int;
        _kmV[id] = TextEditingController(text: _v(v['km_total']));
      }

      _moCtrl.text          = _v(gastosAnt['valor_to']);
      _combustivelCtrl.text = _v(gastosAnt['valor_combustivel']);
      _estadiasCtrl.text    = _v(gastosAnt['valor_estadias']);
      _materiaisCtrl.text   = _v(gastosAnt['valor_materiais']);
      _refeicoesCtrl.text   = _v(gastosAnt['valor_refeicoes']);
      _temAlteracoes = true;
    });
  }

  // ── Adicionar pessoa ──────────────────────────────────────────────────────
  Future<void> _adicionarPessoa() async {
    final jaIds = _pessoas.map((p) => p['pessoa_id']).toSet();
    final disp  = _todasPessoas.where((p) => !jaIds.contains(p['id'])).toList();
    if (disp.isEmpty) { _snack('⚠️ Todas as pessoas já adicionadas', Colors.orange); return; }

    final escolhida = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Selecionar pessoa'),
        children: disp.map((p) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, p as Map<String, dynamic>),
          child: ListTile(
            leading: CircleAvatar(child: Text((p['nome'] as String)[0])),
            title: Text(p['nome']),
            subtitle: Text('${p['cargo'] ?? ''}  ·  €${p['custo_hora'] ?? 0}/h'),
          ),
        )).toList(),
      ),
    );
    if (escolhida == null) return;
    final id = escolhida['id'] as int;
    setState(() {
      _pessoas.add({'pessoa_id': id, 'horas_total': 8, 'custo_extra': 0});
      _horasP[id]      = TextEditingController(text: '8');
      _custoExtraP[id] = TextEditingController(text: '0');
      _temAlteracoes   = true;
    });
  }

  // ── Adicionar máquina ─────────────────────────────────────────────────────
  Future<void> _adicionarMaquina() async {
    final jaIds = _maquinas.map((m) => m['maquina_id']).toSet();
    final disp  = _todasMaquinas.where((m) => !jaIds.contains(m['id'])).toList();
    if (disp.isEmpty) { _snack('⚠️ Todas as máquinas já adicionadas', Colors.orange); return; }

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
      _maquinas.add({'maquina_id': id, 'horas_total': 0});
      _horasM[id]    = TextEditingController(text: '0');
      _temAlteracoes = true;
    });
  }

  // ── Adicionar viatura ─────────────────────────────────────────────────────
  Future<void> _adicionarViatura() async {
    final jaIds = _viaturas.map((v) => v['viatura_id']).toSet();
    final disp  = _todasViaturas.where((v) => !jaIds.contains(v['id'])).toList();
    if (disp.isEmpty) { _snack('⚠️ Todas as viaturas já adicionadas', Colors.orange); return; }

    final escolhida = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Selecionar viatura'),
        children: disp.map((v) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, v as Map<String, dynamic>),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.directions_car)),
            title: Text(v['modelo'] ?? ''),
            subtitle: Text('${v['matricula'] ?? ''}  ·  €${v['custo_km'] ?? 0}/km'),
          ),
        )).toList(),
      ),
    );
    if (escolhida == null) return;
    final id = escolhida['id'] as int;
    setState(() {
      _viaturas.add({'viatura_id': id, 'km_total': 0});
      _kmV[id]       = TextEditingController(text: '0');
      _temAlteracoes = true;
    });
  }

  // ── Totais ────────────────────────────────────────────────────────────────
  double get _totalPessoal {
    double total = 0;
    for (final p in _pessoas) {
      final id = p['pessoa_id'] as int;
      final horas = _p(_horasP[id]?.text);
      final pessoa = _todasPessoas.firstWhere((tp) => tp['id'] == id, orElse: () => {'custo_hora': 0});
      // usa override se existir, caso contrário usa o valor base do operador
      final custoH = _custoHoraOverride.containsKey(id) ? _custoHoraOverride[id]! : _p(pessoa['custo_hora']);
      final extra  = _p(_custoExtraP[id]?.text);
      total += horas * custoH + extra;
    }
    return total;
  }

  double get _totalMaquinas {
    double total = 0;
    for (final m in _maquinas) {
      final id = m['maquina_id'] as int;
      final horas = _p(_horasM[id]?.text);
      final maq   = _todasMaquinas.firstWhere((tm) => tm['id'] == id, orElse: () => {'custo_hora': 0});
      total += horas * _p(maq['custo_hora']);
    }
    return total;
  }

  double get _totalViaturas {
    double total = 0;
    for (final v in _viaturas) {
      final id  = v['viatura_id'] as int;
      final km  = _p(_kmV[id]?.text);
      final viat = _todasViaturas.firstWhere((tv) => tv['id'] == id, orElse: () => {'custo_km': 0});
      total += km * _p(viat['custo_km']);
    }
    return total;
  }

  double get _totalGastosDiretos =>
      _p(_moCtrl.text) + _p(_combustivelCtrl.text) +
      _p(_estadiasCtrl.text) + _p(_materiaisCtrl.text) + _p(_refeicoesCtrl.text);

  double get _totalGeral => _totalPessoal + _totalMaquinas + _totalViaturas + _totalGastosDiretos;

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (_diaId == null) return;
    setState(() => _saving = true);

    try {
      final horasPessoas = <Map<String, dynamic>>[];
      for (final p in _pessoas) {
        final id    = p['pessoa_id'] as int;
        final horas = _p(_horasP[id]?.text);
        if (horas <= 0) continue;
        final pessoa = _todasPessoas.firstWhere((tp) => tp['id'] == id, orElse: () => {'custo_hora': 0});
        final custoH = _custoHoraOverride.containsKey(id) ? _custoHoraOverride[id]! : _p(pessoa['custo_hora']);
        horasPessoas.add({
          'pessoa_id':         id,
          'horas_total':        horas,
          'custo_total':        horas * custoH,
          'custo_extra':        _p(_custoExtraP[id]?.text),
          'custo_hora_override': _custoHoraOverride.containsKey(id) ? _custoHoraOverride[id] : null,
        });
      }

      final horasMaquinas = <Map<String, dynamic>>[];
      for (final m in _maquinas) {
        final id    = m['maquina_id'] as int;
        final horas = _p(_horasM[id]?.text);
        if (horas <= 0) continue;
        final maq = _todasMaquinas.firstWhere((tm) => tm['id'] == id, orElse: () => {'combustivel_hora': 0});
        horasMaquinas.add({
          'maquina_id':       id,
          'horas_total':       horas,
          'combustivel_total': horas * _p(maq['combustivel_hora']),
        });
      }

      final horasViaturas = <Map<String, dynamic>>[];
      for (final v in _viaturas) {
        final id = v['viatura_id'] as int;
        final km = _p(_kmV[id]?.text);
        if (km <= 0) continue;
        final viat = _todasViaturas.firstWhere((tv) => tv['id'] == id, orElse: () => {'custo_km': 0});
        horasViaturas.add({
          'viatura_id': id,
          'km_total':   km,
          'custo_total': km * _p(viat['custo_km']),
        });
      }

      await ApiService.guardarDia(_diaId!, {
        'estado':   'aberta',
        'faturado': _p(_faturadoCtrl.text),
        'horasPessoas':  horasPessoas,
        'horasMaquinas': horasMaquinas,
        'horasViaturas': horasViaturas,
        'gastos': {
          'valor_to':          _p(_moCtrl.text),
          'valor_combustivel': _p(_combustivelCtrl.text),
          'valor_estadias':    _p(_estadiasCtrl.text),
          'valor_materiais':   _p(_materiaisCtrl.text),
          'valor_refeicoes':   _p(_refeicoesCtrl.text),
        },
      });

      if (mounted) {
        setState(() { _saving = false; _temAlteracoes = false; });
        _snack('✓ Dia guardado!', Colors.green);
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) _snack('❌ ${e.mensagem}', Colors.red);
    }
  }

  // ── Aviso ao sair com alterações ──────────────────────────────────────────
  Future<bool> _aoTentarSair() async {
    if (!_temAlteracoes) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alterações não guardadas'),
        content: const Text('Tens alterações por guardar. Sair mesmo assim?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok ?? false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _v(dynamic val) {
    if (val == null) return '0';
    if (val is num) return val == 0 ? '0' : val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2);
    return val.toString().replaceAll(',', '.');
  }

  double _p(dynamic val) {
    if (val == null) return 0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().replaceAll(',', '.').trim()) ?? 0;
  }

  void _snack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.copy_all, color: Colors.white),
              tooltip: 'Copiar dados',
              onSelected: (v) {
                if (v == 'anterior') _copiarAnterior();
                if (v == 'escolher') _copiarDeDia();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'anterior', child: Text('Copiar dia anterior')),
                const PopupMenuItem(value: 'escolher', child: Text('Copiar de dia específico...')),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ── Pessoas ─────────────────────────────────────────────
                  _cabecalho('Equipa', trailing: TextButton.icon(
                    onPressed: _adicionarPessoa,
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Adicionar'),
                  )),
                  if (_pessoas.isEmpty) _vazioMsg('Sem pessoas. Carrega em "Adicionar".'),
                  ..._pessoas.map((p) => _linhaPessoa(p)),

                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Máquinas ────────────────────────────────────────────
                  _cabecalho('Máquinas', trailing: TextButton.icon(
                    onPressed: _adicionarMaquina,
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Adicionar'),
                  )),
                  if (_maquinas.isEmpty) _vazioMsg('Sem máquinas.'),
                  ..._maquinas.map((m) => _linhaHoras(
                    id: m['maquina_id'] as int, lista: _todasMaquinas,
                    ctrl: _horasM, sufixo: 'h',
                    iconeBg: const Color(0xFFF1EFE8), iconeColor: const Color(0xFF5F5E5A),
                    onRemover: () => setState(() {
                      _maquinas.removeWhere((x) => x['maquina_id'] == m['maquina_id']);
                      _horasM.remove(m['maquina_id'])?.dispose();
                      _temAlteracoes = true;
                    }),
                  )),

                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Viaturas ────────────────────────────────────────────
                  _cabecalho('Viaturas', trailing: TextButton.icon(
                    onPressed: _adicionarViatura,
                    icon: const Icon(Icons.directions_car_outlined, size: 16),
                    label: const Text('Adicionar'),
                  )),
                  if (_viaturas.isEmpty) _vazioMsg('Sem viaturas.'),
                  ..._viaturas.map((v) => _linhaHoras(
                    id: v['viatura_id'] as int, lista: _todasViaturas,
                    ctrl: _kmV, sufixo: 'km',
                    iconeBg: const Color(0xFFE1F5EE), iconeColor: const Color(0xFF0F6E56),
                    nomeCampo: 'modelo',
                    onRemover: () => setState(() {
                      _viaturas.removeWhere((x) => x['viatura_id'] == v['viatura_id']);
                      _kmV.remove(v['viatura_id'])?.dispose();
                      _temAlteracoes = true;
                    }),
                  )),

                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Gastos diretos ──────────────────────────────────────
                  _cabecalho('Gastos do dia'),
                  const SizedBox(height: 8),
                  _campo('Mão de obra (€)',        _moCtrl),
                  _campo('Combustível (€)',         _combustivelCtrl),
                  _campo('Estadias (€)',            _estadiasCtrl),
                  _campo('Refeições (€)',           _refeicoesCtrl),
                  _campo('Materiais / outros (€)',  _materiaisCtrl),

                  const SizedBox(height: 12),

                  // ── Totais por sector ───────────────────────────────────
                  _totalSector('Pessoal',    _totalPessoal,  const Color(0xFFE6F1FB)),
                  _totalSector('Máquinas',   _totalMaquinas, const Color(0xFFF1EFE8)),
                  _totalSector('Viaturas',   _totalViaturas, const Color(0xFFE1F5EE)),
                  _totalSector('Gastos diretos', _totalGastosDiretos, const Color(0xFFFAEEDA)),

                  const SizedBox(height: 4),
                  // ── Total geral ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A2A3E)
                          : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL GASTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(_eur.format(_totalGeral), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Faturação ───────────────────────────────────────────
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

  // ── Linha de pessoa (com override de custo/hora) ─────────────────────────
  Widget _linhaPessoa(Map<String, dynamic> p) {
    final id   = p['pessoa_id'] as int;
    final item = _todasPessoas.firstWhere((x) => x['id'] == id, orElse: () => {'nome': 'Desconhecido', 'custo_hora': 0});
    final nome      = (item['nome'] ?? '') as String;
    final custoBase = _p(item['custo_hora']);
    final custoAtivo = _custoHoraOverride.containsKey(id) ? _custoHoraOverride[id]! : custoBase;
    final temOverride = _custoHoraOverride.containsKey(id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFE6F1FB),
                  child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF185FA5), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(nome, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                // Campo horas
                _miniCampo(_horasP[id], 'h', 60),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => setState(() {
                    _pessoas.removeWhere((x) => x['pessoa_id'] == id);
                    _horasP.remove(id)?.dispose();
                    _custoExtraP.remove(id)?.dispose();
                    _custoHoraOverride.remove(id);
                    _temAlteracoes = true;
                  }),
                ),
              ],
            ),
            // Linha do custo/hora com botão de editar
            Row(
              children: [
                const SizedBox(width: 44),
                // Se tem override, mostra tachado o valor base
                if (temOverride) ...[
                  Text(
                    '€${custoBase.toStringAsFixed(2)}/h',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '€${custoAtivo.toStringAsFixed(2)}/h',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF185FA5), fontWeight: FontWeight.w600),
                  ),
                ] else
                  Text(
                    '€${custoBase.toStringAsFixed(2)}/h base',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                const SizedBox(width: 4),
                // Botão editar
                GestureDetector(
                  onTap: () => _editarCustoHora(id, custoBase, custoAtivo),
                  child: Icon(
                    temOverride ? Icons.edit : Icons.edit_outlined,
                    size: 14,
                    color: temOverride ? const Color(0xFF185FA5) : Colors.grey,
                  ),
                ),
                // Botão repor base (só aparece se tiver override)
                if (temOverride) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() {
                      _custoHoraOverride.remove(id);
                      _temAlteracoes = true;
                    }),
                    child: const Icon(Icons.refresh, size: 14, color: Colors.grey),
                  ),
                ],
                const Spacer(),
                // Custo total desta pessoa
                Text(
                  _eur.format(_p(_horasP[id]?.text) * custoAtivo + _p(_custoExtraP[id]?.text)),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            // Linha de custo extra (horas extras — inalterada)
            Row(
              children: [
                const SizedBox(width: 44),
                const Text('extra neste dia:',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 8),
                _miniCampo(_custoExtraP[id], '€', 72),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog para editar o custo/hora neste dia ────────────────────────────
  Future<void> _editarCustoHora(int pessoaId, double custoBase, double custoAtual) async {
    final ctrl = TextEditingController(text: custoAtual.toStringAsFixed(2));

    final resultado = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Custo/hora neste dia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Valor base: €${custoBase.toStringAsFixed(2)}/h',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: const InputDecoration(
                labelText: 'Custo/hora para este dia',
                prefixText: '€ ',
                suffixText: '/h',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          // Repor valor base
          TextButton(
            onPressed: () => Navigator.pop(context, -1),
            child: const Text('Repor base', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (val != null && val > 0) Navigator.pop(context, val);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (resultado == null) return;
    setState(() {
      if (resultado < 0) {
        // -1 = repor base
        _custoHoraOverride.remove(pessoaId);
      } else {
        _custoHoraOverride[pessoaId] = resultado;
      }
      _temAlteracoes = true;
    });
  }

  // ── Linha genérica (máquinas / viaturas) ─────────────────────────────────
  Widget _linhaHoras({
    required int id,
    required List<dynamic> lista,
    required Map<int, TextEditingController> ctrl,
    required String sufixo,
    required Color iconeBg,
    required Color iconeColor,
    required VoidCallback onRemover,
    String nomeCampo = 'nome',
  }) {
    final item = lista.firstWhere((x) => x['id'] == id, orElse: () => {});
    final nome = (item[nomeCampo] ?? item['nome'] ?? '') as String;
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
          _miniCampo(ctrl[id], sufixo, 72),
          IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () {
            onRemover();
            setState(() => _temAlteracoes = true);
          }),
        ],
      ),
    );
  }

  Widget _miniCampo(TextEditingController? ctrl, String sufixo, double width) => SizedBox(
    width: width,
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        suffixText: sufixo,
      ),
      onChanged: (_) => setState(() => _temAlteracoes = true),
    ),
  );

  Widget _cabecalho(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
      if (trailing != null) trailing,
    ]),
  );

  Widget _vazioMsg(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 13)),
  );

  Widget _campo(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      decoration: InputDecoration(labelText: label, prefixText: '€ '),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _totalSector(String label, double valor, Color bg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? bg.withOpacity(0.2) : bg;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
          Text(_eur.format(valor), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}