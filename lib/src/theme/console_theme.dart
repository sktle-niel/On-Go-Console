import 'package:flutter/material.dart';
import 'package:on_go_design/on_go_design.dart';

export 'package:on_go_design/on_go_design.dart';

export 'console_layout.dart';

/// The console's colours.
///
/// Every one of these is derived from the palette the shared
/// [ThemeController] has in force — the same controller, the same six themes
/// and the same Dark Mode / Dynamic Themes / Warm Filter the mobile app uses.
/// There is no second set of colour values here to drift from the app's.
///
/// What this class is, then, is a *naming* layer: the console's screens talk
/// about a sidebar and a canvas and a border, which is how a desktop tool is
/// built, and each of those resolves to one of the palette's semantic roles.
/// Keeping the vocabulary means the pages did not have to change; deriving the
/// values means they cannot disagree with the app.
class ConsoleColors {
  ConsoleColors._();

  static AppPalette get _p => AppColors.palette;

  /// Brand colour — the app bar, the sidebar, primary buttons.
  static Color get brand => _p.primary;

  /// The pressed/deeper shade of [brand].
  static Color get brandStrong => _p.primarydark;

  /// The page background behind cards and tables.
  static Color get canvas => _p.background;

  /// Cards, panels and the top bar.
  static Color get surface => _p.surface;

  /// A recessed surface inside a card: table headers, field wells, the inside
  /// of an empty state.
  ///
  /// The app has no such role — nothing on a phone nests two surfaces deep —
  /// so it is mixed here rather than invented as a new palette entry, which
  /// would mean editing six palettes for one console detail.
  static Color get surfaceMuted => Color.alphaBlend(
    _p.textmedium.withValues(alpha: AppColors.isDark ? 0.10 : 0.05),
    _p.background,
  );

  /// Hairlines, outlines and dividers. The same weight the app's dividers use.
  static Color get border => _p.textmedium.withValues(alpha: 0.3);

  /// High-emphasis text.
  static Color get text => _p.textdark;

  /// Secondary text, hints and disabled states.
  static Color get textMuted => _p.textmedium;

  /// Text drawn on [brand].
  static Color get textInverse => _p.textlight;

  /// The navigation rail. The app paints its drawer header and app bars in
  /// [AppPalette.primary]; the rail is the console's counterpart, so it is the
  /// same colour rather than a console-only near-black.
  static Color get sidebar => _p.primary;

  /// The selected and hovered states inside the rail — the brand colour
  /// deepened, so the rail stays one surface instead of gaining a second one.
  static Color get sidebarHover => _p.primarydark;

  /// Secondary text and icons in the rail.
  static Color get sidebarText => _p.textlight.withValues(alpha: 0.78);

  /// Full-emphasis text, icons and markers drawn on the rail.
  ///
  /// The rail is painted in [brand] now, so anything that used to pick out an
  /// element *with* the brand colour has to pick it out against it instead —
  /// this is that colour, and it is the same "on primary" role the app's app
  /// bars use.
  static Color get onSidebar => _p.textlight;

  /// Hairlines inside the rail.
  static Color get sidebarDivider => _p.textlight.withValues(alpha: 0.16);

  /// A raised chip on the rail: the logo tile, the avatar backing.
  static Color get sidebarRaised => _p.textlight.withValues(alpha: 0.16);

  static Color get info => _p.info;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get danger => _p.error;
}

/// Layout constants the console lays itself out on.
///
/// A desktop tool wants a handful of shared measurements far more than a phone
/// does — the rail has to be one width everywhere, content has to stop growing
/// at the same place on every page, and every breakpoint decision has to agree.
///
/// The corner radii come from the shared [AppRadii] scale, so a card here is
/// rounded exactly like a card in the app.
class ConsoleMetrics {
  ConsoleMetrics._();

  /// Width of the navigation rail when it is pinned open.
  static const double sidebarWidth = 248;

  /// Width of the icon-only rail a tablet gets instead.
  static const double collapsedSidebarWidth = 72;

  /// Height of the bar above the content.
  static const double topBarHeight = 62;

  /// Content stops growing here; wider viewports get margins instead of
  /// 2000-pixel-long table rows.
  static const double contentMaxWidth = 1180;

  /// Below this the rail collapses into a drawer.
  static const double railBreakpoint = 1080;

  /// Below this, two-column grids fold to one.
  static const double compactBreakpoint = 760;

  static const double gutter = 24;
  static const double cardPadding = 20;

  /// Controls and small surfaces use the app's medium step; cards use its
  /// large one — the same two radii the app's cards and fields use.
  // Both read from the UI Style system, so a radius changed in
  // `ui_container_styles.dart` reaches the console as well as the app.
  static double get radius => AppOutlinedContainers.field.radius;
  static double get radiusLarge => AppOutlinedContainers.card.radius;

  static BorderRadius get borderRadius => AppOutlinedContainers.field.borderRadius;
  static BorderRadius get borderRadiusLarge => AppOutlinedContainers.card.borderRadius;

  /// How long a toast stays up. The console's lists do not repaint as fast as
  /// the app's, so a message gets a beat longer to be read.
  static const Duration snackBar = Duration(seconds: 2);
}

/// Builds the console's [ThemeData] from a shared [AppThemeOption].
///
/// Same palettes, same theme names, same brand shapes as the mobile app — the
/// pill buttons and the [AppRadii] corners are the app's visual signature and
/// they are kept. What differs is density: tighter type, controls that size to
/// their content instead of filling the width, and hover states, because this
/// is used with a mouse for hours rather than tapped at arm's length.
class ConsoleTheme {
  ConsoleTheme._();

  /// The [ThemeData] for whichever theme is in force right now.
  static ThemeData get current => of(ThemeController.instance.selected);

  static ThemeData of(AppThemeOption option) {
    final c = option.palette;
    final border = c.textmedium.withValues(alpha: 0.3);
    final muted = Color.alphaBlend(
      c.textmedium.withValues(alpha: option.isDark ? 0.10 : 0.05),
      c.background,
    );

    final scheme =
        (option.isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              primary: c.primary,
              onPrimary: c.textlight,
              secondary: c.info,
              surface: c.surface,
              onSurface: c.textdark,
              error: c.error,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: option.isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      dividerColor: border,
      // The same family the app sets, so type matches across the product.
      fontFamily: AppTextStyles.fontFamily,
      visualDensity: VisualDensity.compact,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.primary,
        foregroundColor: c.textlight,
        elevation: AppElevation.flat,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textlight,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: c.textlight),
      ),
      // Sizes, weights and typeface come from the UI Style system, shared with
      // the mobile app; the two colours come from the palette. The console
      // scales up because a monitor is read from further away than a phone —
      // see `AppTextScale`.
      textTheme: AppText.textTheme(
        scale: AppTextScale.desktop,
        color: c.textdark,
        mutedColor: c.textmedium,
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: AppBorders.thin,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: AppElevation.flat,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderLg,
          side: BorderSide(color: border),
        ),
      ),
      // Pills, like the app. The console's are sized to their label rather
      // than stretched to the width of a phone.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.textlight,
          disabledBackgroundColor: border,
          disabledForegroundColor: c.textmedium,
          elevation: AppElevation.flat,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: AppRadii.pill,
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textdark,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: BorderSide(color: border),
          shape: AppRadii.pill,
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: AppRadii.pill,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.textmedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // The app fills its fields with `background` against a `surface` card;
        // the console does the same, so a form reads identically.
        fillColor: muted,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: TextStyle(color: c.textmedium, fontSize: 13.5),
        labelStyle: TextStyle(color: c.textmedium, fontSize: 13.5),
        border: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: border, width: AppBorders.thin),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: border, width: AppBorders.thin),
        ),
        // A focused field steps up to the regular border weight, as in the app.
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: c.primary, width: AppBorders.regular),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: c.error, width: AppBorders.thin),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: c.error, width: AppBorders.regular),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.modal,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderXl),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: c.textdark,
        ),
        contentTextStyle: TextStyle(fontSize: 13.5, color: c.textdark),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textdark,
        contentTextStyle: TextStyle(color: c.background, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        elevation: AppElevation.popover,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.textdark,
          borderRadius: AppRadii.borderSm,
        ),
        textStyle: TextStyle(color: c.surface, fontSize: 12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.textlight
              : c.textmedium.withValues(alpha: 0.55),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.primary : c.background,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.primary : c.textmedium,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: border,
        thumbColor: c.primary,
        overlayColor: c.primary.withValues(alpha: 0.12),
        valueIndicatorColor: c.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderXs),
      ),
      chipTheme: const ChipThemeData(shape: AppRadii.pill),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: border,
        borderRadius: AppRadii.borderXs,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          c.textmedium.withValues(alpha: 0.4),
        ),
        radius: const Radius.circular(AppRadii.sm),
        thickness: WidgetStateProperty.all(8),
      ),
    );
  }
}
