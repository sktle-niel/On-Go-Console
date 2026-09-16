import 'package:on_go_shared/on_go_shared.dart';

import 'local/local_appearance_service.dart';
import 'local/local_points_policy_service.dart';
import 'local/local_client_ip_service.dart';
import 'local/local_console_auth_service.dart';
import 'local/local_moderator_directory_service.dart';
import 'local/local_revenue_service.dart';
import 'local/local_leaderboard_config_service.dart';
import 'local/local_performance_audit_log.dart';
import 'local/local_performance_review_service.dart';
import 'local/local_rank_policy_service.dart';
import 'local/local_urgency_policy_service.dart';
import 'local/local_verification_service.dart';

export 'package:on_go_shared/on_go_shared.dart';

export 'local/local_appearance_service.dart';
export 'local/local_moderator_directory_service.dart';
export 'local/local_verification_service.dart';

/// Every call this console makes that will one day leave the browser.
///
/// The mirror of `lib/services/backend/mobile_backend.dart` in the mobile app.
/// The two applications are separate front ends over one system, and this is
/// where the console reaches the parts of that system the phone owns — a
/// mechanic's registration, a payment that completed — and where it writes the
/// parts the phone reads back.
///
/// The defaults are local, in-browser implementations. `ConsoleApi.install`
/// swaps in the On Go API's at startup for whatever the API serves today, and
/// not one screen changes: they already await Futures and build from Streams.
/// The ones the API does not serve yet keep their local implementation.
class ConsoleBackend {
  ConsoleBackend._({
    required this.auth,
    required this.verification,
    required this.moderators,
    required this.revenue,
    required this.appearance,
    required this.pointsPolicy,
    required this.urgencyPolicy,
    required this.rankPolicy,
    required this.leaderboardConfig,
    required this.performanceReview,
    this.usesApi = false,
  });

  /// Builds the default, local-only backend. Everything shares one directory
  /// instance, because deciding a request has to be able to credit the
  /// moderator who decided it.
  factory ConsoleBackend._local() {
    final directory = LocalModeratorDirectoryService(clientIp: _clientIp);
    // One audit trail for settings, seasons, adjustments and invalidations.
    final performanceAudit = LocalPerformanceAuditLog();
    final leaderboardConfig = LocalLeaderboardConfigService(audit: performanceAudit);
    return ConsoleBackend._(
      leaderboardConfig: leaderboardConfig,
      performanceReview: LocalPerformanceReviewService(config: leaderboardConfig, audit: performanceAudit),
      auth: LocalConsoleAuthService(directory),
      verification: LocalVerificationService(directory),
      moderators: directory,
      revenue: LocalRevenueService(),
      appearance: LocalAppearanceService(),
      pointsPolicy: LocalPointsPolicyService(),
      urgencyPolicy: LocalUrgencyPolicyService(),
      rankPolicy: LocalRankPolicyService(),
    );
  }

  /// The address stamped onto audit entries written locally.
  ///
  /// One instance for the whole console, so every entry agrees on where this
  /// session is working from. The server takes this over per request once the
  /// API client is installed — see [LocalClientIpService].
  static final LocalClientIpService _clientIp = LocalClientIpService();

  static LocalClientIpService get clientIp => _clientIp;

  static ConsoleBackend _instance = ConsoleBackend._local();

  static ConsoleBackend get instance => _instance;

  /// Who is signed in to the console.
  final AuthApi auth;

  /// The moderation queue — filed by the mobile app, decided here.
  final AccountVerificationApi verification;

  /// The moderator roster and its audit trail.
  final ModeratorDirectoryApi moderators;

  /// Platform revenue — reported by the mobile app, read here.
  final PlatformRevenueApi revenue;

  /// Branding this console publishes for the mobile app.
  final PlatformAppearanceApi appearance;

  /// The points rules this console configures for the whole platform.
  final PointsPolicyApi pointsPolicy;

  /// Each urgency level's additional charge and completion time. Local even
  /// with the API installed: the API contract has no place for them yet.
  final UrgencyPolicyApi urgencyPolicy;

  /// The mechanic ranks' requirements and points multipliers. Local even with
  /// the API installed: the API contract has no place for them yet.
  final RankPolicyApi rankPolicy;

  /// The seasonal leaderboard's settings — including whether it is public — and
  /// its seasons. Local even with the API installed: not in the contract yet.
  final LeaderboardConfigApi leaderboardConfig;

  /// Standings, score breakdowns, evaluations and point transactions for the
  /// admin to review. Local, and empty, until the jobs domain is on the API.
  final PerformanceReviewApi performanceReview;

  /// The local review service, when that is what is installed — so a page can
  /// tell "no records have reached this console" from "no activity".
  LocalPerformanceReviewService? get localPerformanceReview => performanceReview is LocalPerformanceReviewService
      ? performanceReview as LocalPerformanceReviewService
      : null;

  /// Whether accounts and sessions live on the On Go API. When true, who is
  /// signed in and what they may do come from the server's session rather than
  /// the local moderator directory.
  final bool usesApi;

  /// The local moderation service, when that is what is installed.
  ///
  /// A handful of console screens need things that are genuinely not API
  /// operations — the unread count behind the notification bell, the bytes of
  /// a photo that has nowhere to be uploaded to. Reaching them through a
  /// nullable accessor keeps those screens honest: they degrade to the plain
  /// API rather than assuming the local implementation is there.
  LocalVerificationService? get localVerification =>
      verification is LocalVerificationService ? verification as LocalVerificationService : null;

  LocalModeratorDirectoryService? get localModerators => moderators is LocalModeratorDirectoryService
      ? moderators as LocalModeratorDirectoryService
      : null;

  LocalAppearanceService? get localAppearance =>
      appearance is LocalAppearanceService ? appearance as LocalAppearanceService : null;

  /// Replaces some or all of the implementations. Call it once, before
  /// `runApp`, when the API client arrives; each argument left null keeps the
  /// local implementation it already had.
  static void configure({
    AuthApi? auth,
    AccountVerificationApi? verification,
    ModeratorDirectoryApi? moderators,
    PlatformRevenueApi? revenue,
    PlatformAppearanceApi? appearance,
    PointsPolicyApi? pointsPolicy,
    UrgencyPolicyApi? urgencyPolicy,
    RankPolicyApi? rankPolicy,
    LeaderboardConfigApi? leaderboardConfig,
    PerformanceReviewApi? performanceReview,
    bool? usesApi,
  }) {
    _instance = ConsoleBackend._(
      auth: auth ?? _instance.auth,
      verification: verification ?? _instance.verification,
      moderators: moderators ?? _instance.moderators,
      revenue: revenue ?? _instance.revenue,
      appearance: appearance ?? _instance.appearance,
      pointsPolicy: pointsPolicy ?? _instance.pointsPolicy,
      urgencyPolicy: urgencyPolicy ?? _instance.urgencyPolicy,
      rankPolicy: rankPolicy ?? _instance.rankPolicy,
      leaderboardConfig: leaderboardConfig ?? _instance.leaderboardConfig,
      performanceReview: performanceReview ?? _instance.performanceReview,
      usesApi: usesApi ?? _instance.usesApi,
    );
  }

  /// Back to the local implementations. For tests.
  static void debugReset() => _instance = ConsoleBackend._local();
}
