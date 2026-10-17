/// What the presentation page needs from the browser: full screen, and
/// reading the roster file. Does nothing off the web (e.g. in tests).
library;

export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
