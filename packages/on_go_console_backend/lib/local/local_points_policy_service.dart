import 'package:on_go_shared/on_go_shared.dart';

import 'live_value.dart';

/// The points rules, held in this browser session.
///
/// The console is where they are set, so unlike the mobile app's end of this
/// interface, [update] is the operation that matters here. It starts on
/// [PointsPolicy.defaults] — the platform's opening position, which the admin
/// edits rather than a second copy of the rules.
///
/// Until the backend exists, a change made here reaches no phone: the rules
/// live in this browser, exactly as a published background photo does. When
/// the API client is installed this class is replaced and the same screen
/// starts writing rules the whole platform obeys.
class LocalPointsPolicyService implements PointsPolicyApi {
  LocalPointsPolicyService({PointsPolicy? policy})
      : _policy = LiveValue(policy ?? PointsPolicy.defaults);

  final LiveValue<PointsPolicy> _policy;

  @override
  Future<PointsPolicy> fetch() async => _policy.value;

  @override
  Stream<PointsPolicy> watch() => _policy.stream;

  @override
  Future<PointsPolicy> update(PointsPolicy policy) async {
    if (policy.clientNormal < 0 ||
        policy.clientUrgent < 0 ||
        policy.clientEmergency < 0 ||
        policy.mechanicPerPeso < 0) {
      throw const ApiException(
        ApiErrorKind.rejected,
        'Points rates cannot be negative.',
      );
    }

    _policy.set(policy);
    return policy;
  }

  Future<void> dispose() => _policy.dispose();
}
