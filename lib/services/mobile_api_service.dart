import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api_config.dart';
import '../models/app_models.dart';

class MobileApiService {
  MobileApiService({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _requestTimeout = Duration(seconds: 8);
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

  Future<ApiResult<AuthPayload>> loginWithGoogle({
    required String idToken,
    String? email,
    String? name,
    String? avatarUrl,
  }) async {
    return _postAuth(
      path: ApiConfig.googleLogin,
      payload: <String, dynamic>{
        'id_token': idToken.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          'avatar_url': avatarUrl.trim(),
      },
    );
  }

  Future<ApiResult<bool>> register({
    required String name,
    required String email,
    required String password,
    String? passwordConfirmation,
    String? phoneNumber,
    String? school,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation ?? password,
    };

    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      payload['phone_number'] = phoneNumber.trim();
    }
    if (school != null && school.trim().isNotEmpty) {
      payload['school'] = school.trim();
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.register,
        payload: payload,
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<bool>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      return ApiResult<bool>.success(true);
    } catch (_) {
      return ApiResult<bool>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<bool>> forgotPassword({required String email}) async {
    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.forgotPassword,
        payload: <String, dynamic>{'email': email.trim()},
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<bool>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      return ApiResult<bool>.success(true);
    } catch (_) {
      return ApiResult<bool>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<bool>> resendVerification({required String email}) async {
    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.resendVerification,
        payload: <String, dynamic>{'email': email.trim()},
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<bool>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      return ApiResult<bool>.success(true);
    } catch (_) {
      return ApiResult<bool>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<bool>> isEmailAvailable({
    required String email,
    String? ignoreEmail,
  }) async {
    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.checkEmail,
        payload: <String, dynamic>{
          'email': email.trim(),
          if (ignoreEmail != null && ignoreEmail.trim().isNotEmpty)
            'ignore_email': ignoreEmail.trim(),
        },
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<bool>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final bool available =
          decoded is Map<String, dynamic> && decoded['available'] == true;
      return ApiResult<bool>.success(available);
    } catch (_) {
      return ApiResult<bool>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<AuthPayload>> fetchCurrentUser() async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<AuthPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _getWithFallback(path: ApiConfig.me);
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

      return ApiResult<AuthPayload>.success(parsed);
    } catch (_) {
      return ApiResult<AuthPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
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

  Future<ApiResult<CheckoutPayload>> createCheckout({
    required int planId,
    String? billingCycle,
    String? reference,
    List<String>? paymentMethodTypes,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<CheckoutPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final List<String>? cleanedMethods = paymentMethodTypes
          ?.map((String item) => item.trim().toLowerCase())
          .where((String item) => item.isNotEmpty)
          .toSet()
          .toList();

      final http.Response response = await _postWithFallback(
        path: ApiConfig.paymongoCheckout,
        payload: <String, dynamic>{
          'plan_id': planId,
          if (billingCycle != null && billingCycle.trim().isNotEmpty)
            'billing_cycle': billingCycle.trim().toLowerCase(),
          if (reference != null && reference.trim().isNotEmpty)
            'reference': reference.trim(),
          if (cleanedMethods != null && cleanedMethods.isNotEmpty)
            'payment_method_types': cleanedMethods,
        },
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<CheckoutPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final CheckoutPayload? payload = _toCheckoutPayload(decoded);
      if (payload == null) {
        return ApiResult<CheckoutPayload>.failure(
          'Checkout response is missing URL.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<CheckoutPayload>.success(payload);
    } catch (_) {
      return ApiResult<CheckoutPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<List<PracticeSubjectPayload>>>
  fetchPracticeSubjects() async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<List<PracticeSubjectPayload>>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _getWithFallback(
        path: ApiConfig.subjects,
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<List<PracticeSubjectPayload>>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final List<dynamic> rawSubjects;
      if (decoded is List<dynamic>) {
        rawSubjects = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final dynamic nested = decoded['data'] ?? decoded['subjects'];
        rawSubjects = nested is List<dynamic> ? nested : <dynamic>[];
      } else {
        rawSubjects = <dynamic>[];
      }

      final List<PracticeSubjectPayload> parsed = rawSubjects
          .map(_toPracticeSubjectPayload)
          .whereType<PracticeSubjectPayload>()
          .toList();

      return ApiResult<List<PracticeSubjectPayload>>.success(parsed);
    } catch (_) {
      return ApiResult<List<PracticeSubjectPayload>>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<DashboardMetricsPayload>> fetchDashboardMetrics() async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<DashboardMetricsPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _getWithFallback(
        path: ApiConfig.dashboardMetrics,
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<DashboardMetricsPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final DashboardMetricsPayload? payload = _toDashboardMetricsPayload(
        decoded,
      );
      if (payload == null) {
        return ApiResult<DashboardMetricsPayload>.failure(
          'Dashboard metrics response is missing data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<DashboardMetricsPayload>.success(payload);
    } catch (_) {
      return ApiResult<DashboardMetricsPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<ReferralSummaryPayload>> fetchReferrals({
    int page = 1,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<ReferralSummaryPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _getWithFallback(
        path: '${ApiConfig.referrals}?page=$page',
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<ReferralSummaryPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final ReferralSummaryPayload? payload = _toReferralSummaryPayload(
        decoded,
      );
      if (payload == null) {
        return ApiResult<ReferralSummaryPayload>.failure(
          'Referral response is missing data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<ReferralSummaryPayload>.success(payload);
    } catch (_) {
      return ApiResult<ReferralSummaryPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<bool>> applyReferralCode({required String code}) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<bool>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.referralApply,
        payload: <String, dynamic>{'referral_code': code.trim()},
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<bool>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      return ApiResult<bool>.success(true);
    } catch (_) {
      return ApiResult<bool>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<ReferralRedemptionPayload>> redeemReferralOffer({
    required int offerId,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<ReferralRedemptionPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.referralRedeem,
        payload: <String, dynamic>{'offer_id': offerId},
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<ReferralRedemptionPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final ReferralRedemptionPayload? payload = _toReferralRedemptionPayload(
        decoded,
      );
      if (payload == null) {
        return ApiResult<ReferralRedemptionPayload>.failure(
          'Redemption response is missing data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<ReferralRedemptionPayload>.success(payload);
    } catch (_) {
      return ApiResult<ReferralRedemptionPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<SubscriptionHistoryPayload>> fetchSubscriptionHistory({
    int page = 1,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<SubscriptionHistoryPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _getWithFallback(
        path: '${ApiConfig.subscriptionHistory}?page=$page',
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<SubscriptionHistoryPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final SubscriptionHistoryPayload? payload = _toSubscriptionHistoryPayload(
        decoded,
      );
      if (payload == null) {
        return ApiResult<SubscriptionHistoryPayload>.failure(
          'Subscription history response is missing data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<SubscriptionHistoryPayload>.success(payload);
    } catch (_) {
      return ApiResult<SubscriptionHistoryPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<QuizAttemptHistoryPayload>> fetchQuizAttempts({
    int page = 1,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<QuizAttemptHistoryPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _getWithFallback(
        path: '${ApiConfig.quizAttempts}?page=$page',
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<QuizAttemptHistoryPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final QuizAttemptHistoryPayload? payload = _toQuizAttemptHistoryPayload(
        decoded,
      );
      if (payload == null) {
        return ApiResult<QuizAttemptHistoryPayload>.failure(
          'Quiz attempt history is missing data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<QuizAttemptHistoryPayload>.success(payload);
    } catch (_) {
      return ApiResult<QuizAttemptHistoryPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<QuizAttemptDetailPayload>> fetchQuizAttemptDetails({
    required int attemptId,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<QuizAttemptDetailPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _getWithFallback(
        path: '${ApiConfig.quizAttempts}/$attemptId',
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<QuizAttemptDetailPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final QuizAttemptDetailPayload? payload = _toQuizAttemptDetailPayload(
        decoded,
      );
      if (payload == null) {
        return ApiResult<QuizAttemptDetailPayload>.failure(
          'Quiz attempt details are missing data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<QuizAttemptDetailPayload>.success(payload);
    } catch (_) {
      return ApiResult<QuizAttemptDetailPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<int>> deleteQuizAttempts({
    required List<int> attemptIds,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<int>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    final List<int> cleaned = attemptIds
        .where((int id) => id > 0)
        .toSet()
        .toList();
    if (cleaned.isEmpty) {
      return ApiResult<int>.failure('No attempts selected.');
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.quizAttemptsDelete,
        payload: <String, dynamic>{'attempt_ids': cleaned},
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<int>.failure(message, statusCode: response.statusCode);
      }

      final int deleted =
          _parseInt(
            decoded is Map<String, dynamic> ? decoded['deleted'] : null,
          ) ??
          cleaned.length;

      return ApiResult<int>.success(deleted);
    } catch (_) {
      return ApiResult<int>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<int>> clearQuizAttempts() async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<int>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.quizAttemptsClear,
        payload: <String, dynamic>{},
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<int>.failure(message, statusCode: response.statusCode);
      }

      final int deleted =
          _parseInt(
            decoded is Map<String, dynamic> ? decoded['deleted'] : null,
          ) ??
          0;
      return ApiResult<int>.success(deleted);
    } catch (_) {
      return ApiResult<int>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<List<QuestionItem>>> generateQuiz({
    required int subjectId,
    required int totalQuestions,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<List<QuestionItem>>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.quizGenerate,
        payload: <String, dynamic>{
          'subject_id': subjectId,
          'total_questions': totalQuestions,
        },
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<List<QuestionItem>>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final List<dynamic> rawQuestions;
      if (decoded is List<dynamic>) {
        rawQuestions = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final dynamic nested = decoded['data'] ?? decoded['questions'];
        rawQuestions = nested is List<dynamic> ? nested : <dynamic>[];
      } else {
        rawQuestions = <dynamic>[];
      }

      final List<QuestionItem> parsed = rawQuestions
          .map(_toQuestionItem)
          .whereType<QuestionItem>()
          .toList();

      if (parsed.isEmpty) {
        return ApiResult<List<QuestionItem>>.failure(
          'No questions available for this subject.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<List<QuestionItem>>.success(parsed);
    } catch (_) {
      return ApiResult<List<QuestionItem>>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<QuizSubmitPayload>> submitQuizAttempt({
    required int subjectId,
    required List<QuizAnswerPayload> answers,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<QuizSubmitPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.quizSubmit,
        payload: <String, dynamic>{
          'subject_id': subjectId,
          'answers': answers
              .map((QuizAnswerPayload item) => item.toJson())
              .toList(),
        },
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<QuizSubmitPayload>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      final QuizSubmitPayload? payload = _toQuizSubmitPayload(decoded);
      if (payload == null) {
        return ApiResult<QuizSubmitPayload>.failure(
          'Quiz submission response is missing data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<QuizSubmitPayload>.success(payload);
    } catch (_) {
      return ApiResult<QuizSubmitPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<AuthPayload>> updateProfile({
    required String name,
    required String email,
    String? school,
    String? place,
    String? phoneNumber,
    DateTime? birthdate,
    String? gender,
    Uint8List? avatarBytes,
    String? avatarFilename,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<AuthPayload>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final Map<String, String> fields = <String, String>{
        'name': name.trim(),
        'email': email.trim(),
      };
      final String? normalizedSchool = _trimOrNull(school);
      final String? normalizedPlace = _trimOrNull(place);
      final String? normalizedPhone = _trimOrNull(phoneNumber);
      final String? normalizedGender = _trimOrNull(gender);
      final String? normalizedBirthdate = _formatDateForApi(birthdate);
      if (normalizedSchool != null) {
        fields['school'] = normalizedSchool;
      }
      if (normalizedPlace != null) {
        fields['place'] = normalizedPlace;
      }
      if (normalizedPhone != null) {
        fields['phone_number'] = normalizedPhone;
      }
      if (normalizedGender != null) {
        fields['gender'] = normalizedGender;
      }
      if (normalizedBirthdate != null) {
        fields['birthdate'] = normalizedBirthdate;
      }

      final http.Response response = avatarBytes == null
          ? await _postWithFallback(path: ApiConfig.profile, payload: fields)
          : await _postMultipartWithFallback(
              path: ApiConfig.profile,
              fields: fields,
              fileField: 'avatar',
              fileBytes: avatarBytes,
              filename: _normalizeAvatarFilename(avatarFilename, avatarBytes),
              contentType: _resolveImageContentType(
                avatarFilename,
                avatarBytes,
              ),
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
          'Profile response is missing user data.',
          statusCode: response.statusCode,
        );
      }

      return ApiResult<AuthPayload>.success(parsed);
    } catch (_) {
      return ApiResult<AuthPayload>.failure(
        'Cannot connect to web app. Check API url and backend server.',
      );
    }
  }

  Future<ApiResult<bool>> submitFeedback({
    required int rating,
    required String comment,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return ApiResult<bool>.failure(
        'You are not authenticated.',
        statusCode: 401,
      );
    }

    try {
      final http.Response response = await _postWithFallback(
        path: ApiConfig.feedback,
        payload: <String, dynamic>{'rating': rating, 'comment': comment.trim()},
      );
      final dynamic decoded = _decodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message = _extractErrorMessage(decoded);
        return ApiResult<bool>.failure(
          message,
          statusCode: response.statusCode,
        );
      }

      return ApiResult<bool>.success(true);
    } catch (_) {
      return ApiResult<bool>.failure(
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
        final http.Response response = await _client
            .get(
              ApiConfig.uri(path, overrideBaseUrl: baseUrl),
              headers: _headers(),
            )
            .timeout(_requestTimeout);
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
        final http.Response response = await _client
            .post(
              ApiConfig.uri(path, overrideBaseUrl: baseUrl),
              headers: _headers(),
              body: jsonEncode(payload),
            )
            .timeout(_requestTimeout);
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

  Future<http.Response> _postMultipartWithFallback({
    required String path,
    required Map<String, String> fields,
    required String fileField,
    required Uint8List fileBytes,
    required String filename,
    MediaType? contentType,
  }) async {
    Object? lastError;
    http.Response? fallbackResponse;

    for (final String baseUrl in _candidateBaseUrls()) {
      try {
        final Uri uri = ApiConfig.uri(path, overrideBaseUrl: baseUrl);
        final http.MultipartRequest request = http.MultipartRequest(
          'POST',
          uri,
        );
        final Map<String, String> headers = Map<String, String>.from(
          _headers(),
        );
        headers.remove('Content-Type');
        request.headers.addAll(headers);
        request.fields.addAll(fields);
        request.files.add(
          http.MultipartFile.fromBytes(
            fileField,
            fileBytes,
            filename: filename,
            contentType: contentType,
          ),
        );

        final http.StreamedResponse streamed = await _client
            .send(request)
            .timeout(_requestTimeout);
        final http.Response response = await http.Response.fromStream(streamed);
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

  MediaType _resolveImageContentType(String? filename, Uint8List bytes) {
    final String? byName = _contentTypeFromFilename(filename);
    if (byName != null) {
      return MediaType.parse(byName);
    }

    final String? byMagic = _contentTypeFromBytes(bytes);
    return MediaType.parse(byMagic ?? 'image/jpeg');
  }

  String _normalizeAvatarFilename(String? filename, Uint8List bytes) {
    final String trimmed = (filename ?? '').trim();
    if (trimmed.isNotEmpty && trimmed.contains('.')) {
      return trimmed;
    }
    final String? type = _contentTypeFromBytes(bytes);
    final String extension = _extensionFromContentType(type) ?? 'jpg';
    return 'avatar.$extension';
  }

  String? _contentTypeFromFilename(String? filename) {
    if (filename == null || filename.trim().isEmpty) {
      return null;
    }
    final String lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    return null;
  }

  String? _contentTypeFromBytes(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 6) {
      final String header = String.fromCharCodes(bytes.sublist(0, 6));
      if (header == 'GIF87a' || header == 'GIF89a') {
        return 'image/gif';
      }
    }
    if (bytes.length >= 12) {
      final String riff = String.fromCharCodes(bytes.sublist(0, 4));
      final String webp = String.fromCharCodes(bytes.sublist(8, 12));
      if (riff == 'RIFF' && webp == 'WEBP') {
        return 'image/webp';
      }
    }
    return null;
  }

  String? _extensionFromContentType(String? contentType) {
    switch (contentType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return null;
    }
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
      'Boardmasters User',
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
    final DateTime? emailVerifiedAt = _parseDate(
      user['email_verified_at'] ??
          dataMap?['email_verified_at'] ??
          decoded['email_verified_at'],
    );
    final bool emailVerified =
        _parseBool(
          user['email_verified'] ??
              dataMap?['email_verified'] ??
              decoded['email_verified'],
        ) ??
        emailVerifiedAt != null;
    final String? school = _nullableText(
      user['school'] ?? dataMap?['school'] ?? decoded['school'],
    );
    final DateTime? birthdate = _parseDate(
      user['birthdate'] ?? dataMap?['birthdate'] ?? decoded['birthdate'],
    );
    final String? gender = _nullableText(
      user['gender'] ?? dataMap?['gender'] ?? decoded['gender'],
    );
    final String? place = _nullableText(
      user['place'] ?? dataMap?['place'] ?? decoded['place'],
    );
    final String? phoneNumber = _nullableText(
      user['phone_number'] ??
          user['phone'] ??
          dataMap?['phone_number'] ??
          decoded['phone_number'],
    );
    String? avatarUrl = _nullableText(
      user['avatar_url'] ?? dataMap?['avatar_url'] ?? decoded['avatar_url'],
    );
    avatarUrl = _normalizeAvatarUrl(avatarUrl);
    final String? referralCode = _nullableText(
      user['referral_code'] ??
          dataMap?['referral_code'] ??
          decoded['referral_code'],
    );
    final int? referredBy = _parseInt(
      user['referred_by'] ?? dataMap?['referred_by'] ?? decoded['referred_by'],
    );

    if (email.isEmpty && name.isEmpty) {
      return null;
    }

    final bool trialConsumed =
        _parseBool(
          user['trial_consumed'] ??
              dataMap?['trial_consumed'] ??
              decoded['trial_consumed'],
        ) ??
        false;

    return AuthPayload(
      name: name,
      email: email,
      token: token.isEmpty ? null : token,
      tier: tier,
      planId: planId,
      billingCycle: billingCycle,
      endDate: endDate,
      trialConsumed: trialConsumed,
      emailVerified: emailVerified,
      emailVerifiedAt: emailVerifiedAt,
      school: school,
      birthdate: birthdate,
      gender: gender,
      place: place,
      phoneNumber: phoneNumber,
      avatarUrl: avatarUrl,
      referralCode: referralCode,
      referredBy: referredBy,
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
      raw['group_label'],
      raw['name'],
      raw['display_name'],
      tier == PlanTier.free ? 'Free Plan' : 'Subscription',
    ]);
    final String planGroup = _firstNonEmpty(<dynamic>[
      raw['plan_group'],
      raw['group_key'],
      tier == PlanTier.free ? 'free_trial' : 'premium',
    ]).toLowerCase();
    final String groupLabel = _firstNonEmpty(<dynamic>[
      raw['group_label'],
      raw['title'],
      title,
    ]);
    final String subPlanLabel = _firstNonEmpty(<dynamic>[
      raw['sub_plan_label'],
      raw['subplan_label'],
      raw['name'],
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
    final int durationDays = _parseInt(raw['duration_days']) ?? 0;
    final int sortOrder = _parseInt(raw['sort_order']) ?? 0;
    final String description = _firstNonEmpty(<dynamic>[raw['description']]);

    final List<String> features = _toFeatureList(raw['features']);

    return PlanOption(
      id: id,
      name: name.isEmpty ? title : name,
      tier: tier,
      title: title,
      planGroup: planGroup,
      groupLabel: groupLabel.isEmpty ? title : groupLabel,
      subPlanLabel: subPlanLabel.isEmpty ? name : subPlanLabel,
      price: price,
      priceLabel: priceLabel,
      billingCycle: billingCycle,
      billingLabel: billingLabel,
      durationDays: durationDays,
      sortOrder: sortOrder,
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

  CheckoutPayload? _toCheckoutPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final dynamic nested = decoded['data'];
    final Map<String, dynamic> map = nested is Map<String, dynamic>
        ? nested
        : decoded;

    final String checkoutId = _firstNonEmpty(<dynamic>[
      map['checkout_id'],
      map['id'],
    ]);
    final String checkoutUrl = _firstNonEmpty(<dynamic>[
      map['checkout_url'],
      map['url'],
    ]);
    if (checkoutUrl.isEmpty) {
      return null;
    }

    return CheckoutPayload(
      checkoutId: checkoutId,
      checkoutUrl: checkoutUrl,
      status: _nullableText(map['status']),
      billingCycle: _nullableText(map['billing_cycle']),
    );
  }

  PracticeSubjectPayload? _toPracticeSubjectPayload(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final int? id = _parseInt(raw['id']);
    if (id == null) {
      return null;
    }

    final String title = _firstNonEmpty(<dynamic>[
      raw['title'],
      raw['name'],
      raw['subject_name'],
    ]);
    if (title.isEmpty) {
      return null;
    }

    final String rawCode = _firstNonEmpty(<dynamic>[raw['code'], title]);
    final String cleanedCode = rawCode
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final String code = cleanedCode.isEmpty
        ? 'SUBJ'
        : cleanedCode.substring(
            0,
            cleanedCode.length > 4 ? 4 : cleanedCode.length,
          );
    final int totalQuestions =
        _parseInt(
          raw['total_questions'] ?? raw['question_count'] ?? raw['questions'],
        ) ??
        0;
    int questionLimit =
        _parseInt(raw['question_limit'] ?? raw['max_questions_per_set']) ?? 0;
    if (questionLimit < 0) {
      questionLimit = 0;
    }
    final dynamic accessRaw =
        raw['is_accessible'] ?? raw['accessible'] ?? raw['has_access'];
    bool isAccessible = false;
    if (accessRaw is bool) {
      isAccessible = accessRaw;
    } else if (accessRaw is num) {
      isAccessible = accessRaw > 0;
    } else if (accessRaw is String) {
      final String normalized = accessRaw.trim().toLowerCase();
      isAccessible =
          normalized == 'true' || normalized == '1' || normalized == 'yes';
    } else {
      isAccessible = questionLimit > 0;
    }
    final String? colorHex = _nullableText(raw['color_hex'] ?? raw['color']);
    final String groupKey = _firstNonEmpty(<dynamic>[
      raw['group_key'],
      raw['group'],
      'nursing_concepts',
    ]).toLowerCase();
    final String groupLabel = _firstNonEmpty(<dynamic>[
      raw['group_label'],
      groupKey == 'mock_board_exam'
          ? 'Mock Board Exam'
          : 'All Nursing Concepts',
    ]);

    return PracticeSubjectPayload(
      id: id,
      code: code,
      title: title,
      groupKey: groupKey,
      groupLabel: groupLabel,
      totalQuestions: totalQuestions < 0 ? 0 : totalQuestions,
      questionLimit: questionLimit,
      isAccessible: isAccessible,
      colorHex: colorHex,
    );
  }

  QuestionItem? _toQuestionItem(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final int? id = _parseInt(raw['id']);
    final String question = _firstNonEmpty(<dynamic>[
      raw['question'],
      raw['prompt'],
    ]);
    final String subjectId = _firstNonEmpty(<dynamic>[
      raw['subject_id'],
      raw['subject'],
    ]);
    if (question.isEmpty || subjectId.isEmpty) {
      return null;
    }

    final Map<String, String> choices = _toStringMap(raw['choices']);
    if (choices.isEmpty) {
      return null;
    }

    String correctKey = _firstNonEmpty(<dynamic>[
      raw['correct_key'],
      raw['correctKey'],
    ]).toUpperCase();
    if (!choices.containsKey(correctKey)) {
      correctKey = choices.keys.first;
    }

    final Map<String, String> rationales = _toStringMap(raw['rationales']);
    final Map<String, String> normalizedRationales = <String, String>{};
    for (final String key in choices.keys) {
      normalizedRationales[key] =
          rationales[key] ??
          (key == correctKey
              ? 'This option is correct.'
              : 'This option is not a correct answer.');
    }

    return QuestionItem(
      id: id,
      subjectId: subjectId,
      question: question,
      choices: choices,
      correctKey: correctKey,
      rationales: normalizedRationales,
    );
  }

  QuizSubmitPayload? _toQuizSubmitPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final dynamic data = decoded['data'] ?? decoded;
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final int? attemptId = _parseInt(data['attempt_id']);
    final int score = _parseInt(data['score']) ?? 0;
    final int total = _parseInt(data['total_questions']) ?? 0;

    if (attemptId == null) {
      return null;
    }

    return QuizSubmitPayload(
      attemptId: attemptId,
      score: score,
      totalQuestions: total,
    );
  }

  DashboardMetricsPayload? _toDashboardMetricsPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final dynamic data = decoded['data'];
    final Map<String, dynamic> map = data is Map<String, dynamic>
        ? data
        : decoded;

    final int referralCount = _parseInt(map['referral_join_count']) ?? 0;
    final dynamic lastAttempt = map['last_attempt'];
    if (lastAttempt is Map<String, dynamic>) {
      return DashboardMetricsPayload(
        referralJoinCount: referralCount,
        lastScore: _parseInt(lastAttempt['score']),
        lastTotal: _parseInt(lastAttempt['total_questions']),
        lastSubject: _nullableText(lastAttempt['subject']),
        lastCompletedAt: _parseDate(lastAttempt['completed_at']),
      );
    }

    return DashboardMetricsPayload(
      referralJoinCount: referralCount,
      lastScore: null,
      lastTotal: null,
      lastSubject: null,
      lastCompletedAt: null,
    );
  }

  ReferralSummaryPayload? _toReferralSummaryPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final dynamic data = decoded['data'];
    final Map<String, dynamic> map = data is Map<String, dynamic>
        ? data
        : decoded;

    final List<ReferralEntryPayload> entries = _toReferralEntries(
      map['referrals'],
    );
    final ReferralPointsPayload points = _toReferralPointsPayload(
      map['points'],
    );
    final List<ReferralOfferPayload> offers = _toReferralOffers(map['offers']);
    final List<String> categories = _toStringList(map['categories']);
    final List<String> brands = _toStringList(map['brands']);
    final List<ReferralRewardPayload> activeRewards = _toReferralRewards(
      map['active_rewards'],
    );
    final PaginationPayload pagination = _toPaginationPayload(
      decoded['pagination'] ?? map['pagination'],
    );

    return ReferralSummaryPayload(
      referralCode: _nullableText(map['referral_code']),
      referredByName: _nullableText(map['referred_by']?['name']),
      referredByEmail: _nullableText(map['referred_by']?['email']),
      joinCount: _parseInt(map['join_count']) ?? entries.length,
      referrals: entries,
      points: points,
      offers: offers,
      categories: categories,
      brands: brands,
      activeRewards: activeRewards,
      pagination: pagination,
    );
  }

  ReferralPointsPayload _toReferralPointsPayload(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return const ReferralPointsPayload(
        earned: 0,
        spent: 0,
        available: 0,
        perReferral: 0,
      );
    }

    return ReferralPointsPayload(
      earned: _parseInt(raw['earned']) ?? 0,
      spent: _parseInt(raw['spent']) ?? 0,
      available: _parseInt(raw['available']) ?? 0,
      perReferral: _parseInt(raw['per_referral']) ?? 0,
    );
  }

  List<ReferralOfferPayload> _toReferralOffers(dynamic raw) {
    if (raw is! List<dynamic>) {
      return <ReferralOfferPayload>[];
    }
    return raw
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }
          return ReferralOfferPayload(
            id: _parseInt(item['id']) ?? 0,
            title: _firstNonEmpty(<dynamic>[item['title']]),
            description: _nullableText(item['description']),
            pointsCost: _parseInt(item['points_cost']) ?? 0,
            subject: _nullableText(item['subject']),
            subjectId: _parseInt(item['subject_id']),
            questionLimit: _parseInt(item['question_limit']),
            durationDays: _parseInt(item['access_duration_days']),
            category: _nullableText(item['category']),
            brand: _nullableText(item['brand']),
            imageUrl: _nullableText(item['image_url']),
            isFeatured: item['is_featured'] == true,
          );
        })
        .whereType<ReferralOfferPayload>()
        .toList();
  }

  List<ReferralRewardPayload> _toReferralRewards(dynamic raw) {
    if (raw is! List<dynamic>) {
      return <ReferralRewardPayload>[];
    }
    return raw
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }
          return ReferralRewardPayload(
            id: _parseInt(item['id']) ?? 0,
            offerId: _parseInt(item['offer_id']) ?? 0,
            subjectId: _parseInt(item['subject_id']),
            questionLimit: _parseInt(item['question_limit']),
            expiresAt: _parseDate(item['expires_at']),
          );
        })
        .whereType<ReferralRewardPayload>()
        .toList();
  }

  List<String> _toStringList(dynamic raw) {
    if (raw is! List<dynamic>) {
      return <String>[];
    }
    return raw
        .map((dynamic item) => _firstNonEmpty(<dynamic>[item]))
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  ReferralRedemptionPayload? _toReferralRedemptionPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final Map<String, dynamic> data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
    final Map<String, dynamic> pointsRaw =
        decoded['points'] is Map<String, dynamic>
        ? decoded['points'] as Map<String, dynamic>
        : <String, dynamic>{};

    return ReferralRedemptionPayload(
      id: _parseInt(data['id']) ?? 0,
      offerId: _parseInt(data['offer_id']) ?? 0,
      subjectId: _parseInt(data['subject_id']),
      questionLimit: _parseInt(data['question_limit']),
      expiresAt: _parseDate(data['expires_at']),
      points: ReferralPointsPayload(
        earned: _parseInt(pointsRaw['earned']) ?? 0,
        spent: _parseInt(pointsRaw['spent']) ?? 0,
        available: _parseInt(pointsRaw['available']) ?? 0,
        perReferral: _parseInt(pointsRaw['per_referral']) ?? 0,
      ),
    );
  }

  List<ReferralEntryPayload> _toReferralEntries(dynamic raw) {
    if (raw is! List<dynamic>) {
      return <ReferralEntryPayload>[];
    }
    return raw
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }
          final Map<String, dynamic>? invited =
              item['invited_user'] is Map<String, dynamic>
              ? item['invited_user'] as Map<String, dynamic>
              : null;
          final String name = _firstNonEmpty(<dynamic>[invited?['name']]);
          final String email = _firstNonEmpty(<dynamic>[invited?['email']]);
          return ReferralEntryPayload(
            id: _parseInt(item['id']) ?? 0,
            invitedName: name,
            invitedEmail: email,
            createdAt: _parseDate(item['created_at']),
          );
        })
        .whereType<ReferralEntryPayload>()
        .toList();
  }

  SubscriptionHistoryPayload? _toSubscriptionHistoryPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final List<SubscriptionHistoryEntryPayload> entries =
        _toSubscriptionEntries(decoded['data']);
    final PaginationPayload pagination = _toPaginationPayload(
      decoded['pagination'],
    );
    return SubscriptionHistoryPayload(entries: entries, pagination: pagination);
  }

  QuizAttemptHistoryPayload? _toQuizAttemptHistoryPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final List<QuizAttemptSummaryPayload> attempts = _toQuizAttemptSummaries(
      decoded['data'],
    );
    final PaginationPayload pagination = _toPaginationPayload(
      decoded['pagination'],
    );
    return QuizAttemptHistoryPayload(
      attempts: attempts,
      pagination: pagination,
    );
  }

  List<QuizAttemptSummaryPayload> _toQuizAttemptSummaries(dynamic raw) {
    if (raw is! List<dynamic>) {
      return <QuizAttemptSummaryPayload>[];
    }
    return raw
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }
          final int? id = _parseInt(item['id']);
          if (id == null) {
            return null;
          }
          return QuizAttemptSummaryPayload(
            id: id,
            subjectId: _parseInt(item['subject_id']),
            subject: _nullableText(item['subject']),
            subjectCode: _nullableText(item['subject_code']),
            score: _parseInt(item['score']) ?? 0,
            totalQuestions: _parseInt(item['total_questions']) ?? 0,
            createdAt: _parseDate(item['created_at']),
          );
        })
        .whereType<QuizAttemptSummaryPayload>()
        .toList();
  }

  QuizAttemptDetailPayload? _toQuizAttemptDetailPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final dynamic data = decoded['data'] ?? decoded;
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final Map<String, dynamic>? subjectMap =
        data['subject'] is Map<String, dynamic>
        ? data['subject'] as Map<String, dynamic>
        : null;
    final int? subjectId =
        _parseInt(subjectMap?['id']) ?? _parseInt(data['subject_id']);
    final String subjectTitle = _firstNonEmpty(<dynamic>[
      subjectMap?['title'],
      data['subject'],
    ]);
    final String subjectCode = _firstNonEmpty(<dynamic>[
      subjectMap?['code'],
      data['subject_code'],
    ]);

    final List<QuestionItem> questions = (data['questions'] is List<dynamic>)
        ? (data['questions'] as List<dynamic>)
              .map(_toQuestionItem)
              .whereType<QuestionItem>()
              .toList()
        : <QuestionItem>[];

    final Map<int, String?> answerByQuestionId = <int, String?>{};
    if (data['answers'] is List<dynamic>) {
      for (final dynamic item in data['answers']) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final int? qid = _parseInt(item['question_id']);
        if (qid == null) {
          continue;
        }
        answerByQuestionId[qid] = _nullableText(item['selected_choice']);
      }
    }

    final Map<int, String> answers = <int, String>{};
    for (int i = 0; i < questions.length; i++) {
      final QuestionItem question = questions[i];
      if (question.id == null) {
        continue;
      }
      final String? selected = answerByQuestionId[question.id!];
      if (selected != null && selected.isNotEmpty) {
        answers[i] = selected;
      }
    }

    final int? attemptId = _parseInt(data['id']);
    final DateTime? createdAt = _parseDate(data['created_at']);
    if (attemptId == null || subjectTitle.isEmpty || createdAt == null) {
      return null;
    }

    return QuizAttemptDetailPayload(
      id: attemptId,
      subjectId: subjectId,
      subjectCode: subjectCode.isEmpty ? 'SUBJ' : subjectCode,
      subjectTitle: subjectTitle,
      score: _parseInt(data['score']) ?? 0,
      totalQuestions: _parseInt(data['total_questions']) ?? questions.length,
      createdAt: createdAt,
      questions: questions,
      answers: answers,
    );
  }

  List<SubscriptionHistoryEntryPayload> _toSubscriptionEntries(dynamic raw) {
    if (raw is! List<dynamic>) {
      return <SubscriptionHistoryEntryPayload>[];
    }
    return raw
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }
          final String planName = _firstNonEmpty(<dynamic>[
            item['plan_name'],
            item['plan'],
          ]);
          final DateTime? startDate = _parseDate(item['start_date']);
          if (startDate == null) {
            return null;
          }
          return SubscriptionHistoryEntryPayload(
            id: _parseInt(item['id']) ?? 0,
            planName: planName,
            price: _parseDouble(item['price']) ?? 0,
            billingCycle: _nullableText(item['billing_cycle']) ?? 'monthly',
            startDate: startDate,
            endDate: _parseDate(item['end_date']),
            status: _nullableText(item['status']) ?? 'active',
          );
        })
        .whereType<SubscriptionHistoryEntryPayload>()
        .toList();
  }

  PaginationPayload _toPaginationPayload(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return const PaginationPayload();
    }
    final int currentPage = _parseInt(raw['current_page']) ?? 1;
    final int lastPage = _parseInt(raw['last_page']) ?? 1;
    final bool hasMore =
        raw['has_more'] == true ||
        (raw['next_page_url'] != null && raw['next_page_url'] != '');
    return PaginationPayload(
      currentPage: currentPage,
      lastPage: lastPage,
      hasMore: hasMore,
    );
  }

  Map<String, String> _toStringMap(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return <String, String>{};
    }

    final Map<String, String> result = <String, String>{};
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final String key = entry.key.trim().toUpperCase();
      final String value = _firstNonEmpty(<dynamic>[entry.value]);
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      result[key] = value;
    }
    return result;
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

  bool? _parseBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value > 0;
    }
    final String normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
  }

  String? _nullableText(dynamic value) {
    final String text = _firstNonEmpty(<dynamic>[value]);
    return text.isEmpty ? null : text;
  }

  String? _trimOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _formatDateForApi(DateTime? value) {
    if (value == null) {
      return null;
    }
    return value.toIso8601String().split('T').first;
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

  String _resolveAssetUrl(String path) {
    final String base = (_resolvedBaseUrl ?? ApiConfig.baseUrl).trim();
    String root = base;
    if (root.endsWith('/api')) {
      root = root.substring(0, root.length - 4);
    }
    if (root.endsWith('/')) {
      root = root.substring(0, root.length - 1);
    }
    return '$root$path';
  }

  String? _normalizeAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null) {
      return null;
    }
    final String trimmed = avatarUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('/')) {
      return _resolveAssetUrl(trimmed);
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasAuthority) {
      return trimmed;
    }
    final String host = parsed.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1' && host != '0.0.0.0') {
      return trimmed;
    }

    final String pathWithQuery =
        '${parsed.path}'
        '${parsed.hasQuery ? '?${parsed.query}' : ''}'
        '${parsed.hasFragment ? '#${parsed.fragment}' : ''}';
    return _resolveAssetUrl(pathWithQuery);
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
    required this.trialConsumed,
    required this.emailVerified,
    required this.emailVerifiedAt,
    required this.school,
    required this.birthdate,
    required this.gender,
    required this.place,
    required this.phoneNumber,
    required this.avatarUrl,
    required this.referralCode,
    required this.referredBy,
  });

  final String name;
  final String email;
  final String? token;
  final PlanTier? tier;
  final int? planId;
  final String? billingCycle;
  final DateTime? endDate;
  final bool trialConsumed;
  final bool emailVerified;
  final DateTime? emailVerifiedAt;
  final String? school;
  final DateTime? birthdate;
  final String? gender;
  final String? place;
  final String? phoneNumber;
  final String? avatarUrl;
  final String? referralCode;
  final int? referredBy;
}

class PracticeSubjectPayload {
  const PracticeSubjectPayload({
    required this.id,
    required this.code,
    required this.title,
    required this.groupKey,
    required this.groupLabel,
    required this.totalQuestions,
    required this.questionLimit,
    required this.isAccessible,
    required this.colorHex,
  });

  final int id;
  final String code;
  final String title;
  final String groupKey;
  final String groupLabel;
  final int totalQuestions;
  final int questionLimit;
  final bool isAccessible;
  final String? colorHex;
}

class QuizAnswerPayload {
  const QuizAnswerPayload({
    required this.questionId,
    required this.selectedChoice,
  });

  final int questionId;
  final String? selectedChoice;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question_id': questionId,
      'selected_choice': selectedChoice,
    };
  }
}

class QuizSubmitPayload {
  const QuizSubmitPayload({
    required this.attemptId,
    required this.score,
    required this.totalQuestions,
  });

  final int attemptId;
  final int score;
  final int totalQuestions;
}

class QuizAttemptHistoryPayload {
  const QuizAttemptHistoryPayload({
    required this.attempts,
    required this.pagination,
  });

  final List<QuizAttemptSummaryPayload> attempts;
  final PaginationPayload pagination;
}

class QuizAttemptSummaryPayload {
  const QuizAttemptSummaryPayload({
    required this.id,
    required this.subjectId,
    required this.subject,
    required this.subjectCode,
    required this.score,
    required this.totalQuestions,
    required this.createdAt,
  });

  final int id;
  final int? subjectId;
  final String? subject;
  final String? subjectCode;
  final int score;
  final int totalQuestions;
  final DateTime? createdAt;
}

class QuizAttemptDetailPayload {
  const QuizAttemptDetailPayload({
    required this.id,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectTitle,
    required this.score,
    required this.totalQuestions,
    required this.createdAt,
    required this.questions,
    required this.answers,
  });

  final int id;
  final int? subjectId;
  final String subjectCode;
  final String subjectTitle;
  final int score;
  final int totalQuestions;
  final DateTime createdAt;
  final List<QuestionItem> questions;
  final Map<int, String> answers;
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

class CheckoutPayload {
  const CheckoutPayload({
    required this.checkoutId,
    required this.checkoutUrl,
    required this.status,
    required this.billingCycle,
  });

  final String checkoutId;
  final String checkoutUrl;
  final String? status;
  final String? billingCycle;
}

class DashboardMetricsPayload {
  const DashboardMetricsPayload({
    required this.referralJoinCount,
    required this.lastScore,
    required this.lastTotal,
    required this.lastSubject,
    required this.lastCompletedAt,
  });

  final int referralJoinCount;
  final int? lastScore;
  final int? lastTotal;
  final String? lastSubject;
  final DateTime? lastCompletedAt;
}

class ReferralSummaryPayload {
  const ReferralSummaryPayload({
    required this.referralCode,
    required this.referredByName,
    required this.referredByEmail,
    required this.joinCount,
    required this.referrals,
    required this.points,
    required this.offers,
    required this.categories,
    required this.brands,
    required this.activeRewards,
    required this.pagination,
  });

  final String? referralCode;
  final String? referredByName;
  final String? referredByEmail;
  final int joinCount;
  final List<ReferralEntryPayload> referrals;
  final ReferralPointsPayload points;
  final List<ReferralOfferPayload> offers;
  final List<String> categories;
  final List<String> brands;
  final List<ReferralRewardPayload> activeRewards;
  final PaginationPayload pagination;
}

class ReferralPointsPayload {
  const ReferralPointsPayload({
    required this.earned,
    required this.spent,
    required this.available,
    required this.perReferral,
  });

  final int earned;
  final int spent;
  final int available;
  final int perReferral;
}

class ReferralOfferPayload {
  const ReferralOfferPayload({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.subject,
    required this.subjectId,
    required this.questionLimit,
    required this.durationDays,
    required this.category,
    required this.brand,
    required this.imageUrl,
    required this.isFeatured,
  });

  final int id;
  final String title;
  final String? description;
  final int pointsCost;
  final String? subject;
  final int? subjectId;
  final int? questionLimit;
  final int? durationDays;
  final String? category;
  final String? brand;
  final String? imageUrl;
  final bool isFeatured;
}

class ReferralRewardPayload {
  const ReferralRewardPayload({
    required this.id,
    required this.offerId,
    required this.subjectId,
    required this.questionLimit,
    required this.expiresAt,
  });

  final int id;
  final int offerId;
  final int? subjectId;
  final int? questionLimit;
  final DateTime? expiresAt;
}

class ReferralRedemptionPayload {
  const ReferralRedemptionPayload({
    required this.id,
    required this.offerId,
    required this.subjectId,
    required this.questionLimit,
    required this.expiresAt,
    required this.points,
  });

  final int id;
  final int offerId;
  final int? subjectId;
  final int? questionLimit;
  final DateTime? expiresAt;
  final ReferralPointsPayload points;
}

class ReferralEntryPayload {
  const ReferralEntryPayload({
    required this.id,
    required this.invitedName,
    required this.invitedEmail,
    required this.createdAt,
  });

  final int id;
  final String invitedName;
  final String invitedEmail;
  final DateTime? createdAt;
}

class SubscriptionHistoryPayload {
  const SubscriptionHistoryPayload({
    required this.entries,
    required this.pagination,
  });

  final List<SubscriptionHistoryEntryPayload> entries;
  final PaginationPayload pagination;
}

class SubscriptionHistoryEntryPayload {
  const SubscriptionHistoryEntryPayload({
    required this.id,
    required this.planName,
    required this.price,
    required this.billingCycle,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final int id;
  final String planName;
  final double price;
  final String billingCycle;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
}

class PaginationPayload {
  const PaginationPayload({
    this.currentPage = 1,
    this.lastPage = 1,
    this.hasMore = false,
  });

  final int currentPage;
  final int lastPage;
  final bool hasMore;
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
