import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../services/mobile_api_service.dart';

class AppState extends ChangeNotifier {
  AppState() {
    unawaited(loadPlans());
    unawaited(_loadRememberPreference());
    _initConnectivity();
  }

  bool onboardingDone = false;
  bool signedIn = false;
  bool rememberMe = false;
  String? rememberedEmail;
  String userName = 'Future Topnotcher';
  String userEmail = '';
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
  bool isOffline = false;
  final MobileApiService _api = MobileApiService();
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
  bool _restoringSession = false;

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

  final List<QuizRecord> records = <QuizRecord>[];

  static const String _prefsRememberMe = 'remember_me';
  static const String _prefsAuthToken = 'auth_token';
  static const String _prefsRememberedEmail = 'remembered_email';

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

    final ApiResult<List<PlanOption>> response = await _api.fetchPlans();
    if (!response.ok || response.data == null) {
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
    await _persistSession(
      token: data.token,
      email: data.email.trim().isNotEmpty ? data.email.trim() : email.trim(),
    );
    notifyListeners();

    await loadPlans(force: true);
    await loadPracticeSubjects(force: true);
    await loadDashboardMetrics(force: true);
    await loadSubscriptionHistory(loadMore: false);
    await loadReferrals(loadMore: false);
    await loadQuizAttempts(loadMore: false);
    return null;
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? passwordConfirmation,
    DateTime? birthdate,
    String? gender,
  }) async {
    final ApiResult<AuthPayload> response = await _api.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      birthdate: birthdate,
      gender: gender,
    );
    if (!response.ok || response.data == null) {
      return response.message ?? 'Registration failed.';
    }

    final AuthPayload data = response.data!;
    final String fallbackName = name.trim().isNotEmpty
        ? name.trim()
        : _nameFromEmail(email.trim());
    _applyAuthPayload(
      data,
      emailFallback: email.trim(),
      nameFallback: fallbackName,
    );
    notifyListeners();

    await loadPlans(force: true);
    await loadPracticeSubjects(force: true);
    await loadDashboardMetrics(force: true);
    await loadSubscriptionHistory(loadMore: false);
    await loadReferrals(loadMore: false);
    await loadQuizAttempts(loadMore: false);
    return null;
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
    userSchool = data.school ?? '';
    userBirthdate = data.birthdate;
    userGender = data.gender;
    userPlace = data.place ?? '';
    userPhoneNumber = data.phoneNumber ?? '';
    userAvatarUrl = data.avatarUrl;
    referralCode = data.referralCode;
    referredBy = data.referredBy;
    if (data.tier != null) {
      selectedTier = data.tier!;
    }
    if (data.planId != null) {
      selectedPlanId = data.planId;
    }
    subscriptionBillingCycle = data.billingCycle;
    subscriptionEndDate = data.endDate;
    notifyListeners();
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
      _practiceSubjectsLoaded = false;
      _practiceSubjects = <SubjectItem>[];
      practiceSubjectsError =
          response.message ?? 'Unable to load practice subjects.';
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

  Future<String?> loadReferrals({bool loadMore = false}) async {
    if (!signedIn) {
      return null;
    }
    if (loadingReferrals) {
      return null;
    }

    loadingReferrals = true;
    notifyListeners();

    final int targetPage = loadMore ? _referralsPage + 1 : 1;
    final ApiResult<ReferralSummaryPayload> response = await _api
        .fetchReferrals(page: targetPage);
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
        startDate: item.startDate,
        endDate: item.endDate,
        status: item.status,
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
    signedIn = false;
    selectedPlanId = null;
    subscriptionBillingCycle = null;
    subscriptionEndDate = null;
    selectingPlan = false;
    creatingCheckout = false;
    userSchool = '';
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
    _api.setAuthToken(null);
    unawaited(_clearStoredSession());
    notifyListeners();
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

    return _api.submitQuizAttempt(subjectId: subjectId, answers: payload);
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
    userSchool = data.school ?? '';
    userBirthdate = data.birthdate;
    userGender = data.gender;
    userPlace = data.place ?? '';
    userPhoneNumber = data.phoneNumber ?? '';
    userAvatarUrl = data.avatarUrl;
    referralCode = data.referralCode;
    referredBy = data.referredBy;
    if (data.tier != null) {
      selectedTier = data.tier!;
    }
    if (data.planId != null) {
      selectedPlanId = data.planId;
    }
    subscriptionBillingCycle = data.billingCycle;
    subscriptionEndDate = data.endDate;
    signedIn = true;
  }

  Future<void> _persistSession({
    required String? token,
    required String email,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsRememberMe, rememberMe);
      await prefs.setString(_prefsRememberedEmail, email);
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
    } catch (_) {
      // Ignore storage cleanup errors.
    }
  }
}
