import 'dart:convert';

import 'package:on_go_shared/on_go_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_value.dart';

/// Each urgency level's additional charge and completion time, as the admin
/// sets them.
///
/// Local even when the console is connected to the On Go API: the API has no
/// place for these values yet (see [UrgencyPolicyApi]). They are saved in this
/// browser so a reload keeps them, and reach no phone — the page that edits
/// them says so. When the backend stores them, an HTTP implementation replaces
/// this one.
class LocalUrgencyPolicyService implements UrgencyPolicyApi {
  LocalUrgencyPolicyService({UrgencyPolicy? policy, this.persist = true})
      : _policy = LiveValue(policy ?? UrgencyPolicy.defaults) {
    if (persist) _restored = _restore();
  }

  static const String _prefsKey = 'urgency_policy';

  /// False for tests, which should not read or write browser storage.
  final bool persist;

  final LiveValue<UrgencyPolicy> _policy;
  Future<void> _restored = Future<void>.value();
  bool _updated = false;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      // An update made while this was loading is newer than what was saved.
      if (raw == null || _updated) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final saved = UrgencyPolicy.fromJson(Map<String, dynamic>.from(decoded));
        if (saved.isValid) _policy.set(saved);
      }
    } catch (_) {
      // No storage, or something unreadable in it: the defaults stand.
    }
  }

  @override
  Future<UrgencyPolicy> fetch() async {
    await _restored;
    return _policy.value;
  }

  @override
  Stream<UrgencyPolicy> watch() => _policy.stream;

  @override
  Future<UrgencyPolicy> update(UrgencyPolicy policy) async {
    if (!policy.isValid) {
      throw const ApiException(
        ApiErrorKind.rejected,
        'Additional charges cannot be negative, and a completion time needs at least 1 of its unit.',
      );
    }

    _updated = true;
    _policy.set(policy);
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(policy.toJson()));
      } catch (_) {
        // Still applies for this session.
      }
    }
    return policy;
  }

  Future<void> dispose() => _policy.dispose();
}
