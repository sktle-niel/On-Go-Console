import 'package:flutter/material.dart';

import '../theme/console_theme.dart';

/// The building blocks every console page is assembled from.
///
/// Collected in one file on purpose: the console is a dozen screens showing
/// the same five shapes — a panel, a section heading, a stat, a status pill, an
/// empty state — and they only stay consistent if there is one of each.

/// A bordered panel. The console's unit of content: one subject per card,
/// title above, body below.
class ConsoleCard extends StatelessWidget {
  final Widget child;

  /// Inner padding. Left null it follows the device — tighter on a phone,
  /// where 20 points either side is a fifth of the screen.
  final EdgeInsetsGeometry? padding;
  final String? title;
  final String? subtitle;

  /// Rendered at the top-right of the header, for a filter or an action.
  final Widget? trailing;

  /// Keep the panel's border and background on a phone.
  ///
  /// Off by default, because the Admin and Moderator panels drew their
  /// *sections* flat — a bold heading with the content beneath it — and saved
  /// the bordered box for things that are genuinely one object, like a form
  /// group or a record in a list. Boxing a whole section on a 390-point screen
  /// spends two borders and 40 points of padding to say "these things are
  /// together", which the heading already said.
  final bool boxedOnPhone;

  const ConsoleCard({
    super.key,
    required this.child,
    this.padding,
    this.title,
    this.subtitle,
    this.trailing,
    this.boxedOnPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final header = title;
    final resolvedPadding = padding ?? EdgeInsets.all(layout.cardPadding);

    if (layout.isPhone && !boxedOnPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        header,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ConsoleColors.surface,
        borderRadius: ConsoleMetrics.borderRadiusLarge,
        border: Border.all(color: ConsoleColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                layout.cardPadding,
                layout.isPhone ? 13 : 16,
                layout.cardPadding,
                layout.isPhone ? 13 : 16,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(header, style: Theme.of(context).textTheme.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            Divider(height: 1, color: ConsoleColors.border),
          ],
          Padding(padding: resolvedPadding, child: child),
        ],
      ),
    );
  }
}

/// An all-caps label above a group of rows. The console's section divider,
/// used where a full card would be too heavy.
class ConsoleSectionLabel extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;

  const ConsoleSectionLabel(
    this.label, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

/// One headline number with its label — the tiles across the top of Overview
/// and Income.
class ConsoleStatTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  /// A supporting line under the label: a comparison, a count, a period.
  final String? footnote;
  final Color? footnoteColor;

  const ConsoleStatTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    this.footnote,
    this.footnoteColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final layout = context.layout;

    // Icon in a tinted rounded square at the top-left, then the figure, then
    // its label — the Admin panel's stat card, at every size.
    return Container(
      padding: EdgeInsets.all(layout.isPhone ? 16 : 18),
      decoration: BoxDecoration(
        color: ConsoleColors.surface,
        borderRadius: ConsoleMetrics.borderRadiusLarge,
        border: Border.all(color: ConsoleColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadii.borderSm,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          SizedBox(height: layout.isPhone ? 16 : 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.displaySmall?.copyWith(fontSize: layout.isPhone ? 24 : 26),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
          if (footnote != null) ...[
            const SizedBox(height: 6),
            Text(
              footnote!,
              maxLines: 2,
              style: text.bodySmall?.copyWith(
                color: footnoteColor ?? ConsoleColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small coloured status word — approved, pending, active, escalated.
class ConsoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const ConsoleBadge({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 9 : 7, 3, 9, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A selectable filter, used above every list that has one.
class ConsoleFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ConsoleFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ConsoleColors.brand : ConsoleColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? ConsoleColors.brand : ConsoleColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? ConsoleColors.textInverse : ConsoleColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// What a list shows when it has nothing in it.
///
/// Every one of these in the console says the same kind of thing: nothing is
/// here yet, and here is what would put something here. That second half
/// matters more than usual right now, because several of these lists fill up
/// from the mobile app and cannot fill up until the two are connected.
class ConsoleEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const ConsoleEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ConsoleColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: ConsoleColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(message, textAlign: TextAlign.center, style: text.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// A labelled key/value pair, for the detail panels.
class ConsoleField extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final Widget? action;

  const ConsoleField({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ConsoleColors.surfaceMuted,
        borderRadius: ConsoleMetrics.borderRadius,
        border: Border.all(color: ConsoleColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: ConsoleColors.textMuted),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(value, style: text.titleSmall),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// A permission or preference row: title, explanation, control on the right.
class ConsoleToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const ConsoleToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(
                    color: enabled ? ConsoleColors.text : ConsoleColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A read-only yes/no, for showing a moderator what they hold.
class ConsolePermissionRow extends StatelessWidget {
  final String label;
  final bool granted;

  const ConsolePermissionRow({super.key, required this.label, required this.granted});

  @override
  Widget build(BuildContext context) {
    // A solid disc, not a tinted one: the Profile tab drew granted in green
    // and withheld in the brand red, and at a glance the fill is what reads.
    final color = granted ? ConsoleColors.success : ConsoleColors.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(
              granted ? Icons.check : Icons.close,
              size: 14,
              color: ConsoleColors.textInverse,
            ),
          ),
          const SizedBox(width: 12),
          // Expanded, so the label wraps inside the row rather than demanding
          // its full intrinsic width. Without it the longest permission —
          // "Change the app's background photo" — makes this row want ~541
          // points whatever the window is, which overflows every phone.
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// Circular avatar with an initials fallback, used for moderators everywhere.
class ConsoleAvatar extends StatelessWidget {
  final String initials;
  final ImageProvider? image;
  final double radius;

  const ConsoleAvatar({
    super.key,
    required this.initials,
    this.image,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: ConsoleColors.surfaceMuted,
      foregroundImage: image,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: ConsoleColors.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.62,
        ),
      ),
    );
  }
}

/// A horizontally scrollable wrapper for wide content.
///
/// The console's tables are wider than a tablet window. Rather than letting
/// the whole page scroll sideways, each table scrolls inside its own card.
///
/// This is the *tablet* answer. A phone gets stacked cards instead — see
/// [ConsoleLayout.stacksTableRows] — because a sideways scroll on a phone is
/// something people do not find.
class ConsoleHorizontalScroll extends StatelessWidget {
  final Widget child;
  final double minWidth;

  const ConsoleHorizontalScroll({
    super.key,
    required this.child,
    this.minWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= minWidth) return child;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: child),
          ),
        );
      },
    );
  }
}

/// Lays widgets out in [columns] equal columns, wrapping as needed.
///
/// Used for the dashboard stat tiles, where the column count comes from the
/// device rather than from a width guess made at the call site.
class ConsoleResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double spacing;

  /// Whether every cell in a row should be as tall as the tallest one.
  ///
  /// Off by default, because the plain [Wrap] below lets each cell keep its
  /// own height — which is what a grid of theme swatches or rings wants, and
  /// which costs nothing to measure.
  ///
  /// Turn it ON for a row of cards that must read as a set. Cards are a
  /// rectangle with a border: one of them standing 20 pixels taller than its
  /// neighbours because it carries an extra line of text looks like a mistake,
  /// not like emphasis. See [ConsoleStatTile], which is the case this exists
  /// for.
  ///
  /// The cost is [IntrinsicHeight], which asks every cell how tall it would
  /// like to be before laying any of them out. Cheap for a card of text; not
  /// available at all to a cell built by a `LayoutBuilder`, which cannot
  /// answer that question — so this stays opt-in rather than becoming the
  /// default for every grid in the console.
  final bool stretchRows;

  const ConsoleResponsiveGrid({
    super.key,
    required this.children,
    required this.columns,
    this.spacing = 16,
    this.stretchRows = false,
  });

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }

    if (stretchRows) return _stretchedRows();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }

  /// The same grid, built as explicit rows so every cell can be given one
  /// common height.
  ///
  /// [Wrap] cannot do this: it measures every child on its own and aligns the
  /// short ones to the top of the run, which is exactly the ragged edge this
  /// avoids. A [Row] can stretch its cells, but only when it has a height to
  /// stretch to — and a row in a scrolling page has none until something
  /// measures it. That is what the [IntrinsicHeight] is for.
  ///
  /// Equal ACROSS rows as well as within one. A phone shows the four dashboard
  /// figures as a 2×2 block, and two rows of different heights look just as
  /// wrong there as two cards of different heights do on a desktop. Wrapping
  /// the whole column in one [IntrinsicHeight] and giving each row an
  /// [Expanded] does it: a column's intrinsic height with flexible children is
  /// the tallest child times the number of them, so every row is handed the
  /// height of the tallest.
  Widget _stretchedRows() {
    // One row of cells, each as tall as the row it is in.
    Widget rowOf(List<Widget> cells) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: cells[i]),
            ],
            // A last row that is not full is padded with empty columns, so
            // three cards in a four-column grid stay card-width instead of
            // stretching to fill the row.
            for (var i = cells.length; i < columns; i++) ...[
              SizedBox(width: spacing),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        );

    final rows = <Widget>[
      for (var start = 0; start < children.length; start += columns)
        rowOf(children.sublist(start, (start + columns).clamp(0, children.length))),
    ];

    if (rows.length == 1) return IntrinsicHeight(child: rows.single);

    return IntrinsicHeight(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            Expanded(child: rows[i]),
          ],
        ],
      ),
    );
  }
}

/// Lays two panels side by side, or stacks them when the window is too narrow
/// for both.
class ConsoleSplitRow extends StatelessWidget {
  final Widget first;
  final Widget second;
  final double spacing;

  /// Overrides the device's own judgement, for a pair that needs more room
  /// than most.
  final bool? stacked;

  const ConsoleSplitRow({
    super.key,
    required this.first,
    required this.second,
    this.spacing = 16,
    this.stacked,
  });

  @override
  Widget build(BuildContext context) {
    if (stacked ?? context.layout.stacksPairs) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, SizedBox(height: spacing), second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: first),
        SizedBox(width: spacing),
        Expanded(child: second),
      ],
    );
  }
}

/// Sizes a dialog's body for the device.
///
/// A dialog is built outside the shell, so it reads the layout from
/// `MediaQuery` — [preferredWidth] is what it would like on a desktop, and it
/// gets that or whatever the window can spare, whichever is smaller. Height is
/// capped too, so a long review scrolls inside the dialog instead of
/// overflowing it.
class ConsoleDialogBody extends StatelessWidget {
  final Widget child;
  final double preferredWidth;

  /// Whether the body should scroll. Off for dialogs that are a single field.
  final bool scrollable;

  const ConsoleDialogBody({
    super.key,
    required this.child,
    this.preferredWidth = 460,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final layout = ConsoleLayout.of(context);
    return SizedBox(
      width: layout.dialogWidth(preferredWidth),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: layout.dialogMaxHeight),
        child: scrollable ? SingleChildScrollView(child: child) : child,
      ),
    );
  }
}

/// The margin a dialog keeps from the edge of the window — narrow on a phone,
/// where there is not enough screen to spend on it.
EdgeInsets consoleDialogInsets(BuildContext context) {
  final inset = ConsoleLayout.of(context).dialogInset;
  return EdgeInsets.symmetric(horizontal: inset, vertical: 24);
}

/// Shows a message in the console's own toast style.
void showConsoleMessage(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 17,
              color: isError ? ConsoleColors.danger : ConsoleColors.success,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: ConsoleMetrics.snackBar,
        // A fixed-width floating toast is right on a desktop and overflows a
        // phone, where the toast should simply span the screen with a margin.
        width: ConsoleLayout.of(context).isPhone ? null : 420.0,
        margin: ConsoleLayout.of(context).isPhone
            ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
            : null,
      ),
    );
}

/// Asks before something destructive. Returns true only on confirmation.
Future<bool> confirmConsoleAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      insetPadding: consoleDialogInsets(ctx),
      title: Text(title),
      content: ConsoleDialogBody(
        preferredWidth: 420,
        scrollable: false,
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: TextStyle(color: ConsoleColors.textMuted)),
        ),
        ElevatedButton(
          style: destructive
              ? ElevatedButton.styleFrom(backgroundColor: ConsoleColors.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
