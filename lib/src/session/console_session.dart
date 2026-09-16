import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:on_go_console_backend/api/console_api.dart';
import 'package:on_go_console_backend/console_backend.dart';

/// Who is signed in to the console, and what they are allowed to do.
///
/// One object rather than a per-screen check, because the answer decides three
/// separate things: which navigation the shell shows, which routes resolve, and
/// which arguments a decision is submitted with. A screen that needs any of
/// those reads it here.
///
/// Nothing about permissions is enforced *only* here — the server (or, in a
/// local build, the services) re-checks every one. This is what the UI uses to
/// avoid offering an action that would be refused.
class ConsoleSession extends ChangeNotifier {
  ConsoleSession._internal();
  static final ConsoleSession instance = ConsoleSession._internal();

  AuthenticatedUser? _user;
  ModeratorPermissions _granted = ModeratorPermissions.none;
  ModeratorAccount? _moderator;
  StreamSubscription<List<ModeratorAccount>>? _rosterWatch;
  StreamSubscription<SessionChange>? _apiWatch;
  bool _restoreAttempted = false;
  String? _endedNotice;

  /// The signed-in principal, or null when nobody is.
  AuthenticatedUser? get user => _user;

  bool get isSignedIn => _user != null;

  bool get isAdmin => _user?.role == UserRole.admin;

  bool get isModerator => _user?.role == UserRole.moderator;

  /// The signed-in moderator's directory record, kept current so a permission
  /// an admin changes mid-session takes effect without a re-login. Only a
  /// local build has one: against the API the directory is admin-only, and a
  /// moderator's rights come from the session instead. Null when an admin is
  /// signed in, or nobody is.
  ModeratorAccount? get moderator => _moderator;

  /// The name to record as the actor on anything this session decides. The
  /// API ignores it — the actor is whoever holds the token.
  String get actorName => _moderator?.name ?? _user?.displayName ?? 'Unknown';

  /// The moderator account to credit an action to, or null for an admin —
  /// which is exactly what [ModerationDecision.actorId] means.
  String? get actorId => _moderator?.id;

  /// What this session may do. Admins hold everything; a moderator holds what
  /// their account was granted; a signed-out session holds nothing.
  ModeratorPermissions get permissions {
    if (isAdmin) return ModeratorPermissions.all;
    if (_user == null) return ModeratorPermissions.none;
    return _moderator?.permissions ?? _granted;
  }

  /// Why the session ended when nobody signed out — shown once on Sign In.
  String? takeEndedNotice() {
    final notice = _endedNotice;
    _endedNotice = null;
    return notice;
  }

  /// Signs in through [ConsoleBackend.auth].
  Future<SignInResult> signIn(String identifier, String password) async {
    final result = await ConsoleBackend.instance.auth.signIn(
      SignInRequest(
        identifier: identifier,
        password: password,
        surface: AppSurface.console,
      ),
    );

    final account = result.account;
    if (account != null) await _adopt(account);
    return result;
  }

  /// Re-opens the session the browser still holds (the refresh cookie), once
  /// per page load. True when someone is signed in afterwards. Throws
  /// [ApiException] when the server could not be asked.
  Future<bool> restore() async {
    if (isSignedIn) return true;
    if (_restoreAttempted) return false;
    // Every refresh counts against the auth rate limit; one try per load.
    _restoreAttempted = true;

    final account = await ConsoleBackend.instance.auth.restoreSession();
    if (account == null) return false;
    if (account.user.role.surface != AppSurface.console) {
      await ConsoleBackend.instance.auth.signOut();
      return false;
    }
    await _adopt(account);
    return true;
  }

  /// Re-reads the account's permissions from the server — after a refusal,
  /// when an admin may have changed them.
  Future<void> refreshPermissions() async {
    if (_user == null) return;
    try {
      final account = await ConsoleBackend.instance.auth.fetchCurrentAccount();
      if (_user == null) return;
      _user = account.user;
      _granted = account.permissions;
      notifyListeners();
    } on ApiException {
      // Keep what we have; a session that is really over ends on its own.
    }
  }

  Future<void> _adopt(AuthenticatedAccount account) async {
    final user = account.user;
    _user = user;
    _granted = account.permissions;
    _endedNotice = null;
    await _rosterWatch?.cancel();
    _rosterWatch = null;
    _moderator = null;

    final accountId = user.accountId;
    if (!ConsoleBackend.instance.usesApi && user.role == UserRole.moderator && accountId != null) {
      _rosterWatch = ConsoleBackend.instance.moderators
          .watchModerators()
          .listen((roster) => _onRosterChanged(accountId, roster));
    }
    _apiWatch ??= ConsoleApi.sessionChanges.listen(_onApiSessionChange);

    notifyListeners();
  }

  void _onApiSessionChange(SessionChange change) {
    switch (change.kind) {
      case SessionChangeKind.ended:
        if (_user == null || change.reason == SessionEndReason.signedOut) return;
        _endedNotice = switch (change.reason) {
          SessionEndReason.accountInactive => change.message ?? 'This account is no longer active.',
          SessionEndReason.invalid => 'You were signed out. Please sign in again.',
          _ => 'Your session has ended. Please sign in again.',
        };
        unawaited(_clear());
        notifyListeners();
      case SessionChangeKind.forbidden:
        unawaited(refreshPermissions());
      case SessionChangeKind.started:
      case SessionChangeKind.refreshed:
      case SessionChangeKind.tokenReplaced:
      case SessionChangeKind.accountChanged:
        break;
    }
  }

  /// Keeps [moderator] in step with the roster, and signs the session out if
  /// the account it belongs to is removed while it is open.
  void _onRosterChanged(String accountId, List<ModeratorAccount> roster) {
    for (final account in roster) {
      if (account.id == accountId) {
        if (_moderator != account) {
          _moderator = account;
          notifyListeners();
        }
        return;
      }
    }
    // The admin removed this account. There is nothing left to be signed in as.
    unawaited(signOut());
  }

  Future<void> _clear() async {
    await _rosterWatch?.cancel();
    _rosterWatch = null;
    _user = null;
    _moderator = null;
    _granted = ModeratorPermissions.none;
  }

  Future<void> signOut() async {
    await _clear();
    await ConsoleBackend.instance.auth.signOut();
    notifyListeners();
  }
}
