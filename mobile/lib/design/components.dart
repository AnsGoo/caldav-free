import 'package:flutter/material.dart';

/// A borderless white sheet used for grouped content.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? scheme.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: content,
            ),
    );
  }
}

/// Large, quiet heading used at the top of a primary tab.
class AppPageTitle extends StatelessWidget {
  const AppPageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 12, 10),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = scheme.primary;
    final verticalPadding = compact ? 20.0 : 36.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28, vertical: verticalPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          // A rotated phone leaves barely 300dp of height, so the empty state
          // has to scroll instead of overflowing. It still centres itself
          // whenever the viewport is tall enough.
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: maxHeight.isFinite ? maxHeight : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: compact ? 48 : 72),
                  Container(
                    width: compact ? 64 : 88,
                    height: compact ? 64 : 88,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(compact ? 20 : 26),
                    ),
                    child: Icon(icon, size: compact ? 30 : 40, color: tint),
                  ),
                  SizedBox(height: compact ? 14 : 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 18), action!],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.destinations,
    required this.onSelected,
    this.onSettings,
    this.userInitial,
  });

  final int index;
  final List<AppNavDestination> destinations;
  final ValueChanged<int> onSelected;

  /// Bottom-right profile entry; hidden when null.
  final VoidCallback? onSettings;

  /// First character of the signed-in username, shown inside the avatar.
  final String? userInitial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == index,
                  activeColor: scheme.primary,
                  inactiveColor: scheme.onSurfaceVariant,
                  onTap: () => onSelected(i),
                ),
              ),
            if (onSettings != null) ...[
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: scheme.outlineVariant,
              ),
              SizedBox(
                width: 46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _UserAvatarButton(
                      onTap: onSettings!,
                      initial: userInitial,
                      size: 36,
                    ),
                    // 与导航项下方的选中点占位对齐，让头像中心和图标中心一致。
                    const SizedBox(height: 3),
                    const SizedBox(width: 4, height: 4),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserAvatarButton extends StatelessWidget {
  const _UserAvatarButton({
    required this.onTap,
    required this.initial,
    this.size = 40,
  });

  final VoidCallback onTap;
  final String? initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasInitial = initial != null && initial!.isNotEmpty;
    return Tooltip(
      message: '设置',
      child: Semantics(
        button: true,
        label: '设置',
        child: Material(
          color: scheme.surface,
          elevation: 1,
          shadowColor: scheme.shadow.withValues(alpha: 0.2),
          shape: CircleBorder(
            side: BorderSide(color: scheme.outline, width: 1.4),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: hasInitial
                    ? Text(
                        initial!,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: size * 0.38,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Icon(
                        Icons.person_outline_rounded,
                        size: size * 0.52,
                        color: scheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// True once the viewport is wide enough to trade the bottom bar for the
/// vertical rail and the task list for a master-detail pane: any landscape
/// phone, plus tablets in either orientation.
bool isWideLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height || size.shortestSide >= 600;
}

/// Vertical companion of [AppBottomNav] for landscape phones and tablets,
/// where a 62dp bar would eat the height the page content needs. Same icon
/// language, same selection dot, no labels and no tooltips.
class AppSideNav extends StatelessWidget {
  const AppSideNav({
    super.key,
    required this.index,
    required this.destinations,
    required this.onSelected,
    this.onSettings,
    this.userInitial,
  });

  final int index;
  final List<AppNavDestination> destinations;
  final ValueChanged<int> onSelected;

  /// Bottom profile entry; hidden when null.
  final VoidCallback? onSettings;

  /// First character of the signed-in username, shown inside the avatar.
  final String? userInitial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      right: false,
      bottom: false,
      child: Container(
        width: 64,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      SizedBox(
                        height: 52,
                        child: _NavItem(
                          destination: destinations[i],
                          selected: i == index,
                          activeColor: scheme.primary,
                          inactiveColor: scheme.onSurfaceVariant,
                          rail: true,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (onSettings != null)
              SizedBox(
                height: 56,
                child: Center(
                  child: _UserAvatarButton(
                    onTap: onSettings!,
                    initial: userInitial,
                  ),
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.rail = false,
  });

  final AppNavDestination destination;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  /// In the vertical rail the selection reads as a filled rounded block
  /// behind the icon; the horizontal bar keeps its quiet underline dot.
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? activeColor : inactiveColor;
    final icon = AnimatedScale(
      scale: selected && !rail ? 1.06 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Icon(
        selected ? destination.selectedIcon : destination.icon,
        size: 24,
        color: color,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(16),
        child: rail
            ? Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: icon),
                ),
              )
            : SizedBox(
                height: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: selected ? 4 : 0,
                      height: 4,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// A compact selectable text tab with a quiet underline.
class AppUnderlineTabs<T> extends StatelessWidget {
  const AppUnderlineTabs({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                hoverColor: scheme.onSurface.withValues(alpha: 0.08),
                onTap: () => onChanged(values[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: values[i] == selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontWeight: values[i] == selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 2.5,
                        width: values[i] == selected ? 22 : 0,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact on/off switch used across the app.
///
/// Material's default switch is 52×32 with a 48×48 tap target, which looks
/// heavy next to the 13–14px labels in settings rows and editor sheets. This
/// keeps the theme colors but paints the control at roughly 80% size.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 42,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 32 / 52,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// Capsule search field: light gray fill, leading search icon, inline clear
/// button, and a thin accent ring only while focused.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 14,
      color: scheme.onSurface,
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: bodyStyle,
      // 全局搜索框保持紧凑，不再显示右侧清空按钮。
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: bodyStyle?.copyWith(color: scheme.onSurfaceVariant),
        isDense: true,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.75),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
