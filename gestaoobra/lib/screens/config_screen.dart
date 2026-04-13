import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'admin_panel_screen.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final theme  = context.watch<ThemeProvider>();
    final user   = auth.utilizador;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const seed   = Color(0xFF185FA5);

    final cardBg  = isDark ? const Color(0xFF252D3A) : Colors.white;
    final border  = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
    final txtMain = isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233);
    final txtSub  = isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478);
    final iconBg  = isDark ? const Color(0xFF1E2A38) : const Color(0xFFEEF4FB);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Perfil ───────────────────────────────────────────────────────
          _profileCard(user, isDark),
          const SizedBox(height: 20),

          // ── Exportação ───────────────────────────────────────────────────
          _sectionLabel('Exportação', txtSub),
          const SizedBox(height: 8),
          _group(isDark, cardBg, border, [
            _tile(context, Icons.table_chart_outlined, 'Exportar Excel por obra',
                iconBg, seed, txtMain, () => _exportarExcel(context)),
            Divider(height: 1, color: border),
            _tile(context, Icons.picture_as_pdf_outlined, 'Exportar PDF por intervalo',
                iconBg, seed, txtMain, () => _exportarPdf(context)),
          ]),
          const SizedBox(height: 20),

          // ── Aparência ────────────────────────────────────────────────────
          _sectionLabel('Aparência', txtSub),
          const SizedBox(height: 8),
          _group(isDark, cardBg, border, [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final selector = DropdownButton<ThemeMode>(
                    value: theme.themeMode,
                    underline: const SizedBox(),
                    isExpanded: compact,
                    style: TextStyle(color: txtSub, fontSize: 13, fontWeight: FontWeight.w600),
                    dropdownColor: cardBg,
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                      DropdownMenuItem(value: ThemeMode.light,  child: Text('Claro')),
                      DropdownMenuItem(value: ThemeMode.dark,   child: Text('Escuro')),
                    ],
                    onChanged: (v) {
                      if (v != null) context.read<ThemeProvider>().setThemeMode(v);
                    },
                  );

                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.palette_outlined, size: 18, color: seed),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Text('Tema da app', style: TextStyle(color: txtMain, fontSize: 14))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            selector,
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.palette_outlined, size: 18, color: seed),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Text('Tema da app', style: TextStyle(color: txtMain, fontSize: 14))),
                            selector,
                          ],
                        );
                },
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Info ─────────────────────────────────────────────────────────
          _sectionLabel('Informação', txtSub),
          const SizedBox(height: 8),
          _group(isDark, cardBg, border, [
            _tile(context, Icons.info_outline_rounded, 'Versão 1.6.7',
                iconBg, seed, txtMain, null),
            Divider(height: 1, color: border),
            _tile(context, Icons.code_rounded, 'Flutter + Node.js + MySQL',
                iconBg, seed, txtMain, null),
          ]),
          const SizedBox(height: 28),

          // ── Logout ───────────────────────────────────────────────────────
          SizedBox(
            height: 48,
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
                          child: const Text('Cancelar')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sair',
                              style: TextStyle(color: Color(0xFFE53935)))),
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
                foregroundColor: const Color(0xFFE53935),
                side: BorderSide(color: const Color(0xFFE53935).withOpacity(0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // ── Admin ────────────────────────────────────────────────────────
          if (user?['role'] == 'admin') ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                ),
                icon: Icon(Icons.admin_panel_settings_outlined, size: 16, color: txtSub),
                label: Text('Painel de administrador', style: TextStyle(fontSize: 13, color: txtSub)),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _profileCard(Map<String, dynamic>? user, bool isDark) {
    final nome  = user?['nome']  ?? 'Utilizador';
    final email = user?['email'] ?? '';
    final role  = user?['role']  ?? '';

    final roleLabel = switch (role) {
      'admin'      => 'Administrador',
      'gestor'     => 'Gestor',
      'utilizador' => 'Utilizador',
      _            => role,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2B4E), Color(0xFF185FA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final avatar = Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
          );
          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(roleLabel,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        avatar,
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nome,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    badge,
                  ],
                )
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    badge,
                  ],
                );
        },
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.5)),
  );

  Widget _group(bool isDark, Color bg, Color border, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );

  Widget _tile(BuildContext context, IconData icon, String label,
      Color iconBg, Color iconColor, Color textColor, VoidCallback? onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: textColor))),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18,
                  color: isDark ? const Color(0xFF5A6478) : const Color(0xFFADB8C8)),
          ],
        ),
      ),
    );
  }

  // ── Export helpers ────────────────────────────────────────────────────────

  Future<void> _exportarExcel(BuildContext context) async {
    try {
      final obras = await ApiService.listarObras();
      if (!context.mounted) return;
      if (obras.isEmpty) {
        _snackInfo(context, 'Nenhuma obra disponível');
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
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEEF4FB),
                    child: Text(
                      (o['codigo'] ?? '?').toString().substring(0, 1),
                      style: const TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(o['codigo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(o['nome'] ?? ''),
                  onTap: () => Navigator.pop(_, o),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (obra == null || !context.mounted) return;

      final obraId = int.parse(obra['id'].toString());
      final codigo = obra['codigo'] ?? 'obra';

      await _descarregarFicheiro(
        context: context,
        bytes: () => ApiService.downloadExcel(obraId),
        nomeFicheiro: 'excel_${codigo}_${_fmtApi(DateTime.now())}.xlsx',
        successMsg: 'Excel guardado com sucesso!',
      );
    } on ApiException catch (e) {
      if (context.mounted) _snackError(context, e.mensagem);
    }
  }

  Future<void> _exportarPdf(BuildContext context) async {
    final hoje      = DateTime.now();
    final inicioMes = DateTime(hoje.year, hoje.month, 1);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

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
              : const ColorScheme.light(primary: Color(0xFF185FA5), onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );

    if (intervalo == null || !context.mounted) return;

    final ini = _fmtApi(intervalo.start);
    final fim = _fmtApi(intervalo.end);

    await _descarregarFicheiro(
      context: context,
      bytes: () => ApiService.downloadPdf(ini, fim),
      nomeFicheiro: 'relatorio_${ini}_$fim.pdf',
      successMsg: 'PDF guardado ($ini a $fim)!',
    );
  }

  /// Descarrega um ficheiro autenticado, guarda-o localmente e mostra feedback.
  ///
  /// [bytes]        — função assíncrona que chama o ApiService e devolve os bytes.
  /// [nomeFicheiro] — nome do ficheiro a criar no dispositivo.
  /// [successMsg]   — mensagem apresentada no SnackBar de sucesso.
  Future<void> _descarregarFicheiro({
    required BuildContext context,
    required Future<List<int>> Function() bytes,
    required String nomeFicheiro,
    required String successMsg,
  }) async {
    // Feedback imediato ao utilizador
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A descarregar ficheiro…'),
          duration: Duration(seconds: 60), // será cancelado manualmente
        ),
      );
    }

    try {
      // 1. Descarregar bytes com autenticação
      final data = await bytes();

      // 2. Determinar diretório de destino — tentamos múltiplas opções por
      //    ordem de preferência para garantir compatibilidade entre plataformas
      //    e permissões de armazenamento.
      Directory? dir;
      try {
        if (Platform.isAndroid) {
          // getExternalStorageDirectory devolve algo como
          // /storage/emulated/0/Android/data/<pkg>/files — não precisa de
          // permissão WRITE_EXTERNAL_STORAGE em Android 10+.
          dir = await getExternalStorageDirectory();
        }
      } catch (_) {
        dir = null;
      }
      // Fallback universal (funciona em iOS e Android sem permissões extra)
      dir ??= await getApplicationDocumentsDirectory();

      // 3. Garantir que o diretório existe
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 4. Escrever ficheiro
      final file = File('${dir.path}/$nomeFicheiro');
      await file.writeAsBytes(data, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: const Color(0xFF0F9D8A),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copiar caminho',
              textColor: Colors.white,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: file.path));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Caminho copiado!')),
                  );
                }
              },
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _snackError(context, e.mensagem);
      }
    } catch (e, stack) {
      // Mostra o erro real para facilitar diagnóstico
      debugPrint('_descarregarFicheiro erro: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _snackError(context, 'Erro: ${e.toString()}');
      }
    }
  }

  void _snackError(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE53935)),
      );

  void _snackInfo(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

  String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}