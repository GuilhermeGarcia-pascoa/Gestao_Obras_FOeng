import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'services/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  await initializeDateFormatting('pt_PT', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const ObrasApp(),
    ),
  );
}

class ObrasApp extends StatelessWidget {
  const ObrasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Obras',
      debugShowCheckedModeBanner: false,

      // ── Localizações (necessário para DateRangePicker) ──────────
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'PT'),
        Locale('en', 'US'),
      ],
      locale: const Locale('pt', 'PT'),

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) =>
            auth.estaAutenticado ? const MainShell() : const LoginScreen(),
      ),
    );
  }
}