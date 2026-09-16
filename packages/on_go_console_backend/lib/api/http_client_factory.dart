// The browser build needs a client that sends cookies; everything else (the
// VM that runs the tests) takes the plain one.
export 'http_client_factory_io.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart';
