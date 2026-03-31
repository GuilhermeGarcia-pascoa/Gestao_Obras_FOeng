import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                  label: 'Exportar PDF (por semana)',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seleciona uma semana na lista de obras para exportar PDF'))),
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
                _opcao(context, icon: Icons.code,         label: 'Flutter + Node.js + MySQL', onTap: null),
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
                    TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Sair')),
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

  Future<void> _exportarExcel(BuildContext context) async {
    try {
      final obras = await ApiService.listarObras();
      if (!context.mounted || obras.isEmpty) return;

      final obra = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Seleciona a obra'),
          children: obras.map<Widget>((o) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, o),
            child: Text(o['codigo'] ?? ''),
          )).toList(),
        ),
      );

      if (obra == null || !context.mounted) return;
      final url = ApiService.urlExcel(obra['id']);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abre este URL no browser:\n$url')));
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Widget _opcao(BuildContext context, {required IconData icon, required String label, required VoidCallback? onTap}) =>
      ListTile(
        leading: Icon(icon, size: 20, color: const Color(0xFF1A1A2E)),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: onTap != null ? const Icon(Icons.chevron_right, size: 18, color: Colors.grey) : null,
        onTap: onTap,
      );
}
