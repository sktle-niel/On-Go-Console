import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Requests carry credentials, so the browser attaches the httpOnly refresh
/// cookie to `/api/v1/auth/*`. Harmless where it is not needed.
http.Client createConsoleHttpClient() => BrowserClient()..withCredentials = true;
