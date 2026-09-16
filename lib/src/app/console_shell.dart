import 'package:flutter/material.dart';

import 'package:on_go_console_backend/console_backend.dart';
import '../session/console_session.dart';
import '../theme/console_theme.dart';
import '../widgets/console_widgets.dart';
import 'console_routes.dart';

/// The frame every signed-in console page sits in, in whichever shape the
/// device calls for.
///
/// One shell, three arrangements, chosen from the window size alone:
///
/// * **Desktop** — the full 248-pixel rail pinned open, a title bar, content
///   capped at a readable width with margins either side.
/// * **Tablet** — an icon-only rail with tooltips, so navigation stays on
///   screen without spending a quarter of the width on labels. Below
///   [ConsoleLayout.iconRailMin] it folds into the drawer.
/// * **Phone** — navigation in a drawer *and* a bottom bar carrying the
///   destinations people reach for most, so the common moves are one thumb
///   away rather than two taps in.
///
/// Admin and Moderator go through this same code with their own destination
/// list, so neither can drift from the other.
class ConsoleShell extends StatelessWidget {
  /// The page body.
  final Widget child;

  /// Overrides the title, for pages that are not rail destinations.
  final String? title;
  final String? subtitle;

  /// Actions for the top bar, right of the title.
  final List<Widget> actions;

  /// Shown when this page was pushed on top of a destination.
  final bool showBackButton;

  const ConsoleShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final session = ConsoleSession.instance;
    final role = session.user?.role ?? UserRole.moderator;
    final route = ModalRoute.of(context)?.settings.name;
    final destination = ConsoleNavigation.find(role, route);

    final heading = title ?? destination?.label ?? 'On Go Console';
    final blurb = subtitle ?? destination?.blurb;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = ConsoleLayout.fromSize(
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        if (layout.isPhone) {
          return ConsoleLayoutScope(
            layout: layout,
            child: _PhoneShell(
              role: role,
              currentRoute: route,
              title: title,
              showBackButton: showBackButton,
              actions: actions,
              child: child,
            ),
          );
        }

        return ConsoleLayoutScope(
          layout: layout,
          child: Scaffold(
            backgroundColor: ConsoleColors.canvas,
            drawer: layout.railPinned
                ? null
                : Drawer(
                    backgroundColor: ConsoleColors.sidebar,
                    width: 268,
                    child: _ConsoleRail(
                      role: role,
                      currentRoute: route,
                      inDrawer: true,
                    ),
                  ),
            body: Row(
              children: [
                if (!layout.railInDrawer)
                  SizedBox(
                    width: layout.railWidth,
                    child: _ConsoleRail(
                      role: role,
                      currentRoute: route,
                      collapsed: layout.railCollapsed,
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _ConsoleTopBar(
                        title: heading,
                        subtitle: blurb,
                        actions: actions,
                        showMenuButton: layout.railInDrawer,
                        showBackButton: showBackButton,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(maxWidth: layout.contentMaxWidth),
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The phone arrangement: the On Go app bar, the floating pill bottom bar and
/// the drawer — the same chrome the Client and Mechanic shells wear, from the
/// same widgets in `package:on_go_design`, so this is the app's navigation bar
/// rather than a copy of it.
///
/// A page pushed on top of a destination (Themes, App background) shows a
/// plain back-arrow bar instead, exactly as the app's sub-screens do.
class _PhoneShell extends StatelessWidget {
  const _PhoneShell({
    required this.role,
    required this.currentRoute,
    required this.title,
    required this.showBackButton,
    required this.actions,
    required this.child,
  });

  final UserRole role;
  final String? currentRoute;
  final String? title;
  final bool showBackButton;
  final List<Widget> actions;
  final Widget child;

  /// 'Admin Panel' / 'Moderator Panel' — the line under the wordmark.
  String get _panelName =>
      role == UserRole.admin ? 'Admin Panel' : 'Moderator Panel';

  @override
  Widget build(BuildContext context) {
    final destinations = ConsoleNavigation.bottomNavFor(role);
    final destination = ConsoleNavigation.find(role, currentRoute);

    // Anything reached from the drawer or the bell is a pushed screen with a
    // back arrow, the way the app's Settings and Notifications screens were —
    // so is anything a page explicitly pushed. Everything else is one of the
    // bar's own destinations.
    final isSubScreen = showBackButton ||
        (destination != null &&
            destination.placement != ConsolePlacement.bottomNav);

    if (isSubScreen) {
      return Scaffold(
        backgroundColor: ConsoleColors.canvas,
        appBar: AppBar(
          backgroundColor: ConsoleColors.brand,
          foregroundColor: ConsoleColors.textInverse,
          title: Text(title ?? destination?.label ?? ''),
          actions: actions,
        ),
        body: child,
      );
    }

    // A route the navigation does not know (one built without settings) still
    // gets the bar, showing the role's first destination rather than nothing.
    final found = destinations.indexWhere((d) => d.route == currentRoute);
    final index = found < 0 ? 0 : found;

    return Scaffold(
      backgroundColor: ConsoleColors.canvas,
      drawer: _PhoneDrawer(role: role),
      appBar: OnGoAppBar(
        subtitle: _panelName,
        secondaryAction: actions.isEmpty ? null : Row(children: actions),
        notificationAction: _Bell(role: role),
      ),
      body: child,
      bottomNavigationBar: OnGoBottomNav(
        currentIndex: index,
        onTap: (selected) {
          final route = destinations[selected].route;
          if (route == currentRoute) return;
          Navigator.pushReplacementNamed(context, route);
        },
        items: [
          for (final destination in destinations)
            OnGoNavItem(icon: destination.icon, label: destination.shortLabel),
        ],
      ),
    );
  }
}

/// The app bar's bell.
///
/// Admin's opens the Notifications screen and counts unseen moderator
/// activity; Moderator's counts the pending queue and jumps to it — the two
/// behaviours the original panels had.
class _Bell extends StatelessWidget {
  const _Bell({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final backend = ConsoleBackend.instance;

    if (role == UserRole.admin) {
      final destination = ConsoleNavigation.bellFor(role);
      // Escalations only. Routine moderator activity is recorded in the Audit
      // Log and no longer counted here — a badge that ticks up on every
      // approval is a badge an admin learns to ignore. This counts the one
      // thing that actually needs them, and clears itself when those requests
      // are settled rather than when the screen is opened.
      return StreamBuilder<List<AccountVerificationRequest>>(
        stream: backend.verification.watchRequests(),
        initialData: const <AccountVerificationRequest>[],
        builder: (context, snapshot) {
          final waiting = (snapshot.data ?? const <AccountVerificationRequest>[])
              .where((r) => r.escalated && r.isPending)
              .length;
          return NotificationBell(
            count: waiting,
            onTap: destination == null
                ? null
                : () => Navigator.pushNamed(context, destination.route),
          );
        },
      );
    }

    return StreamBuilder<List<AccountVerificationRequest>>(
      stream: backend.verification.watchRequests(),
      builder: (context, snapshot) {
        final pending =
            (snapshot.data ?? const <AccountVerificationRequest>[])
                .where((r) => r.isPending)
                .length;
        return NotificationBell(
          count: pending,
          onTap: () => Navigator.pushReplacementNamed(
            context,
            ConsoleRoutes.moderatorQueue,
          ),
        );
      },
    );
  }
}

/// The phone drawer: the account header, then whatever this role keeps out of
/// the bottom bar, then Sign Out. Same shape as the app's drawers.
class _PhoneDrawer extends StatelessWidget {
  const _PhoneDrawer({required this.role});

  final UserRole role;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await confirmConsoleAction(
      context,
      title: 'Sign out?',
      message: 'You will need your password to get back into the console.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !context.mounted) return;

    await ConsoleSession.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, ConsoleRoutes.signIn, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: ConsoleColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadii.xl)),
      ),
      child: AnimatedBuilder(
        animation: ConsoleSession.instance,
        builder: (context, _) {
          final session = ConsoleSession.instance;
          final moderator = session.moderator;
          final photo = moderator == null
              ? null
              : ConsoleBackend.instance.localModerators
                  ?.photoBytesFor(moderator.id);

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: ConsoleColors.brand,
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: ConsoleColors.sidebarRaised,
                      foregroundImage: photo == null ? null : MemoryImage(photo),
                      child: Icon(
                        Icons.person_outline,
                        color: ConsoleColors.onSidebar,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.user?.displayName ?? 'Signed out',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: ConsoleColors.onSidebar,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            moderator?.role ??
                                (session.isAdmin ? 'Administrator' : 'No account'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: ConsoleColors.sidebarText,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    for (final destination in ConsoleNavigation.drawerFor(role))
                      _DrawerItem(
                        icon: destination.icon,
                        label: destination.label,
                        // Pushed, not replaced: these open as sub-screens with
                        // a back arrow, so Back has to return to the
                        // destination the drawer was opened from.
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, destination.route);
                        },
                      ),
                    _DrawerItem(
                      icon: Icons.logout,
                      label: 'Log Out',
                      destructive: true,
                      onTap: () => _signOut(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One row in the phone drawer, styled like the app's.
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? ConsoleColors.danger : ConsoleColors.text;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      horizontalTitleGap: 12,
      minLeadingWidth: 20,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
      leading: Icon(icon, size: 20, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 14),
      ),
      onTap: onTap,
    );
  }
}

/// The navigation rail: product mark, destinations, then the signed-in account.
///
/// [collapsed] renders the same list as icons with tooltips — the tablet
/// arrangement. Nothing is dropped, so a tablet reaches every destination a
/// desktop does.
class _ConsoleRail extends StatelessWidget {
  final UserRole role;
  final String? currentRoute;
  final bool inDrawer;
  final bool collapsed;

  const _ConsoleRail({
    required this.role,
    required this.currentRoute,
    this.inDrawer = false,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = ConsoleNavigation.forRole(role);

    return Container(
      color: ConsoleColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RailBrand(collapsed: collapsed),
            Divider(height: 1, color: ConsoleColors.sidebarDivider),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: collapsed ? 8 : 10,
                ),
                children: [
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: Text(
                        role == UserRole.admin ? 'ADMINISTRATION' : 'MODERATION',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w700,
                          color: ConsoleColors.sidebarText.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  for (final destination in destinations)
                    _RailItem(
                      destination: destination,
                      selected: destination.route == currentRoute,
                      collapsed: collapsed,
                      onTap: () {
                        if (inDrawer) Navigator.pop(context);
                        if (destination.route == currentRoute) return;
                        Navigator.pushReplacementNamed(context, destination.route);
                      },
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: ConsoleColors.sidebarDivider),
            _RailAccount(collapsed: collapsed),
          ],
        ),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    // A light tile carrying the brand icon. The rail is painted in the brand
    // colour now, so the mark reads by inverting against it rather than by
    // being the brand colour itself.
    final mark = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: ConsoleColors.onSidebar,
        borderRadius: AppRadii.borderSm,
      ),
      child: Icon(Icons.build_rounded, size: 19, color: ConsoleColors.brand),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Tooltip(message: 'On Go Console', child: Center(child: mark)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'On Go',
                  style: TextStyle(
                    color: ConsoleColors.onSidebar,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Console',
                  style: TextStyle(
                    color: ConsoleColors.sidebarText.withValues(alpha: 0.7),
                    fontSize: 11.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final ConsoleDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _RailItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = collapsed
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Icon(
              destination.icon,
              size: 20,
              color: selected ? ConsoleColors.onSidebar : ConsoleColors.sidebarText,
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                // The active marker: a short brand-coloured bar, the one place
                // the rail uses colour.
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 11),
                  decoration: BoxDecoration(
                    color: selected ? ConsoleColors.onSidebar : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  destination.icon,
                  size: 18,
                  color: selected ? ConsoleColors.onSidebar : ConsoleColors.sidebarText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? ConsoleColors.onSidebar : ConsoleColors.sidebarText,
                    ),
                  ),
                ),
              ],
            ),
          );

    final item = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? ConsoleColors.sidebarHover : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: ConsoleColors.sidebarHover.withValues(alpha: 0.7),
          child: body,
        ),
      ),
    );

    // A collapsed rail is icons only, so the label has to be reachable some
    // other way — otherwise a tablet user is guessing at pictograms.
    return collapsed
        ? Tooltip(
            message: destination.label,
            preferBelow: false,
            child: item,
          )
        : item;
  }
}

/// The account block at the bottom of the rail, with Sign Out.
class _RailAccount extends StatelessWidget {
  const _RailAccount({required this.collapsed});

  final bool collapsed;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await confirmConsoleAction(
      context,
      title: 'Sign out?',
      message: 'You will need your password to get back into the console.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !context.mounted) return;

    await ConsoleSession.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, ConsoleRoutes.signIn, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ConsoleSession.instance,
      builder: (context, _) {
        final session = ConsoleSession.instance;
        final user = session.user;
        final moderator = session.moderator;
        final photo = _moderatorPhoto(moderator?.id);

        final avatar = CircleAvatar(
          radius: 17,
          backgroundColor: ConsoleColors.sidebarRaised,
          foregroundImage: photo,
          child: Text(
            moderator?.initials ?? 'A',
            style: TextStyle(
              color: ConsoleColors.onSidebar,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

        if (collapsed) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Tooltip(
                  message: '${user?.displayName ?? 'Signed out'}'
                      '\n${user?.role.label ?? '—'}',
                  child: avatar,
                ),
                const SizedBox(height: 6),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () => _signOut(context),
                  icon: Icon(Icons.logout, size: 17, color: ConsoleColors.sidebarText),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 16),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.displayName ?? 'Signed out',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ConsoleColors.onSidebar,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user?.role.label ?? '—',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ConsoleColors.sidebarText.withValues(alpha: 0.75),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => _signOut(context),
                icon: Icon(Icons.logout, size: 17, color: ConsoleColors.sidebarText),
              ),
            ],
          ),
        );
      },
    );
  }

  ImageProvider? _moderatorPhoto(String? moderatorId) {
    if (moderatorId == null) return null;
    final bytes = ConsoleBackend.instance.localModerators?.photoBytesFor(moderatorId);
    return bytes == null ? null : MemoryImage(bytes);
  }
}

/// The bar above the content: page title, then the page's own actions.
///
/// On a phone the subtitle is dropped — it is context, not information, and
/// the width is better spent on the title and whatever the page put on the
/// right.
class _ConsoleTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showMenuButton;
  final bool showBackButton;

  const _ConsoleTopBar({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.showMenuButton,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final showSubtitle = subtitle != null && !layout.isPhone;

    return Container(
      height: layout.topBarHeight,
      padding: EdgeInsets.symmetric(horizontal: layout.isPhone ? 6 : 18),
      decoration: BoxDecoration(
        color: ConsoleColors.surface,
        border: Border(bottom: BorderSide(color: ConsoleColors.border)),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu, size: 20),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          if (showBackButton)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
          if (showMenuButton || showBackButton) const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: layout.isPhone
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleLarge,
                ),
                if (showSubtitle)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The page padding for the device in force at [context].
///
/// A function rather than a constant because the answer depends on the window:
/// 24 points of margin either side is right on a desktop and wasteful on a
/// phone.
EdgeInsets consolePagePadding(BuildContext context) => context.layout.pagePadding;
