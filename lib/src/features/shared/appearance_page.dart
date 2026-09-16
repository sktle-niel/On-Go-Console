import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';

/// The console's Themes screen.
///
/// The same six themes, the same three controls and the same behaviour as the
/// mobile app's Themes screen, because it is the same [ThemeController] behind
/// both. The list is built from [AppThemes.all], so a theme added there shows
/// up here and in the app with no further change.
///
/// Note what this does NOT do: it changes nothing on anyone's phone. Each
/// person picks their own theme, on whichever front end they are using. The
/// only appearance the console reaches across into the app is the Sign In
/// background, which is platform-wide branding and lives on its own screen
/// behind its own permission.
class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  final _controller = ThemeController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _select(AppThemeOption option) async {
    if (option.id == _controller.selectedId) return;
    await _controller.select(option.id);
    if (!mounted) return;
    showConsoleMessage(context, '${option.label} theme applied');
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final dark = _controller.isDarkModeActive;

    return ConsoleShell(
      title: 'Themes',
      subtitle: 'The same themes the On Go app uses',
      showBackButton: true,
      child: ListView(
        padding: consolePagePadding(context),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.formMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConsoleCard(
                  boxedOnPhone: true,
                  title: 'Appearance',
                  subtitle: 'Remembered on this browser',
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Pick a colour theme. It applies across the whole '
                          'console and is remembered the next time you sign in.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DarkModeRow(controller: _controller),
                      Divider(height: 1, color: ConsoleColors.border),
                      _DynamicThemesRow(controller: _controller),
                      Divider(height: 1, color: ConsoleColors.border),
                      _WarmFilterRow(controller: _controller),
                    ],
                  ),
                ),
                SizedBox(height: layout.sectionSpacing),
                ConsoleSectionLabel(dark ? 'Dark themes' : 'Light themes'),
                _ThemeGrid(
                  options: _controller.availableThemes,
                  selectedId: _controller.selectedId,
                  onSelect: _select,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark Mode. Inert while Dynamic Themes owns the light/dark decision, and it
/// says so rather than silently ignoring a tap — same as the app.
class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final dynamicOn = controller.dynamicThemes;
    return ConsoleToggleRow(
      title: 'Dark Mode',
      subtitle: dynamicOn
          ? 'Controlled by Dynamic Themes right now.'
          : 'Show the dark version of each theme.',
      value: controller.isDarkModeActive,
      onChanged: dynamicOn ? null : controller.setDarkMode,
    );
  }
}

/// Dynamic Themes: follow the clock, exactly as the app does.
class _DynamicThemesRow extends StatelessWidget {
  const _DynamicThemesRow({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return ConsoleToggleRow(
      title: 'Dynamic Themes',
      subtitle: 'Follow the time of day — light from '
          '${ThemeController.dayStartHour}:00, dark from '
          '${ThemeController.nightStartHour}:00.',
      value: controller.dynamicThemes,
      onChanged: controller.setDynamicThemes,
    );
  }
}

/// The Warm Filter slider.
class _WarmFilterRow extends StatelessWidget {
  const _WarmFilterRow({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Warm Filter', style: text.titleSmall)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Warms the whole screen for easier reading in low light.',
            style: text.bodySmall,
          ),
          WarmFilterSlider(controller: controller),
        ],
      ),
    );
  }
}

/// The themes available at the current brightness.
///
/// Two across on a wide window, one on a phone — the console's own layout
/// rules applied to the app's own list.
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({
    required this.options,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AppThemeOption> options;
  final String selectedId;
  final ValueChanged<AppThemeOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return ConsoleResponsiveGrid(
      columns: context.layout.isPhone ? 1 : 2,
      spacing: 12,
      children: [
        for (final option in options)
          _ThemeOptionCard(
            option: option,
            selected: option.id == selectedId,
            onTap: () => onSelect(option),
          ),
      ],
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: ConsoleMetrics.borderRadiusLarge,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ConsoleColors.surface,
          borderRadius: ConsoleMetrics.borderRadiusLarge,
          border: Border.all(
            color: selected ? ConsoleColors.brand : ConsoleColors.border,
            width: selected ? AppBorders.regular : AppBorders.thin,
          ),
        ),
        child: Row(
          children: [
            _PalettePreview(palette: option.palette),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? ConsoleColors.brand : ConsoleColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature of the console in a palette: the rail, the canvas, a card and
/// the brand accent — what that theme actually looks like here.
class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadii.borderSm,
        border: Border.all(color: ConsoleColors.border),
      ),
      child: Row(
        children: [
          Container(width: 15, color: palette.primary),
          Expanded(
            child: Container(
              color: palette.background,
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 6,
                    width: 26,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: palette.textmedium.withValues(alpha: 0.3),
                        width: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
