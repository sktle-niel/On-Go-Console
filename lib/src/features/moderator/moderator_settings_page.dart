import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../session/console_session.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';
import '../../widgets/password_widgets.dart';
import '../shared/settings_rows.dart';

/// Moderator settings: appearance, the app background if they are allowed it,
/// and their own password.
class ModeratorSettingsPage extends StatefulWidget {
  const ModeratorSettingsPage({super.key});

  @override
  State<ModeratorSettingsPage> createState() => _ModeratorSettingsPageState();
}

class _ModeratorSettingsPageState extends State<ModeratorSettingsPage> {
  /// Nothing acts on this yet — there is no notification service behind it.
  /// Static so the choice survives leaving and coming back, which is what it
  /// did inside the mobile shell's tab.
  static bool _notifyOnNewRequests = true;

  Future<void> _changePassword() async {
    // The account is always the signed-in one; no directory record needed.
    if (!ConsoleSession.instance.isModerator) return;

    final changed = await showChangePasswordDialog(
      context: context,
      onSubmit: (current, next, confirm) async {
        if (next.length < 6) return 'New password must be at least 6 characters';
        if (next != confirm) return 'Passwords do not match';
        if (evaluatePasswordStrength(next) == PasswordStrength.weak) {
          return 'Choose a stronger password';
        }
        try {
          final ok = await ConsoleBackend.instance.auth.changePassword(
            currentPassword: current,
            newPassword: next,
          );
          return ok ? null : 'Current password is incorrect';
        } on ApiException catch (error) {
          return error.message;
        }
      },
    );

    if (changed && mounted) showConsoleMessage(context, 'Password updated');
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleShell(
      child: AnimatedBuilder(
        animation: ConsoleSession.instance,
        builder: (context, _) {
          final session = ConsoleSession.instance;
          final moderator = session.moderator;

          return ListView(
            padding: consolePagePadding(context),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ConsoleSettingsSection(
                      title: 'This console',
                      subtitle: 'Applies to your browser only',
                      children: [AppearanceSettingsRow()],
                    ),
                    SizedBox(height: context.layout.sectionSpacing),
                    ConsoleSettingsSection(
                      title: 'Mobile app',
                      subtitle: 'Branding every client and mechanic sees',
                      children: [
                        BackgroundSettingsRow(
                          enabled: session.permissions.canChangeBackground,
                        ),
                      ],
                    ),
                    SizedBox(height: context.layout.sectionSpacing),
                    ConsoleCard(
                      title: 'Notifications',
                      child: ConsoleToggleRow(
                        title: 'New requests in the queue',
                        subtitle:
                            'Alert me when an account is submitted for review',
                        value: _notifyOnNewRequests,
                        onChanged: (v) =>
                            setState(() => _notifyOnNewRequests = v),
                      ),
                    ),
                    SizedBox(height: context.layout.sectionSpacing),
                    ConsoleSettingsSection(
                      title: 'Security',
                      children: [
                        ConsoleSettingsRow(
                          icon: Icons.lock_outline,
                          title: 'Change password',
                          enabled: session.isModerator,
                          subtitle: !session.isModerator
                              ? 'Only a moderator account has a password here'
                              : 'Update the password for ${moderator?.email ?? session.user?.email ?? 'this account'}',
                          onTap: _changePassword,
                        ),
                      ],
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
