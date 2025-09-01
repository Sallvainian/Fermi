// Conditional import for PWA update notifier
export 'pwa_update_notifier_stub.dart'
    if (dart.library.js_interop) 'pwa_update_notifier_web.dart';
