import 'package:on_go_shared/on_go_shared.dart';

import 'local_moderator_directory_service.dart';

/// Sign-in for the console, against the moderator directory it holds.
/// Installed only when the console is built with `ONGO_BACKEND=local`; the
/// default build signs in through the On Go API (see `ConsoleApi`).
///
/// Two roles and only two. A Client or Mechanic typing their email here gets
/// [SignInFailure.wrongSurface] and a pointer back to the mobile app, the
/// mirror image of what the app does to an admin — the local half of the rule
/// the server enforces.
class LocalConsoleAuthService implements AuthApi {
  LocalConsoleAuthService(this._directory);

  final LocalModeratorDirectoryService _directory;

  /// The single built-in admin, until admin accounts are real. It is the same
  /// shortcut the mobile Admin panel had, kept so the console is usable from a
  /// clean start — someone has to be able to create the first moderator.
  static const String adminUsername = 'admin';

  /// Usernames that belong to the other application.
  static const Set<String> _mobileUsernames = {
    'client',
    'demo-client',
    'mechanic',
    'demo-mechanic',
  };

  /// Who is signed in, so a password change applies to that account — the
  /// same "the actor is the session" rule the server follows.
  AuthenticatedAccount? _current;

  @override
  Future<SignInResult> signIn(SignInRequest request) async {
    final identifier = request.identifier.trim().toLowerCase();
    if (identifier.isEmpty) {
      return const SignInResult.failed(SignInFailure.unknownAccount);
    }

    if (request.surface == AppSurface.console && _mobileUsernames.contains(identifier)) {
      return const SignInResult.failed(SignInFailure.wrongSurface);
    }

    if (identifier == adminUsername) {
      return _opened(const AuthenticatedAccount(
        user: AuthenticatedUser(
          displayName: LocalModeratorDirectoryService.adminActorName,
          role: UserRole.admin,
        ),
        permissions: ModeratorPermissions.all,
      ));
    }

    final account = _directory.findByEmail(identifier);
    if (account == null) {
      return const SignInResult.failed(SignInFailure.unknownAccount);
    }
    if (!_directory.verifyPassword(account.id, request.password)) {
      return const SignInResult.failed(SignInFailure.wrongPassword);
    }
    if (!account.isActive) {
      return const SignInResult.failed(SignInFailure.accountInactive);
    }

    return _opened(AuthenticatedAccount(
      user: AuthenticatedUser(
        accountId: account.id,
        displayName: account.name,
        email: account.email,
        role: UserRole.moderator,
      ),
      permissions: account.permissions,
    ));
  }

  SignInResult _opened(AuthenticatedAccount account) {
    _current = account;
    return SignInResult.success(account);
  }

  @override
  Future<AuthenticatedAccount> register(RegisterRequest request) {
    throw const ApiException(
      ApiErrorKind.forbidden,
      'Console accounts are created by an admin, not registered.',
    );
  }

  /// Local sessions do not outlive the page.
  @override
  Future<AuthenticatedAccount?> restoreSession() async => null;

  @override
  Future<AuthenticatedAccount> fetchCurrentAccount() async {
    final current = _current;
    if (current == null) {
      throw const ApiException(ApiErrorKind.unauthenticated, 'Nobody is signed in.');
    }
    final accountId = current.user.accountId;
    if (accountId == null) return current;
    final moderator = _directory.findByEmail(current.user.email);
    return moderator == null
        ? current
        : AuthenticatedAccount(user: current.user, permissions: moderator.permissions);
  }

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final accountId = _current?.user.accountId;
    if (accountId == null) {
      throw const ApiException(
        ApiErrorKind.unsupported,
        'The built-in admin has no password to change.',
      );
    }
    return _directory.changePassword(
      accountId,
      oldPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<PasswordResetRequested> requestPasswordReset(String email) {
    throw const ApiException.unsupported(
      'Local console passwords are reset by an admin from the moderator directory.',
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) {
    throw const ApiException.unsupported(
      'Local console passwords are reset by an admin from the moderator directory.',
    );
  }

  @override
  Future<void> signOut() async {
    // Nothing to revoke while sessions are local; the console session object
    // clears itself and the router falls back to Sign In.
    _current = null;
  }
}
