import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../services/apple_auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/in_app_purchase_service.dart';
import '../services/mobile_api_service.dart';

class GoogleLoginResult {
  const GoogleLoginResult._({
    required this.success,
    required this.requiresProfile,
    required this.message,
    this.prefillName,
    this.prefillEmail,
  });

  final bool success;
  final bool requiresProfile;
  final String? message;
  final String? prefillName;
  final String? prefillEmail;

  factory GoogleLoginResult.success() {
    return const GoogleLoginResult._(
      success: true,
      requiresProfile: false,
      message: null,
    );
  }

  factory GoogleLoginResult.failure(String message) {
    return GoogleLoginResult._(
      success: false,
      requiresProfile: false,
      message: message,
    );
  }

  factory GoogleLoginResult.requiresProfile({
    String? message,
    String? prefillName,
    String? prefillEmail,
  }) {
    return GoogleLoginResult._(
      success: false,
      requiresProfile: true,
      message: message,
      prefillName: prefillName,
      prefillEmail: prefillEmail,
    );
  }
}

class AppleLoginResult {
  const AppleLoginResult._({
    required this.success,
    required this.requiresProfile,
    required this.message,
    this.prefillName,
    this.prefillEmail,
  });

  final bool success;
  final bool requiresProfile;
  final String? message;
  final String? prefillName;
  final String? prefillEmail;

  factory AppleLoginResult.success() {
    return const AppleLoginResult._(
      success: true,
      requiresProfile: false,
      message: null,
    );
  }

  factory AppleLoginResult.failure(String message) {
    return AppleLoginResult._(
      success: false,
      requiresProfile: false,
      message: message,
    );
  }

  factory AppleLoginResult.requiresProfile({
    String? message,
    String? prefillName,
    String? prefillEmail,
  }) {
    return AppleLoginResult._(
      success: false,
      requiresProfile: true,
      message: message,
      prefillName: prefillName,
      prefillEmail: prefillEmail,
    );
  }
}

class AppState extends ChangeNotifier {
  AppState() {
    unawaited(loadPlans());
    unawaited(_loadRememberPreference());
    _initConnectivity();
  }

  bool onboardingDone = false;
  bool signedIn = false;
  bool signedInWithGoogle = false;
  bool signedInWithApple = false;
  bool rememberMe = false;
  String? rememberedEmail;
  String userName = 'Future Topnotcher';
  String userEmail = '';
  bool userEmailVerified = false;
  DateTime? userEmailVerifiedAt;
  String userSchool = '';
  DateTime? userBirthdate;
  String? userGender;
  String userPlace = '';
  String userPhoneNumber = '';
  String? userAvatarUrl;
  String? referralCode;
  int? referredBy;
  String? referredByName;
  String? referredByEmail;
  int referralJoinedCount = 0;
  bool trialConsumed = false;
  bool mobileDemoSeen = false;
  DateTime? mobileDemoSeenAt;
  ReferralPoints? referralPoints;
  List<ReferralOfferItem> _referralOffers = <ReferralOfferItem>[];
  List<String> referralCategories = <String>[];
  List<String> referralBrands = <String>[];
  List<ReferralRewardItem> _activeRewards = <ReferralRewardItem>[];
  int? lastScore;
  int? lastScoreTotal;
  String? lastScoreSubject;
  DateTime? lastScoreAt;
  PlanTier selectedTier = PlanTier.free;
  int? selectedPlanId;
  String? subscriptionBillingCycle;
  DateTime? subscriptionEndDate;
  bool selectingPlan = false;
  bool creatingCheckout = false;
  bool updatingProfile = false;
  bool deletingAccount = false;
  bool isOffline = false;
  bool loadingPlans = false;
  final MobileApiService _api = MobileApiService();
  final InAppPurchaseService _inAppPurchase = InAppPurchaseService();
  final GoogleAuthService _googleAuth = GoogleAuthService();
  final AppleAuthService _appleAuth = AppleAuthService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _plansLoaded = false;
  bool loadingPracticeSubjects = false;
  String? practiceSubjectsError;
  bool _practiceSubjectsLoaded = false;
  List<SubjectItem> _practiceSubjects = <SubjectItem>[];
  bool _metricsLoaded = false;
  List<SubscriptionHistoryItem> _subscriptionHistory =
      <SubscriptionHistoryItem>[];
  bool loadingSubscriptionHistory = false;
  bool hasMoreSubscriptionHistory = false;
  int _subscriptionHistoryPage = 1;
  List<QuizAttemptItem> _quizAttempts = <QuizAttemptItem>[];
  bool loadingQuizAttempts = false;
  bool hasMoreQuizAttempts = false;
  int _quizAttemptsPage = 1;
  final Map<int, QuizAttemptDetail> _quizAttemptDetails =
      <int, QuizAttemptDetail>{};
  List<ReferralEntry> _referralEntries = <ReferralEntry>[];
  bool loadingReferrals = false;
  bool hasMoreReferrals = false;
  int _referralsPage = 1;
  int _referralsPerPage = 5;
  bool _restoringSession = false;
  GoogleAuthResult? _pendingGoogleAuth;
  AppleAuthResult? _pendingAppleAuth;

  static const PlanOption _placeholderPlan = PlanOption(
    id: -1,
    name: 'Loading Plan',
    tier: PlanTier.free,
    title: 'Loading Plan',
    planGroup: 'placeholder',
    groupLabel: 'Loading',
    subPlanLabel: 'Loading',
    price: 0,
    priceLabel: 'PHP 0',
    billingCycle: 'trial',
    billingLabel: 'Loading',
    durationDays: 0,
    sortOrder: 0,
    description: 'Waiting for server data.',
    features: <String>[],
    paymentProvider: 'paymongo',
    inAppProductIdAndroid: null,
    inAppProductIdIos: null,
  );
  static const List<Color> _subjectPalette = <Color>[
    Color(0xFF9F76C0),
    Color(0xFF70A764),
    Color(0xFFF45A64),
    Color(0xFF2CA6AA),
    Color(0xFFF29C33),
    Color(0xFFEF4DA8),
    Color(0xFF4B8DDF),
  ];

  List<PlanOption> _plans = <PlanOption>[];

  List<PlanOption> get plans => List<PlanOption>.unmodifiable(_plans);
  bool get practiceSubjectsLoaded => _practiceSubjectsLoaded;
  List<SubjectItem> get practiceSubjects =>
      List<SubjectItem>.unmodifiable(_practiceSubjects);
  List<SubscriptionHistoryItem> get subscriptionHistory =>
      List<SubscriptionHistoryItem>.unmodifiable(_subscriptionHistory);
  List<QuizAttemptItem> get quizAttempts =>
      List<QuizAttemptItem>.unmodifiable(_quizAttempts);
  List<ReferralEntry> get referralEntries =>
      List<ReferralEntry>.unmodifiable(_referralEntries);
  List<ReferralOfferItem> get referralOffers =>
      List<ReferralOfferItem>.unmodifiable(_referralOffers);
  List<ReferralRewardItem> get activeRewards =>
      List<ReferralRewardItem>.unmodifiable(_activeRewards);
  bool get signedInWithSocial => signedInWithGoogle || signedInWithApple;

  final List<QuizRecord> records = <QuizRecord>[];

  static const String _prefsRememberMe = 'remember_me';
  static const String _prefsAuthToken = 'auth_token';
  static const String _prefsRememberedEmail = 'remembered_email';
  static const String _prefsAuthProvider = 'auth_provider';
  static const String _prefsCachedSubjects = 'cached_practice_subjects';

  void finishOnboarding() {
    onboardingDone = true;
    notifyListeners();
  }

  Future<void> _loadRememberPreference() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      rememberMe = prefs.getBool(_prefsRememberMe) ?? false;
      rememberedEmail = prefs.getString(_prefsRememberedEmail);
      notifyListeners();
    } catch (_) {
      // Ignore preference load errors.
    }
  }

  Future<void> setRememberMe(bool value) async {
    rememberMe = value;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsRememberMe, value);
      if (!value) {
        await prefs.remove(_prefsAuthToken);
        await prefs.remove(_prefsAuthProvider);
      }
    } catch (_) {
      // Ignore preference persistence errors.
    }
  }

  Future<bool> restoreSession() async {
    if (_restoringSession) {
      return signedIn;
    }
    _restoringSession = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      rememberMe = prefs.getBool(_prefsRememberMe) ?? false;
      rememberedEmail = prefs.getString(_prefsRememberedEmail);
      final String authProvider =
          (prefs.getString(_prefsAuthProvider) ?? 'password')
              .trim()
              .toLowerCase();
      signedInWithGoogle = authProvider == 'google';
      signedInWithApple = authProvider == 'apple';
      final String? token = prefs.getString(_prefsAuthToken);
      if (!rememberMe || token == null || token.isEmpty) {
        _restoringSession = false;
        notifyListeners();
        return false;
      }

      _api.setAuthToken(token);
      final ApiResult<AuthPayload> response = await _api.fetchCurrentUser();
      if (!response.ok || response.data == null) {
        _api.setAuthToken(null);
        await prefs.remove(_prefsAuthToken);
        await prefs.remove(_prefsAuthProvider);
        _restoringSession = false;
        notifyListeners();
        return false;
      }

      _applyAuthPayload(response.data!, emailFallback: rememberedEmail);
      _restoringSession = false;

      await loadPlans(force: true);
      await loadPracticeSubjects(force: true);
      await loadDashboardMetrics(force: true);
      await loadSubscriptionHistory(loadMore: false);
      await loadReferrals(loadMore: false);
      await loadQuizAttempts(loadMore: false);
      notifyListeners();
      return true;
    } catch (_) {
      _restoringSession = false;
      return false;
    }
  }

  Future<void> _initConnectivity() async {
    final Connectivity connectivity = Connectivity();
    try {
      final List<ConnectivityResult> result = await connectivity
          .checkConnectivity();
      _setOffline(result.contains(ConnectivityResult.none));
    } catch (_) {
      _setOffline(false);
    }

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _setOffline(results.contains(ConnectivityResult.none));
    });
  }

  void _setOffline(bool value) {
    if (isOffline == value) {
      return;
    }
    isOffline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<String?> loadPlans({bool force = false}) async {
    if (_plansLoaded && !force) {
      return null;
    }

    loadingPlans = true;
    notifyListeners();
    final ApiResult<List<PlanOption>> response = await _api.fetchPlans();
    if (!response.ok || response.data == null) {
      loadingPlans = false;
      notifyListeners();
      return response.message ?? 'Unable to load plans from web app.';
    }

    final List<PlanOption> remotePlans = response.data!;
    if (remotePlans.isEmpty) {
      return 'No plan data available from server.';
    }

    _plans = List<PlanOption>.from(remotePlans)
      ..sort((PlanOption a, PlanOption b) {
        if (a.sortOrder != b.sortOrder) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        if (a.price != b.price) {
          return a.price.compareTo(b.price);
        }
        return a.id.compareTo(b.id);
      });
    _plansLoaded = true;
    loadingPlans = false;

    if (selectedPlanId != null &&
        !_plans.any((PlanOption item) => item.id == selectedPlanId)) {
      selectedPlanId = null;
    }

    if (selectedPlanId == null) {
      PlanOption? tierMatch;
      for (final PlanOption item in _plans) {
        if (item.tier == selectedTier) {
          tierMatch = item;
          break;
        }
      }
      selectedPlanId = (tierMatch ?? _plans.first).id;
    }

    final PlanOption? selected = _findPlanById(selectedPlanId);
    if (selected != null) {
      selectedTier = selected.tier;
    }
    notifyListeners();
    return null;
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final ApiResult<AuthPayload> response = await _api.login(
      email: email,
      password: password,
    );
    if (!response.ok || response.data == null) {
      return response.message ?? 'Login failed.';
    }

    final AuthPayload data = response.data!;
    _applyAuthPayload(
      data,
      emailFallback: email.trim(),
      nameFallback: _nameFromEmail(email),
    );
    signedInWithGoogle = false;
    signedInWithApple = false;
    _pendingGoogleAuth = null;
    _pendingAppleAuth = null;
    await _persistSession(
      token: data.token,
      email: data.email.trim().isNotEmpty ? data.email.trim() : email.trim(),
      authProvider: 'password',
    );
    notifyListeners();
    unawaited(_warmupSignedInData());
    return null;
  }

  Future<GoogleLoginResult> loginWithGoogle({
    String? fullName,
    String? phoneNumber,
    String? school,
    bool reusePendingAuth = false,
  }) async {
    GoogleAuthResult? googleAuth = reusePendingAuth ? _pendingGoogleAuth : null;
    try {
      googleAuth ??= await _googleAuth.signIn();
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.clientConfigurationError:
          return GoogleLoginResult.failure(
            'Google sign-in is not configured correctly. Check Firebase and OAuth client setup.',
          );
        case GoogleSignInExceptionCode.uiUnavailable:
          return GoogleLoginResult.failure(
            'Google sign-in UI is unavailable on this device.',
          );
        case GoogleSignInExceptionCode.userMismatch:
          return GoogleLoginResult.failure(
            'Google account mismatch detected. Please try again.',
          );
        case GoogleSignInExceptionCode.providerConfigurationError:
          return GoogleLoginResult.failure(
            'Google provider configuration error. Check package name and SHA fingerprints.',
          );
        default:
          return GoogleLoginResult.failure(
            'Unable to complete Google sign-in. Please try again.',
          );
      }
    } on StateError catch (error) {
      return GoogleLoginResult.failure(error.message);
    } catch (_) {
      return GoogleLoginResult.failure(
        'Unable to complete Google sign-in. Please try again.',
      );
    }

    if (googleAuth == null) {
      return GoogleLoginResult.failure(
        'Google sign-in was canceled or interrupted. Please try again.',
      );
    }

    final ApiResult<AuthPayload> response = await _api.loginWithGoogle(
      idToken: googleAuth.idToken,
      email: googleAuth.email,
      name: (fullName ?? googleAuth.name ?? '').trim().isEmpty
          ? googleAuth.name
          : fullName,
      avatarUrl: googleAuth.avatarUrl,
      school: school,
      phoneNumber: phoneNumber,
    );
    if (!response.ok || response.data == null) {
      if (response.statusCode == 428) {
        _pendingGoogleAuth = googleAuth;
        return GoogleLoginResult.requiresProfile(
          message:
              response.message ??
              'Complete your profile first (full name, phone number, school).',
          prefillName: googleAuth.name,
          prefillEmail: googleAuth.email,
        );
      }
      _pendingGoogleAuth = null;
      return GoogleLoginResult.failure(
        response.message ?? 'Google login failed.',
      );
    }

    _pendingGoogleAuth = null;
    final AuthPayload data = response.data!;
    final String fallbackEmail = googleAuth.email.trim();
    _applyAuthPayload(
      data,
      emailFallback: fallbackEmail,
      nameFallback: (googleAuth.name ?? '').trim().isNotEmpty
          ? googleAuth.name!.trim()
          : _nameFromEmail(fallbackEmail),
    );
    signedInWithGoogle = true;
    signedInWithApple = false;
    _pendingAppleAuth = null;
    // Google login requires a verified Google account before token acceptance.
    if (!userEmailVerified) {
      userEmailVerified = true;
      userEmailVerifiedAt ??= DateTime.now();
    }
    await _persistSession(
      token: data.token,
      email: data.email.trim().isNotEmpty ? data.email.trim() : fallbackEmail,
      authProvider: 'google',
    );
    notifyListeners();
    unawaited(_warmupSignedInData());
    return GoogleLoginResult.success();
  }

  Future<AppleLoginResult> loginWithApple({
    String? fullName,
    String? phoneNumber,
    String? school,
    bool reusePendingAuth = false,
  }) async {
    AppleAuthResult? appleAuth = reusePendingAuth ? _pendingAppleAuth : null;
    try {
      appleAuth ??= await _appleAuth.signIn();
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return AppleLoginResult.failure(
          'Apple sign-in was canceled. Please try again.',
        );
      }
      return AppleLoginResult.failure(
        'Unable to complete Apple sign-in. Please try again.',
      );
    } on StateError catch (error) {
      return AppleLoginResult.failure(error.message);
    } catch (_) {
      return AppleLoginResult.failure(
        'Unable to complete Apple sign-in. Please try again.',
      );
    }

    if (appleAuth == null) {
      return AppleLoginResult.failure(
        'Apple sign-in was canceled or interrupted. Please try again.',
      );
    }

    final String effectiveName = (fullName ?? appleAuth.name ?? '').trim();
    final ApiResult<AuthPayload> response = await _api.loginWithApple(
      idToken: appleAuth.idToken,
      appleUserId: appleAuth.userIdentifier,
      email: appleAuth.email,
      name: effectiveName.isEmpty ? appleAuth.name : effectiveName,
      school: school,
      phoneNumber: phoneNumber,
    );
    if (!response.ok || response.data == null) {
      if (response.statusCode == 428) {
        _pendingAppleAuth = appleAuth;
        final String prefillEmail = appleAuth.email.trim();
        return AppleLoginResult.requiresProfile(
          message:
              response.message ??
              'Complete your profile first (full name, phone number, school).',
          prefillName: appleAuth.name,
          prefillEmail: prefillEmail.isEmpty ? null : prefillEmail,
        );
      }
      _pendingAppleAuth = null;
      return AppleLoginResult.failure(
        response.message ?? 'Apple login failed.',
      );
    }

    _pendingAppleAuth = null;
    final AuthPayload data = response.data!;
    final String fallbackEmail = appleAuth.email.trim();
    _applyAuthPayload(
      data,
      emailFallback: fallbackEmail.isNotEmpty ? fallbackEmail : rememberedEmail,
      nameFallback: (appleAuth.name ?? '').trim().isNotEmpty
          ? appleAuth.name!.trim()
          : _nameFromEmail(
              (fallbackEmail.isNotEmpty ? fallbackEmail : 'apple_user'),
            ),
    );
    signedInWithGoogle = false;
    signedInWithApple = true;
    _pendingGoogleAuth = null;
    if (!userEmailVerified) {
      userEmailVerified = true;
      userEmailVerifiedAt ??= DateTime.now();
    }
    await _persistSession(
      token: data.token,
      email: data.email.trim().isNotEmpty ? data.email.trim() : fallbackEmail,
      authProvider: 'apple',
    );
    notifyListeners();
    unawaited(_warmupSignedInData());
    return AppleLoginResult.success();
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? passwordConfirmation,
    String? phoneNumber,
    String? school,
  }) async {
    final ApiResult<bool> response = await _api.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      phoneNumber: phoneNumber,
      school: school,
    );
    if (!response.ok || response.data != true) {
      return response.message ?? 'Registration failed.';
    }
    return null;
  }

  Future<String?> forgotPassword({required String email}) async {
    final ApiResult<bool> response = await _api.forgotPassword(email: email);
    if (!response.ok || response.data != true) {
      return response.message ?? 'Unable to send password reset link.';
    }
    return null;
  }

  Future<String?> resendVerification({required String email}) async {
    final ApiResult<bool> response = await _api.resendVerification(
      email: email,
    );
    if (!response.ok || response.data != true) {
      return response.message ?? 'Unable to send verification email.';
    }
    return null;
  }

  Future<bool> isEmailAvailable({
    required String email,
    String? ignoreEmail,
  }) async {
    final ApiResult<bool> response = await _api.isEmailAvailable(
      email: email,
      ignoreEmail: ignoreEmail,
    );
    return response.ok && response.data == true;
  }

  Future<String?> updateProfile({
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
    updatingProfile = true;
    notifyListeners();

    final ApiResult<AuthPayload> response = await _api.updateProfile(
      name: name,
      email: email,
      school: school,
      place: place,
      phoneNumber: phoneNumber,
      birthdate: birthdate,
      gender: gender,
      avatarBytes: avatarBytes,
      avatarFilename: avatarFilename,
    );

    updatingProfile = false;

    if (!response.ok || response.data == null) {
      notifyListeners();
      if (response.statusCode == 401) {
        return 'Session expired. Please login again.';
      }
      return response.message ?? 'Unable to update profile.';
    }

    final AuthPayload data = response.data!;
    userName = data.name.trim().isNotEmpty ? data.name.trim() : userName;
    userEmail = data.email.trim().isNotEmpty ? data.email.trim() : userEmail;
    userEmailVerified = data.emailVerified;
    userEmailVerifiedAt = data.emailVerifiedAt;
    userSchool = data.school ?? '';
    userBirthdate = data.birthdate;
    userGender = data.gender;
    userPlace = data.place ?? '';
    userPhoneNumber = data.phoneNumber ?? '';
    userAvatarUrl = data.avatarUrl;
    referralCode = data.referralCode;
    referredBy = data.referredBy;
    trialConsumed = data.trialConsumed;
    mobileDemoSeen = data.mobileDemoSeen;
    mobileDemoSeenAt = data.mobileDemoSeenAt;
    if (data.tier != null) {
      selectedTier = data.tier!;
    }
    selectedPlanId = data.planId;
    subscriptionBillingCycle = data.billingCycle;
    subscriptionEndDate = data.endDate;
    notifyListeners();
    return null;
  }

  Future<String?> submitFeedback({
    required int rating,
    required String comment,
  }) async {
    if (!signedIn) {
      return 'Please login first.';
    }
    final String trimmed = comment.trim();
    if (rating < 1 || rating > 5) {
      return 'Please select a rating.';
    }
    if (trimmed.length < 10) {
      return 'Please share at least 10 characters.';
    }

    final ApiResult<bool> response = await _api.submitFeedback(
      rating: rating,
      comment: trimmed,
    );

    if (!response.ok || response.data != true) {
      if (response.statusCode == 401) {
        return 'Session expired. Please login again.';
      }
      return response.message ?? 'Unable to send feedback.';
    }

    return null;
  }

  Future<String?> deleteAccount({String? password}) async {
    if (!signedIn) {
      return 'Please login first.';
    }
    if (deletingAccount) {
      return null;
    }

    deletingAccount = true;
    notifyListeners();

    ApiResult<bool> response;
    try {
      response = await _api.deleteAccount(password: password);
    } finally {
      deletingAccount = false;
      notifyListeners();
    }

    if (!response.ok || response.data != true) {
      if (response.statusCode == 401) {
        return 'Session expired. Please login again.';
      }
      return response.message ?? 'Unable to delete account.';
    }

    return null;
  }

  Future<String?> loadPracticeSubjects({bool force = false}) async {
    if (!signedIn) {
      return null;
    }
    if (_practiceSubjectsLoaded && !force) {
      return null;
    }

    loadingPracticeSubjects = true;
    practiceSubjectsError = null;
    notifyListeners();

    final ApiResult<List<PracticeSubjectPayload>> response = await _api
        .fetchPracticeSubjects();

    loadingPracticeSubjects = false;

    if (!response.ok || response.data == null) {
      final String fallbackMessage =
          response.message ?? 'Unable to load practice subjects.';
      if (_isSubscriptionAccessError(response)) {
        final List<SubjectItem> cached = await _loadCachedPracticeSubjects(
          lockAll: true,
        );
        if (cached.isNotEmpty) {
          _practiceSubjectsLoaded = true;
          _practiceSubjects = cached;
          practiceSubjectsError = null;
          notifyListeners();
          return null;
        }
      }
      _practiceSubjectsLoaded = false;
      _practiceSubjects = <SubjectItem>[];
      practiceSubjectsError = fallbackMessage;
      notifyListeners();
      return practiceSubjectsError;
    }

    final List<PracticeSubjectPayload> payloads = response.data!;
    _practiceSubjects = payloads.asMap().entries.map((entry) {
      final int index = entry.key;
      final PracticeSubjectPayload item = entry.value;
      return SubjectItem(
        id: item.id.toString(),
        code: item.code,
        title: item.title,
        groupKey: item.groupKey,
        groupLabel: item.groupLabel,
        totalQuestions: item.totalQuestions,
        maxQuestionsPerSet: item.questionLimit,
        color: _subjectColorForPayload(item, index),
        isAccessible: item.isAccessible,
      );
    }).toList();

    _practiceSubjectsLoaded = true;
    practiceSubjectsError = null;
    notifyListeners();
    unawaited(_cachePracticeSubjects(_practiceSubjects));
    return null;
  }

  bool _isSubscriptionAccessError(
    ApiResult<List<PracticeSubjectPayload>> result,
  ) {
    final int? code = result.statusCode;
    if (code == 402 || code == 403 || code == 422) {
      return true;
    }
    final String message = (result.message ?? '').toLowerCase();
    if (message.isEmpty) {
      return false;
    }
    return message.contains('no active subscription') ||
        message.contains('free trial') ||
        message.contains('choose a paid plan') ||
        (message.contains('subscription') && message.contains('ended'));
  }

  Future<void> _cachePracticeSubjects(List<SubjectItem> subjects) async {
    if (subjects.isEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> payload = subjects
          .map(
            (SubjectItem item) => <String, dynamic>{
              'id': item.id,
              'code': item.code,
              'title': item.title,
              'group_key': item.groupKey,
              'group_label': item.groupLabel,
              'total_questions': item.totalQuestions,
              'max_questions_per_set': item.maxQuestionsPerSet,
              'is_accessible': item.isAccessible,
              'color_value': item.color.toARGB32(),
            },
          )
          .toList();
      final Map<String, dynamic> wrapper = <String, dynamic>{
        'version': 1,
        'subjects': payload,
      };
      await prefs.setString(_prefsCachedSubjects, jsonEncode(wrapper));
    } catch (_) {
      // Ignore cache persistence errors.
    }
  }

  Future<List<SubjectItem>> _loadCachedPracticeSubjects({
    bool lockAll = false,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_prefsCachedSubjects);
      if (raw == null || raw.trim().isEmpty) {
        return <SubjectItem>[];
      }
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <SubjectItem>[];
      }
      final dynamic rawSubjects = decoded['subjects'];
      if (rawSubjects is! List<dynamic>) {
        return <SubjectItem>[];
      }

      int index = 0;
      final List<SubjectItem> subjects = <SubjectItem>[];
      for (final dynamic entry in rawSubjects) {
        if (entry is! Map<String, dynamic>) {
          index++;
          continue;
        }
        final String id = _cachedText(entry['id']);
        final String code = _cachedText(entry['code']);
        final String title = _cachedText(entry['title']);
        final String groupKey = _cachedText(entry['group_key']);
        final String groupLabel = _cachedText(entry['group_label']);
        final int? totalQuestions = _cachedInt(entry['total_questions']);
        final int? maxQuestions = _cachedInt(entry['max_questions_per_set']);
        final int? colorValue = _cachedInt(entry['color_value']);
        final bool accessible = _cachedBool(entry['is_accessible']) ?? true;

        if (id.isEmpty || code.isEmpty || title.isEmpty) {
          index++;
          continue;
        }

        final Color fallbackColor =
            _subjectPalette[index % _subjectPalette.length];
        subjects.add(
          SubjectItem(
            id: id,
            code: code,
            title: title,
            groupKey: groupKey.isNotEmpty ? groupKey : 'nursing_concepts',
            groupLabel: groupLabel.isNotEmpty
                ? groupLabel
                : 'All Nursing Concepts',
            totalQuestions: totalQuestions ?? 0,
            maxQuestionsPerSet: maxQuestions ?? 0,
            color: colorValue != null ? Color(colorValue) : fallbackColor,
            isAccessible: lockAll ? false : accessible,
          ),
        );
        index++;
      }

      return subjects;
    } catch (_) {
      return <SubjectItem>[];
    }
  }

  String _cachedText(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  int? _cachedInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  bool? _cachedBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value > 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  Future<String?> loadDashboardMetrics({bool force = false}) async {
    if (!signedIn) {
      return null;
    }
    if (_metricsLoaded && !force) {
      return null;
    }

    final ApiResult<DashboardMetricsPayload> response = await _api
        .fetchDashboardMetrics();
    if (!response.ok || response.data == null) {
      return response.message ?? 'Unable to load dashboard metrics.';
    }

    final DashboardMetricsPayload payload = response.data!;
    referralJoinedCount = payload.referralJoinCount;
    lastScore = payload.lastScore;
    lastScoreTotal = payload.lastTotal;
    lastScoreSubject = payload.lastSubject;
    lastScoreAt = payload.lastCompletedAt;
    _metricsLoaded = true;
    notifyListeners();
    return null;
  }

  Future<String?> loadReferrals({bool loadMore = false, int? perPage}) async {
    if (!signedIn) {
      return null;
    }
    if (loadingReferrals) {
      return null;
    }

    loadingReferrals = true;
    notifyListeners();

    final int resolvedPerPage = loadMore
        ? _referralsPerPage
        : (perPage ?? _referralsPerPage);
    _referralsPerPage = resolvedPerPage;

    final int targetPage = loadMore ? _referralsPage + 1 : 1;
    final ApiResult<ReferralSummaryPayload> response = await _api
        .fetchReferrals(page: targetPage, perPage: resolvedPerPage);
    loadingReferrals = false;

    if (!response.ok || response.data == null) {
      notifyListeners();
      return response.message ?? 'Unable to load referrals.';
    }

    final ReferralSummaryPayload payload = response.data!;
    referralCode = payload.referralCode ?? referralCode;
    referralJoinedCount = payload.joinCount;
    referredByName = payload.referredByName;
    referredByEmail = payload.referredByEmail;
    referralPoints = ReferralPoints(
      earned: payload.points.earned,
      spent: payload.points.spent,
      available: payload.points.available,
      perReferral: payload.points.perReferral,
    );
    referralCategories = payload.categories;
    referralBrands = payload.brands;
    _referralOffers = payload.offers
        .map(
          (ReferralOfferPayload item) => ReferralOfferItem(
            id: item.id,
            title: item.title,
            description: item.description,
            pointsCost: item.pointsCost,
            subject: item.subject,
            subjectId: item.subjectId,
            questionLimit: item.questionLimit,
            durationDays: item.durationDays,
            category: item.category,
            brand: item.brand,
            imageUrl: item.imageUrl,
            isFeatured: item.isFeatured,
          ),
        )
        .toList();
    _activeRewards = payload.activeRewards
        .map(
          (ReferralRewardPayload item) => ReferralRewardItem(
            id: item.id,
            offerId: item.offerId,
            subjectId: item.subjectId,
            questionLimit: item.questionLimit,
            expiresAt: item.expiresAt,
          ),
        )
        .toList();
    if (loadMore) {
      _referralEntries = <ReferralEntry>[
        ..._referralEntries,
        ...payload.referrals.map(
          (ReferralEntryPayload item) => ReferralEntry(
            id: item.id,
            invitedName: item.invitedName,
            invitedEmail: item.invitedEmail,
            createdAt: item.createdAt,
          ),
        ),
      ];
    } else {
      _referralEntries = payload.referrals.map((ReferralEntryPayload item) {
        return ReferralEntry(
          id: item.id,
          invitedName: item.invitedName,
          invitedEmail: item.invitedEmail,
          createdAt: item.createdAt,
        );
      }).toList();
    }
    _referralsPage = payload.pagination.currentPage;
    hasMoreReferrals = payload.pagination.hasMore;
    notifyListeners();
    return null;
  }

  Future<String?> loadAllReferrals() async {
    if (!signedIn) {
      return null;
    }
    if (loadingReferrals) {
      return null;
    }

    String? error = await loadReferrals(loadMore: false);
    if (error != null) {
      return error;
    }

    int guard = 0;
    while (hasMoreReferrals && guard < 50) {
      error = await loadReferrals(loadMore: true);
      if (error != null) {
        return error;
      }
      guard++;
    }
    return null;
  }

  Future<String?> applyReferralCode(String code) async {
    if (!signedIn) {
      return 'Please login first.';
    }
    final ApiResult<bool> response = await _api.applyReferralCode(code: code);
    if (!response.ok) {
      return response.message ?? 'Unable to apply referral code.';
    }

    await loadReferrals(loadMore: false);
    await loadQuizAttempts(loadMore: false);
    await loadDashboardMetrics(force: true);
    notifyListeners();
    return null;
  }

  Future<String?> redeemReferralOffer(ReferralOfferItem offer) async {
    if (!signedIn) {
      return 'Please login first.';
    }

    final ApiResult<ReferralRedemptionPayload> response = await _api
        .redeemReferralOffer(offerId: offer.id);
    if (!response.ok || response.data == null) {
      return response.message ?? 'Unable to redeem this offer.';
    }

    final ReferralRedemptionPayload payload = response.data!;
    referralPoints = ReferralPoints(
      earned: payload.points.earned,
      spent: payload.points.spent,
      available: payload.points.available,
      perReferral: payload.points.perReferral,
    );

    await loadReferrals(loadMore: false);
    await loadQuizAttempts(loadMore: false);
    await loadPracticeSubjects(force: true);
    notifyListeners();
    return null;
  }

  Future<String?> loadSubscriptionHistory({bool loadMore = false}) async {
    if (!signedIn) {
      return null;
    }
    if (loadingSubscriptionHistory) {
      return null;
    }

    loadingSubscriptionHistory = true;
    notifyListeners();

    final int targetPage = loadMore ? _subscriptionHistoryPage + 1 : 1;
    final ApiResult<SubscriptionHistoryPayload> response = await _api
        .fetchSubscriptionHistory(page: targetPage);
    loadingSubscriptionHistory = false;

    if (!response.ok || response.data == null) {
      notifyListeners();
      return response.message ?? 'Unable to load subscription history.';
    }

    final SubscriptionHistoryPayload payload = response.data!;
    final List<SubscriptionHistoryItem> mapped = payload.entries.map((
      SubscriptionHistoryEntryPayload item,
    ) {
      return SubscriptionHistoryItem(
        id: item.id,
        planName: item.planName,
        price: item.price,
        billingCycle: item.billingCycle,
        providerPaymentId: item.providerPaymentId,
        startDate: item.startDate,
        endDate: item.endDate,
        status: item.status,
        paymentMethod: item.paymentMethod,
      );
    }).toList();

    if (loadMore) {
      _subscriptionHistory = <SubscriptionHistoryItem>[
        ..._subscriptionHistory,
        ...mapped,
      ];
    } else {
      _subscriptionHistory = mapped;
    }

    _subscriptionHistoryPage = payload.pagination.currentPage;
    hasMoreSubscriptionHistory = payload.pagination.hasMore;
    notifyListeners();
    return null;
  }

  Future<String?> loadQuizAttempts({bool loadMore = false}) async {
    if (!signedIn) {
      return null;
    }
    if (loadingQuizAttempts) {
      return null;
    }

    loadingQuizAttempts = true;
    notifyListeners();

    final int targetPage = loadMore ? _quizAttemptsPage + 1 : 1;
    final ApiResult<QuizAttemptHistoryPayload> response = await _api
        .fetchQuizAttempts(page: targetPage);
    loadingQuizAttempts = false;

    if (!response.ok || response.data == null) {
      notifyListeners();
      return response.message ?? 'Unable to load quiz attempts.';
    }

    final QuizAttemptHistoryPayload payload = response.data!;
    final List<QuizAttemptItem> mapped = payload.attempts.map((
      QuizAttemptSummaryPayload item,
    ) {
      return QuizAttemptItem(
        id: item.id,
        subjectId: item.subjectId,
        subjectCode: item.subjectCode ?? 'SUBJ',
        subjectTitle: item.subject ?? 'Subject',
        score: item.score,
        total: item.totalQuestions,
        completedAt: item.createdAt ?? DateTime.now(),
      );
    }).toList();

    if (loadMore) {
      _quizAttempts = <QuizAttemptItem>[..._quizAttempts, ...mapped];
    } else {
      _quizAttempts = mapped;
    }

    _quizAttemptsPage = payload.pagination.currentPage;
    hasMoreQuizAttempts = payload.pagination.hasMore;
    notifyListeners();
    return null;
  }

  Future<String?> deleteQuizAttempts(List<int> attemptIds) async {
    if (!signedIn) {
      return 'Please login first.';
    }
    if (attemptIds.isEmpty) {
      return 'No attempts selected.';
    }

    final ApiResult<int> response = await _api.deleteQuizAttempts(
      attemptIds: attemptIds,
    );
    if (!response.ok) {
      return response.message ?? 'Unable to delete attempts.';
    }

    final Set<int> ids = attemptIds.toSet();
    _quizAttempts = _quizAttempts
        .where((QuizAttemptItem item) => !ids.contains(item.id))
        .toList();
    ids.forEach(_quizAttemptDetails.remove);

    if (_quizAttempts.isEmpty && hasMoreQuizAttempts) {
      await loadQuizAttempts(loadMore: false);
    } else {
      notifyListeners();
    }
    return null;
  }

  Future<String?> clearQuizAttempts() async {
    if (!signedIn) {
      return 'Please login first.';
    }

    final ApiResult<int> response = await _api.clearQuizAttempts();
    if (!response.ok) {
      return response.message ?? 'Unable to clear attempts.';
    }

    _quizAttempts = <QuizAttemptItem>[];
    _quizAttemptDetails.clear();
    hasMoreQuizAttempts = false;
    _quizAttemptsPage = 1;
    notifyListeners();
    return null;
  }

  Future<ApiResult<QuizAttemptDetail>> loadQuizAttemptDetails(
    int attemptId, {
    bool force = false,
  }) async {
    if (!signedIn) {
      return ApiResult<QuizAttemptDetail>.failure('Please login first.');
    }

    if (!force && _quizAttemptDetails.containsKey(attemptId)) {
      return ApiResult<QuizAttemptDetail>.success(
        _quizAttemptDetails[attemptId]!,
      );
    }

    final ApiResult<QuizAttemptDetailPayload> response = await _api
        .fetchQuizAttemptDetails(attemptId: attemptId);
    if (!response.ok || response.data == null) {
      return ApiResult<QuizAttemptDetail>.failure(
        response.message ?? 'Unable to load attempt details.',
      );
    }

    final QuizAttemptDetailPayload payload = response.data!;
    final SubjectItem subject = _subjectForAttempt(payload);
    final QuizAttemptDetail detail = QuizAttemptDetail(
      id: payload.id,
      subject: subject,
      score: payload.score,
      total: payload.totalQuestions,
      completedAt: payload.createdAt,
      questions: payload.questions,
      answers: payload.answers,
    );
    _quizAttemptDetails[attemptId] = detail;
    return ApiResult<QuizAttemptDetail>.success(detail);
  }

  void logout() {
    _resetSessionState(notify: true, signOutGoogle: true);
  }

  void clearSessionAfterAccountDeletion() {
    _resetSessionState(notify: false, signOutGoogle: false);
  }

  void _resetSessionState({required bool notify, required bool signOutGoogle}) {
    signedIn = false;
    signedInWithGoogle = false;
    signedInWithApple = false;
    selectedPlanId = null;
    subscriptionBillingCycle = null;
    subscriptionEndDate = null;
    selectingPlan = false;
    creatingCheckout = false;
    deletingAccount = false;
    userSchool = '';
    userEmailVerified = false;
    userEmailVerifiedAt = null;
    userBirthdate = null;
    userGender = null;
    userPlace = '';
    userPhoneNumber = '';
    userAvatarUrl = null;
    referralCode = null;
    referredBy = null;
    referredByName = null;
    referredByEmail = null;
    referralJoinedCount = 0;
    trialConsumed = false;
    mobileDemoSeen = false;
    mobileDemoSeenAt = null;
    referralPoints = null;
    _referralOffers = <ReferralOfferItem>[];
    referralCategories = <String>[];
    referralBrands = <String>[];
    _activeRewards = <ReferralRewardItem>[];
    lastScore = null;
    lastScoreTotal = null;
    lastScoreSubject = null;
    lastScoreAt = null;
    _practiceSubjects = <SubjectItem>[];
    _practiceSubjectsLoaded = false;
    loadingPracticeSubjects = false;
    practiceSubjectsError = null;
    _metricsLoaded = false;
    _subscriptionHistory = <SubscriptionHistoryItem>[];
    loadingSubscriptionHistory = false;
    hasMoreSubscriptionHistory = false;
    _subscriptionHistoryPage = 1;
    _quizAttempts = <QuizAttemptItem>[];
    loadingQuizAttempts = false;
    hasMoreQuizAttempts = false;
    _quizAttemptsPage = 1;
    _quizAttemptDetails.clear();
    _referralEntries = <ReferralEntry>[];
    loadingReferrals = false;
    hasMoreReferrals = false;
    _referralsPage = 1;
    _pendingGoogleAuth = null;
    _pendingAppleAuth = null;
    _api.setAuthToken(null);
    if (signOutGoogle) {
      unawaited(_signOutGoogleSafely());
    }
    unawaited(_clearStoredSessionSafely());
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _signOutGoogleSafely() async {
    try {
      await _googleAuth.signOut();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'AppState Google sign-out',
        ),
      );
    }
  }

  Future<void> _clearStoredSessionSafely() async {
    try {
      await _clearStoredSession();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'AppState clear stored session',
        ),
      );
    }
  }

  PlanOption get currentPlan {
    if (_plans.isEmpty) {
      return _placeholderPlan;
    }
    if (selectedPlanId != null) {
      final PlanOption? byId = _findPlanById(selectedPlanId);
      if (byId != null) {
        return byId;
      }
    }
    for (final PlanOption item in _plans) {
      if (item.tier == selectedTier) {
        return item;
      }
    }
    return _plans.isNotEmpty ? _plans.first : _placeholderPlan;
  }

  bool get isSubscriptionExpired {
    if (selectedTier != PlanTier.premium) {
      return false;
    }
    if (subscriptionEndDate == null) {
      return false;
    }
    final DateTime now = DateTime.now();
    return now.isAfter(subscriptionEndDate!);
  }

  bool get isFreeTrialExpired {
    final PlanOption plan = currentPlan;
    if (plan.planGroup != 'free_trial') {
      return false;
    }
    final DateTime now = DateTime.now();
    if (subscriptionEndDate != null) {
      return now.isAfter(subscriptionEndDate!);
    }
    return true;
  }

  bool get hasPremiumAccess =>
      selectedTier == PlanTier.premium && !isSubscriptionExpired;

  bool get hasActivePaidPlan => currentPlan.isPaid && !isSubscriptionExpired;

  List<SubjectItem> get visibleSubjects {
    if (!signedIn) {
      return const <SubjectItem>[];
    }
    return List<SubjectItem>.unmodifiable(_practiceSubjects);
  }

  int get maxQuestionPerSet {
    if (_practiceSubjects.isNotEmpty) {
      final Iterable<SubjectItem> accessible = _practiceSubjects.where(
        (SubjectItem item) => item.isAccessible && item.maxQuestionsPerSet > 0,
      );
      if (accessible.isEmpty) {
        return 1;
      }
      return accessible.fold<int>(
        1,
        (int maxValue, SubjectItem item) =>
            max(maxValue, item.maxQuestionsPerSet),
      );
    }
    return 1;
  }

  Future<String?> choosePlan({
    required PlanOption plan,
    String? billingCycle,
  }) async {
    selectingPlan = true;
    notifyListeners();

    final ApiResult<PlanSelectionPayload> response = await _api.selectPlan(
      planId: plan.id,
      billingCycle: billingCycle,
    );

    selectingPlan = false;

    if (!response.ok || response.data == null) {
      notifyListeners();
      if (response.statusCode == 401) {
        return 'Session expired. Please login again.';
      }
      if (response.statusCode == 500) {
        return 'Server error. Please try again later.';
      }
      return response.message ?? 'Unable to choose plan.';
    }

    final PlanSelectionPayload payload = response.data!;
    await _applyPlanSelectionAndRefresh(
      payload: payload,
      plan: plan,
      billingCycle: billingCycle,
    );
    return null;
  }

  Future<String?> purchasePlanWithInAppPurchase({
    required PlanOption plan,
    String? billingCycle,
  }) async {
    if (!plan.usesInAppPurchase) {
      return 'This plan is not configured for in-app purchase.';
    }

    final String? productId = _resolveInAppProductId(plan);
    if (productId == null || productId.trim().isEmpty) {
      return 'In-app product ID is not configured for this platform and plan.';
    }

    creatingCheckout = true;
    notifyListeners();

    final InAppPurchaseAttemptResult storeResult = await _inAppPurchase
        .buyProduct(productId: productId);
    if (!storeResult.success) {
      creatingCheckout = false;
      notifyListeners();
      if (storeResult.cancelled) {
        return storeResult.message ?? 'Purchase was cancelled.';
      }
      return storeResult.message ?? 'Unable to complete in-app purchase.';
    }

    final ApiResult<PlanSelectionPayload> completion = await _api
        .completeInAppPurchase(
          planId: plan.id,
          billingCycle: billingCycle ?? plan.billingCycle,
          platform: storeResult.platform ?? '',
          productId: storeResult.productId ?? productId,
          purchaseId: storeResult.purchaseId,
          verificationData: storeResult.verificationData ?? '',
          verificationSource: storeResult.verificationSource,
          transactionDateMillis: storeResult.transactionDateMillis,
        );

    creatingCheckout = false;

    if (!completion.ok || completion.data == null) {
      notifyListeners();
      if (completion.statusCode == 401) {
        return 'Session expired. Please login again.';
      }
      if (completion.statusCode == 500) {
        return 'Server error. Please try again later.';
      }
      return completion.message ??
          'Unable to activate plan after in-app purchase.';
    }

    await _applyPlanSelectionAndRefresh(
      payload: completion.data!,
      plan: plan,
      billingCycle: billingCycle,
    );
    return null;
  }

  Future<String?> cancelCurrentPlan() async {
    if (!currentPlan.isPaid) {
      return 'You are already on the free plan.';
    }

    final PlanOption? freePlan = _findFreePlan();
    if (freePlan == null) {
      return 'No free plan is available to switch to.';
    }

    return choosePlan(plan: freePlan, billingCycle: freePlan.billingCycle);
  }

  Future<ApiResult<CheckoutPayload>> createCheckout({
    required PlanOption plan,
    String? billingCycle,
    List<String>? paymentMethodTypes,
  }) async {
    creatingCheckout = true;
    notifyListeners();

    final ApiResult<CheckoutPayload> response = await _api.createCheckout(
      planId: plan.id,
      billingCycle: billingCycle,
      paymentMethodTypes: paymentMethodTypes,
    );

    creatingCheckout = false;
    notifyListeners();
    return response;
  }

  Future<void> _applyPlanSelectionAndRefresh({
    required PlanSelectionPayload payload,
    required PlanOption plan,
    String? billingCycle,
  }) async {
    selectedPlanId = payload.planId;
    selectedTier = payload.tier ?? plan.tier;
    subscriptionBillingCycle =
        payload.billingCycle ?? billingCycle ?? plan.billingCycle;
    subscriptionEndDate = payload.endDate;

    await loadPlans(force: true);
    await loadPracticeSubjects(force: true);
    await loadDashboardMetrics(force: true);
    await loadSubscriptionHistory(loadMore: false);
    await loadReferrals(loadMore: false);
    await loadQuizAttempts(loadMore: false);
    notifyListeners();
  }

  String? _resolveInAppProductId(PlanOption plan) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return plan.inAppProductIdAndroid;
      case TargetPlatform.iOS:
        return plan.inAppProductIdIos;
      default:
        return null;
    }
  }

  Future<String?> refreshCurrentUser() async {
    if (!signedIn) {
      return 'Please login first.';
    }

    final ApiResult<AuthPayload> response = await _api.fetchCurrentUser();
    if (!response.ok || response.data == null) {
      if (response.statusCode == 401) {
        logout();
        return 'Session expired. Please login again.';
      }
      return response.message ?? 'Unable to refresh account data.';
    }

    final AuthPayload data = response.data!;
    _applyAuthPayload(data, emailFallback: userEmail, nameFallback: userName);

    await loadPlans(force: true);
    await loadPracticeSubjects(force: true);
    notifyListeners();
    return null;
  }

  Future<void> markFirstAccountGuideSeen() async {
    if (!signedIn || mobileDemoSeen) {
      return;
    }

    mobileDemoSeen = true;
    mobileDemoSeenAt ??= DateTime.now();
    notifyListeners();

    final ApiResult<AuthPayload> response = await _api.markDemoSeen();
    if (!response.ok || response.data == null) {
      return;
    }

    _applyAuthPayload(
      response.data!,
      emailFallback: userEmail,
      nameFallback: userName,
    );
    notifyListeners();
  }

  Future<ApiResult<List<QuestionItem>>> generateQuiz({
    required SubjectItem subject,
    required int count,
  }) async {
    final int? subjectId = int.tryParse(subject.id);
    if (subjectId == null) {
      return ApiResult<List<QuestionItem>>.failure(
        'Invalid subject selection.',
      );
    }
    final int safeCount = count.clamp(1, max(1, subject.totalQuestions));

    return _api.generateQuiz(subjectId: subjectId, totalQuestions: safeCount);
  }

  Future<ApiResult<QuizSubmitPayload>> submitQuizAttempt({
    required SubjectItem subject,
    required List<QuestionItem> questions,
    required Map<int, String> answers,
  }) async {
    final int? subjectId = int.tryParse(subject.id);
    if (subjectId == null) {
      return ApiResult<QuizSubmitPayload>.failure('Invalid subject selection.');
    }

    final List<QuizAnswerPayload> payload = <QuizAnswerPayload>[];
    for (int index = 0; index < questions.length; index++) {
      final QuestionItem item = questions[index];
      if (item.id == null) {
        return ApiResult<QuizSubmitPayload>.failure(
          'Cannot submit an offline quiz attempt.',
        );
      }
      payload.add(
        QuizAnswerPayload(questionId: item.id!, selectedChoice: answers[index]),
      );
    }

    if (payload.isEmpty) {
      return ApiResult<QuizSubmitPayload>.failure('No quiz answers to submit.');
    }

    int? displaySeed;
    for (final QuestionItem item in questions) {
      final int? candidate = item.displaySeed;
      if (candidate != null && candidate > 0) {
        displaySeed = candidate;
        break;
      }
    }

    return _api.submitQuizAttempt(
      subjectId: subjectId,
      answers: payload,
      displaySeed: displaySeed,
    );
  }

  SubjectItem _subjectForAttempt(QuizAttemptDetailPayload payload) {
    final String code = payload.subjectCode;
    final String title = payload.subjectTitle;
    final int? subjectId = payload.subjectId;

    for (final SubjectItem item in _practiceSubjects) {
      if (subjectId != null && int.tryParse(item.id) == subjectId) {
        return item;
      }
      if (item.code == code || item.title == title) {
        return item;
      }
    }

    return SubjectItem(
      id: subjectId?.toString() ?? code,
      code: code.isEmpty ? 'SUBJ' : code,
      title: title.isEmpty ? 'Subject' : title,
      groupKey: 'nursing_concepts',
      groupLabel: 'All Nursing Concepts',
      totalQuestions: payload.totalQuestions,
      color: AppPalette.primary,
    );
  }

  void saveRecord({
    required SubjectItem subject,
    required int score,
    required int total,
    List<QuestionItem> questions = const <QuestionItem>[],
    Map<int, String> answers = const <int, String>{},
  }) {
    records.insert(
      0,
      QuizRecord(
        subjectCode: subject.code,
        subjectTitle: subject.title,
        score: score,
        total: total,
        completedAt: DateTime.now(),
        questions: List<QuestionItem>.from(questions),
        answers: Map<int, String>.from(answers),
      ),
    );
    lastScore = score;
    lastScoreTotal = total;
    lastScoreSubject = subject.title;
    lastScoreAt = DateTime.now();
    notifyListeners();
  }

  Color _subjectColorForPayload(PracticeSubjectPayload item, int index) {
    if (item.colorHex != null) {
      final Color? parsed = _hexToColor(item.colorHex!);
      if (parsed != null) {
        return parsed;
      }
    }

    if (_subjectPalette.isEmpty) {
      return const Color(0xFF4B8DDF);
    }
    return _subjectPalette[index % _subjectPalette.length];
  }

  Color? _hexToColor(String hex) {
    final String normalized = hex.trim().replaceAll('#', '');
    if (normalized.length != 6 && normalized.length != 8) {
      return null;
    }

    final String value = normalized.length == 6 ? 'FF$normalized' : normalized;
    final int? parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }

  String _nameFromEmail(String email) {
    final String clean = email.trim();
    if (!clean.contains('@')) {
      return userName;
    }
    final String base = clean.split('@').first.trim();
    if (base.isEmpty) {
      return userName;
    }
    return '${base[0].toUpperCase()}${base.substring(1)}';
  }

  PlanOption? _findPlanById(int? id) {
    if (id == null) {
      return null;
    }
    for (final PlanOption item in _plans) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  PlanOption? _findFreePlan() {
    for (final PlanOption item in _plans) {
      if (item.planGroup == 'free_trial' ||
          !item.isPaid ||
          item.tier == PlanTier.free) {
        return item;
      }
    }
    return null;
  }

  void _applyAuthPayload(
    AuthPayload data, {
    String? emailFallback,
    String? nameFallback,
  }) {
    final String trimmedEmail = data.email.trim();
    userEmail = trimmedEmail.isNotEmpty
        ? trimmedEmail
        : (emailFallback ?? userEmail);
    final String trimmedName = data.name.trim();
    userName = trimmedName.isNotEmpty
        ? trimmedName
        : (nameFallback ?? userName);
    userEmailVerified = data.emailVerified;
    userEmailVerifiedAt = data.emailVerifiedAt;
    userSchool = data.school ?? '';
    userBirthdate = data.birthdate;
    userGender = data.gender;
    userPlace = data.place ?? '';
    userPhoneNumber = data.phoneNumber ?? '';
    userAvatarUrl = data.avatarUrl;
    referralCode = data.referralCode;
    referredBy = data.referredBy;
    mobileDemoSeen = data.mobileDemoSeen;
    mobileDemoSeenAt = data.mobileDemoSeenAt;
    if (data.tier != null) {
      selectedTier = data.tier!;
    }
    selectedPlanId = data.planId;
    subscriptionBillingCycle = data.billingCycle;
    subscriptionEndDate = data.endDate;
    signedIn = true;
  }

  Future<void> _persistSession({
    required String? token,
    required String email,
    required String authProvider,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsRememberMe, rememberMe);
      await prefs.setString(_prefsRememberedEmail, email);
      await prefs.setString(_prefsAuthProvider, authProvider.trim());
      if (rememberMe && token != null && token.trim().isNotEmpty) {
        await prefs.setString(_prefsAuthToken, token.trim());
      } else {
        await prefs.remove(_prefsAuthToken);
      }
    } catch (_) {
      // Ignore storage persistence errors.
    }
  }

  Future<void> _clearStoredSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsAuthToken);
      await prefs.remove(_prefsAuthProvider);
    } catch (_) {
      // Ignore storage cleanup errors.
    }
  }

  Future<void> _warmupSignedInData() async {
    await _runWarmupLoad(() => loadPlans(force: true));
    await _runWarmupLoad(() => loadPracticeSubjects(force: true));
    await _runWarmupLoad(() => loadDashboardMetrics(force: true));
    await _runWarmupLoad(() => loadSubscriptionHistory(loadMore: false));
    await _runWarmupLoad(() => loadReferrals(loadMore: false));
    await _runWarmupLoad(() => loadQuizAttempts(loadMore: false));
  }

  Future<void> _runWarmupLoad(Future<String?> Function() task) async {
    try {
      await task();
    } catch (_) {
      // Ignore warmup fetch errors to avoid blocking login flow.
    }
  }
}
