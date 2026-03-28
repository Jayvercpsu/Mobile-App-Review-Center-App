import 'package:flutter/services.dart';

class RuntimeEnv {
  RuntimeEnv._();

  static const String _assetFileName = '.env';
  static final Map<String, String> _values = <String, String>{};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }

    try {
      final String raw = await rootBundle.loadString(_assetFileName);
      for (final String line in raw.split('\n')) {
        final String trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }

        final int index = trimmed.indexOf('=');
        if (index <= 0) {
          continue;
        }

        String key = trimmed.substring(0, index).trim();
        String value = trimmed.substring(index + 1).trim();
        if (key.startsWith('export ')) {
          key = key.substring(7).trim();
        }
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        if (key.isEmpty) {
          continue;
        }
        _values[key] = value;
      }
    } catch (_) {
      // Optional .env file. App will continue with defaults.
    } finally {
      _loaded = true;
    }
  }

  static String get(String key) {
    final String value = _values[key] ?? '';
    return value.trim();
  }
}
