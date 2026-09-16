import 'package:flutter/material.dart';

import 'package:on_go_console_backend/console_backend.dart';
import '../theme/console_theme.dart';

/// Formatting and colour rules the console applies to shared domain values.
///
/// These are presentation, so they live here rather than on the DTOs in
/// `package:on_go_shared` — the mobile app renders several of the same values
/// its own way, and neither should be forced through the other's choices.

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 'Sep 8, 2026'.
String formatConsoleDate(DateTime d) {
  final local = d.toLocal();
  return '${_monthNames[local.month - 1]} ${local.day}, ${local.year}';
}

/// 'Sep 8, 2:05 PM'.
String formatConsoleDateTime(DateTime d) {
  final local = d.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_monthNames[local.month - 1]} ${local.day}, $hour:$minute $period';
}

/// Peso amounts for the revenue screens. Platform fee revenue starts small, so
/// exact pesos are shown until the number passes a thousand.
String formatPeso(double value) {
  if (value.abs() < 1000) return '₱${value.toStringAsFixed(0)}';
  return '₱${(value / 1000).toStringAsFixed(1)}K';
}

/// The colour a verification status is drawn in, everywhere it appears.
Color colorForApproval(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => ConsoleColors.success,
      ApprovalStatus.rejected => ConsoleColors.danger,
      ApprovalStatus.pending => ConsoleColors.warning,
    };

Color colorForModerationAction(ModerationAction action) => switch (action) {
      ModerationAction.approved => ConsoleColors.success,
      ModerationAction.rejected => ConsoleColors.danger,
      ModerationAction.escalated => ConsoleColors.warning,
    };

IconData iconForModerationAction(ModerationAction action) => switch (action) {
      ModerationAction.approved => Icons.check,
      ModerationAction.rejected => Icons.close,
      ModerationAction.escalated => Icons.flag_outlined,
    };

Color colorForAuditAction(AuditAction action) => switch (action) {
      AuditAction.added => ConsoleColors.success,
      AuditAction.removed => ConsoleColors.danger,
      AuditAction.promoted => ConsoleColors.warning,
      // Queue decisions keep the colours they wear in the activity feed and
      // on the queue itself, so one action reads the same everywhere.
      AuditAction.approved => ConsoleColors.success,
      AuditAction.rejected => ConsoleColors.danger,
      AuditAction.escalated => ConsoleColors.warning,
    };

IconData iconForAuditAction(AuditAction action) => switch (action) {
      AuditAction.added => Icons.person_add_alt,
      AuditAction.removed => Icons.person_remove_alt_1,
      AuditAction.promoted => Icons.trending_up,
      AuditAction.approved => Icons.check_circle_outline,
      AuditAction.rejected => Icons.cancel_outlined,
      AuditAction.escalated => Icons.flag_outlined,
    };

/// Business accounts read as informational, mechanics as brand — the same
/// split the mobile app's moderator panel used.
Color colorForAccountRole(AccountRole role) =>
    role == AccountRole.mechanic ? ConsoleColors.brand : ConsoleColors.info;

/// Turns an [ApiException] into something worth putting in front of a person.
///
/// The services throw these for every refused action, so this is the console's
/// single place for saying what went wrong.
String describeApiError(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}
