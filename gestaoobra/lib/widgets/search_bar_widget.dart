import 'package:flutter/material.dart';

class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final TextEditingController? controller;

  const SearchBarWidget({
    super.key,
    required this.onChanged,
    this.hintText = 'Pesquisar...',
    this.controller,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_updateState);
  }

  @override
  void didUpdateWidget(covariant SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller?.removeListener(_updateState);
    if (oldWidget.controller == null) {
      _controller.dispose();
    }

    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_updateState);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_updateState);
    }
    super.dispose();
  }

  void _updateState() {
    if (!mounted) return;
    setState(() => _hasText = _controller.text.isNotEmpty);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.14 : 0.05),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          gradient: LinearGradient(
            colors: [
              theme.cardColor.withOpacity(isDark ? 0.96 : 0.98),
              theme.colorScheme.surface.withOpacity(isDark ? 0.98 : 0.94),
            ],
          ),
        ),
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
            ),
            suffixIcon: _hasText
                ? IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: _clear,
                  )
                : null,
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ),
    );
  }
}
