import 'package:flutter/material.dart';
import 'obras/obras_list_screen.dart';
import 'equipa/equipa_screen.dart';
import 'graficos/graficos_screen.dart';
import 'config_screen.dart';
import 'dashboard_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label:        'Início',
          ),
          NavigationDestination(
            icon:         Icon(Icons.construction_outlined),
            selectedIcon: Icon(Icons.construction),
            label:        'Obras',
          ),
          NavigationDestination(
            icon:         Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label:        'Equipa',
          ),
          NavigationDestination(
            icon:         Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label:        'Gráficos',
          ),
          NavigationDestination(
            icon:         Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label:        'Config',
          ),
        ],
      ),
    );
  }
}
