import 'package:flutter/material.dart';

import '../../app/console_routes.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';

/// The rows both Settings screens are built from.
///
/// Admin and Moderator settings are genuinely different pages — different
/// permissions, different sections — but the rows they share should be one
/// implementation, not two that drift.

/// A navigation row: label, current value, chevron.
class ConsoleSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// When false the row is inert and explains why via [subtitle].
  final bool enabled;

  const ConsoleSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = enabled ? ConsoleColors.text : ConsoleColors.textMuted;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: ConsoleMetrics.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(enabled ? icon : Icons.lock_outline, size: 19, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall?.copyWith(color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
            if (enabled)
              Icon(Icons.chevron_right, size: 20, color: ConsoleColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// The Appearance row, on both Settings screens.
class AppearanceSettingsRow extends StatelessWidget {
  const AppearanceSettingsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final controller = ThemeController.instance;
        final extras = [
          if (controller.dynamicThemes) 'Dynamic',
          if (controller.warmFilter > 0) 'Warm ${controller.warmFilterLabel}',
        ];
        return ConsoleSettingsRow(
          icon: Icons.palette_outlined,
          title: 'Themes',
          subtitle: extras.isEmpty
              ? '${controller.selected.label} theme'
              : '${controller.selected.label} · ${extras.join(' · ')}',
          onTap: () => Navigator.pushNamed(context, ConsoleRoutes.appearance),
        );
      },
    );
  }
}

/// The App Background row. Always available to an admin; a moderator needs
/// `canChangeBackground`, and the row says so when they do not have it.
class BackgroundSettingsRow extends StatelessWidget {
  final bool enabled;

  const BackgroundSettingsRow({super.key, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlatformAppearance>(
      stream: ConsoleBackend.instance.appearance.watch(),
      initialData: PlatformAppearance.none,
      builder: (context, snapshot) {
        final appearance = snapshot.data ?? PlatformAppearance.none;
        return ConsoleSettingsRow(
          icon: Icons.image_outlined,
          title: 'App background',
          enabled: enabled,
          subtitle: enabled
              ? (appearance.hasBackground
                  ? 'A photo is published for the mobile app'
                  : 'Mobile app uses its theme background color')
              : 'Your admin has not given you this permission',
          onTap: () => Navigator.pushNamed(context, ConsoleRoutes.background),
        );
      },
    );
  }
}

/// A settings card: label, then rows separated by hairlines.
class ConsoleSettingsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const ConsoleSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return ConsoleCard(
      // The Settings screens used all-caps section labels on a phone;
      // sentence case is the desktop panel's heading style.
      title: layout.isPhone ? title.toUpperCase() : title,
      subtitle: layout.isPhone ? null : subtitle,
      padding: layout.isPhone
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: ConsoleColors.border),
            children[i],
          ],
        ],
      ),
    );
  }
}
