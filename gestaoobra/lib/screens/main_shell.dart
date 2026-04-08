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
    _ShellItem('Início', Icons.space_dashboard_outlined, Icons.space_dashboard),
    _ShellItem('Obras', Icons.domain_add_outlined, Icons.domain_add),
    _ShellItem('Equipa', Icons.groups_2_outlined, Icons.groups_2),
    _ShellItem('Gráficos', Icons.insights_outlined, Icons.insights),
    _ShellItem('Config', Icons.tune_outlined, Icons.tune),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        final extendedRail = constraints.maxWidth >= 1220;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(theme.brightness == Brightness.dark ? 0.12 : 0.08),
                  theme.scaffoldBackgroundColor,
                  theme.colorScheme.secondary.withOpacity(theme.brightness == Brightness.dark ? 0.08 : 0.05),
                ],
              ),
            ),
            child: SafeArea(
              child: useRail
                  ? Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
                          child: _buildRail(context, extendedRail),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: IndexedStack(index: _tab, children: _screens),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: IndexedStack(index: _tab, children: _screens),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          bottomNavigationBar: useRail ? null : _buildBottomBar(context),
        );
      },
    );
  }

  Widget _buildRail(BuildContext context, bool extended) {
    final theme = Theme.of(context);

    return Container(
      width: extended ? 232 : 92,
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(theme.brightness == Brightness.dark ? 0.92 : 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.18 : 0.05),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(extended ? 20 : 12, 20, extended ? 20 : 12, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.construction_rounded, color: Colors.white),
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gestão Obra', style: theme.textTheme.titleMedium),
                        Text(
                          'Operação diária',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 212,
              selectedIndex: _tab,
              groupAlignment: -0.9,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: _items
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
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
      ),
    );
  }
}

class _ShellItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _ShellItem(this.label, this.icon, this.selectedIcon);
}
