import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_go_console/src/theme/console_theme.dart';

/// The console and the mobile app are meant to be one theme system, not two
/// that resemble each other. These assert the part that would otherwise rot
/// quietly: that the console's colours are *derived* from the shared palettes
/// rather than copied, so a change to a palette reaches both front ends.

void main() {
  setUp(() async {
    // Each test drives the shared controller directly, so reset the parts that
    // persist between them.
    await ThemeController.instance.setDynamicThemes(false);
    await ThemeController.instance.setDarkMode(false);
    await ThemeController.instance.setWarmFilter(0);
    await ThemeController.instance.select(AppThemes.defaultId);
  });

  group('shared theme registry', () {
    test('the console offers exactly the themes the app does', () {
      expect(
        AppThemes.all.map((option) => option.label).toList(),
        [
          'Default',
          'Dark Default',
          'Calm Blue',
          'Cold Blue',
          'Ember Light',
          'Ember',
          'Forest',
          'Forest Night',
        ],
      );
    });

    test('every theme belongs to a light/dark pair', () {
      for (final option in AppThemes.all) {
        final counterpart = AppThemes.variantOf(option, dark: !option.isDark);
        expect(
          counterpart.isDark,
          !option.isDark,
          reason: '${option.label} has no ${option.isDark ? 'light' : 'dark'} twin',
        );
        expect(counterpart.family, option.family);
      }
    });
  });

  group('ConsoleColors derive from the active palette', () {
    test('brand, canvas and text follow the selected theme', () async {
      await ThemeController.instance.select(AppThemes.defaultId);
      final light = AppThemes.byId(AppThemes.defaultId).palette;
      expect(ConsoleColors.brand, light.primary);
      expect(ConsoleColors.canvas, light.background);
      expect(ConsoleColors.text, light.textdark);

      await ThemeController.instance.select('ember');
      final ember = AppThemes.byId('ember').palette;
      expect(ConsoleColors.brand, ember.primary);
      expect(ConsoleColors.canvas, ember.background);
      expect(ConsoleColors.text, ember.textdark);
    });

    test('the sidebar is the brand colour, as the app paints its app bars',
        () async {
      await ThemeController.instance.select('blue');
      expect(ConsoleColors.sidebar, AppThemes.byId('blue').palette.primary);
      expect(ConsoleColors.onSidebar, AppThemes.byId('blue').palette.textlight);
    });

    test('status colours are the palette roles, not console inventions', () {
      final palette = AppColors.palette;
      expect(ConsoleColors.success, palette.success);
      expect(ConsoleColors.warning, palette.warning);
      expect(ConsoleColors.danger, palette.error);
      expect(ConsoleColors.info, palette.info);
    });
  });

  group('Dark Mode, Dynamic Themes and the Warm Filter', () {
    test('Dark Mode swaps to the same family in the other brightness',
        () async {
      await ThemeController.instance.select('blue');
      expect(ThemeController.instance.selected.isDark, isFalse);

      await ThemeController.instance.setDarkMode(true);
      expect(ThemeController.instance.selected.isDark, isTrue);
      // Same identity, other brightness — not a jump to some other theme.
      expect(ThemeController.instance.selected.family, 'blue');
      expect(ConsoleColors.canvas, AppThemes.byId('blue_dark').palette.background);
    });

    test('Dynamic Themes takes the brightness decision over', () async {
      await ThemeController.instance.setDynamicThemes(true);
      expect(ThemeController.instance.dynamicThemes, isTrue);
      // Whatever the clock says, the selected theme agrees with it.
      expect(
        ThemeController.instance.selected.isDark,
        ThemeController.isNightNow,
      );
      await ThemeController.instance.setDynamicThemes(false);
    });

    test('the theme picker only ever offers one brightness at a time', () async {
      await ThemeController.instance.setDarkMode(false);
      expect(
        ThemeController.instance.availableThemes.every((o) => !o.isDark),
        isTrue,
      );

      await ThemeController.instance.setDarkMode(true);
      expect(
        ThemeController.instance.availableThemes.every((o) => o.isDark),
        isTrue,
      );
    });

    test('the Warm Filter is off at 0 and warms as it rises', () {
      expect(AppWarmFilter.tintFor(0), isNull);

      final low = AppWarmFilter.tintFor(3)!;
      final high = AppWarmFilter.tintFor(ThemeController.maxWarmFilter)!;
      // Warmer means less blue: the tint multiplies the whole UI.
      expect(high.b, lessThan(low.b));
      expect(high.r, closeTo(1.0, 0.001));
    });

    test('the Warm Filter wraps the tree only when it is on', () {
      const child = SizedBox.shrink();
      expect(AppWarmFilter.wrap(0, child), same(child));
      expect(AppWarmFilter.wrap(5, child), isA<ColorFiltered>());
    });

    test('the level is clamped to the shared range', () async {
      await ThemeController.instance.setWarmFilter(99);
      expect(ThemeController.instance.warmFilter, ThemeController.maxWarmFilter);

      await ThemeController.instance.setWarmFilter(-4);
      expect(ThemeController.instance.warmFilter, 0);
    });
  });

  group('ConsoleTheme.of', () {
    test('carries the palette into ThemeData for every theme', () {
      for (final option in AppThemes.all) {
        final theme = ConsoleTheme.of(option);
        expect(theme.colorScheme.primary, option.palette.primary,
            reason: option.label);
        expect(theme.scaffoldBackgroundColor, option.palette.background,
            reason: option.label);
        expect(
          theme.brightness,
          option.isDark ? Brightness.dark : Brightness.light,
          reason: option.label,
        );
      }
    });

    test('keeps the app\'s pill buttons and corner scale', () {
      final theme = ConsoleTheme.of(AppThemes.all.first);
      final shape = theme.elevatedButtonTheme.style?.shape
          ?.resolve(const <WidgetState>{});
      expect(shape, isA<StadiumBorder>());

      final card = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(card.borderRadius, AppRadii.borderLg);
    });
  });
}
