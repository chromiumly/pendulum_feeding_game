/// The sound effects on one Web Audio context; on the web only.
library;

export 'web_audio_effects_stub.dart'
    if (dart.library.js_interop) 'web_audio_effects_web.dart';
