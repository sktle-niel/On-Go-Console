import 'package:flutter/material.dart';

import '../../app/console_routes.dart';
import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';
import '../../widgets/password_widgets.dart';

/// Creating a console account for a moderator.
///
/// The form is in two panels — who they are, then what they may do — because
/// those are two separate decisions and an admin should not be able to skim
/// past the second one. Permissions default to approve and reject on; escalate
/// and background are granted deliberately.
class AdminAddModeratorPage extends StatefulWidget {
  const AdminAddModeratorPage({super.key});

  @override
  State<AdminAddModeratorPage> createState() => _AdminAddModeratorPageState();
}

class _AdminAddModeratorPageState extends State<AdminAddModeratorPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  ModeratorPermissions _permissions = const ModeratorPermissions();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final created = await ConsoleBackend.instance.moderators.createModerator(
        CreateModeratorRequest(
          name: _name.text.trim(),
          email: _email.text.trim(),
          temporaryPassword: _password.text,
          permissions: _permissions,
        ),
      );
      if (!mounted) return;

      _formKey.currentState!.reset();
      _name.clear();
      _email.clear();
      _password.clear();
      setState(() => _permissions = const ModeratorPermissions());
      showConsoleMessage(context, '${created.name} can now sign in to the console');
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleShell(
      actions: [
        TextButton(
          onPressed: () => Navigator.pushReplacementNamed(
            context,
            ConsoleRoutes.adminModerators,
          ),
          child: const Text('View Moderators'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: ListView(
          padding: consolePagePadding(context),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConsoleCard(
                    boxedOnPhone: true,
                    title: 'Account details',
                    subtitle: 'How this moderator signs in',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            hintText: 'e.g. Vince Juno',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            hintText: 'name@company.com',
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Required';
                            if (!value.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ConsolePasswordField(
                          controller: _password,
                          label: 'Temporary password',
                          hint: 'At least 6 characters',
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),
                        PasswordStrengthMeter(password: _password.text),
                        const SizedBox(height: 8),
                        Text(
                          'They sign in with this password and can change it from '
                          'their own Settings.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  ConsoleCard(
                    boxedOnPhone: true,
                    title: 'Permissions',
                    subtitle: 'Checked again on every action, not just hidden',
                    child: Column(
                      children: [
                        ConsoleToggleRow(
                          title: 'Approve accounts',
                          subtitle:
                              'Grants a registered account access to the platform',
                          value: _permissions.canApprove,
                          onChanged: (v) => setState(
                            () => _permissions = _permissions.copyWith(canApprove: v),
                          ),
                        ),
                        Divider(height: 1, color: ConsoleColors.border),
                        ConsoleToggleRow(
                          title: 'Reject accounts',
                          subtitle: 'Declines a registration, with a reason',
                          value: _permissions.canReject,
                          onChanged: (v) => setState(
                            () => _permissions = _permissions.copyWith(canReject: v),
                          ),
                        ),
                        Divider(height: 1, color: ConsoleColors.border),
                        ConsoleToggleRow(
                          title: 'Escalate to admin',
                          subtitle: 'Flags a request for an admin to settle',
                          value: _permissions.canEscalate,
                          onChanged: (v) => setState(
                            () => _permissions = _permissions.copyWith(canEscalate: v),
                          ),
                        ),
                        Divider(height: 1, color: ConsoleColors.border),
                        ConsoleToggleRow(
                          title: 'Change the app background',
                          subtitle:
                              "Sets the mobile app's Sign In and Welcome photo",
                          value: _permissions.canChangeBackground,
                          onChanged: (v) => setState(
                            () => _permissions =
                                _permissions.copyWith(canChangeBackground: v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.layout.sectionSpacing),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: const Icon(Icons.person_add_alt, size: 17),
                        label: Text(_busy ? 'Adding…' : 'Add moderator'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
