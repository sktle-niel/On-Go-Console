import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:on_go_api/on_go_api.dart';

import '../console_backend.dart';
import 'http_client_factory.dart';

export 'package:on_go_api/on_go_api.dart'
    show ApiEnvironment, ApiFeatures, BackendMode, SessionChange, SessionChangeKind, SessionEndReason;

/// Connects the console to the On Go API.
///
/// The console's session is the browser's: the refresh token is an httpOnly
/// cookie (`ongo_refresh`) the page never sees, so there is nothing to store,
/// and every request goes out with credentials so the cookie can travel.
///
/// | Contract | Backed by |
/// |---|---|
/// | [AuthApi] | the API, `surface: console` |
/// | [PointsPolicyApi] | the API — admins can update it |
/// | [PlatformRevenueApi] | the API (`GET /revenue/summary`) |
/// | [PlatformAppearanceApi] | the API; publish/remove answer 501 until Step 7 |
/// | [AccountVerificationApi] | local until Step 5 (`ONGO_API_VERIFICATION`) |
/// | [ModeratorDirectoryApi] | local until Step 6 (`ONGO_API_MODERATORS`) |
class ConsoleApi {
  ConsoleApi._();

  static OnGoApi? _api;

  static OnGoApi? get connection => _api;

  /// Installs the API unless the build asked for `ONGO_BACKEND=local`.
  /// Returns whether it did.
  static bool installFromDefines() {
    if (ApiEnvironment.backendModeFromDefines() == BackendMode.local) return false;
    install();
    return true;
  }

  static OnGoApi install({
    ApiEnvironment? environment,
    http.Client? httpClient,
    EventConnector? eventConnector,
    ApiFeatures? features,
  }) {
    final api = OnGoApi(
      environment: environment ?? ApiEnvironment.fromDefines(),
      surface: AppSurface.console,
      httpClient: httpClient ?? createConsoleHttpClient(),
      eventConnector: eventConnector,
      logger: _log,
      features: features ?? ApiFeatures.fromDefines(),
    );
    _api = api;
    ConsoleBackend.configure(
      usesApi: true,
      auth: api.auth,
      pointsPolicy: api.pointsPolicy,
      revenue: api.revenue,
      appearance: api.appearance,
      verification: api.features.verification ? api.verification : null,
      moderators: api.features.moderators ? api.moderators : null,
    );
    return api;
  }

  /// Session starts and ends. Empty in a local build.
  static Stream<SessionChange> get sessionChanges =>
      _api?.session.changes ?? const Stream<SessionChange>.empty();

  static void _log(String method, String path, ApiException error) {
    // The requestId in here is what links a report to the server log.
    debugPrint('On Go API $method $path failed: $error');
  }

  @visibleForTesting
  static Future<void> debugReset() async {
    final api = _api;
    _api = null;
    ConsoleBackend.debugReset();
    await api?.close();
  }
}
