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

  // Ordenação
  _OrdemTipo _ordem = _OrdemTipo.nomeAsc;

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
    } catch (_) {}
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
        final inseridas = resultado['inseridas'] ?? 0;
        final actualizadas = resultado['actualizadas'] ?? 0;
        final ignoradas = resultado['ignoradas'] ?? 0;
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
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final hora = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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

  Color _corRole(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFF185FA5);
      case 'gestor':
        return Colors.deepPurple;
      case 'utilizador':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _iconeRole(String role) {
    switch (role) {
      case 'admin':
        return Icons.shield_outlined;
      case 'gestor':
        return Icons.manage_accounts_outlined;
      default:
        return Icons.person_outline;
    }
  }

  void _abrirLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogsScreen()),
    );
  }

  // ── Filtro + Ordenação ────────────────────────────────────────────────────────

  List<dynamic> get _utilizadoresFiltrados {
    final filtro = _filtroPesquisa.toLowerCase();

    var lista = _utilizadores.where((u) {
      final nome = (u['nome'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return filtro.isEmpty || nome.contains(filtro) || email.contains(filtro);
    }).toList();

    switch (_ordem) {
      case _OrdemTipo.nomeAsc:
        lista.sort((a, b) =>
            (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));
      case _OrdemTipo.nomeDesc:
        lista.sort((a, b) =>
            (b['nome'] ?? '').toString().compareTo((a['nome'] ?? '').toString()));
      case _OrdemTipo.roleAsc:
        lista.sort((a, b) =>
            (a['role'] ?? '').toString().compareTo((b['role'] ?? '').toString()));
    }

    return lista;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.utilizador?['id'];
    final lista = _utilizadoresFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Administração'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _carregar();
                await _carregarSyncStatus();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // Banner Logs
                  _BannerLogs(onTap: _abrirLogs),
                  const SizedBox(height: 14),

                  // Secção Sincronização
                  _SyncCard(
                    syncStatus: _syncStatus,
                    syncLoading: _syncLoading,
                    formatarData: _formatarData,
                    onSincronizar: _sincronizarAgora,
                  ),
                  const SizedBox(height: 24),

                  // Cabeçalho da secção Utilizadores
                  Row(
                    children: [
                      const Text(
                        'Utilizadores',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF185FA5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${lista.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF185FA5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Barra de Pesquisa + Ordenação
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pesquisaCtrl,
                          decoration: InputDecoration(
                            hintText: 'Pesquisar por nome ou email...',
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
                          onChanged: (valor) =>
                              setState(() => _filtroPesquisa = valor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<_OrdemTipo>(
                        tooltip: 'Ordenar',
                        initialValue: _ordem,
                        onSelected: (v) => setState(() => _ordem = v),
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.sort, size: 22),
                        ),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _OrdemTipo.nomeAsc,
                            child: Row(children: [
                              Icon(Icons.sort_by_alpha, size: 18),
                              SizedBox(width: 8),
                              Text('Nome A→Z'),
                            ]),
                          ),
                          PopupMenuItem(
                            value: _OrdemTipo.nomeDesc,
                            child: Row(children: [
                              Icon(Icons.sort_by_alpha, size: 18),
                              SizedBox(width: 8),
                              Text('Nome Z→A'),
                            ]),
                          ),
                          PopupMenuItem(
                            value: _OrdemTipo.roleAsc,
                            child: Row(children: [
                              Icon(Icons.badge_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Por função'),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Carrossel de utilizadores ou estado vazio
                  if (lista.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _filtroPesquisa.isEmpty
                                  ? 'Nenhum utilizador encontrado'
                                  : 'Nenhum resultado para "$_filtroPesquisa"',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _UtilizadoresCarrossel(
                      utilizadores: lista,
                      currentUserId: currentUserId,
                      labelRole: _labelRole,
                      corRole: _corRole,
                      iconeRole: _iconeRole,
                      onAlterarSenha: _alterarSenha,
                      onApagar: _apagarUtilizador,
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioCriar,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo utilizador'),
        backgroundColor: const Color(0xFF185FA5),
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Enum de ordenação ────────────────────────────────────────────────────────

enum _OrdemTipo { nomeAsc, nomeDesc, roleAsc }

// ── Carrossel de utilizadores ─────────────────────────────────────────────────
//
// Mostra os cards em scroll horizontal com peek do card seguinte (~20 px),
// para que o utilizador perceba que há mais para deslizar.

class _UtilizadoresCarrossel extends StatelessWidget {
  const _UtilizadoresCarrossel({
    required this.utilizadores,
    required this.currentUserId,
    required this.labelRole,
    required this.corRole,
    required this.iconeRole,
    required this.onAlterarSenha,
    required this.onApagar,
  });

  final List<dynamic> utilizadores;
  final dynamic currentUserId;
  final String Function(String) labelRole;
  final Color Function(String) corRole;
  final IconData Function(String) iconeRole;
  final Future<void> Function(dynamic) onAlterarSenha;
  final Future<void> Function(dynamic) onApagar;

  @override
  Widget build(BuildContext context) {
    // Largura do card: ocupa ~85 % do ecrã para mostrar o início do próximo
    final cardWidth = MediaQuery.of(context).size.width * 0.80;

    return SizedBox(
      // Altura fixa para o carrossel; o card cresce até este limite
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Padding lateral: alinha o primeiro card com o resto do conteúdo
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: utilizadores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final user = utilizadores[i];
          final role = (user['role'] ?? 'utilizador').toString();
          final cor = corRole(role);
          final isCurrentUser = user['id'] == currentUserId;
          final nome = user['nome'] ?? 'Sem nome';
          final email = user['email'] ?? '';
          final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return SizedBox(
            width: cardWidth,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2A38) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFDDE3ED),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha superior: avatar + nome + menu
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cor, cor.withOpacity(0.65)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            inicial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nome + badge "Você"
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF185FA5)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Você',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF185FA5),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Menu de ações (só se não for o utilizador atual)
                      if (!isCurrentUser)
                        PopupMenuButton(
                          icon: Icon(
                            Icons.more_vert,
                            size: 20,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey,
                          ),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              onTap: () => onAlterarSenha(user),
                              child: const Row(
                                children: [
                                  Icon(Icons.vpn_key,
                                      size: 18, color: Colors.amber),
                                  SizedBox(width: 8),
                                  Text('Alterar senha'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              onTap: () => onApagar(user),
                              child: const Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Apagar',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Divisor subtil
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 12),

                  // Badge de role + índice no carrossel
                  Row(
                    children: [
                      // Badge de role
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: cor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: cor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(iconeRole(role), size: 13, color: cor),
                            const SizedBox(width: 5),
                            Text(
                              labelRole(role),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Indicador de posição: "2 / 5"
                      Text(
                        '${i + 1} / ${utilizadores.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
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

// ── Banner Logs ──────────────────────────────────────────────────────────────

class _BannerLogs extends StatelessWidget {
  const _BannerLogs({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D2B4E), Color(0xFF185FA5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history, color: Colors.white, size: 20),
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
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ver registo de ações do sistema',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Secção Sync ──────────────────────────────────────────────────────────────

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.syncStatus,
    required this.syncLoading,
    required this.formatarData,
    required this.onSincronizar,
  });

  final Map<String, dynamic>? syncStatus;
  final bool syncLoading;
  final String Function(String?) formatarData;
  final VoidCallback onSincronizar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A38) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED),
        ),
        boxShadow: [
          if (!isDark)
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF185FA5).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sync,
                    color: Color(0xFF185FA5), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sincronizar com fo_panel',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      'Importar obras do sistema externo',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (syncStatus != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.transparent : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.transparent
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _SyncInfoRow(
                    icon: Icons.check_circle_outline,
                    label: 'Último sync',
                    valor: formatarData(syncStatus!['ultimoSync'] as String?),
                    cor: Colors.green.shade600,
                  ),
                  const SizedBox(height: 8),
                  _SyncInfoRow(
                    icon: Icons.schedule,
                    label: 'Próximo sync',
                    valor:
                        formatarData(syncStatus!['proximoSync'] as String?),
                    cor: Colors.orange.shade700,
                  ),
                  const SizedBox(height: 8),
                  _SyncInfoRow(
                    icon: Icons.add_circle_outline,
                    label: 'Total importadas',
                    valor: '${syncStatus!['totalInseridas'] ?? 0} obras',
                    cor: const Color(0xFF185FA5),
                  ),
                  if (syncStatus!['ultimoErro'] != null) ...[
                    const SizedBox(height: 8),
                    _SyncInfoRow(
                      icon: Icons.error_outline,
                      label: 'Último erro',
                      valor: syncStatus!['ultimoErro'] as String,
                      cor: Colors.red.shade600,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: syncLoading ? null : onSincronizar,
              icon: syncLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync, size: 18),
              label:
                  Text(syncLoading ? 'A sincronizar...' : 'Sincronizar agora'),
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
        Text('$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();

  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _carregando = false;

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
    if (senha.length < 8) {
      return 'A password deve ter pelo menos 8 caracteres';
    }
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
        'nome': _nomeCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _senhaCtrl.text,
        'role': _roleSeleccionado,
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
    final bottomSafe = MediaQuery.of(context).padding.bottom;

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
              // Cabeçalho do formulário
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF185FA5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF185FA5).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF185FA5).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_add,
                          color: Color(0xFF185FA5), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Novo utilizador',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nomeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome completo',
                  hintText: 'ex: João Silva',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'ex: joao@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                validator: _validarEmail,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _senhaCtrl,
                obscureText: _obscureSenha,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  hintText: 'Mínimo 8 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureSenha
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureSenha = !_obscureSenha),
                    splashRadius: 20,
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
                  hintText: 'Repita a senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmar
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _obscureConfirmar = !_obscureConfirmar),
                    splashRadius: 20,
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
                decoration: InputDecoration(
                  labelText: 'Função',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'utilizador',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 18, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('Utilizador'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'gestor',
                    child: Row(
                      children: [
                        Icon(Icons.manage_accounts,
                            size: 18, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text('Gestor'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(Icons.shield,
                            size: 18, color: Color(0xFF185FA5)),
                        SizedBox(width: 8),
                        Text('Administrador'),
                      ],
                    ),
                  ),
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
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label:
                      Text(_carregando ? 'A criar...' : 'Criar utilizador'),
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

// ── Prompt de texto ──────────────────────────────────────────────────────────

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