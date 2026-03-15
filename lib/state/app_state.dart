import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/mobile_api_service.dart';

class AppState extends ChangeNotifier {
  AppState() {
    unawaited(loadPlans());
  }

  bool onboardingDone = false;
  bool signedIn = false;
  String userName = 'Future Topnotcher';
  String userEmail = '';
  PlanTier selectedTier = PlanTier.free;
  int? selectedPlanId;
  String? subscriptionBillingCycle;
  DateTime? subscriptionEndDate;
  bool selectingPlan = false;
  final MobileApiService _api = MobileApiService();
  bool _plansLoaded = false;

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

  List<PlanOption> _plans = List<PlanOption>.from(_fallbackPlans);

  List<PlanOption> get plans => List<PlanOption>.unmodifiable(_plans);

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
    selectedPlanId = data.planId;
    if (data.tier != null) {
      selectedTier = data.tier!;
    }
    subscriptionBillingCycle = data.billingCycle;
    subscriptionEndDate = data.endDate;
    signedIn = true;
    notifyListeners();

    await loadPlans(force: true);
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
    selectedPlanId = data.planId;
    if (data.tier != null) {
      selectedTier = data.tier!;
    }
    subscriptionBillingCycle = data.billingCycle;
    subscriptionEndDate = data.endDate;
    signedIn = true;
    notifyListeners();

    await loadPlans(force: true);
    return null;
  }

  void logout() {
    signedIn = false;
    selectedPlanId = null;
    subscriptionBillingCycle = null;
    subscriptionEndDate = null;
    _api.setAuthToken(null);
    notifyListeners();
  }

  int get referralJoinedCount => 28;

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

  List<SubjectItem> get visibleSubjects =>
      hasPremiumAccess ? allSubjects : allSubjects.take(3).toList();

  int get maxQuestionPerSet => hasPremiumAccess ? 100 : 30;

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
    notifyListeners();
    return null;
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
    notifyListeners();
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
