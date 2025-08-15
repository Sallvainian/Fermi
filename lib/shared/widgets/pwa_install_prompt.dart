// Conditional import for PWA install prompt
export 'pwa_install_prompt_stub.dart'
    if (dart.library.js_interop) 'pwa_install_prompt_web.dart';