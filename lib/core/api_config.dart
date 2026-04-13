import 'runtime_env.dart';

class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _configuredWebsiteBaseUrl = String.fromEnvironment(
    'WEBSITE_BASE_URL',
    defaultValue: '',
  );
  static const String _configuredFallbackBaseUrls = String.fromEnvironment(
    'API_FALLBACK_BASE_URLS',
    defaultValue: '',
  );
  static const List<String> _fallbackBaseUrls = <String>[
    'http://127.0.0.1:8000/api',
    'http://localhost:8000/api',
    'http://10.0.2.2:8000/api',
    'http://10.0.3.2:8000/api',
    'http://192.168.0.157:8000/api',
    'http://10.239.202.119:8000/api',
  ];

  static String get baseUrl {
    final String configured = _primaryConfiguredBaseUrl();
    if (configured.isNotEmpty) {
      return configured;
    }
    return _fallbackBaseUrls.first;
  }

  static List<String> candidateBaseUrls() {
    final Set<String> urls = <String>{};

    final String primary = _primaryConfiguredBaseUrl();
    if (primary.isNotEmpty) {
      urls.add(primary);
    }

    for (final String candidate in _configuredFallbackCandidates()) {
      final String normalized = _normalizeBaseUrl(candidate);
      if (normalized.isNotEmpty) {
        urls.add(normalized);
      }
    }

    for (final String candidate in _splitCandidates(
      _configuredFallbackBaseUrls,
    )) {
      final String normalized = _normalizeBaseUrl(candidate);
      if (normalized.isNotEmpty) {
        urls.add(normalized);
      }
    }

    for (final String fallback in _fallbackBaseUrls) {
      final String normalized = _normalizeBaseUrl(fallback);
      if (normalized.isNotEmpty) {
        urls.add(normalized);
      }
    }

    return urls.toList(growable: false);
  }

  static String get websiteBaseUrl {
    final String fromDartDefine = _normalizeWebsiteBaseUrl(
      _configuredWebsiteBaseUrl,
    );
    if (fromDartDefine.isNotEmpty) {
      return fromDartDefine;
    }

    final String fromRuntimeEnv = _normalizeWebsiteBaseUrl(
      RuntimeEnv.get('WEBSITE_BASE_URL'),
    );
    if (fromRuntimeEnv.isNotEmpty) {
      return fromRuntimeEnv;
    }

    return _deriveWebsiteBaseUrlFromApi(baseUrl);
  }

  static const String login = '/mobile/login';
  static const String googleLogin = '/mobile/login/google';
  static const String register = '/mobile/register';
  static const String forgotPassword = '/mobile/password/forgot';
  static const String checkEmail = '/mobile/email/check';
  static const String resendVerification =
      '/mobile/email/verification-notification';
  static const String me = '/mobile/me';
  static const String demoSeen = '/mobile/demo/seen';
  static const String plans = '/mobile/plans';
  static const String profile = '/mobile/profile';
  static const String planSelect = '/mobile/plans/select';
  static const String dashboardMetrics = '/mobile/dashboard/metrics';
  static const String referrals = '/mobile/referrals';
  static const String referralApply = '/mobile/referrals/apply';
  static const String referralRedeem = '/mobile/referrals/redeem';
  static const String subscriptionHistory = '/mobile/subscriptions/history';
  static const String paymongoCheckout = '/paymongo/checkout';
  static const String subjects = '/mobile/subjects';
  static const String quizGenerate = '/mobile/quiz/generate';
  static const String quizSubmit = '/mobile/quiz/submit';
  static const String quizAttempts = '/mobile/quiz/attempts';
  static const String quizAttemptsDelete = '/mobile/quiz/attempts/delete';
  static const String quizAttemptsClear = '/mobile/quiz/attempts/clear';
  static const String feedback = '/mobile/reviews';

  static Uri uri(String path, {String? overrideBaseUrl}) {
    final String sourceBase = (overrideBaseUrl ?? baseUrl).trim();
    final String normalizedBase = sourceBase.endsWith('/')
        ? sourceBase.substring(0, sourceBase.length - 1)
        : sourceBase;
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  static Uri marketingUri(String path, {String? overrideWebsiteBaseUrl}) {
    final String sourceBase = (overrideWebsiteBaseUrl ?? websiteBaseUrl).trim();
    final Uri websiteUri = Uri.parse(sourceBase);
    final List<String> baseSegments = List<String>.from(websiteUri.pathSegments)
      ..removeWhere((String segment) => segment.isEmpty);
    final List<String> pathSegments = path
        .split('/')
        .map((String segment) => segment.trim())
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);

    return websiteUri.replace(
      pathSegments: <String>[...baseSegments, ...pathSegments],
      query: null,
      fragment: null,
    );
  }

  static String _normalizeBaseUrl(String value) {
    String normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }

    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    if (!normalized.toLowerCase().endsWith('/api')) {
      normalized = '$normalized/api';
    }

    return normalized;
  }

  static String _normalizeWebsiteBaseUrl(String value) {
    String normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }

    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }

  static String _deriveWebsiteBaseUrlFromApi(String apiBaseUrl) {
    final Uri apiUri = Uri.parse(apiBaseUrl);
    final List<String> segments = List<String>.from(apiUri.pathSegments);
    if (segments.isNotEmpty && segments.last.toLowerCase() == 'api') {
      segments.removeLast();
    }

    final Uri websiteUri = apiUri.replace(
      pathSegments: segments,
      query: null,
      fragment: null,
    );
    return _normalizeWebsiteBaseUrl(websiteUri.toString());
  }

  static Iterable<String> _splitCandidates(String raw) sync* {
    for (final String chunk in raw.split(RegExp(r'[,\n;]+'))) {
      final String trimmed = chunk.trim();
      if (trimmed.isNotEmpty) {
        yield trimmed;
      }
    }
  }

  static String _primaryConfiguredBaseUrl() {
    final String fromDartDefine = _normalizeBaseUrl(_configuredBaseUrl);
    if (fromDartDefine.isNotEmpty) {
      return fromDartDefine;
    }
    return _normalizeBaseUrl(RuntimeEnv.get('API_BASE_URL'));
  }

  static Iterable<String> _configuredFallbackCandidates() {
    final String fromRuntimeEnv = RuntimeEnv.get('API_FALLBACK_BASE_URLS');
    if (fromRuntimeEnv.isEmpty) {
      return const <String>[];
    }
    return _splitCandidates(fromRuntimeEnv);
  }
}
