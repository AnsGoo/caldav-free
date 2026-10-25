import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

Future<String?> showThemeSheet(
  BuildContext context, {
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ThemeSheet(current: current),
  );
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('主题颜色', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '选择一个强调色，立即应用到任务、日历、习惯、专注和倒数。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
              children: [
                for (final accent in appAccents)
                  _AccentTile(
                    accent: accent,
                    selected: accent.hex.toUpperCase() == current.toUpperCase(),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '深色模式会使用同一色系的浅色变体。主题保存在本机。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentTile extends StatelessWidget {
  const _AccentTile({required this.accent, required this.selected});

  final AppAccent accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: accent.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, accent.hex),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: scheme.onSurface, width: 2.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: accent.color.withValues(alpha: 0.24),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 24,
                      color: accent.color.computeLuminance() > 0.55
                          ? const Color(0xFF07122F)
                          : Colors.white,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              accent.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
