// Conditional import for web auth helper
export 'web_auth_helper_stub.dart'
    if (dart.library.html) 'web_auth_helper.dart';