class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.14.189.119:8000/api',
  );
  static const List<String> _fallbackBaseUrls = <String>[
    'http://10.0.2.2:8000/api',
    'http://127.0.0.1:8000/api',
    'http://localhost:8000/api',
  ];

  static String get baseUrl => _configuredBaseUrl;

  static List<String> candidateBaseUrls() {
    final Set<String> urls = <String>{};
    final String primary = _configuredBaseUrl.trim();
    if (primary.isNotEmpty) {
      urls.add(primary);
    }
    urls.addAll(_fallbackBaseUrls);
    return urls.toList(growable: false);
  }

  static const String login = '/mobile/login';
  static const String register = '/mobile/register';
  static const String plans = '/mobile/plans';
  static const String planSelect = '/mobile/plans/select';
  static const String subjects = '/mobile/subjects';
  static const String quizGenerate = '/mobile/quiz/generate';
  static const String quizSubmit = '/mobile/quiz/submit';

  static Uri uri(String path, {String? overrideBaseUrl}) {
    final String sourceBase = (overrideBaseUrl ?? baseUrl).trim();
    final String normalizedBase = sourceBase.endsWith('/')
        ? sourceBase.substring(0, sourceBase.length - 1)
        : sourceBase;
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }
}
