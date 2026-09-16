import 'package:flutter/material.dart';

import '../theme/console_theme.dart';
import 'console_widgets.dart';

/// Password feedback, matching the rules the mobile app applies to its own
/// forms so a password judged "fair" in one place is not "good" in the other.
///
/// When the backend owns accounts this moves behind the API — a strength rule
/// that only runs in the client is a hint, not a policy — but until then both
/// front ends should at least agree.

enum PasswordStrength { empty, weak, fair, good, strong }

PasswordStrength evaluatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;

  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]/\\+=~`]').hasMatch(password)) score++;

  if (password.length < 6) return PasswordStrength.weak;
  if (score <= 1) return PasswordStrength.weak;
  if (score == 2) return PasswordStrength.fair;
  if (score <= 4) return PasswordStrength.good;
  return PasswordStrength.strong;
}

extension PasswordStrengthDisplay on PasswordStrength {
  String get label => switch (this) {
        PasswordStrength.empty => '',
        PasswordStrength.weak => 'Weak',
        PasswordStrength.fair => 'Fair',
        PasswordStrength.good => 'Good',
        PasswordStrength.strong => 'Strong',
      };

  Color get color => switch (this) {
        PasswordStrength.empty => ConsoleColors.border,
        PasswordStrength.weak => ConsoleColors.danger,
        PasswordStrength.fair => ConsoleColors.warning,
        PasswordStrength.good => ConsoleColors.success,
        PasswordStrength.strong => ConsoleColors.success,
      };

  double get fraction => switch (this) {
        PasswordStrength.empty => 0,
        PasswordStrength.weak => 0.25,
        PasswordStrength.fair => 0.5,
        PasswordStrength.good => 0.75,
        PasswordStrength.strong => 1,
      };
}

/// A labelled strength bar — drop under any password field.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final strength = evaluatePasswordStrength(password);
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: strength.fraction,
              minHeight: 5,
              backgroundColor: ConsoleColors.border,
              valueColor: AlwaysStoppedAnimation(strength.color),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Password strength: ${strength.label}',
            style: TextStyle(
              fontSize: 11.5,
              color: strength.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live "do these two match?" feedback under a confirmation field.
///
/// Says nothing until the confirmation has something in it, so a field the
/// user has not reached yet is never pre-emptively marked wrong.
class PasswordMatchIndicator extends StatelessWidget {
  final String password;
  final String confirmPassword;

  const PasswordMatchIndicator({
    super.key,
    required this.password,
    required this.confirmPassword,
  });

  @override
  Widget build(BuildContext context) {
    if (confirmPassword.isEmpty) return const SizedBox.shrink();

    final matches = password == confirmPassword;
    final color = matches ? ConsoleColors.success : ConsoleColors.danger;

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(matches ? Icons.check_circle : Icons.cancel, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            matches ? 'Passwords match' : 'Passwords do not match',
            style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A password field with a show/hide toggle. Used by every form here that
/// takes one.
class ConsolePasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  const ConsolePasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.onChanged,
    this.validator,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  State<ConsolePasswordField> createState() => _ConsolePasswordFieldState();
}

class _ConsolePasswordFieldState extends State<ConsolePasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      validator: widget.validator,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Runs the caller's own rules. Return an error to show inside the dialog, or
/// null once the password has actually been changed.
typedef ChangePasswordAttempt = Future<String?> Function(
  String current,
  String next,
  String confirm,
);

/// The console's Change Password dialog.
///
/// Returns true when the password was changed, so the caller reports it
/// however that screen normally does.
Future<bool> showChangePasswordDialog({
  required BuildContext context,
  required ChangePasswordAttempt onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ChangePasswordDialog(onSubmit: onSubmit),
  );
  return result == true;
}

/// A widget rather than a StatefulBuilder so the controllers are owned by
/// something with a real lifecycle: disposing them by hand when showDialog
/// returns tears them down while the exit animation is still painting the
/// fields, which throws.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.onSubmit});

  final ChangePasswordAttempt onSubmit;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(_current.text, _next.text, _confirm.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: consoleDialogInsets(context),
      title: const Text('Change password'),
      content: SizedBox(
        width: ConsoleLayout.of(context).dialogWidth(400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConsolePasswordField(
                controller: _current,
                label: 'Current password',
                autofocus: true,
              ),
              const SizedBox(height: 14),
              ConsolePasswordField(
                controller: _next,
                label: 'New password',
                onChanged: (_) => setState(() {}),
              ),
              PasswordStrengthMeter(password: _next.text),
              const SizedBox(height: 14),
              ConsolePasswordField(
                controller: _confirm,
                label: 'Confirm new password',
                onChanged: (_) => setState(() {}),
                onSubmitted: _busy ? null : _submit,
              ),
              PasswordMatchIndicator(
                password: _next.text,
                confirmPassword: _confirm.text,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: ConsoleColors.danger, fontSize: 12.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: ConsoleColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
