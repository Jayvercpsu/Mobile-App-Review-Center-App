import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Simple, screen-scoped protection against screenshots/screen-recording.
///
/// On Android this uses `FLAG_SECURE`, which typically results in:
/// - screenshots being blocked
/// - screen recordings / screen sharing showing a black screen
///
/// No-op on Web and non-Android platforms.
class ScreenSecurity {
  static int _refCount = 0;
  static const MethodChannel _channel = MethodChannel(
    'ph.boardmaster.app_review_center/screen_security',
  );

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> enable() async {
    if (!_isSupported) return;

    _refCount += 1;
    if (_refCount != 1) return;

    try {
      await _channel.invokeMethod<void>('enableSecure');
    } catch (_) {
      // If the platform channel isn't available, we silently ignore.
    }
  }

  static Future<void> disable() async {
    if (!_isSupported) return;
    if (_refCount <= 0) return;

    _refCount -= 1;
    if (_refCount != 0) return;

    try {
      await _channel.invokeMethod<void>('disableSecure');
    } catch (_) {
      // If the platform channel isn't available, we silently ignore.
    }
  }
}
