import 'package:on_go_shared/on_go_shared.dart';

import 'live_value.dart';
import 'local_moderator_directory_service.dart';

/// The moderation queue as this console holds it.
///
/// It implements the console's half of [AccountVerificationApi] fully:
/// listing, deciding, and the activity feed the Admin escalations screen
/// reads. Every permission check a moderator's buttons imply is repeated here,
/// so a decision cannot be made by disabling a button's `onPressed` guard —
/// the same check the backend will run on the token.
///
/// [submit] is the mobile app's end of the pipe and is refused here: nobody
/// registers for an account from the admin console. It is on the interface
/// because the interface describes the whole crossing, not one side of it.
///
/// The queue starts empty and stays empty until requests arrive from the
/// mobile app — which needs the backend. That is the honest state of two
/// disconnected applications, and it is exactly what the API is for.
class LocalVerificationService implements AccountVerificationApi {
  LocalVerificationService(this._directory);

  final LocalModeratorDirectoryService _directory;

  final List<AccountVerificationRequest> _requests = [];
  final List<ModerationActivity> _activity = [];

  late final LiveValue<List<AccountVerificationRequest>> _live = LiveValue(_snapshot);
  late final LiveValue<List<ModerationActivity>> _liveActivity = LiveValue(_activitySnapshot);

  /// How many activity entries the admin has already looked at, so the bell
  /// can show what is new since.
  int _seenActivityCount = 0;

  List<AccountVerificationRequest> get _snapshot =>
      List<AccountVerificationRequest>.unmodifiable(_requests.reversed);

  List<ModerationActivity> get _activitySnapshot =>
      List<ModerationActivity>.unmodifiable(_activity.reversed);

  void _publish() {
    _live.set(_snapshot);
    _liveActivity.set(_activitySnapshot);
  }

  int _indexOf(String requestId) => _requests.indexWhere((r) => r.id == requestId);

  /// Puts a request straight into the queue.
  ///
  /// Tests only. [submit] is the real door and is refused here on purpose, so
  /// without this there is no way to exercise [decide] — and therefore no way
  /// to check what a decision writes to the audit trail — until the backend
  /// connects the mobile app to the console. It does not appear on
  /// [AccountVerificationApi] and no screen calls it.
  void debugSeedRequest(AccountVerificationRequest request) {
    _requests.add(request);
    _publish();
  }

  // ------------------------------------------------------------- read side ---

  @override
  Future<List<AccountVerificationRequest>> listRequests({
    ApprovalStatus? status,
    bool escalatedOnly = false,
    String? search,
  }) async =>
      filterRequests(_snapshot, status: status, escalatedOnly: escalatedOnly, search: search);

  /// The same narrowing [listRequests] applies, exposed so a screen watching
  /// the live queue filters it identically rather than writing its own.
  static List<AccountVerificationRequest> filterRequests(
    List<AccountVerificationRequest> requests, {
    ApprovalStatus? status,
    bool escalatedOnly = false,
    String? search,
  }) {
    final needle = search?.trim().toLowerCase() ?? '';
    return requests.where((request) {
      if (status != null && request.status != status) return false;
      if (escalatedOnly && !request.escalated) return false;
      if (needle.isNotEmpty) {
        return request.name.toLowerCase().contains(needle) ||
            request.email.toLowerCase().contains(needle) ||
            request.userNumber.toLowerCase().contains(needle);
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Future<AccountVerificationRequest?> findRequest(String requestId) async {
    final index = _indexOf(requestId);
    return index < 0 ? null : _requests[index];
  }

  @override
  Future<List<ModerationActivity>> listActivity({int limit = 50}) async =>
      _activitySnapshot.take(limit).toList(growable: false);

  @override
  Stream<AccountVerificationRequest?> watchRequest(String requestId) =>
      _live.stream.map((requests) {
        for (final request in requests) {
          if (request.id == requestId) return request;
        }
        return null;
      });

  @override
  Stream<List<AccountVerificationRequest>> watchRequests() => _live.stream;

  /// The activity feed, live — what the Admin bell and escalations screen read.
  Stream<List<ModerationActivity>> watchActivity() => _liveActivity.stream;

  /// Entries the admin has not opened yet.
  int get unseenActivityCount => _activity.length - _seenActivityCount;

  /// The same count, live — what the app bar's bell badge counts.
  Stream<int> watchUnseenActivityCount() =>
      _liveActivity.stream.map((_) => unseenActivityCount).distinct();

  void markActivitySeen() {
    if (_seenActivityCount == _activity.length) return;
    _seenActivityCount = _activity.length;
    _publish();
  }

  // ------------------------------------------------------------ write side ---

  @override
  Future<AccountVerificationRequest> submit(SubmitVerificationRequest request) {
    throw const ApiException(
      ApiErrorKind.forbidden,
      'Verification requests are filed by the On Go mobile app during '
      'registration, not from the console.',
    );
  }

  @override
  Future<AccountVerificationRequest> decide(
    String requestId,
    ModerationDecision decision,
  ) async {
    final index = _indexOf(requestId);
    if (index < 0) {
      throw ApiException(ApiErrorKind.notFound, 'No request with id $requestId.');
    }

    final existing = _requests[index];
    _requirePermission(decision);

    if (decision.action != ModerationAction.escalated && !existing.isPending) {
      throw ApiException(
        ApiErrorKind.rejected,
        '${existing.name} was already ${existing.status.label.toLowerCase()}.',
      );
    }
    if (decision.action == ModerationAction.escalated && existing.escalated) {
      throw ApiException(
        ApiErrorKind.rejected,
        '${existing.name} is already escalated.',
      );
    }

    final now = DateTime.now();
    final AccountVerificationRequest updated;
    final String? activityReason;

    switch (decision.action) {
      case ModerationAction.approved:
        updated = existing.copyWith(
          status: ApprovalStatus.approved,
          reviewedAt: now,
          reviewerName: decision.actorName,
          clearReason: true,
        );
        activityReason = null;
      case ModerationAction.rejected:
        final reason = (decision.reason ?? '').trim();
        final finalReason = reason.isEmpty ? 'No reason given' : reason;
        updated = existing.copyWith(
          status: ApprovalStatus.rejected,
          reviewedAt: now,
          reviewerName: decision.actorName,
          reason: finalReason,
        );
        activityReason = finalReason;
      case ModerationAction.escalated:
        updated = existing.copyWith(escalated: true);
        activityReason = 'Flagged for admin review';
    }

    _requests[index] = updated;
    _activity.add(ModerationActivity(
      id: 'act_${now.microsecondsSinceEpoch}',
      action: decision.action,
      requestId: updated.id,
      accountName: updated.name,
      role: updated.role,
      moderatorName: decision.actorName,
      occurredAt: now,
      reason: activityReason,
    ));

    final actorId = decision.actorId;

    // The same decision, in the audit log. No actor id means an admin
    // resolved it — that is the one thing that tells the two apart here, and
    // it is what the Audit Log's role filter reads.
    _directory.writeAudit(
      subjectName: updated.name,
      action: switch (decision.action) {
        ModerationAction.approved => AuditAction.approved,
        ModerationAction.rejected => AuditAction.rejected,
        ModerationAction.escalated => AuditAction.escalated,
      },
      subjectRole: updated.role.label,
      actorName: decision.actorName,
      actorRole: actorId == null ? UserRole.admin : UserRole.moderator,
      reason: activityReason,
    );

    if (actorId != null) _directory.recordHandledAction(actorId);

    _publish();
    return updated;
  }

  /// The permission check, applied to the decision itself rather than to the
  /// button that produced it.
  void _requirePermission(ModerationDecision decision) {
    final actorId = decision.actorId;
    // No actor id means an admin resolved it; admins hold every permission.
    if (actorId == null) return;

    final account = _directory.findById(actorId);
    if (account == null) {
      throw const ApiException(
        ApiErrorKind.unauthenticated,
        'That moderator account no longer exists.',
      );
    }
    if (!account.isActive) {
      throw const ApiException(
        ApiErrorKind.forbidden,
        'That moderator account is inactive.',
      );
    }

    final permissions = account.permissions;
    final allowed = switch (decision.action) {
      ModerationAction.approved => permissions.canApprove,
      ModerationAction.rejected => permissions.canReject,
      ModerationAction.escalated => permissions.canEscalate,
    };
    if (!allowed) {
      throw ApiException(
        ApiErrorKind.forbidden,
        "You don't have permission to ${_permissionLabel(decision.action)}.",
      );
    }
  }

  static String _permissionLabel(ModerationAction action) => switch (action) {
        ModerationAction.approved => 'approve accounts',
        ModerationAction.rejected => 'reject accounts',
        ModerationAction.escalated => 'escalate to admin',
      };
}
