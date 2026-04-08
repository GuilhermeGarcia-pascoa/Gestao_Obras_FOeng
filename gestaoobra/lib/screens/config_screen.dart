import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import '../theme/app_theme.dart';
import 'admin_panel_screen.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final theme  = context.watch<ThemeProvider>();
    final user   = auth.utilizador;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Perfil ────────────────────────────────────────────────────────
          _profileCard(context, user, isDark),
          const SizedBox(height: 24),

          // ── Exportações ───────────────────────────────────────────────────
          _sectionLabel('Exportação'),
          const SizedBox(height: 8),
          _group([
            _tile(
              context,
              icon: Icons.table_chart_outlined,
              label: 'Exportar Excel por obra',
              onTap: () => _exportarExcel(context),
            ),
            _divider(context),
            _tile(
              context,
              icon: Icons.picture_as_pdf_outlined,
              label: 'Exportar PDF por intervalo de datas',
              onTap: () => _exportarPdf(context),
            ),
          ], isDark),
          const SizedBox(height: 24),

          // ── Aparência ─────────────────────────────────────────────────────
          _sectionLabel('Aparência'),
          const SizedBox(height: 8),
          _group([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.infoSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.palette_outlined, size: 18, color: AppColors.navy),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Text('Tema da app')),
                  DropdownButton<ThemeMode>(
                    value: theme.themeMode,
                    underline: const SizedBox(),
                    style: TextStyle(
                      color: isDark ? const Color(0xFFB0AFA8) : AppColors.gray600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                      DropdownMenuItem(value: ThemeMode.light,  child: Text('Claro')),
                      DropdownMenuItem(value: ThemeMode.dark,   child: Text('Escuro')),
                    ],
                    onChanged: (v) {
                      if (v != null) context.read<ThemeProvider>().setThemeMode(v);
                    },
                  ),
                ],
              ),
            ),
          ], isDark),
          const SizedBox(height: 24),

          // ── Informação ────────────────────────────────────────────────────
          _sectionLabel('Informação'),
          const SizedBox(height: 8),
          _group([
            _tile(context, icon: Icons.info_outline_rounded, label: 'Versão 1.6.7', onTap: null),
            _divider(context),
            _tile(context, icon: Icons.code_rounded, label: 'Flutter + Node.js + MySQL', onTap: null),
          ], isDark),
          const SizedBox(height: 32),

          // ── Logout ────────────────────────────────────────────────────────
          _logoutButton(context),
          const SizedBox(height: 12),

          // ── Admin ─────────────────────────────────────────────────────────
          if (user?['role'] == 'admin') ...[
            const SizedBox(height: 4),
            _adminButton(context),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    Map<String, dynamic>? user,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final nome  = user?['nome'] ?? 'Utilizador';
    final email = user?['email'] ?? '';
    final role  = user?['role'] ?? '';

    final roleLabel = switch (role) {
      'admin'      => 'Administrador',
      'gestor'     => 'Gestor',
      'utilizador' => 'Utilizador',
      _            => role,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A38) : AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              roleLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 0),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.gray400,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _group(List<Widget> children, bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF242426) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? const Color(0xFF38383A) : const Color(0xFFE8E7E2),
        width: 0.5,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: AppColors.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? const Color(0xFF5A5A5C) : AppColors.gray400,
              ),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) => Divider(
    color: Theme.of(context).dividerColor,
    thickness: 0.5,
    height: 0,
    indent: 66,
  );

  Widget _logoutButton(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: OutlinedButton.icon(
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Terminar sessão'),
            content: const Text('Tens a certeza que queres sair?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sair'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          context.read<AuthProvider>().logout();
        }
      },
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Terminar sessão'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.dangerSurface, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  Widget _adminButton(BuildContext context) => Center(
    child: TextButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      ),
      icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
      label: const Text('Painel de administrador'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.gray400,
        textStyle: const TextStyle(fontSize: 13),
      ),
    ),
  );

  // ── Export helpers (unchanged logic) ────────────────────────────────────
  Future<void> _exportarExcel(BuildContext context) async {
    try {
      final obras = await ApiService.listarObras();
      if (!context.mounted) return;
      if (obras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma obra disponível')),
        );
        return;
      }
      final obra = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Escolher obra'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: obras.length,
              itemBuilder: (_, i) {
                final o = obras[i];
                return ListTile(
                  leading: InitialAvatar(o['codigo'] ?? '?', size: 36),
                  title: Text(o['codigo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(o['nome'] ?? ''),
                  onTap: () => Navigator.pop(_, o),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ],
        ),
      );
      if (obra == null || !context.mounted) return;
      await _abrirUrl(
        context,
        url: ApiService.urlExcel(int.parse(obra['id'].toString())),
        successMsg: 'Excel aberto!',
      );
    } on ApiException catch (e) {
      if (context.mounted) _snackError(context, e.mensagem);
    }
  }

  Future<void> _exportarPdf(BuildContext context) async {
    final hoje     = DateTime.now();
    final inicioMes = DateTime(hoje.year, hoje.month, 1);
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    final intervalo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year + 1),
      initialDateRange: DateTimeRange(start: inicioMes, end: hoje),
      locale: const Locale('pt', 'PT'),
      helpText: 'Intervalo de datas',
      cancelText: 'Cancelar',
      confirmText: 'Exportar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: isDark
              ? Theme.of(ctx).colorScheme
              : const ColorScheme.light(
                  primary: AppColors.navy,
                  onPrimary: Colors.white,
                ),
        ),
        child: child!,
      ),
    );

    if (intervalo == null || !context.mounted) return;
    final ini = _fmtApi(intervalo.start);
    final fim = _fmtApi(intervalo.end);
    await _abrirUrl(
      context,
      url: ApiService.urlPdf(ini, fim),
      successMsg: 'PDF de $ini a $fim aberto!',
    );
  }

  Future<void> _abrirUrl(
    BuildContext context, {
    required String url,
    required String successMsg,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A abrir ficheiro...'),
        duration: Duration(seconds: 3),
      ),
    );
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não foi possível abrir automaticamente'),
            action: SnackBarAction(
              label: 'Copiar URL',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL copiada!')),
                  );
                }
              },
            ),
          ),
        );
      }
    }
  }

  void _snackError(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
        ),
      );

  String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
