import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/app_models.dart';

class MobileApiService {
  MobileApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;
  String? _resolvedBaseUrl;

  void setAuthToken(String? token) {
    _token = token;
  }

  Future<ApiResult<AuthPayload>> login({
    required String email,
    required String password,
  }) async {
    return _postAuth(
      path: ApiConfig.login,
      payload: <String, dynamic>{'email': email.trim(), 'password': password},
    );
  }

  Future<ApiResult<AuthPayload>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _postAuth(
      path: ApiConfig.register,
      payload: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  Future<ApiResult<List<PlanOption>>> fetchPlans() async {
    try {
      final http.Response response = await _getWithFallback(
        path: ApiConfig.plans,
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<List<PlanOption>>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final List<dynamic> rawPlans;
      if (decoded is List<dynamic>) {
        rawPlans = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final dynamic nested = decoded['data'] ?? decoded['plans'];
        rawPlans = nested is List<dynamic> ? nested : <dynamic>[];
      } else {
        rawPlans = <dynamic>[];
      }

      final List<PlanOption> parsed = rawPlans
          .map(_toPlanOption)
          .whereType<PlanOption>()
          .toList();
      if (parsed.isEmpty) {
        return ApiResult<List<PlanOption>>.failure(
          'No plan data was returned by the server.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<List<PlanOption>>.success(parsed);
    } catch (_) {
      return ApiResult<List<PlanOption>>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<PlanSelectionPayload>> selectPlan({
    required int planId,
    String? billingCycle,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<PlanSelectionPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.planSelect,
        payload: <String, dynamic>{
          'plan_id': planId,
          if (billingCycle != null && billingCycle.trim().isNotEmpty)
            'billing_cycle': billingCycle.trim().toLowerCase(),
        },
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<PlanSelectionPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final PlanSelectionPayload? payload = _toPlanSelectionPayload(decoded);
      if (payload == null) {
        return ApiResult<PlanSelectionPayload>.failure(
          'Plan selection response is missing data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<PlanSelectionPayload>.success(payload);
    } catch (_) {
      return ApiResult<PlanSelectionPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<AuthPayload>> _postAuth({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final http.Response response = await _postWithFallback(
        path: path,
        payload: payload,
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<AuthPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final AuthPayload? parsed = _toAuthPayload(decoded);
      if (parsed == null) {
        return ApiResult<AuthPayload>.failure(
          'Server response is missing user data.',
          statusCode: response.statusCode,
        );
      }

      if (parsed.token != null && parsed.token!.isNotEmpty) {
        _token = parsed.token;
      }
      return ApiResult<AuthPayload>.success(parsed);
    } catch (_) {
      return ApiResult<AuthPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Map<String, String> _headers() {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_token != null && _token!.isNotEmpty)
        'Authorization': 'Bearer $_token',
    };
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    Object? lastError;
    http.Response? fallbackResponse;

    for (final String baseUrl in _candidateBaseUrls()) {
      try {
        final http.Response response = await _client.get(
          ApiConfig.uri(path, overrideBaseUrl: baseUrl),
          headers: _headers(),
        );
        if (response.statusCode == 404) {
          fallbackResponse = response;
          continue;
        }
        _resolvedBaseUrl = baseUrl;
        return response;
      } catch (error) {
        lastError = error;
      }
    }

    if (fallbackResponse != null) {
      return fallbackResponse;
    }
    throw lastError ?? Exception('Cannot connect to any configured API host.');
  }

  Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    Object? lastError;
    http.Response? fallbackResponse;

    for (final String baseUrl in _candidateBaseUrls()) {
      try {
        final http.Response response = await _client.post(
          ApiConfig.uri(path, overrideBaseUrl: baseUrl),
          headers: _headers(),
          body: jsonEncode(payload),
        );
        if (response.statusCode == 404) {
          fallbackResponse = response;
          continue;
        }
        _resolvedBaseUrl = baseUrl;
        return response;
      } catch (error) {
        lastError = error;
      }
    }

    if (fallbackResponse != null) {
      return fallbackResponse;
    }
    throw lastError ?? Exception('Cannot connect to any configured API host.');
  }

  List<String> _candidateBaseUrls() {
    final List<String> result = <String>[];
    final Set<String> seen = <String>{};

    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.trim().isNotEmpty) {
      final String normalized = _resolvedBaseUrl!.trim();
      if (seen.add(normalized)) {
        result.add(normalized);
      }
    }

    for (final String url in ApiConfig.candidateBaseUrls()) {
      final String normalized = url.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (seen.add(normalized)) {
        result.add(normalized);
      }
    }

    return result;
  }

  dynamic _decodeJson(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      final String trimmed = body.trim();
      final bool looksHtml =
          trimmed.startsWith('<!DOCTYPE html') || trimmed.startsWith('<html');
      return <String, dynamic>{
        'message': looksHtml
            ? 'Server returned HTML response. Check API endpoint path.'
            : 'Server returned non-JSON response.',
      };
    }
  }

  AuthPayload? _toAuthPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final dynamic data = decoded['data'];
    final Map<String, dynamic>? dataMap = data is Map<String, dynamic>
        ? data
        : null;

    final dynamic userRaw =
        decoded['user'] ??
        dataMap?['user'] ??
        (dataMap != null && _looksLikeUserMap(dataMap) ? dataMap : null);
    final Map<String, dynamic> user = userRaw is Map<String, dynamic>
        ? userRaw
        : <String, dynamic>{};
    Map<String, dynamic>? planMap;
    if (user['plan'] is Map<String, dynamic>) {
      planMap = user['plan'] as Map<String, dynamic>;
    } else if (dataMap != null && dataMap['plan'] is Map<String, dynamic>) {
      planMap = dataMap['plan'] as Map<String, dynamic>;
    }

    Map<String, dynamic>? subMap;
    if (user['subscription'] is Map<String, dynamic>) {
      subMap = user['subscription'] as Map<String, dynamic>;
    } else if (dataMap != null &&
        dataMap['subscription'] is Map<String, dynamic>) {
      subMap = dataMap['subscription'] as Map<String, dynamic>;
    }

    final String name = _firstNonEmpty(<dynamic>[
      user['name'],
      decoded['name'],
      dataMap?['name'],
      _emailToName(
        _firstNonEmpty(<dynamic>[
          user['email'],
          decoded['email'],
          dataMap?['email'],
        ]),
      ),
      'Board Master User',
    ]);

    final String email = _firstNonEmpty(<dynamic>[
      user['email'],
      decoded['email'],
      dataMap?['email'],
    ]);

    final String token = _firstNonEmpty(<dynamic>[
      decoded['token'],
      decoded['access_token'],
      dataMap?['token'],
      dataMap?['access_token'],
      decoded['plainTextToken'],
      dataMap?['plainTextToken'],
    ]);

    final PlanTier? tier = _parseTier(
      user['plan_tier'] ??
          user['tier'] ??
          user['plan'] ??
          planMap?['tier'] ??
          dataMap?['plan_tier'] ??
          dataMap?['tier'] ??
          decoded['plan_tier'] ??
          decoded['tier'],
    );

    final int? planId = _parseInt(
      user['plan_id'] ??
          subMap?['plan_id'] ??
          planMap?['id'] ??
          dataMap?['plan_id'] ??
          decoded['plan_id'],
    );
    final String? billingCycle = _nullableText(
      user['billing_cycle'] ??
          subMap?['billing_cycle'] ??
          planMap?['billing_cycle'] ??
          dataMap?['billing_cycle'] ??
          decoded['billing_cycle'],
    );
    final DateTime? endDate = _parseDate(
      user['end_date'] ??
          subMap?['end_date'] ??
          dataMap?['end_date'] ??
          decoded['end_date'],
    );

    if (email.isEmpty && name.isEmpty) {
      return null;
    }

    return AuthPayload(
      name: name,
      email: email,
      token: token.isEmpty ? null : token,
      tier: tier,
      planId: planId,
      billingCycle: billingCycle,
      endDate: endDate,
    );
  }

  PlanOption? _toPlanOption(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final int? id = _parseInt(raw['id']);
    if (id == null) {
      return null;
    }

    final String name = _firstNonEmpty(<dynamic>[raw['name'], raw['title']]);
    final PlanTier tier =
        _parseTier(
          raw['tier'] ??
              raw['plan_tier'] ??
              raw['slug'] ??
              raw['code'] ??
              raw['name'] ??
              raw['title'],
        ) ??
        PlanTier.premium;

    final String title = _firstNonEmpty(<dynamic>[
      raw['title'],
      raw['display_title'],
      raw['name'],
      raw['display_name'],
      tier == PlanTier.free ? 'Free Plan' : 'Subscription',
    ]);

    final double price = _parseDouble(raw['price']) ?? 0;
    final String priceLabel = _priceLabel(raw);
    final String billingCycle = _firstNonEmpty(<dynamic>[
      raw['billing_cycle'],
      raw['cycle'],
      'monthly',
    ]).toLowerCase();
    final String billingLabel = _firstNonEmpty(<dynamic>[
      raw['billing_label'],
      raw['billing'],
      raw['period'],
      raw['interval'],
      tier == PlanTier.free ? 'Forever free' : 'per month',
    ]);
    final String description = _firstNonEmpty(<dynamic>[raw['description']]);

    final List<String> features = _toFeatureList(raw['features']);

    return PlanOption(
      id: id,
      name: name.isEmpty ? title : name,
      tier: tier,
      title: title,
      price: price,
      priceLabel: priceLabel,
      billingCycle: billingCycle,
      billingLabel: billingLabel,
      description: description,
      features: features.isEmpty
          ? <String>[
              tier == PlanTier.free
                  ? 'Starter access from your current plan settings'
                  : 'Premium features from your current subscription settings',
            ]
          : features,
    );
  }

  PlanSelectionPayload? _toPlanSelectionPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final dynamic data = decoded['data'];
    final Map<String, dynamic> map = data is Map<String, dynamic>
        ? data
        : decoded;

    final int? planId = _parseInt(map['plan_id']);
    if (planId == null) {
      return null;
    }

    return PlanSelectionPayload(
      subscriptionId: _parseInt(map['subscription_id']),
      planId: planId,
      tier: _parseTier(map['tier']),
      planName: _nullableText(map['plan_name']),
      billingCycle: _nullableText(map['billing_cycle']),
      endDate: _parseDate(map['end_date']),
    );
  }

  String _priceLabel(Map<String, dynamic> raw) {
    final String explicit = _firstNonEmpty(<dynamic>[
      raw['price_label'],
      raw['formatted_price'],
      raw['display_price'],
    ]);
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final dynamic value = raw['price'] ?? raw['amount'] ?? raw['monthly_price'];
    if (value is num) {
      if (value == 0) {
        return 'PHP 0';
      }
      return 'PHP ${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
    }

    final String parsed = _firstNonEmpty(<dynamic>[value]);
    if (parsed.isNotEmpty) {
      return parsed.startsWith('PHP') ? parsed : 'PHP $parsed';
    }
    return 'PHP 0';
  }

  List<String> _toFeatureList(dynamic raw) {
    if (raw is List<dynamic>) {
      return raw
          .map((dynamic item) => _firstNonEmpty(<dynamic>[item]))
          .where((String item) => item.isNotEmpty)
          .toList();
    }

    if (raw is Map<String, dynamic>) {
      return raw.values
          .map((dynamic item) => _firstNonEmpty(<dynamic>[item]))
          .where((String item) => item.isNotEmpty)
          .toList();
    }

    final String single = _firstNonEmpty(<dynamic>[raw]);
    return single.isEmpty ? <String>[] : <String>[single];
  }

  PlanTier? _parseTier(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Map<String, dynamic>) {
      return _parseTier(
        value['tier'] ??
            value['slug'] ??
            value['code'] ??
            value['name'] ??
            value['title'],
      );
    }

    final String normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains('free') || normalized == '0') {
      return PlanTier.free;
    }
    if (normalized.contains('premium') ||
        normalized.contains('subscription') ||
        normalized.contains('pro') ||
        normalized == '1') {
      return PlanTier.premium;
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString().trim());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().trim());
  }

  String? _nullableText(dynamic value) {
    final String text = _firstNonEmpty(<dynamic>[value]);
    return text.isEmpty ? null : text;
  }

  DateTime? _parseDate(dynamic value) {
    final String text = _firstNonEmpty(<dynamic>[value]);
    if (text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  String _extractErrorMessage(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return 'Unexpected server response format.';
    }

    final String top = _firstNonEmpty(<dynamic>[decoded['message']]);
    if (top.isNotEmpty &&
        !top.toLowerCase().contains('validation') &&
        !top.contains('<')) {
      return top;
    }

    final dynamic errors = decoded['errors'];
    if (errors is Map<String, dynamic>) {
      for (final dynamic item in errors.values) {
        if (item is List<dynamic> && item.isNotEmpty) {
          final String first = _firstNonEmpty(<dynamic>[item.first]);
          if (first.isNotEmpty) {
            return first;
          }
        }
        final String single = _firstNonEmpty(<dynamic>[item]);
        if (single.isNotEmpty) {
          return single;
        }
      }
    }

    if (top.isNotEmpty) {
      return top;
    }

    return 'Request failed. Please check your credentials and server setup.';
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      if (value == null) {
        continue;
      }
      final String candidate = value.toString().trim();
      if (candidate.isNotEmpty && candidate.toLowerCase() != 'null') {
        return candidate;
      }
    }
    return '';
  }

  String _emailToName(String email) {
    final String trimmed = email.trim();
    if (!trimmed.contains('@') || trimmed.startsWith('@')) {
      return '';
    }
    final String base = trimmed.split('@').first.trim();
    if (base.isEmpty) {
      return '';
    }
    return '${base[0].toUpperCase()}${base.substring(1)}';
  }

  bool _looksLikeUserMap(Map<String, dynamic> map) {
    return map.containsKey('email') || map.containsKey('name');
  }
}

class AuthPayload {
  const AuthPayload({
    required this.name,
    required this.email,
    required this.token,
    required this.tier,
    required this.planId,
    required this.billingCycle,
    required this.endDate,
  });

  final String name;
  final String email;
  final String? token;
  final PlanTier? tier;
  final int? planId;
  final String? billingCycle;
  final DateTime? endDate;
}

class PlanSelectionPayload {
  const PlanSelectionPayload({
    required this.subscriptionId,
    required this.planId,
    required this.tier,
    required this.planName,
    required this.billingCycle,
    required this.endDate,
  });

  final int? subscriptionId;
  final int planId;
  final PlanTier? tier;
  final String? planName;
  final String? billingCycle;
  final DateTime? endDate;
}

class ApiResult<T> {
  const ApiResult._({
    required this.ok,
    required this.data,
    required this.message,
    required this.statusCode,
  });

  final bool ok;
  final T? data;
  final String? message;
  final int? statusCode;

  factory ApiResult.success(T data) {
    return ApiResult<T>._(
      ok: true,
      data: data,
      message: null,
      statusCode: null,
    );
  }

  factory ApiResult.failure(String message, {int? statusCode}) {
    return ApiResult<T>._(
      ok: false,
      data: null,
      message: message,
      statusCode: statusCode,
    );
  }
}
