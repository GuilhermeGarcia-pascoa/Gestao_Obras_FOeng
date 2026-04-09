import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppBreakpoints {
  static bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 720;
  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 720 && width < 1180;
  }

  static bool isExpanded(BuildContext context) => MediaQuery.sizeOf(context).width >= 1180;
  static double contentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1600) return 1440;
    if (width >= 1280) return 1180;
    if (width >= 960) return 960;
    return width;
  }

  static int columns(BuildContext context, {int compact = 1, int medium = 2, int expanded = 3}) {
    if (isExpanded(context)) return expanded;
    if (isMedium(context)) return medium;
    return compact;
  }
}

class AppShellPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? trailingHeader;
  final EdgeInsetsGeometry? padding;
  final PreferredSizeWidget? bottom;
  final FloatingActionButton? floatingActionButton;
  final Future<void> Function()? onRefresh;

  const AppShellPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.leading,
    this.trailingHeader,
    this.padding,
    this.bottom,
    this.floatingActionButton,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontal = AppBreakpoints.isCompact(context) ? 16.0 : 24.0;
    final maxWidth = AppBreakpoints.contentWidth(context);

    Widget body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
          child: child,
        ),
      ),
    );

    if (onRefresh != null) {
      body = RefreshIndicator(onRefresh: onRefresh!, child: body);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 86,
        titleSpacing: 0,
        leadingWidth: leading != null ? 72 : 20,
        leading: leading == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
                child: leading,
              ),
        title: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailingHeader != null) ...[
                const SizedBox(width: 12),
                trailingHeader!,
              ],
            ],
          ),
        ),
        actions: actions,
        bottom: bottom,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.09),
              theme.scaffoldBackgroundColor,
              theme.colorScheme.secondary.withValues(alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: body,
        ),
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const AppPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: isDark ? 0.92 : 0.97),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(22),
        child: child,
      ),
    );
  }
}

class AppHeroBanner extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final List<Widget> actions;
  final List<Widget> highlights;

  const AppHeroBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.actions = const [],
    this.highlights = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = AppBreakpoints.isCompact(context);
    return Container(
      padding: EdgeInsets.all(isCompact ? 22 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            Color.alphaBlend(
              theme.colorScheme.secondary.withValues(alpha: 0.55),
              theme.colorScheme.primary,
            ),
            const Color(0xFF041B2D),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: isCompact ? 28 : 38,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
          ],
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(spacing: 10, runSpacing: 10, children: highlights),
          ],
        ],
      ),
    );
  }
}

class AppHighlightChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const AppHighlightChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const AppSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class AppStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final Color accentColor;

  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 34, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppAdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int compact;
  final int medium;
  final int expanded;
  final double spacing;
  final double childAspectRatio;

  const AppAdaptiveGrid({
    super.key,
    required this.children,
    this.compact = 1,
    this.medium = 2,
    this.expanded = 4,
    this.spacing = 16,
    this.childAspectRatio = 1.18,
  });

  @override
  Widget build(BuildContext context) {
    final columns = AppBreakpoints.columns(
      context,
      compact: compact,
      medium: medium,
      expanded: expanded,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (columns - 1);
        final width = math.max(0, constraints.maxWidth - totalSpacing);
        final itemWidth = width / columns;
        final itemHeight = itemWidth / childAspectRatio;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  height: itemHeight,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class AppSegmentedOption<T> {
  final T value;
  final String label;
  final IconData icon;

  const AppSegmentedOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class AppSegmentedControl<T> extends StatelessWidget {
  final T value;
  final List<AppSegmentedOption<T>> options;
  final ValueChanged<T> onChanged;

  const AppSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = AppBreakpoints.isCompact(context);

    return AppPanel(
      padding: const EdgeInsets.all(8),
      radius: 22,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          final active = option.value == value;
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onChanged(option.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: active ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    option.icon,
                    size: 16,
                    color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    option.label,
                    style: TextStyle(
                      color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
