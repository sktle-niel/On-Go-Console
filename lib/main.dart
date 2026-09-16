import 'package:flutter/material.dart';

import 'src/app/console_app.dart';
import 'package:on_go_console_backend/api/console_api.dart';
import 'src/dev_mock/dev_mock.dart';
import 'src/theme/console_theme.dart';

/// The On Go admin console — the Admin and Moderator web application.
///
/// This is one of the product's two front ends. The other is the On Go mobile
/// app (Client + Mechanic), in its own repository beside this one. They share
/// no code except `package:on_go_shared`, which holds the models and API
/// contracts they exchange, and they will meet at a backend that implements
/// those contracts. See ARCHITECTURE.md in the On Go repository.
///
/// The console talks to the On Go API (staging unless `ONGO_API_BASE_URL`
/// says otherwise) — see `ConsoleApi`. Built with `ONGO_BACKEND=local`, every
/// contract keeps its in-browser implementation instead.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the saved appearance before the first frame, so the console never
  // flashes light before painting dark.
  await ThemeController.instance.load();

  if (!ConsoleApi.installFromDefines()) {
    // FAKE DATA — UI testing only, and only in a local build: against the API
    // the charts draw the real ledger. Fills the Admin revenue ledger so the
    // Overview and Income charts have something to draw. Delete this line and
    // the import above with `src/dev_mock/` to remove it — see its README.
    installDevMocks();
  }

  runApp(const ConsoleApp());
}
