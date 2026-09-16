import 'package:http/http.dart' as http;

/// Off the web there is no cookie jar to opt into.
http.Client createConsoleHttpClient() => http.Client();
