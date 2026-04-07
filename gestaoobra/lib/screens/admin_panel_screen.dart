import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <-- Adicionado o package provider
import '../services/api_service.dart';
import '../services/auth_provider.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<dynamic> _utilizadores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.listarUtilizadores();
      setState(() { _utilizadores = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  void _abrirFormularioCriar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FormularioCriarUtilizador(
        onCriado: () async {
          await _carregar();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Utilizador criado com sucesso!')),
            );
          }
        },
      ),
    );
  }

  Future<void> _alterarSenha(dynamic user) async {
    final novaSenha = await _promptTexto(context, 'Nova senha', '', obscureText: true);
    if (novaSenha == null || novaSenha.isEmpty) return;
    try {
      await ApiService.alterarSenhaUtilizador(user['id'] as int, novaSenha);
      await _carregar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha alterada com sucesso!')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _apagarUtilizador(dynamic user) async {
    final nome = user['nome'] ?? 'Utilizador';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminação'),
        content: Text('Apagar "$nome"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.apagarUtilizador(user['id'] as int);
      await _carregar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilizador eliminado!')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  String _labelRole(String role) {
    switch (role) {
      case 'admin':      return 'Administrador';
      case 'gestor':     return 'Gestor';
      case 'utilizador': return 'Utilizador';
      default:           return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vamos buscar o ID do utilizador logado aqui no início do build
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.utilizador?['id'];

    return Scaffold(
      appBar: AppBar(title: const Text('Painel de Administração')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: _utilizadores.isEmpty
                  ? const Center(child: Text('Nenhum utilizador encontrado'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _utilizadores.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final user  = _utilizadores[i];
                        final id    = user['id']; // <-- Capturamos o ID do utilizador da lista
                        final nome  = user['nome']  ?? 'Sem nome';
                        final email = user['email'] ?? '';
                        final role  = user['role']  ?? 'utilizador';
                        
                        // Verificamos se é o utilizador logado
                        final isCurrentUser = id == currentUserId;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE6F1FB),
                              child: Text(
                                nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                                style: const TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                // Adiciona o marcador (Você)
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  const Text('(Você)', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                                ]
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email, style: const TextStyle(fontSize: 12)),
                                Text(_labelRole(role), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            // Se for o próprio utilizador, esconde o botão de apagar/editar
                            trailing: isCurrentUser 
                                ? const SizedBox.shrink() 
                                : PopupMenuButton(
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        child: const Row(children: [Icon(Icons.vpn_key, size: 18), SizedBox(width: 8), Text('Alterar senha')]),
                                        onTap: () => _alterarSenha(user),
                                      ),
                                      PopupMenuItem(
                                        child: const Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Apagar', style: TextStyle(color: Colors.red))]),
                                        onTap: () => _apagarUtilizador(user),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioCriar,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formulário de criação
// ---------------------------------------------------------------------------

class _FormularioCriarUtilizador extends StatefulWidget {
  const _FormularioCriarUtilizador({required this.onCriado});
  final VoidCallback onCriado;

  @override
  State<_FormularioCriarUtilizador> createState() => _FormularioCriarUtilizadorState();
}

class _FormularioCriarUtilizadorState extends State<_FormularioCriarUtilizador> {
  final _formKey            = GlobalKey<FormState>();
  final _nomeCtrl           = TextEditingController();
  final _emailCtrl          = TextEditingController();
  final _senhaCtrl          = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();

  bool   _obscureSenha     = true;
  bool   _obscureConfirmar = true;
  bool   _carregando       = false;

  String _roleSeleccionado = 'utilizador';

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await ApiService.criarUtilizador({
        'nome':     _nomeCtrl.text.trim(),
        'email':    _emailCtrl.text.trim(),
        'password': _senhaCtrl.text,
        'role':     _roleSeleccionado, 
      });
      if (mounted) Navigator.pop(context);
      widget.onCriado();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add, color: Color(0xFF185FA5)),
                  const SizedBox(width: 8),
                  const Text('Novo utilizador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _nomeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                  if (!v.contains('@')) return 'Email inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaCtrl,
                obscureText: _obscureSenha,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureSenha ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obrigatório';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmarSenhaCtrl,
                obscureText: _obscureConfirmar,
                decoration: InputDecoration(
                  labelText: 'Confirmar senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmar ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obrigatório';
                  if (v != _senhaCtrl.text) return 'As senhas não coincidem';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _roleSeleccionado,
                decoration: const InputDecoration(labelText: 'Função', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'utilizador', child: Text('Utilizador')),
                  DropdownMenuItem(value: 'gestor',     child: Text('Gestor')),
                  DropdownMenuItem(value: 'admin',      child: Text('Administrador')),
                ],
                onChanged: (v) => setState(() => _roleSeleccionado = v ?? 'utilizador'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _carregando ? null : _submeter,
                  icon: _carregando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_carregando ? 'A criar...' : 'Criar utilizador'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185FA5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper — prompt simples (usado para "alterar senha")
// ---------------------------------------------------------------------------

Future<String?> _promptTexto(BuildContext context, String titulo, String valor, {bool obscureText = false}) async {
  final ctrl = TextEditingController(text: valor);
  final resultado = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(titulo),
      content: TextField(controller: ctrl, obscureText: obscureText, decoration: const InputDecoration(border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Confirmar')),
      ],
    ),
  );
  ctrl.dispose();
  return resultado;
}