import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ObraFormScreen extends StatefulWidget {
  final Map<String, dynamic>? obra; // null = criar novo
  const ObraFormScreen({super.key, this.obra});

  @override
  State<ObraFormScreen> createState() => _ObraFormScreenState();
}

class _ObraFormScreenState extends State<ObraFormScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _nomeCtrl   = TextEditingController();
  final _orcCtrl    = TextEditingController();

  String _tipo   = 'AC';
  String _estado = 'planeada';
  bool _saving   = false;

  static const _tipos   = ['AC', 'DC', 'AC/DC', 'ACTIV', 'Mecânica', 'Inst. Elétrica'];
  static const _estados = ['planeada', 'em_curso', 'concluida'];

  @override
  void initState() {
    super.initState();
    if (widget.obra != null) {
      final o = widget.obra!;
      _codigoCtrl.text = o['codigo'] ?? '';
      _nomeCtrl.text   = o['nome']   ?? '';
      _orcCtrl.text    = o['orcamento']?.toString() ?? '';
      _tipo   = o['tipo']   ?? 'AC';
      _estado = o['estado'] ?? 'planeada';
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nomeCtrl.dispose();
    _orcCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final dados = {
      'codigo':    _codigoCtrl.text.trim(),
      'nome':      _nomeCtrl.text.trim(),
      'tipo':      _tipo,
      'estado':    _estado,
      'orcamento': _orcCtrl.text.isEmpty ? null : double.tryParse(_orcCtrl.text),
    };

    try {
      if (widget.obra == null) {
        await ApiService.criarObra(dados);
      } else {
        await ApiService.editarObra(widget.obra!['id'], dados);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.obra != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar obra' : 'Nova obra')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(labelText: 'Código *', hintText: 'ex: AC/174/PE'),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome / descrição *'),
              validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo de obra'),
              items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _tipo = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _estado = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _orcCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Orçamento (€)', prefixText: '€ '),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _guardar,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Guardar alterações' : 'Criar obra'),
            ),
          ],
        ),
      ),
    );
  }
}
