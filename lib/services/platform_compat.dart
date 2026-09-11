import 'package:flutter/foundation.dart';

/// Web-safe replacement for `dart:io` Platform checks. Works on every target
/// platform (Android, iOS, web, desktop) because it never touches `dart:io`.
class PlatformCompat {
  PlatformCompat._();

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isWeb => kIsWeb;
  static bool get isMobile => isAndroid || isIOS;
}
