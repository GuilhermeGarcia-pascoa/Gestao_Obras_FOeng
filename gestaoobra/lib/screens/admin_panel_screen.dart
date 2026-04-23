import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_provider.dart';
import 'logs_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<dynamic> _utilizadores = [];
  bool _loading = true;

  // Pesquisa
  String _filtroPesquisa = '';
  final TextEditingController _pesquisaCtrl = TextEditingController();

  // Sync
  Map<String, dynamic>? _syncStatus;
  bool _syncLoading = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarSyncStatus();
  }

  @override
  void dispose() {
    _pesquisaCtrl.dispose();
    super.dispose();
  }

  // ── Utilizadores ────────────────────────────────────────────────────────────

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.listarUtilizadores();
      setState(() {
        _utilizadores = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensagem)),
        );
      }
    }
  }

  // ── Sync ────────────────────────────────────────────────────────────────────

  Future<void> _carregarSyncStatus() async {
    try {
      final status = await ApiService.getSyncStatus();
      if (mounted) setState(() => _syncStatus = status);
    } catch (_) {
      // Silencioso — sync pode não estar disponível
    }
  }

  Future<void> _sincronizarAgora() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sincronizar obras'),
        content: const Text(
          'Vai importar todas as obras do fo_panel para esta aplicação.\n\nDeseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF185FA5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sincronizar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() => _syncLoading = true);
    try {
      final resultado = await ApiService.sincronizarAgora();
      await _carregarSyncStatus();

      if (mounted) {
        final inseridas     = resultado['inseridas']     ?? 0;
        final actualizadas  = resultado['actualizadas']  ?? 0;
        final ignoradas     = resultado['ignoradas']     ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync concluído — $inseridas novas, $actualizadas actualizadas, $ignoradas sem alterações',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no sync: ${e.mensagem}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncLoading = false);
    }
  }

  // ── Formatação de datas ──────────────────────────────────────────────────────

  String _formatarData(String? isoString) {
    if (isoString == null) return 'Nunca';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final dia  = dt.day.toString().padLeft(2, '0');
      final mes  = dt.month.toString().padLeft(2, '0');
      final hora = dt.hour.toString().padLeft(2, '0');
      final min  = dt.minute.toString().padLeft(2, '0');
      return '$dia/$mes/${dt.year} $hora:$min';
    } catch (_) {
      return isoString;
    }
  }

  // ── Utilizadores helpers ─────────────────────────────────────────────────────

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
    final novaSenha = await _promptTexto(
      context,
      'Nova senha',
      '',
      obscureText: true,
    );
    if (novaSenha == null || novaSenha.isEmpty) return;
    try {
      await ApiService.alterarSenhaUtilizador(user['id'] as int, novaSenha);
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada com sucesso!')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensagem)),
        );
      }
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.apagarUtilizador(user['id'] as int);
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilizador eliminado!')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensagem)),
        );
      }
    }
  }

  String _labelRole(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'gestor':
        return 'Gestor';
      case 'utilizador':
        return 'Utilizador';
      default:
        return role;
    }
  }

  void _abrirLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogsScreen()),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.utilizador?['id'];
    final primaryColor = Theme.of(context).colorScheme.primary;

    final utilizadoresFiltrados = _utilizadores.where((u) {
      final nome  = (u['nome']  ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final filtro = _filtroPesquisa.toLowerCase();
      return nome.contains(filtro) || email.contains(filtro);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Administração'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _carregar();
                await _carregarSyncStatus();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ── Banner Logs ──────────────────────────────────────────
                  InkWell(
                    onTap: _abrirLogs,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.80),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.history,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Logs de Auditoria',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Ver registo de ações do sistema',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.white70, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Secção Sincronização fo_panel ────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabeçalho
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF185FA5).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.sync,
                                color: Color(0xFF185FA5),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sincronização fo_panel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Importar obras do sistema fo_panel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Info última / próxima sync
                        if (_syncStatus != null) ...[
                          _SyncInfoRow(
                            icon: Icons.check_circle_outline,
                            label: 'Último sync',
                            valor: _formatarData(_syncStatus!['ultimoSync'] as String?),
                            cor: Colors.green.shade600,
                          ),
                          const SizedBox(height: 6),
                          _SyncInfoRow(
                            icon: Icons.schedule,
                            label: 'Próximo sync',
                            valor: _formatarData(_syncStatus!['proximoSync'] as String?),
                            cor: Colors.orange.shade700,
                          ),
                          const SizedBox(height: 6),
                          _SyncInfoRow(
                            icon: Icons.add_circle_outline,
                            label: 'Total importadas',
                            valor: '${_syncStatus!['totalInseridas'] ?? 0} obras',
                            cor: const Color(0xFF185FA5),
                          ),
                          if (_syncStatus!['ultimoErro'] != null) ...[
                            const SizedBox(height: 6),
                            _SyncInfoRow(
                              icon: Icons.error_outline,
                              label: 'Último erro',
                              valor: _syncStatus!['ultimoErro'] as String,
                              cor: Colors.red.shade600,
                            ),
                          ],
                          const SizedBox(height: 14),
                        ],

                        // Botão sincronizar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _syncLoading ? null : _sincronizarAgora,
                            icon: _syncLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.sync, size: 18),
                            label: Text(
                              _syncLoading ? 'A sincronizar...' : 'Sincronizar agora',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF185FA5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Barra de Pesquisa ────────────────────────────────────
                  TextField(
                    controller: _pesquisaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Pesquisar utilizador...',
                      hintText: 'Nome ou email',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                      suffixIcon: _filtroPesquisa.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _pesquisaCtrl.clear();
                                setState(() => _filtroPesquisa = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (valor) => setState(() => _filtroPesquisa = valor),
                  ),
                  const SizedBox(height: 20),

                  // ── Cabeçalho utilizadores ───────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Utilizadores',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${utilizadoresFiltrados.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Lista utilizadores ───────────────────────────────────
                  if (utilizadoresFiltrados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          _filtroPesquisa.isEmpty
                              ? 'Nenhum utilizador encontrado'
                              : 'Nenhum resultado para "$_filtroPesquisa"',
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: utilizadoresFiltrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final user = utilizadoresFiltrados[i];
                        final id   = user['id'];
                        final nome  = user['nome']  ?? 'Sem nome';
                        final email = user['email'] ?? '';
                        final role  = user['role']  ?? 'utilizador';
                        final isCurrentUser = id == currentUserId;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE6F1FB),
                              child: Text(
                                nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Color(0xFF185FA5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(nome,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  const Text(
                                    '(Você)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email,
                                    style: const TextStyle(fontSize: 12)),
                                Text(
                                  _labelRole(role),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: isCurrentUser
                                ? const SizedBox.shrink()
                                : PopupMenuButton(
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.vpn_key, size: 18),
                                            SizedBox(width: 8),
                                            Text('Alterar senha'),
                                          ],
                                        ),
                                        onTap: () => _alterarSenha(user),
                                      ),
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.delete,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Apagar',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                        onTap: () => _apagarUtilizador(user),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioCriar,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// ── Widget auxiliar para linhas de info do sync ──────────────────────────────

class _SyncInfoRow extends StatelessWidget {
  const _SyncInfoRow({
    required this.icon,
    required this.label,
    required this.valor,
    required this.cor,
  });

  final IconData icon;
  final String label;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: cor),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Formulário criar utilizador ──────────────────────────────────────────────

class _FormularioCriarUtilizador extends StatefulWidget {
  const _FormularioCriarUtilizador({required this.onCriado});

  final VoidCallback onCriado;

  @override
  State<_FormularioCriarUtilizador> createState() =>
      _FormularioCriarUtilizadorState();
}

class _FormularioCriarUtilizadorState
    extends State<_FormularioCriarUtilizador> {
  final _formKey            = GlobalKey<FormState>();
  final _nomeCtrl           = TextEditingController();
  final _emailCtrl          = TextEditingController();
  final _senhaCtrl          = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();

  bool _obscureSenha     = true;
  bool _obscureConfirmar = true;
  bool _carregando       = false;

  String _roleSeleccionado = 'utilizador';

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  String? _validarEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Campo obrigatório';
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) return 'Formato de email inválido';
    return null;
  }

  String? _validarSenha(String? value) {
    final senha = value ?? '';
    if (senha.isEmpty) return 'Campo obrigatório';
    if (senha.length < 8) return 'A password deve ter pelo menos 8 caracteres';
    if (!RegExp(r'[a-zA-Z]').hasMatch(senha)) {
      return 'A password deve conter pelo menos uma letra';
    }
    if (!RegExp(r'[0-9]').hasMatch(senha)) {
      return 'A password deve conter pelo menos um número';
    }
    return null;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensagem)),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe  = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset + bottomSafe),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add, color: Color(0xFF185FA5)),
                  const SizedBox(width: 8),
                  const Text(
                    'Novo utilizador',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _nomeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validarEmail,
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
                    icon: Icon(_obscureSenha
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureSenha = !_obscureSenha),
                  ),
                ),
                validator: _validarSenha,
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
                    icon: Icon(_obscureConfirmar
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _obscureConfirmar = !_obscureConfirmar),
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
                decoration: const InputDecoration(
                  labelText: 'Função',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'utilizador', child: Text('Utilizador')),
                  DropdownMenuItem(
                      value: 'admin', child: Text('Administrador')),
                ],
                onChanged: (v) =>
                    setState(() => _roleSeleccionado = v ?? 'utilizador'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _carregando ? null : _submeter,
                  icon: _carregando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                      _carregando ? 'A criar...' : 'Criar utilizador'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185FA5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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

Future<String?> _promptTexto(
  BuildContext context,
  String titulo,
  String valor, {
  bool obscureText = false,
}) async {
  final ctrl = TextEditingController(text: valor);
  final resultado = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: ctrl,
        obscureText: obscureText,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return resultado;
}
