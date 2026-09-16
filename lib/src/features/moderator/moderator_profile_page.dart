import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../session/console_session.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';

/// The moderator's own account, to read.
///
/// Nothing here is editable by the moderator — name and photo included. The
/// account is the admin's record of who this person is, and an audit trail
/// that names them is worth less if the name on it can be changed by the
/// person being audited.
///
/// It is still worth showing in full: a moderator who cannot escalate should
/// be able to see that, not discover it from a missing button.
class ModeratorProfilePage extends StatelessWidget {
  const ModeratorProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShell(
      child: AnimatedBuilder(
        animation: ConsoleSession.instance,
        builder: (context, _) {
          final session = ConsoleSession.instance;
          final moderator = session.moderator;

          if (moderator == null && session.isModerator) {
            // Signed in through the API, whose moderator directory is not
            // live yet (Step 6) — there is no record to show.
            return const ConsoleEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Profile not available yet',
              message:
                  'Moderator profiles are not served by the On Go API yet. '
                  'Your permissions still apply everywhere in the console.',
            );
          }

          if (moderator == null) {
            return const ConsoleEmptyState(
              icon: Icons.person_off_outlined,
              title: 'No moderator account',
              message:
                  'You are signed in as an admin. This page shows a moderator '
                  'their own account and permissions.',
            );
          }

          return ListView(
            padding: consolePagePadding(context),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileHeader(moderator: moderator),
                    SizedBox(height: context.layout.sectionSpacing),
                    ConsoleCard(
                      title: 'Account details',
                      subtitle: 'Managed by the admin who added you',
                      child: Column(
                        children: [
                          ConsoleField(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: moderator.email.isEmpty ? '—' : moderator.email,
                          ),
                          ConsoleField(
                            icon: Icons.shield_outlined,
                            label: 'Role',
                            value: moderator.role,
                          ),
                          ConsoleField(
                            icon: Icons.event_outlined,
                            label: 'Moderator since',
                            value: formatConsoleDate(moderator.addedAt),
                          ),
                          ConsoleField(
                            icon: Icons.task_alt,
                            label: 'Requests handled',
                            value: '${moderator.actionsHandled}',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.layout.sectionSpacing),
                    ConsoleCard(
                      title: context.layout.isPhone ? 'YOUR PERMISSION' : 'Your permissions',
                      subtitle: context.layout.isPhone ? null : 'Only an admin can change these',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConsolePermissionRow(
                            label: 'Approve accounts',
                            granted: moderator.permissions.canApprove,
                          ),
                          ConsolePermissionRow(
                            label: 'Reject accounts',
                            granted: moderator.permissions.canReject,
                          ),
                          ConsolePermissionRow(
                            label: 'Escalate to admin',
                            granted: moderator.permissions.canEscalate,
                          ),
                          ConsolePermissionRow(
                            label: "Change the app's background photo",
                            granted: moderator.permissions.canChangeBackground,
                          ),
                        ],
                      ),
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.moderator});

  final ModeratorAccount moderator;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bytes =
        ConsoleBackend.instance.localModerators?.photoBytesFor(moderator.id);

    final layout = context.layout;

    // Shown, not set: a photo can still arrive with the account, but the
    // moderator has no way to change it from here.
    final avatar = ConsoleAvatar(
      initials: moderator.initials,
      radius: layout.profileAvatarRadius,
      image: bytes == null ? null : MemoryImage(bytes),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          moderator.name,
          overflow: TextOverflow.ellipsis,
          // One size down on a phone: headlineSmall beside a 68-point avatar
          // leaves a name of any length nothing but an ellipsis.
          style: layout.isPhone ? text.titleLarge : text.headlineSmall,
        ),
        const SizedBox(height: 2),
        Text(
          moderator.email,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium,
        ),
        SizedBox(height: layout.isPhone ? 8 : 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ConsoleBadge(
              label: moderator.role,
              color: ConsoleColors.info,
            ),
            ConsoleBadge(
              label: moderator.status.label,
              color: moderator.isActive
                  ? ConsoleColors.success
                  : ConsoleColors.textMuted,
            ),
          ],
        ),
      ],
    );

    // The same arrangement at every width — avatar, then the identity beside
    // it — because it is the same information in the same order, and a phone
    // reading differently from a desktop is a second design to keep in step.
    // What changes is the scale: a smaller avatar, a tighter gap and one step
    // down in type, all from [ConsoleLayout].
    return ConsoleCard(
      boxedOnPhone: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatar,
          SizedBox(width: layout.isPhone ? 16 : 26),
          Expanded(child: details),
        ],
      ),
    );
  }
}
