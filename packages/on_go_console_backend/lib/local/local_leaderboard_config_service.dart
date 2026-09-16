import 'dart:convert';

import 'package:on_go_shared/on_go_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_value.dart';
import 'local_performance_audit_log.dart';

/// The leaderboard's settings and seasons, as the admin sets them.
///
/// Local even when the console is connected to the On Go API: the API has no
/// place for them yet (see [LeaderboardConfigApi]). Saved in this browser so a
/// reload keeps them, and reaching no phone — the pages that edit them say so.
/// Every change is recorded in the audit log.
class LocalLeaderboardConfigService implements LeaderboardConfigApi {
  LocalLeaderboardConfigService({LocalPerformanceAuditLog? audit, this.persist = true, DateTime Function()? clock})
      : audit = audit ?? LocalPerformanceAuditLog(),
        _clock = clock ?? DateTime.now {
    if (persist) _restored = _restore();
  }

  static const String _configKey = 'leaderboard_config';
  static const String _seasonsKey = 'leaderboard_seasons';

  final LocalPerformanceAuditLog audit;

  /// False for tests, which should not read or write browser storage.
  final bool persist;

  final DateTime Function() _clock;
  final LiveValue<LeaderboardConfig> _config = LiveValue(LeaderboardConfig.defaults);
  final LiveValue<List<Season>> _seasons = LiveValue(const []);
  Future<void> _restored = Future<void>.value();
  bool _changed = false;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_changed) return;
      final config = prefs.getString(_configKey);
      if (config != null) {
        final decoded = jsonDecode(config);
        if (decoded is Map) {
          final saved = LeaderboardConfig.fromJson(Map<String, dynamic>.from(decoded));
          if (saved.isValid) _config.set(saved);
        }
      }
      final seasons = prefs.getString(_seasonsKey);
      if (seasons != null) {
        final decoded = jsonDecode(seasons);
        if (decoded is List) {
          _seasons.set([
            for (final item in decoded.whereType<Map>()) Season.fromJson(Map<String, dynamic>.from(item)),
          ]);
        }
      }
    } catch (_) {
      // No storage, or something unreadable in it: the defaults stand.
    }
  }

  Future<void> _save() async {
    _changed = true;
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(_config.value.toJson()));
      await prefs.setString(_seasonsKey, jsonEncode([for (final s in _seasons.value) s.toJson()]));
    } catch (_) {
      // Still applies for this session.
    }
  }

  @override
  Future<LeaderboardConfig> fetchConfig() async {
    await _restored;
    return _config.value;
  }

  @override
  Stream<LeaderboardConfig> watchConfig() => _config.stream;

  @override
  Future<LeaderboardConfig> updateConfig(LeaderboardConfig config, {required String actor, String? reason}) async {
    final problem = config.problem;
    if (problem != null) throw ApiException(ApiErrorKind.rejected, problem);
    final previous = _config.value;
    _config.set(config);
    await _save();
    audit.record(
      action: PerformanceAuditAction.configUpdated,
      actor: actor,
      subjectId: 'leaderboard',
      reason: reason,
      detail: previous.enabled == config.enabled
          ? 'Scoring and multiplier settings changed'
          : (config.enabled ? 'Leaderboard made public' : 'Leaderboard turned off'),
    );
    return config;
  }

  @override
  Future<List<Season>> listSeasons() async {
    await _restored;
    return _seasons.value;
  }

  @override
  Stream<List<Season>> watchSeasons() => _seasons.stream;

  @override
  Future<Season> createSeason({
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
    required String actor,
  }) async {
    final now = _clock();
    final season = Season(
      id: 'season_${now.microsecondsSinceEpoch}',
      name: name.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
    );
    final problem = season.problem;
    if (problem != null) throw ApiException(ApiErrorKind.rejected, problem);
    _seasons.set([..._seasons.value, season]);
    await _save();
    audit.record(action: PerformanceAuditAction.seasonCreated, actor: actor, subjectId: season.id, detail: season.name);
    return season;
  }

  @override
  Future<Season> startSeason(String seasonId, {required String actor}) async {
    final season = _find(seasonId);
    if (season.status != SeasonStatus.scheduled) {
      throw const ApiException(ApiErrorKind.rejected, 'Only a scheduled season can be started.');
    }
    if (_seasons.value.any((s) => s.status == SeasonStatus.active)) {
      throw const ApiException(ApiErrorKind.rejected, 'End the running season before starting another.');
    }
    final now = _clock();
    if (!now.isBefore(season.endsAt)) {
      throw const ApiException(ApiErrorKind.rejected, "This season's end date has already passed.");
    }
    final started = season.copyWith(status: SeasonStatus.active, startedAt: now);
    _replace(started);
    await _save();
    audit.record(action: PerformanceAuditAction.seasonStarted, actor: actor, subjectId: seasonId, detail: season.name);
    return started;
  }

  @override
  Future<Season> endSeason(String seasonId, {required String actor, List<SeasonResult> results = const []}) async {
    final season = _find(seasonId);
    if (season.status != SeasonStatus.active) {
      throw const ApiException(ApiErrorKind.rejected, 'Only a running season can be ended.');
    }
    final ended = season.copyWith(status: SeasonStatus.ended, endedAt: _clock(), results: results);
    _replace(ended);
    await _save();
    audit.record(
      action: PerformanceAuditAction.seasonEnded,
      actor: actor,
      subjectId: seasonId,
      detail: '${season.name} — ${results.length} final placement${results.length == 1 ? '' : 's'} recorded',
    );
    return ended;
  }

  Season _find(String seasonId) {
    for (final season in _seasons.value) {
      if (season.id == seasonId) return season;
    }
    throw const ApiException(ApiErrorKind.notFound, 'That season no longer exists.');
  }

  void _replace(Season season) =>
      _seasons.set([for (final s in _seasons.value) s.id == season.id ? season : s]);
}
