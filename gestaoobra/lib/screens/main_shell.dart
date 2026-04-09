import 'package:flutter/material.dart';

import 'config_screen.dart';
import 'dashboard_screen.dart';
import 'equipa/equipa_screen.dart';
import 'graficos/graficos_screen.dart';
import 'obras/obras_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ObrasListScreen(),
    EquipaScreen(),
    GraficosScreen(),
    ConfigScreen(),
  ];

  static const _items = [
    _ShellItem('Início',   Icons.space_dashboard_outlined, Icons.space_dashboard),
    _ShellItem('Obras',    Icons.domain_add_outlined,      Icons.domain_add),
    _ShellItem('Equipa',   Icons.groups_2_outlined,        Icons.groups_2),
    _ShellItem('Gráficos', Icons.insights_outlined,        Icons.insights),
    _ShellItem('Config',   Icons.tune_outlined,            Icons.tune),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail     = constraints.maxWidth >= 900;
        final extendedRail = constraints.maxWidth >= 1220;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: useRail
                ? Row(
                    children: [
                      _buildRail(context, extendedRail),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: IndexedStack(index: _tab, children: _screens),
                          ),
                        ),
                      ),
                    ],
                  )
                : IndexedStack(index: _tab, children: _screens),
          ),
          bottomNavigationBar: useRail ? null : _buildBottomBar(context),
        );
      },
    );
  }

  Widget _buildRail(BuildContext context, bool extended) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const seed   = Color(0xFF185FA5);

    return Container(
      width: extended ? 220 : 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        border: Border(
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? 20 : 12, 20, extended ? 20 : 12, 16,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: seed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.construction_rounded, color: Colors.white, size: 22),
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestão Obra',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1A2233),
                          ),
                        ),
                        Text(
                          'Operação diária',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 8),

          // Itens
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8, vertical: 4),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item   = _items[i];
                final active = _tab == i;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    onTap: () => setState(() => _tab = i),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: EdgeInsets.symmetric(
                        horizontal: extended ? 14 : 10,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? seed.withOpacity(isDark ? 0.2 : 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: extended
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Icon(
                            active ? item.selectedIcon : item.icon,
                            size: 22,
                            color: active ? seed : (isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478)),
                          ),
                          if (extended) ...[
                            const SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active
                                    ? seed
                                    : (isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        destinations: _items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShellItem {
  final String   label;
  final IconData icon;
  final IconData selectedIcon;

  const _ShellItem(this.label, this.icon, this.selectedIcon);
}