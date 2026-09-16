import 'dart:convert';

import 'package:on_go_shared/on_go_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_value.dart';

/// The mechanic ranks' requirements and points multipliers, as the admin sets
/// them.
///
/// Local even when the console is connected to the On Go API: the API has no
/// place for these settings yet (see [RankPolicyApi]). They are saved in this
/// browser so a reload keeps them, and reach no phone — the page that edits
/// them says so. When the backend stores them, an HTTP implementation replaces
/// this one.
class LocalRankPolicyService implements RankPolicyApi {
  LocalRankPolicyService({RankPolicy? policy, this.persist = true})
      : _policy = LiveValue(policy ?? RankPolicy.defaults) {
    if (persist) _restored = _restore();
  }

  static const String _prefsKey = 'rank_policy';

  /// False for tests, which should not read or write browser storage.
  final bool persist;

  final LiveValue<RankPolicy> _policy;
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
        final saved = RankPolicy.fromJson(Map<String, dynamic>.from(decoded));
        if (saved.isValid) _policy.set(saved);
      }
    } catch (_) {
      // No storage, or something unreadable in it: the defaults stand.
    }
  }

  @override
  Future<RankPolicy> fetch() async {
    await _restored;
    return _policy.value;
  }

  @override
  Stream<RankPolicy> watch() => _policy.stream;

  @override
  Future<RankPolicy> update(RankPolicy policy) async {
    final problem = policy.problem;
    if (problem != null) throw ApiException(ApiErrorKind.rejected, problem);

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
