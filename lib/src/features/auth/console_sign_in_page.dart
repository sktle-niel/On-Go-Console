import 'package:flutter/material.dart';

import '../../app/console_routes.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../session/console_session.dart';
import '../../theme/console_theme.dart';
import '../../widgets/password_widgets.dart';

/// The console's front door.
///
/// A two-panel sign-in rather than the app's photo-backed card: this is a
/// staff tool opened on a desktop, and the left panel is where it says what it
/// is and who it is for. The photo background belongs to the mobile app — and
/// is in fact set from this console, under Settings.
class ConsoleSignInPage extends StatefulWidget {
  const ConsoleSignInPage({super.key});

  @override
  State<ConsoleSignInPage> createState() => _ConsoleSignInPageState();
}

class _ConsoleSignInPageState extends State<ConsoleSignInPage> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _restoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = ConsoleSession.instance.takeEndedNotice();
    if (ConsoleBackend.instance.usesApi && !ConsoleSession.instance.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
    }
  }

  /// Picks up the session the browser may still hold, so a reload does not
  /// ask for the password again. Once per page load.
  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _restoring = true;
    });
    try {
      final restored = await ConsoleSession.instance.restore();
      final user = ConsoleSession.instance.user;
      if (!mounted) return;
      if (restored && user != null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          ConsoleRoutes.homeFor(user.role),
          (route) => false,
        );
        return;
      }
    } on ApiException catch (error) {
      if (mounted && error.kind == ApiErrorKind.unreachable) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _restoring = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result =
          await ConsoleSession.instance.signIn(_identifier.text, _password.text);
      if (!mounted) return;

      final user = result.user;
      if (user != null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          ConsoleRoutes.homeFor(user.role),
          (route) => false,
        );
        return;
      }
      // The API words its own failures (wrong_surface is shown verbatim);
      // the local implementation leaves the wording to this page.
      setState(() => _error = result.message ?? _messageFor(result.failure));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(SignInFailure? failure) => switch (failure) {
        SignInFailure.wrongSurface =>
          'That account signs in on the On Go mobile app, not the console.',
        SignInFailure.accountInactive =>
          'That moderator account has been deactivated. Ask an admin.',
        SignInFailure.accountLocked => 'Too many failed attempts. Try again later.',
        SignInFailure.wrongPassword => 'Incorrect password.',
        SignInFailure.unknownAccount ||
        null =>
          'No console account matches that. Moderators sign in with the email '
              'their admin registered.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConsoleColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = ConsoleLayout.fromSize(
            Size(constraints.maxWidth, constraints.maxHeight),
          );

          // The brand panel is the desktop half of this screen. A tablet in
          // portrait or a phone gets the form on its own, using the whole
          // width — an explanation of the product is not what someone opening
          // a sign-in page on a phone came for.
          final showBrandPanel = constraints.maxWidth >= 900;

          return ConsoleLayoutScope(
            layout: layout,
            child: Builder(
              builder: (context) {
                final form = Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.isPhone ? 20 : 32,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _form(context),
                    ),
                  ),
                );

                if (!showBrandPanel) return form;
                return Row(
                  children: [
                    const Expanded(flex: 5, child: _BrandPanel()),
                    Expanded(flex: 4, child: form),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sign in', style: text.displaySmall),
        const SizedBox(height: 6),
        Text(
          'Admin and Moderator accounts only.',
          style: text.bodyMedium?.copyWith(color: ConsoleColors.textMuted),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _identifier,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email or username',
            hintText: 'name@company.com',
          ),
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: 14),
        ConsolePasswordField(
          controller: _password,
          label: 'Password',
          onSubmitted: _signIn,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ConsoleColors.danger.withValues(alpha: 0.09),
              borderRadius: ConsoleMetrics.borderRadius,
              border: Border.all(color: ConsoleColors.danger.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 17, color: ConsoleColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(fontSize: 12.5, color: ConsoleColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: _busy ? null : _signIn,
          child: Text(_restoring
              ? 'Checking your session…'
              : _busy
                  ? 'Signing in…'
                  : 'Sign in'),
        ),
      ],
    );
  }
}

/// The left half on a wide window: what this application is.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleColors.sidebar,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ConsoleColors.onSidebar,
                  borderRadius: AppRadii.borderMd,
                ),
                child: Icon(Icons.build_rounded, size: 24, color: ConsoleColors.brand),
              ),
              const SizedBox(width: 14),
              Text(
                'On Go',
                style: TextStyle(
                  color: ConsoleColors.onSidebar,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'The operations console',
              style: TextStyle(
                color: ConsoleColors.onSidebar,
                fontSize: 34,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Review the accounts people register for in the app, manage who '
              'reviews them, and watch what the platform earns.',
              style: TextStyle(
                color: ConsoleColors.sidebarText,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 40),
          const _BrandPoint(
            icon: Icons.pending_actions_outlined,
            title: 'Account verification',
            body: 'Approve, reject or escalate mechanic registrations.',
          ),
          const _BrandPoint(
            icon: Icons.shield_outlined,
            title: 'Moderator management',
            body: 'Create accounts, set permissions, keep an audit trail.',
          ),
          const _BrandPoint(
            icon: Icons.bar_chart,
            title: 'Platform revenue',
            body: 'Every completed payment the mobile app reports.',
          ),
        ],
      ),
    );
  }
}

class _BrandPoint extends StatelessWidget {
  const _BrandPoint({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ConsoleColors.sidebarRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: ConsoleColors.sidebarText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ConsoleColors.onSidebar,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(color: ConsoleColors.sidebarText, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
