import 'package:flutter/material.dart';

import '../../app/console_routes.dart';
import '../../app/console_shell.dart';
import 'package:on_go_console_backend/api/console_api.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_widgets.dart';
import '../shared/settings_rows.dart';

/// Admin settings: this console's appearance, and the platform rules an admin
/// owns.
///
/// The split in the cards is deliberate — the first only affects this browser,
/// the others reach every phone. Grouping them together would blur a
/// difference that matters.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShell(
      child: ListView(
        padding: consolePagePadding(context),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ConsoleSettingsSection(
                  title: 'This console',
                  subtitle: 'Applies to your browser only',
                  children: [AppearanceSettingsRow()],
                ),
                SizedBox(height: context.layout.sectionSpacing),
                ConsoleSettingsSection(
                  title: 'Platform rules',
                  subtitle: 'What every job is worth, costs and must be finished within',
                  children: [
                    ConsoleSettingsRow(
                      icon: Icons.tune,
                      title: 'Urgency levels',
                      subtitle: 'Points, additional charge and time completion for Normal, Urgent and Emergency',
                      onTap: () => Navigator.pushNamed(context, ConsoleRoutes.adminPoints),
                    ),
                    ConsoleSettingsRow(
                      icon: Icons.military_tech_outlined,
                      title: 'Mechanic ranks',
                      subtitle: 'Requirements and points multiplier for Iron, Bronze, Silver, Gold and Platinum',
                      onTap: () => Navigator.pushNamed(context, ConsoleRoutes.adminRanks),
                    ),
                    ConsoleSettingsRow(
                      icon: Icons.emoji_events_outlined,
                      title: 'Leaderboard & seasons',
                      subtitle: 'Public switch, seasons, scoring, seasonal multipliers and the multiplier cap',
                      onTap: () => Navigator.pushNamed(context, ConsoleRoutes.adminLeaderboard),
                    ),
                    ConsoleSettingsRow(
                      icon: Icons.fact_check_outlined,
                      title: 'Performance review',
                      subtitle: 'Standings preview, evaluations, point transactions and flagged activity',
                      onTap: () => Navigator.pushNamed(context, ConsoleRoutes.adminPerformance),
                    ),
                  ],
                ),
                SizedBox(height: context.layout.sectionSpacing),
                const ConsoleSettingsSection(
                  title: 'Mobile app',
                  subtitle: 'Branding every client and mechanic sees',
                  children: [BackgroundSettingsRow()],
                ),
                SizedBox(height: context.layout.sectionSpacing),
                const _ConnectionCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the console stands relative to the On Go API.
///
/// An admin looking at an empty queue deserves to be told why, in the product,
/// rather than left to conclude the tool is broken.
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final connection = ConsoleApi.connection;
    final connected = ConsoleBackend.instance.usesApi && connection != null;

    return ConsoleCard(
      boxedOnPhone: true,
      title: 'Mobile app connection',
      subtitle: 'How this console reaches the On Go app',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                size: 18,
                color: connected ? ConsoleColors.text : ConsoleColors.warning,
              ),
              const SizedBox(width: 10),
              Text(
                connected ? 'Connected to the On Go API' : 'Local build — not connected',
                style: text.titleSmall?.copyWith(color: connected ? null : ConsoleColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            connected
                ? 'Sign-in, the points and the revenue ledger come from the API. The '
                    'verification queue, moderators, the audit log, background uploads and '
                    'the urgency levels\' charges and completion times, the mechanic ranks and the leaderboard '
                    'settings are not served by it '
                    'yet, and stay in this browser until they are.'
                : 'This console was built with ONGO_BACKEND=local: everything stays in this '
                    'browser and nothing reaches the mobile app.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          ConsoleField(
            icon: connected ? Icons.link : Icons.link_off,
            label: 'API base URL',
            value: connected ? connection.environment.baseUrl : 'Not configured',
          ),
          ConsoleField(
            icon: Icons.swap_horiz,
            label: 'Contract',
            value: 'package:on_go_shared · ${ApiEndpoints.version}',
          ),
        ],
      ),
    );
  }
}
