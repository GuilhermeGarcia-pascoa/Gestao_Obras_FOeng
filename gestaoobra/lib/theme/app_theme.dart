import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── DESIGN TOKENS ───────────────────────────────────────────────────────────
// Paleta centralizada — muda aqui, reflecte em toda a app
class AppColors {
  AppColors._();

  // Brand
  static const navy       = Color(0xFF1A3A5C);
  static const navyLight  = Color(0xFF234B78);
  static const teal       = Color(0xFF0F9D8A);
  static const tealLight  = Color(0xFFE1F5EE);
  static const amber      = Color(0xFFE6824D);
  static const amberLight = Color(0xFFFAEEDA);
  static const green      = Color(0xFF3B6D11);
  static const greenLight = Color(0xFFEAF3DE);

  // Neutrals
  static const gray900 = Color(0xFF1C1C1E);
  static const gray800 = Color(0xFF2C2C2E);
  static const gray700 = Color(0xFF3A3A3C);
  static const gray600 = Color(0xFF5F5E5A);
  static const gray400 = Color(0xFF888780);
  static const gray200 = Color(0xFFD3D1C7);
  static const gray100 = Color(0xFFF1EFE8);
  static const gray50  = Color(0xFFF8F7F4);

  // Semantic
  static const success = Color(0xFF3B6D11);
  static const successSurface = Color(0xFFEAF3DE);
  static const warning = Color(0xFF854F0B);
  static const warningSurface = Color(0xFFFAEEDA);
  static const danger  = Color(0xFFA32D2D);
  static const dangerSurface  = Color(0xFFFCEBEB);
  static const info    = Color(0xFF185FA5);
  static const infoSurface    = Color(0xFFE6F1FB);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.light,
      primary:    AppColors.navy,
      secondary:  AppColors.teal,
      tertiary:   AppColors.amber,
      surface:    Colors.white,
      surfaceContainerLowest: AppColors.gray50,
      surfaceContainerLow: AppColors.gray100,
      onSurface: AppColors.gray900,
      onSurfaceVariant: AppColors.gray600,
    );

    return _build(base, scheme, isDark: false);
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.dark,
      primary:    const Color(0xFF6FA8DC),
      secondary:  const Color(0xFF5DCAA5),
      tertiary:   const Color(0xFFF0997B),
      surface:    const Color(0xFF1C1C1E),
      surfaceContainerLowest: const Color(0xFF141416),
      surfaceContainerLow: const Color(0xFF242426),
      onSurface: const Color(0xFFF5F4F0),
      onSurfaceVariant: const Color(0xFFB0AFA8),
    );

    return _build(base, scheme, isDark: true);
  }

  static ThemeData _build(ThemeData base, ColorScheme scheme, {required bool isDark}) {
    final cardBg    = isDark ? const Color(0xFF242426) : Colors.white;
    final scaffoldBg = isDark ? const Color(0xFF141416) : AppColors.gray50;
    final divider   = isDark ? const Color(0xFF38383A) : const Color(0xFFE8E7E2);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      dividerColor: divider,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: 'SF Pro Display',
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        shape: Border(
          bottom: BorderSide(
            color: divider,
            width: 0.5,
          ),
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: divider, width: 0.5),
        ),
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: scheme.primary,
      ),

      // ── ElevatedButton ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF6FA8DC) : AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: divider, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // ── FilledButton ──────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: isDark ? const Color(0xFF6FA8DC) : AppColors.navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? const Color(0xFF6FA8DC) : AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),

      // ── Input ─────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF2C2C2E)
            : AppColors.gray50,
        hoverColor: Colors.transparent,
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withOpacity(0.6),
          fontSize: 14,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF6FA8DC) : AppColors.navy,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 0.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      // ── NavigationBar ─────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        indicatorColor: isDark
            ? const Color(0xFF6FA8DC).withOpacity(0.18)
            : AppColors.navy.withOpacity(0.10),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFF6FA8DC) : AppColors.navy)
              : scheme.onSurfaceVariant,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFF6FA8DC) : AppColors.navy)
              : scheme.onSurfaceVariant,
        )),
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── NavigationRail ────────────────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: isDark
            ? const Color(0xFF6FA8DC).withOpacity(0.18)
            : AppColors.navy.withOpacity(0.10),
        selectedIconTheme: IconThemeData(
          color: isDark ? const Color(0xFF6FA8DC) : AppColors.navy,
          size: 22,
        ),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
        selectedLabelTextStyle: TextStyle(
          color: isDark ? const Color(0xFF6FA8DC) : AppColors.navy,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        useIndicator: true,
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : AppColors.gray100,
        selectedColor: isDark
            ? const Color(0xFF6FA8DC).withOpacity(0.2)
            : AppColors.navy.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: divider, width: 0.5),
        ),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // ── BottomSheet ───────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: divider,
      ),

      // ── Snackbar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF323236) : AppColors.gray800,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 0,
      ),

      // ── Progress ──────────────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? const Color(0xFF6FA8DC) : AppColors.navy,
        linearTrackColor: divider,
        circularTrackColor: divider,
        strokeWidth: 2.5,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 0,
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? (isDark ? const Color(0xFF6FA8DC) : AppColors.navy)
                : divider),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── PopupMenu ─────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: cardBg,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: divider, width: 0.5),
        ),
        textStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),

      // ── Tab ───────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.08)),
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.start,
      ),

      // ── Typography ────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
          height: 1.3,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── WIDGET HELPERS ───────────────────────────────────────────────────────────
/// Badge de estado de obra
class EstadoBadge extends StatelessWidget {
  final String estado;
  const EstadoBadge(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final (text, fg, bg) = switch (estado) {
      'em_curso'  => ('Em curso',  AppColors.green,   AppColors.greenLight),
      'planeada'  => ('Planeada',  AppColors.info,    AppColors.infoSurface),
      'concluida' => ('Concluída', AppColors.gray600,  AppColors.gray100),
      _           => (estado,      AppColors.warning, AppColors.warningSurface),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Avatar com inicial
class InitialAvatar extends StatelessWidget {
  final String text;
  final double size;
  final Color? bg;
  final Color? fg;
  final double radius;

  const InitialAvatar(
    this.text, {
    super.key,
    this.size = 40,
    this.bg,
    this.fg,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = bg ?? (isDark ? const Color(0xFF2C3A4A) : AppColors.infoSurface);
    final fgColor = fg ?? (isDark ? const Color(0xFF6FA8DC) : AppColors.navy);
    final letter = text.isNotEmpty ? text[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: fgColor,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Chip de informação
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withOpacity(0.85)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de KPI
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242426) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF38383A) : const Color(0xFFE8E7E2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Separador com label
class LabeledDivider extends StatelessWidget {
  final String label;
  const LabeledDivider(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.dividerColor, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.dividerColor, thickness: 0.5)),
        ],
      ),
    );
  }
}

/// Secção com título
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Container do Hero da app (fundo navy escuro com chips)
class HeroContainer extends StatelessWidget {
  final Widget child;
  final bool compact;

  const HeroContainer({super.key, required this.child, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, compact ? 14 : 20, 20, compact ? 14 : 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A38) : AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Card de obra reutilizável na lista
class ObraListTile extends StatelessWidget {
  final Map<String, dynamic> obra;
  final VoidCallback onTap;

  const ObraListTile({super.key, required this.obra, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF242426) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF38383A) : const Color(0xFFE8E7E2),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              InitialAvatar(
                obra['codigo'] ?? '?',
                size: 44,
                radius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obra['codigo'] ?? '',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      obra['nome'] ?? '',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              EstadoBadge(obra['estado'] ?? ''),
            ],
          ),
        ),
      ),
    );
  }
}
