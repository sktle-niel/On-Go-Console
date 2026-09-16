import 'package:on_go_shared/on_go_shared.dart';

/// Who changed what about the leaderboard, and why — held in this browser.
///
/// Shared by the local leaderboard services so settings, seasons, adjustments
/// and invalidations land in one trail. Never edited or trimmed; entries are
/// only added.
class LocalPerformanceAuditLog {
  final List<PerformanceAuditEntry> _entries = [];

  /// Newest first.
  List<PerformanceAuditEntry> get entries => List.unmodifiable(_entries.reversed);

  PerformanceAuditEntry record({
    required PerformanceAuditAction action,
    required String actor,
    required String subjectId,
    String? reason,
    String? detail,
    DateTime? at,
  }) {
    final when = at ?? DateTime.now();
    final entry = PerformanceAuditEntry(
      id: 'audit_${when.microsecondsSinceEpoch}_${_entries.length}',
      action: action,
      actor: actor,
      subjectId: subjectId,
      at: when,
      reason: reason,
      detail: detail,
    );
    _entries.add(entry);
    return entry;
  }
}
