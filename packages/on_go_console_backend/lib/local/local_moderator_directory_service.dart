import 'dart:typed_data';

import 'package:on_go_shared/on_go_shared.dart';

import 'live_value.dart';
import 'local_client_ip_service.dart';

/// The moderator roster and its audit trail, held in this browser session.
///
/// Stands in for the directory the backend will own. It starts completely
/// empty — the first moderator is the first one an admin actually creates, the
/// same as the panel this replaced. Nothing is seeded or sampled.
///
/// Two things live here that are NOT on [ModeratorDirectoryApi], because they
/// are storage concerns rather than API ones:
///
/// * Passwords. A directory record never carries one over the wire, so they
///   are kept beside the accounts and reachable only through the console's own
///   auth service.
/// * Photo bytes. There is nowhere to upload a profile photo to yet, so the
///   bytes stay in memory and [ModeratorAccount.photoUrl] gets a `local:`
///   reference naming them. When uploads are hosted, that becomes an https URL
///   and [photoBytesFor] goes away with this class.
class LocalModeratorDirectoryService implements ModeratorDirectoryApi {
  LocalModeratorDirectoryService({LocalClientIpService? clientIp})
      : _clientIp = clientIp ?? LocalClientIpService();

  /// Where the address on each audit entry comes from. The server owns this
  /// once the backend lands; see [LocalClientIpService].
  final LocalClientIpService _clientIp;

  final List<_ModeratorRecord> _records = [];
  final List<AuditEntry> _audit = [];

  late final LiveValue<List<ModeratorAccount>> _moderators = LiveValue(_accounts);
  late final LiveValue<List<AuditEntry>> _auditLog = LiveValue(_auditSnapshot);

  /// The name recorded as the actor on admin-side audit entries. A placeholder
  /// until admin accounts are real — there is no admin profile to read a name
  /// from yet.
  static const String adminActorName = 'Admin';

  List<ModeratorAccount> get _accounts =>
      List<ModeratorAccount>.unmodifiable(_records.map((r) => r.account));

  List<AuditEntry> get _auditSnapshot => List<AuditEntry>.unmodifiable(_audit);

  void _publish() {
    _moderators.set(_accounts);
    _auditLog.set(_auditSnapshot);
  }

  _ModeratorRecord? _record(String id) {
    for (final record in _records) {
      if (record.account.id == id) return record;
    }
    return null;
  }

  _ModeratorRecord _requireRecord(String id) {
    final record = _record(id);
    if (record == null) {
      throw ApiException(ApiErrorKind.notFound, 'No moderator with id $id.');
    }
    return record;
  }

  // ------------------------------------------------------------- read side ---

  @override
  Future<List<ModeratorAccount>> listModerators() async => _accounts;

  @override
  Stream<List<ModeratorAccount>> watchModerators() => _moderators.stream;

  @override
  Future<List<AuditEntry>> listAuditLog() async => _auditSnapshot;

  @override
  Stream<List<AuditEntry>> watchAuditLog() => _auditLog.stream;

  /// The account carrying [email], or null. Used by the console's sign-in.
  ModeratorAccount? findByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final record in _records) {
      if (record.account.email.trim().toLowerCase() == normalized) {
        return record.account;
      }
    }
    return null;
  }

  ModeratorAccount? findById(String id) => _record(id)?.account;

  /// The profile photo held for [moderatorId] in this session, or null.
  Uint8List? photoBytesFor(String moderatorId) => _record(moderatorId)?.photoBytes;

  // ------------------------------------------------------------ write side ---

  @override
  Future<ModeratorAccount> createModerator(CreateModeratorRequest request) async {
    final email = request.email.trim();
    if (findByEmail(email) != null) {
      throw const ApiException(
        ApiErrorKind.rejected,
        'A moderator already uses that email address.',
      );
    }

    final now = DateTime.now();
    final account = ModeratorAccount(
      id: 'mod_${now.millisecondsSinceEpoch}',
      name: request.name.trim(),
      email: email,
      role: request.role,
      addedAt: now,
      permissions: request.permissions,
    );
    _records.add(_ModeratorRecord(account: account, password: request.temporaryPassword));
    _writeAudit(
      moderatorName: account.name,
      action: AuditAction.added,
      role: account.role,
    );
    _publish();
    return account;
  }

  @override
  Future<void> removeModerator(String moderatorId, {String? reason}) async {
    final record = _requireRecord(moderatorId);
    _records.remove(record);
    _writeAudit(
      moderatorName: record.account.name,
      action: AuditAction.removed,
      role: record.account.role,
      reason: reason,
    );
    _publish();
  }

  @override
  Future<ModeratorAccount> updatePermissions(
    String moderatorId,
    ModeratorPermissions permissions,
  ) async {
    final record = _requireRecord(moderatorId);
    record.account = record.account.copyWith(permissions: permissions);
    _publish();
    return record.account;
  }

  @override
  Future<ModeratorAccount> updateProfile(
    String moderatorId, {
    String? name,
    String? photoUrl,
  }) async {
    final record = _requireRecord(moderatorId);
    final trimmed = name?.trim();
    record.account = record.account.copyWith(
      name: trimmed != null && trimmed.isNotEmpty ? trimmed : null,
      photoUrl: photoUrl,
    );
    _publish();
    return record.account;
  }

  /// Stores a profile photo for this session and points the account's
  /// [ModeratorAccount.photoUrl] at it. The upload API replaces this whole
  /// method; the call site keeps working because it already awaits a Future.
  Future<ModeratorAccount> setProfilePhoto(String moderatorId, Uint8List bytes) async {
    final record = _requireRecord(moderatorId);
    record.photoBytes = bytes;
    return updateProfile(
      moderatorId,
      photoUrl: 'local:moderator-photo/$moderatorId#${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Credits one handled request to a moderator. Called by the verification
  /// service after a decision, which is what drives Overview's throughput
  /// chart and the roster's HANDLED column.
  void recordHandledAction(String moderatorId) {
    final record = _record(moderatorId);
    if (record == null) return;
    record.account = record.account.copyWith(
      actionsHandled: record.account.actionsHandled + 1,
    );
    _publish();
  }

  // -------------------------------------------------------------- passwords ---

  /// Checks a sign-in. Only the console's auth service calls this.
  bool verifyPassword(String moderatorId, String password) =>
      _record(moderatorId)?.password == password;

  /// Verifies [oldPassword] before setting [newPassword]. Returns false — and
  /// leaves the password untouched — if the old one does not match.
  bool changePassword(
    String moderatorId, {
    required String oldPassword,
    required String newPassword,
  }) {
    final record = _record(moderatorId);
    if (record == null || record.password != oldPassword) return false;
    record.password = newPassword;
    return true;
  }

  /// Sets a password without the old one, for a reset that proved ownership
  /// another way. Returns false when the account is gone.
  bool resetPassword(String moderatorId, String newPassword) {
    final record = _record(moderatorId);
    if (record == null) return false;
    record.password = newPassword;
    return true;
  }

  void _writeAudit({
    required String moderatorName,
    required AuditAction action,
    required String role,
    String? reason,
  }) {
    // Roster changes are admin-only, so these are always admin activity.
    writeAudit(
      subjectName: moderatorName,
      action: action,
      subjectRole: role,
      actorName: adminActorName,
      actorRole: UserRole.admin,
      reason: reason,
    );
  }

  /// Records one entry in the audit log.
  ///
  /// Public because the audit trail covers the whole console, not just this
  /// service: queue decisions are made in
  /// [LocalVerificationService] and are recorded here too, so the Audit Log
  /// can be read as one list and filtered by who acted.
  ///
  /// The address is stamped from [LocalClientIpService] rather than passed in,
  /// so no caller can claim to have acted from somewhere it did not.
  void writeAudit({
    required String subjectName,
    required AuditAction action,
    required String subjectRole,
    required String actorName,
    required UserRole actorRole,
    String? reason,
  }) {
    final now = DateTime.now();
    _audit.insert(
      0,
      AuditEntry(
        id: 'audit_${now.microsecondsSinceEpoch}',
        moderatorName: subjectName,
        action: action,
        role: subjectRole,
        actorName: actorName,
        actorRole: actorRole.wireName,
        ipAddress: _clientIp.address,
        occurredAt: now,
        reason: reason,
      ),
    );
    _auditLog.set(_auditSnapshot);
  }
}

/// One roster entry plus the things that never leave this browser: the
/// password and, until uploads are hosted, the profile photo's bytes.
class _ModeratorRecord {
  _ModeratorRecord({required this.account, required this.password});

  ModeratorAccount account;
  String password;
  Uint8List? photoBytes;
}
