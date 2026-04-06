import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.utilizador;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Perfil
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFE6F1FB),
                    child: Text(
                      (user?['nome'] ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF185FA5)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user?['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      Text(user?['role'] ?? '', style: const TextStyle(color: Color(0xFF185FA5), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Exportação
          const Text('Exportação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _opcao(
                  context,
                  icon: Icons.table_chart_outlined,
                  label: 'Exportar Excel (por obra)',
                  onTap: () => _exportarExcel(context),
                ),
                const Divider(height: 1),
                _opcao(
                  context,
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Exportar PDF (por intervalo de datas)',
                  onTap: () => _exportarPdf(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('Informação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _opcao(context, icon: Icons.info_outline, label: 'Versão 1.0.0', onTap: null),
                const Divider(height: 1),
                _opcao(context, icon: Icons.code, label: 'Flutter + Node.js + MySQL', onTap: null),
              ],
            ),
          ),

          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Terminar sessão'),
                  content: const Text('Tens a certeza que queres sair?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
                  ],
                ),
              );
              if (ok == true && context.mounted) context.read<AuthProvider>().logout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Terminar sessão'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  // ── Excel ─────────────────────────────────────────────────────────
  Future<void> _exportarExcel(BuildContext context) async {
    try {
      final obras = await ApiService.listarObras();
      if (!context.mounted) return;

      if (obras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma obra disponível para exportar')),
        );
        return;
      }

      // Diálogo para escolher a obra
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
                  leading: const Icon(Icons.business, color: Color(0xFF185FA5)),
                  title: Text(o['codigo'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
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
        url: ApiService.urlExcel(obra['id'] as int),
        successMsg: 'Excel da obra "${obra['codigo']}" aberto!',
      );
    } on ApiException catch (e) {
      if (context.mounted) _mostrarErro(context, e.mensagem);
    } catch (e) {
      if (context.mounted) _mostrarErro(context, e.toString());
    }
  }

  // ── PDF ───────────────────────────────────────────────────────────
  Future<void> _exportarPdf(BuildContext context) async {
    // Pedir intervalo de datas
    final hoje = DateTime.now();
    final inicioMes = DateTime(hoje.year, hoje.month, 1);

    final intervalo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year + 1),
      initialDateRange: DateTimeRange(start: inicioMes, end: hoje),
      locale: const Locale('pt', 'PT'),
      helpText: 'Selecciona o intervalo de datas',
      cancelText: 'Cancelar',
      confirmText: 'Exportar',
      saveText: 'Exportar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF185FA5),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (intervalo == null || !context.mounted) return;

    final dataInicio = _fmtParaApi(intervalo.start);
    final dataFim    = _fmtParaApi(intervalo.end);

    await _abrirUrl(
      context,
      url: ApiService.urlPdf(dataInicio, dataFim),
      successMsg: 'PDF de $dataInicio a $dataFim aberto!',
    );
  }

  // ── Helper: abrir URL no browser ──────────────────────────────────
  Future<void> _abrirUrl(BuildContext context, {required String url, required String successMsg}) async {
    // Mostrar loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 16),
            Text('A abrir ficheiro...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
        );
      }
    } else {
      // Fallback: copiar URL
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
                    const SnackBar(content: Text('URL copiada!'), duration: Duration(seconds: 2)),
                  );
                }
              },
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void _mostrarErro(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro: $msg'), backgroundColor: Colors.red),
    );
  }

  String _fmtParaApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _opcao(BuildContext context, {required IconData icon, required String label, required VoidCallback? onTap}) =>
      ListTile(
        leading: Icon(icon, size: 20, color: const Color(0xFF1A1A2E)),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: onTap != null ? const Icon(Icons.chevron_right, size: 18, color: Colors.grey) : null,
        onTap: onTap,
      );
}