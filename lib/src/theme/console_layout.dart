import 'package:flutter/material.dart';

import 'console_theme.dart';

/// The device class the console is being used on.
///
/// Three, because there are three genuinely different ways this tool gets
/// held: a mouse and a wide window, a tablet in the hand or on a stand, and a
/// phone. Anything finer than that produces breakpoints nobody can reason
/// about; anything coarser makes a phone wear a desktop's layout.
enum ConsoleFormFactor {
  /// Under [ConsoleLayout.tabletMin]. One column, drawer plus bottom bar,
  /// stacked rows instead of tables.
  phone,

  /// Between [ConsoleLayout.tabletMin] and [ConsoleLayout.desktopMin]. Two
  /// columns, an icon rail once there is room for one, tables that scroll.
  tablet,

  /// [ConsoleLayout.desktopMin] and up. The pinned rail, four columns, full
  /// tables.
  desktop,
}

/// Everything layout-related that depends on how big the window is.
///
/// One object rather than breakpoint checks scattered through the pages: a
/// screen asks for `layout.gutter` or `layout.statColumns` and gets an answer
/// that agrees with every other screen. Adding a device class later means
/// changing this file, not thirty `if (width > 900)`s.
///
/// Read it with [ConsoleLayout.of], which is available inside any page under
/// the console shell.
@immutable
class ConsoleLayout {
  /// Below this width the console is a phone.
  static const double tabletMin = 640;

  /// At or above this width the rail pins open and content goes wide.
  static const double desktopMin = 1080;

  /// The narrowest window that still fits an icon-only rail beside the
  /// content. Under it, navigation collapses into the drawer.
  static const double iconRailMin = 860;

  final ConsoleFormFactor formFactor;

  /// The width the console has to lay itself out in.
  final double width;

  /// The height, for the handful of decisions that need it — a short landscape
  /// phone should not be handed a 300-pixel-tall preview.
  final double height;

  const ConsoleLayout({
    required this.formFactor,
    required this.width,
    required this.height,
  });

  /// Derives the layout from [width] alone, which is what every caller
  /// actually has.
  factory ConsoleLayout.fromSize(Size size) {
    final ConsoleFormFactor formFactor;
    if (size.width < tabletMin) {
      formFactor = ConsoleFormFactor.phone;
    } else if (size.width < desktopMin) {
      formFactor = ConsoleFormFactor.tablet;
    } else {
      formFactor = ConsoleFormFactor.desktop;
    }
    return ConsoleLayout(
      formFactor: formFactor,
      width: size.width,
      height: size.height,
    );
  }

  /// The layout in force at [context].
  ///
  /// Falls back to reading `MediaQuery` when nothing has provided one, so a
  /// dialog — which is built outside the shell's subtree — still gets the
  /// right answer.
  static ConsoleLayout of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_ConsoleLayoutScope>();
    if (inherited != null) return inherited.layout;
    return ConsoleLayout.fromSize(MediaQuery.sizeOf(context));
  }

  bool get isPhone => formFactor == ConsoleFormFactor.phone;
  bool get isTablet => formFactor == ConsoleFormFactor.tablet;
  bool get isDesktop => formFactor == ConsoleFormFactor.desktop;

  /// True on anything that is not a desktop — the cases that stack rather than
  /// sit side by side.
  bool get isCompact => !isDesktop;

  // ------------------------------------------------------------ navigation ---

  /// The full 248-pixel rail sits beside the content.
  bool get railPinned => isDesktop;

  /// An icon-only rail sits beside the content: wide enough to keep navigation
  /// on screen, narrow enough not to eat the page.
  bool get railCollapsed => !isDesktop && width >= iconRailMin;

  /// Navigation lives in the drawer, reached from the top bar.
  bool get railInDrawer => !railPinned && !railCollapsed;

  /// A phone also gets a bottom bar, so the destinations people use most are
  /// one thumb away instead of two taps into a drawer.
  bool get showsBottomNav => isPhone;

  /// Width of whichever rail is showing, or zero when it is in the drawer.
  double get railWidth => railPinned
      ? ConsoleMetrics.sidebarWidth
      : railCollapsed
          ? ConsoleMetrics.collapsedSidebarWidth
          : 0;

  // ---------------------------------------------------------------- metrics ---

  /// Space around a page's content.
  double get gutter => switch (formFactor) {
        ConsoleFormFactor.phone => 14,
        ConsoleFormFactor.tablet => 20,
        ConsoleFormFactor.desktop => ConsoleMetrics.gutter,
      };

  /// Space between stacked cards.
  double get sectionSpacing => switch (formFactor) {
        ConsoleFormFactor.phone => 14,
        ConsoleFormFactor.tablet => 20,
        ConsoleFormFactor.desktop => ConsoleMetrics.gutter,
      };

  /// Padding inside a card.
  double get cardPadding => switch (formFactor) {
        ConsoleFormFactor.phone => 14,
        ConsoleFormFactor.tablet => 18,
        ConsoleFormFactor.desktop => ConsoleMetrics.cardPadding,
      };

  /// Height of the bar above the content.
  double get topBarHeight => isPhone ? 56 : ConsoleMetrics.topBarHeight;

  /// The page's own padding.
  EdgeInsets get pagePadding => EdgeInsets.all(gutter);

  /// Content stops growing here. A phone and a tablet use everything they
  /// have; a desktop stops before rows get unreadably long.
  double get contentMaxWidth =>
      isDesktop ? ConsoleMetrics.contentMaxWidth : double.infinity;

  /// The cap on a form or settings column, which wants to be narrower than a
  /// table even on a big screen.
  double get formMaxWidth => isDesktop ? 720 : double.infinity;

  // ----------------------------------------------------------------- content ---

  /// Columns in the dashboard stat grid.
  ///
  /// Two on a phone, not one: the Admin panel's four figures read as a 2×2
  /// block, and a single column turns a glance into a scroll.
  int get statColumns => switch (formFactor) {
        ConsoleFormFactor.phone => 2,
        ConsoleFormFactor.tablet => 2,
        ConsoleFormFactor.desktop => 4,
      };

  /// Whether a pair of side-by-side panels should stack instead.
  bool get stacksPairs => width < 760;

  /// Whether list rows that are tables on a big screen should be rendered as
  /// stacked cards.
  ///
  /// A table squeezed onto a phone is either unreadable or a sideways scroll
  /// nobody finds. The same records, one card each, is the honest answer.
  bool get stacksTableRows => isPhone;

  /// How tall a chart should be.
  double get chartHeight => switch (formFactor) {
        ConsoleFormFactor.phone => 150,
        ConsoleFormFactor.tablet => 170,
        ConsoleFormFactor.desktop => 190,
      };

  /// Print every month under a chart, or every other one. Twelve labels do not
  /// fit across a phone.
  int monthLabelStride(int monthCount) {
    if (!isPhone) return 1;
    if (monthCount <= 6) return 1;
    return (monthCount / 6).ceil();
  }

  /// The avatar size for a profile header.
  double get profileAvatarRadius => isPhone ? 34 : 44;

  // ----------------------------------------------------------------- dialogs ---

  /// The width a dialog should ask for, given what it would like on a desktop.
  ///
  /// Never wider than the window minus its own margins, so a 520-pixel review
  /// dialog does not overflow a 390-pixel phone.
  double dialogWidth(double preferred) {
    final available = width - dialogInset * 2 - 48;
    return available <= 0 ? preferred : preferred.clamp(0.0, available);
  }

  /// How far a dialog sits from the edge of the window. Phones get almost the
  /// whole screen, because there is not enough of it to spend on margins.
  double get dialogInset => isPhone ? 12 : 40;

  /// The cap on a dialog's height, so a long review still scrolls inside the
  /// dialog rather than overflowing it.
  double get dialogMaxHeight => height * (isPhone ? 0.74 : 0.7);

  @override
  bool operator ==(Object other) =>
      other is ConsoleLayout &&
      other.formFactor == formFactor &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(formFactor, width, height);
}

/// Publishes the current [ConsoleLayout] to everything below it.
///
/// The shell wraps its content in one of these, so a page deep in the tree can
/// ask what device it is on without threading the answer down by hand.
class ConsoleLayoutScope extends StatelessWidget {
  final ConsoleLayout layout;
  final Widget child;

  const ConsoleLayoutScope({
    super.key,
    required this.layout,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      _ConsoleLayoutScope(layout: layout, child: child);
}

class _ConsoleLayoutScope extends InheritedWidget {
  final ConsoleLayout layout;

  const _ConsoleLayoutScope({required this.layout, required super.child});

  @override
  bool updateShouldNotify(_ConsoleLayoutScope oldWidget) =>
      oldWidget.layout != layout;
}

/// Convenience for the many `ConsoleLayout.of(context)` reads in build methods.
extension ConsoleLayoutContext on BuildContext {
  ConsoleLayout get layout => ConsoleLayout.of(this);
}
