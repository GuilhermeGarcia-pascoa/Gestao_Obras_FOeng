import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'services/auth_provider.dart';
import 'services/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT', null);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..verificarLoginInicial(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const ObrasApp(),
    ),
  );
}

class ObrasApp extends StatefulWidget {
  const ObrasApp({super.key});

  @override
  State<ObrasApp> createState() => _ObrasAppState();
}

class _ObrasAppState extends State<ObrasApp> {
  int? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = Provider.of<AuthProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    final userId = auth.utilizador?['id'] as int?;
    final temaBD = auth.utilizador?['tema_preferido'] as String?;

    if (userId != _lastUserId) {
      _lastUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          theme.setUserId(userId, temaBD: temaBD);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (_, auth, theme, __) => MaterialApp(
        title: 'Obras',
        debugShowCheckedModeBanner: false,
        themeMode: theme.themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
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
        home: auth.estaAutenticado ? const MainShell() : const LoginScreen(),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  const seed = Color(0xFF185FA5);
  const accent = Color(0xFF0F9D8A);
  const warning = Color(0xFFE6824D);

  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    primary: seed,
    secondary: accent,
    tertiary: warning,
    surface: isDark ? const Color(0xFF1E2530) : Colors.white,
  );

  // Cores bem definidas para cada tema
  final cardColor = isDark ? const Color(0xFF252D3A) : Colors.white;
  final scaffoldBg = isDark ? const Color(0xFF161C26) : const Color(0xFFF0F4F8);
  final outlineColor = isDark ? const Color(0xFF374151) : const Color(0xFFDDE3ED);
  final mutedSurface = isDark ? const Color(0xFF1E2738) : const Color(0xFFF5F7FA);
  final onSurfaceColor = isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A2233);
  final onSurfaceVariantColor = isDark ? const Color(0xFF8B9BB4) : const Color(0xFF5A6478);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBg,
    cardColor: cardColor,
    dividerColor: outlineColor,

    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF1E2530) : seed,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),

    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outlineColor),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: seed,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: seed,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: seed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: onSurfaceColor,
        side: BorderSide(color: outlineColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: cardColor,
      indicatorColor: seed.withOpacity(isDark ? 0.25 : 0.12),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? seed
              : onSurfaceVariantColor,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? seed : onSurfaceVariantColor,
        ),
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: seed.withOpacity(isDark ? 0.25 : 0.12),
      selectedIconTheme: IconThemeData(color: seed),
      unselectedIconTheme: IconThemeData(color: onSurfaceVariantColor),
      selectedLabelTextStyle: TextStyle(color: seed, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: TextStyle(color: onSurfaceVariantColor, fontWeight: FontWeight.w500),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: seed,
      textColor: onSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF2A3345) : const Color(0xFF1A2233),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: mutedSurface,
      labelStyle: TextStyle(color: onSurfaceVariantColor, fontSize: 14),
      hintStyle: TextStyle(color: onSurfaceVariantColor.withOpacity(0.6), fontSize: 14),
      prefixIconColor: onSurfaceVariantColor,
      suffixIconColor: onSurfaceVariantColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: seed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: mutedSurface,
      selectedColor: seed.withOpacity(isDark ? 0.25 : 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: outlineColor),
      ),
      side: BorderSide(color: outlineColor),
      labelStyle: TextStyle(color: onSurfaceColor, fontWeight: FontWeight.w600, fontSize: 13),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: seed,
      linearTrackColor: outlineColor,
      circularTrackColor: outlineColor,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outlineColor),
      ),
      textStyle: TextStyle(color: onSurfaceColor, fontSize: 14),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      dividerColor: Colors.transparent,
    ),

    dividerTheme: DividerThemeData(color: outlineColor, thickness: 1, space: 0),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? seed : outlineColor,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: onSurfaceColor,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: onSurfaceColor,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: onSurfaceColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: onSurfaceColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: onSurfaceColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: onSurfaceVariantColor,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onSurfaceColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurfaceVariantColor,
      ),
    ),
  );
}