import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/app_models.dart';
import '../services/mobile_api_service.dart';

class AppState extends ChangeNotifier {
  AppState() {
    unawaited(loadPlans());
    _initConnectivity();
  }

  bool onboardingDone = false;
  bool signedIn = false;
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
  List<ReferralEntry> _referralEntries = <ReferralEntry>[];
  bool loadingReferrals = false;
  bool hasMoreReferrals = false;
  int _referralsPage = 1;

  static const List<PlanOption> _fallbackPlans = <PlanOption>[
    PlanOption(
      id: 0,
      name: 'Free Plan',
      tier: PlanTier.free,
      title: 'Free Plan',
      price: 0,
      priceLabel: 'PHP 0',
      billingCycle: 'monthly',
      billingLabel: 'Forever free',
      description: 'Starter access for board review.',
      features: <String>[
        'Access to 3 subjects',
        'Up to 30 questions per set',
        'Score summary after each attempt',
        'Basic leaderboard preview',
      ],
    ),
    PlanOption(
      id: 1,
      name: 'Subscription',
      tier: PlanTier.premium,
      title: 'Subscription',
      price: 299,
      priceLabel: 'PHP 299',
      billingCycle: 'monthly',
      billingLabel: 'per month',
      description: 'Full premium review access.',
      features: <String>[
        'All subjects unlocked',
        'Up to 100 questions per set',
        'Full A B C D rationalization',
        'Advanced performance analytics',
        'Bookmarks for weak topics',
        'Referral reward multiplier',
      ],
    ),
  ];
  static const List<Color> _subjectPalette = <Color>[
    Color(0xFF9F76C0),
    Color(0xFF70A764),
    Color(0xFFF45A64),
    Color(0xFF2CA6AA),
    Color(0xFFF29C33),
    Color(0xFFEF4DA8),
    Color(0xFF4B8DDF),
  ];

  List<PlanOption> _plans = List<PlanOption>.from(_fallbackPlans);

  List<PlanOption> get plans => List<PlanOption>.unmodifiable(_plans);
  bool get practiceSubjectsLoaded => _practiceSubjectsLoaded;
  List<SubscriptionHistoryItem> get subscriptionHistory =>
      List<SubscriptionHistoryItem>.unmodifiable(_subscriptionHistory);
  List<ReferralEntry> get referralEntries =>
      List<ReferralEntry>.unmodifiable(_referralEntries);

  final List<SubjectItem> allSubjects = const <SubjectItem>[
    SubjectItem(
      id: 'far',
      code: 'FAR',
      title: 'Financial Accounting and Reporting',
      totalQuestions: 1000,
      color: Color(0xFF9F76C0),
    ),
    SubjectItem(
      id: 'afar',
      code: 'AFAR',
      title: 'Advanced Financial Accounting and Reporting',
      totalQuestions: 900,
      color: Color(0xFF70A764),
    ),
    SubjectItem(
      id: 'ms',
      code: 'MS',
      title: 'Management Services',
      totalQuestions: 800,
      color: Color(0xFFF45A64),
    ),
    SubjectItem(
      id: 'aud',
      code: 'AUD',
      title: 'Auditing',
      totalQuestions: 850,
      color: Color(0xFF2CA6AA),
    ),
    SubjectItem(
      id: 'tax',
      code: 'TAX',
      title: 'Taxation',
      totalQuestions: 750,
      color: Color(0xFFF29C33),
    ),
    SubjectItem(
      id: 'rfbt',
      code: 'RFBT',
      title: 'Regulatory Framework for Business Transactions',
      totalQuestions: 700,
      color: Color(0xFFEF4DA8),
    ),
    SubjectItem(
      id: 'nursing',
      code: 'NUR',
      title: 'Nursing Concepts',
      totalQuestions: 950,
      color: Color(0xFF4B8DDF),
    ),
  ];

  final List<QuizRecord> records = <QuizRecord>[];

  final Map<String, List<_QuestionBlueprint>>
  _bank = <String, List<_QuestionBlueprint>>{
    'far': <_QuestionBlueprint>[
      _QuestionBlueprint(
        prompt:
            "Shareholders' equity will increase when which event happens first",
        options: <String>[
          'Payment of cash dividends',
          'Recognition of net income',
          'Purchase of treasury shares',
          'Settlement of a bank loan',
        ],
        correctIndex: 1,
        reason:
            'net income closes to retained earnings and directly increases equity',
      ),
      _QuestionBlueprint(
        prompt:
            'The statement that reports assets liabilities and equity at one date is',
        options: <String>[
          'Statement of financial position',
          'Statement of cash flows',
          'Statement of comprehensive income',
          'Statement of changes in equity',
        ],
        correctIndex: 0,
        reason:
            'it presents the financial position at a specific point in time',
      ),
    ],
    'afar': <_QuestionBlueprint>[
      _QuestionBlueprint(
        prompt:
            'Intercompany sales in consolidation are removed mainly to avoid',
        options: <String>[
          'Double counting group revenue',
          'Changing parent ownership',
          'Increasing minority interest',
          'Creating new liabilities',
        ],
        correctIndex: 0,
        reason:
            'group reports should include only transactions with external parties',
      ),
      _QuestionBlueprint(
        prompt: 'Goodwill in acquisition is generally measured as',
        options: <String>[
          'Parent book value minus liabilities',
          'Excess of consideration over fair value of net identifiable assets',
          'Difference between revenue and expense',
          'Total subsidiary retained earnings',
        ],
        correctIndex: 1,
        reason:
            'IFRS measures goodwill from purchase consideration and fair values',
      ),
    ],
    'ms': <_QuestionBlueprint>[
      _QuestionBlueprint(
        prompt: 'Break even point occurs when',
        options: <String>[
          'Revenue equals variable costs',
          'Revenue equals total costs',
          'Contribution margin is zero',
          'Profit equals target income',
        ],
        correctIndex: 1,
        reason:
            'at break even profit is zero because total revenue equals total cost',
      ),
      _QuestionBlueprint(
        prompt: 'Contribution margin per unit helps evaluate',
        options: <String>[
          'Short term profitability and coverage of fixed costs',
          'Historical acquisition cost',
          'Bond market value',
          'Payroll withholding taxes',
        ],
        correctIndex: 0,
        reason:
            'contribution margin shows how each unit contributes to fixed costs and profit',
      ),
    ],
    'aud': <_QuestionBlueprint>[
      _QuestionBlueprint(
        prompt: 'Audit evidence is sufficient when there is enough',
        options: <String>[
          'Quantity to reduce audit risk',
          'Internal memo pages only',
          'Verbal explanation only',
          'Unsigned drafts only',
        ],
        correctIndex: 0,
        reason: 'sufficiency refers to the quantity of appropriate evidence',
      ),
      _QuestionBlueprint(
        prompt: 'An unmodified audit opinion indicates statements are',
        options: <String>[
          'Fraud free with absolute assurance',
          'Prepared fairly under the applicable framework',
          'Not yet audited',
          'Guaranteed accurate in every amount',
        ],
        correctIndex: 1,
        reason:
            'auditors provide reasonable assurance and fair presentation conclusion',
      ),
    ],
    'tax': <_QuestionBlueprint>[
      _QuestionBlueprint(
        prompt: 'Value added tax is commonly imposed on',
        options: <String>[
          'Gross sales and covered services of VAT registered persons',
          'Only annual salary income',
          'Only import duties',
          'Only unrealized gains',
        ],
        correctIndex: 0,
        reason: 'VAT generally applies to sale barter exchange and importation',
      ),
      _QuestionBlueprint(
        prompt: 'Withholding tax is designed mainly to',
        options: <String>[
          'Delay tax payments',
          'Advance collection and improve compliance',
          'Replace all other taxes',
          'Remove filing responsibilities',
        ],
        correctIndex: 1,
        reason:
            'it secures collection earlier and improves compliance behavior',
      ),
    ],
    'rfbt': <_QuestionBlueprint>[
      _QuestionBlueprint(
        prompt:
            'Essential requisites of a valid contract include consent object and',
        options: <String>[
          'Cause',
          'Court approval',
          'Notarization in all cases',
          'Board resolution always',
        ],
        correctIndex: 0,
        reason: 'civil law principles require consent object and cause',
      ),
      _QuestionBlueprint(
        prompt: 'A negotiable instrument is payable to bearer when it',
        options: <String>[
          'States payable to bearer',
          'Contains collateral terms',
          'Has fixed maturity only',
          'Uses assignment language only',
        ],
        correctIndex: 0,
        reason: 'bearer wording allows transfer by delivery',
      ),
    ],
    'nursing': <_QuestionBlueprint>[
      _QuestionBlueprint(
        prompt:
            'In emergency care the immediate priority for airway obstruction is',
        options: <String>[
          'Prepare discharge notes',
          'Maintain airway patency',
          'Administer oral medication',
          'Document intake and output',
        ],
        correctIndex: 1,
        reason: 'airway is first in the ABC emergency framework',
      ),
      _QuestionBlueprint(
        prompt: 'A sterile field becomes contaminated when',
        options: <String>[
          'A non sterile object touches it',
          'It remains above waist level',
          'Sterile gloves are used',
          'The nurse avoids reaching over it',
        ],
        correctIndex: 0,
        reason: 'any contact from non sterile items breaks sterility',
      ),
    ],
  };

  void finishOnboarding() {
    onboardingDone = true;
    notifyListeners();
  }

  Future<void> _initConnectivity() async {
    final Connectivity connectivity = Connectivity();
    try {
      final List<ConnectivityResult> result =
          await connectivity.checkConnectivity();
      _setOffline(result.contains(ConnectivityResult.none));
    } catch (_) {
      _setOffline(false);
    }

    _connectivitySubscription = connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
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

    _plans = remotePlans;
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
    userEmail = data.email.trim().isNotEmpty ? data.email.trim() : email.trim();
    userName = data.name.trim().isNotEmpty
        ? data.name.trim()
        : _nameFromEmail(userEmail);
    userSchool = data.school ?? '';
    userBirthdate = data.birthdate;
    userGender = data.gender;
    userPlace = data.place ?? '';
    userPhoneNumber = data.phoneNumber ?? '';
    userAvatarUrl = data.avatarUrl;
    referralCode = data.referralCode;
    referredBy = data.referredBy;
    selectedPlanId = data.planId;
    if (data.tier != null) {
      selectedTier = data.tier!;
    }
    subscriptionBillingCycle = data.billingCycle;
    subscriptionEndDate = data.endDate;
    signedIn = true;
    notifyListeners();

    await loadPlans(force: true);
    await loadPracticeSubjects(force: true);
    await loadDashboardMetrics(force: true);
    await loadSubscriptionHistory(loadMore: false);
    await loadReferrals(loadMore: false);
    return null;
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final ApiResult<AuthPayload> response = await _api.register(
      name: name,
      email: email,
      password: password,
    );
    if (!response.ok || response.data == null) {
      return response.message ?? 'Registration failed.';
    }

    final AuthPayload data = response.data!;
    userName = data.name.trim().isNotEmpty ? data.name.trim() : name.trim();
    if (userName.isEmpty) {
      userName = _nameFromEmail(email.trim());
    }
    userEmail = data.email.trim().isNotEmpty ? data.email.trim() : email.trim();
    userSchool = data.school ?? '';
    userBirthdate = data.birthdate;
    userGender = data.gender;
    userPlace = data.place ?? '';
    userPhoneNumber = data.phoneNumber ?? '';
    userAvatarUrl = data.avatarUrl;
    referralCode = data.referralCode;
    referredBy = data.referredBy;
    selectedPlanId = data.planId;
    if (data.tier != null) {
      selectedTier = data.tier!;
    }
    subscriptionBillingCycle = data.billingCycle;
    subscriptionEndDate = data.endDate;
    signedIn = true;
    notifyListeners();

    await loadPlans(force: true);
    await loadPracticeSubjects(force: true);
    await loadDashboardMetrics(force: true);
    await loadSubscriptionHistory(loadMore: false);
    await loadReferrals(loadMore: false);
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
        totalQuestions: item.totalQuestions,
        maxQuestionsPerSet: item.questionLimit,
        color: _subjectColorForPayload(item, index),
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

    final ApiResult<DashboardMetricsPayload> response =
        await _api.fetchDashboardMetrics();
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
    final ApiResult<ReferralSummaryPayload> response =
        await _api.fetchReferrals(page: targetPage);
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
    if (loadMore) {
      _referralEntries = <ReferralEntry>[
        ..._referralEntries,
        ...payload.referrals.map((ReferralEntryPayload item) => ReferralEntry(
              id: item.id,
              invitedName: item.invitedName,
              invitedEmail: item.invitedEmail,
              createdAt: item.createdAt,
            )),
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
    final ApiResult<bool> response =
        await _api.applyReferralCode(code: code);
    if (!response.ok) {
      return response.message ?? 'Unable to apply referral code.';
    }

    await loadReferrals(loadMore: false);
    await loadDashboardMetrics(force: true);
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
    final ApiResult<SubscriptionHistoryPayload> response =
        await _api.fetchSubscriptionHistory(page: targetPage);
    loadingSubscriptionHistory = false;

    if (!response.ok || response.data == null) {
      notifyListeners();
      return response.message ?? 'Unable to load subscription history.';
    }

    final SubscriptionHistoryPayload payload = response.data!;
    final List<SubscriptionHistoryItem> mapped = payload.entries.map(
      (SubscriptionHistoryEntryPayload item) {
        return SubscriptionHistoryItem(
          id: item.id,
          planName: item.planName,
          price: item.price,
          billingCycle: item.billingCycle,
          startDate: item.startDate,
          endDate: item.endDate,
          status: item.status,
        );
      },
    ).toList();

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
    _referralEntries = <ReferralEntry>[];
    loadingReferrals = false;
    hasMoreReferrals = false;
    _referralsPage = 1;
    _api.setAuthToken(null);
    notifyListeners();
  }

  PlanOption get currentPlan {
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
    return _plans.first;
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

  List<SubjectItem> get visibleSubjects {
    if (_practiceSubjects.isNotEmpty) {
      return List<SubjectItem>.unmodifiable(_practiceSubjects);
    }
    if (signedIn) {
      return const <SubjectItem>[];
    }
    return hasPremiumAccess ? allSubjects : allSubjects.take(3).toList();
  }

  int get maxQuestionPerSet {
    if (_practiceSubjects.isNotEmpty) {
      return _practiceSubjects.fold<int>(
        1,
        (int maxValue, SubjectItem item) => max(
          maxValue,
          item.maxQuestionsPerSet,
        ),
      );
    }
    return hasPremiumAccess ? 100 : 30;
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
    notifyListeners();
    return null;
  }

  Future<ApiResult<CheckoutPayload>> createCheckout({
    required PlanOption plan,
    String? billingCycle,
  }) async {
    creatingCheckout = true;
    notifyListeners();

    final ApiResult<CheckoutPayload> response = await _api.createCheckout(
      planId: plan.id,
      billingCycle: billingCycle,
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
    userEmail = data.email.trim().isNotEmpty ? data.email.trim() : userEmail;
    userName = data.name.trim().isNotEmpty ? data.name.trim() : userName;
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
    final int safeCount = count.clamp(
      1,
      max(1, subject.totalQuestions),
    );

    return _api.generateQuiz(
      subjectId: subjectId,
      totalQuestions: safeCount,
    );
  }

  Future<ApiResult<QuizSubmitPayload>> submitQuizAttempt({
    required SubjectItem subject,
    required List<QuestionItem> questions,
    required Map<int, String> answers,
  }) async {
    final int? subjectId = int.tryParse(subject.id);
    if (subjectId == null) {
      return ApiResult<QuizSubmitPayload>.failure(
        'Invalid subject selection.',
      );
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
        QuizAnswerPayload(
          questionId: item.id!,
          selectedChoice: answers[index],
        ),
      );
    }

    if (payload.isEmpty) {
      return ApiResult<QuizSubmitPayload>.failure(
        'No quiz answers to submit.',
      );
    }

    return _api.submitQuizAttempt(
      subjectId: subjectId,
      answers: payload,
    );
  }

  List<QuestionItem> buildQuiz({
    required SubjectItem subject,
    required int count,
  }) {
    final List<_QuestionBlueprint> source =
        _bank[subject.id] ?? <_QuestionBlueprint>[];
    if (source.isEmpty) {
      return <QuestionItem>[];
    }

    final int safeCount = count.clamp(1, maxQuestionPerSet);
    final Random random = Random(
      subject.id.hashCode + DateTime.now().millisecondsSinceEpoch,
    );
    final List<String> keys = <String>['A', 'B', 'C', 'D'];
    final List<QuestionItem> result = <QuestionItem>[];

    for (int index = 0; index < safeCount; index++) {
      final _QuestionBlueprint bp = source[random.nextInt(source.length)];
      final Map<String, String> choices = <String, String>{
        for (int i = 0; i < 4; i++) keys[i]: bp.options[i],
      };
      final String correctKey = keys[bp.correctIndex];
      final Map<String, String> rationales = <String, String>{
        for (int i = 0; i < 4; i++)
          keys[i]: i == bp.correctIndex
              ? 'is correct because ${bp.reason}.'
              : 'is wrong because it does not satisfy the core rule in this item.',
      };

      result.add(
        QuestionItem(
          id: null,
          subjectId: subject.id,
          question: '${bp.prompt}  Question ${index + 1}',
          choices: choices,
          correctKey: correctKey,
          rationales: rationales,
        ),
      );
    }
    return result;
  }

  void saveRecord({
    required SubjectItem subject,
    required int score,
    required int total,
  }) {
    records.insert(
      0,
      QuizRecord(
        subjectCode: subject.code,
        subjectTitle: subject.title,
        score: score,
        total: total,
        completedAt: DateTime.now(),
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

    final String value = normalized.length == 6
        ? 'FF$normalized'
        : normalized;
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
}

class _QuestionBlueprint {
  const _QuestionBlueprint({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.reason,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String reason;
}
