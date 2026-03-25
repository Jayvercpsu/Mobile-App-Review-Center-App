import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/url_helper.dart';
import '../../models/app_models.dart';
import '../../screens/payment_webview.dart';
import '../../state/app_state.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.onOpenPractice,
    this.initialPlanId,
  });

  final VoidCallback onOpenPractice;
  final int? initialPlanId;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  int? _previewPlanId;
  static const List<String> _planAConcepts = <String>[
    'Anatomy and Physiology',
    'Theoretical Foundation in Nursing & Health Ethics (Bioethics)',
    'Health Assessment',
    'Fundamentals of Nursing Practice, Nursing Informatics, Nutrition & Diet Therapy',
    'Microbiology & Parasitology',
    'Pharmacology and Nursing Therapeutics',
    'Care of Maternal & Child (Well Clients)',
    'Care of Maternal & Child (At-risk or with Problems: Acute & Chronic)',
    'Nursing Research',
    'Medical Surgical Nursing 101',
    'Medical Surgical Nursing 102',
    'Medical Surgical Nursing 103',
    'Geriatric Nursing',
    'Mental Health Disorders / Psychiatric Nursing',
    'Community Health Nursing',
    'Nursing Leadership and Management',
  ];
  static const List<String> _planBCoverage = <String>[
    'Mock Board Exam (All Access)',
    'Nursing Practice I - Community Health Nursing',
    'Nursing Practice II - Care of Healthy / At Risk Mother and Child',
    'Nursing Practice III - Physiologic & Psychosocial Alterations (Part A)',
    'Nursing Practice IV - Physiologic & Psychosocial Alterations (Part B)',
    'Nursing Practice V - Physiologic & Psychosocial Alterations (Part C)',
    'Includes all Plan A Nursing Concepts',
  ];
  static const List<String> _freeTrialCoverage = <String>[
    '3 days FREE trial (Limited Access: Nursing Concepts only)',
    'Upgrade anytime for full subject access and Mock Board Exam sets',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPlanId != null) {
      _previewPlanId = widget.initialPlanId;
    }
  }

  PlanOption _resolvePreviewPlan(AppState appState) {
    if (_previewPlanId == null) {
      return appState.currentPlan;
    }
    for (final PlanOption plan in appState.plans) {
      if (plan.id == _previewPlanId) {
        return plan;
      }
    }
    return appState.currentPlan;
  }

  void _setPreviewPlan(PlanOption plan) {
    if (_previewPlanId == plan.id) {
      return;
    }
    setState(() {
      _previewPlanId = plan.id;
    });
  }

  bool _isPlanB(PlanOption plan) {
    final String normalized =
        '${plan.name} ${plan.title} ${plan.description}'.toLowerCase();
    return normalized.contains('plan b') ||
        normalized.contains('mock board') ||
        normalized.contains('full access') ||
        plan.price >= 1000;
  }

  String _planDisplayTitle(PlanOption plan) {
    if (!plan.isPaid || plan.tier == PlanTier.free) {
      return 'FREE TRIAL (3 DAYS)';
    }
    if (_isPlanB(plan)) {
      return 'PLAN B: MOCK BOARD EXAM + ALL NURSING CONCEPTS';
    }
    return 'PLAN A: ALL NURSING CONCEPTS';
  }

  String _planDisplayDescription(PlanOption plan) {
    if (!plan.isPaid || plan.tier == PlanTier.free) {
      return 'A. Free Trial (Limited Access)';
    }
    if (_isPlanB(plan)) {
      return 'C. FULL ACCESS including All Concepts / All Subjects and Mock Board Exam';
    }
    return 'B. All Concepts / All Subjects Only';
  }

  List<String> _planDisplayFeatures(PlanOption plan) {
    if (!plan.isPaid || plan.tier == PlanTier.free) {
      return _freeTrialCoverage;
    }
    if (_isPlanB(plan)) {
      return _planBCoverage;
    }
    return _planAConcepts;
  }

  Future<void> _choosePlan({
    required BuildContext context,
    required AppState appState,
    required PlanOption plan,
    String? billingCycle,
  }) async {
    final String? error = await appState.choosePlan(
      plan: plan,
      billingCycle: billingCycle,
    );
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Plan activated: ${plan.title}')),
    );

    if (error == null) {
      setState(() {
        _previewPlanId = plan.id;
      });
    }
  }

  Future<void> _handleChoosePlan({
    required BuildContext context,
    required AppState appState,
    required PlanOption plan,
  }) async {
    if (appState.selectingPlan || appState.creatingCheckout) {
      return;
    }

    if (plan.id != appState.currentPlan.id) {
      final bool confirmed = await _confirmPlanChange(
        context: context,
        currentPlan: appState.currentPlan,
        nextPlan: plan,
      );
      if (!context.mounted) {
        return;
      }
      if (!confirmed) {
        return;
      }
    }

    if (!plan.isPaid) {
      await _choosePlan(context: context, appState: appState, plan: plan);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext modalContext) {
        final double bottomPadding = MediaQuery.of(
          modalContext,
        ).viewPadding.bottom;
        final String displayTitle = _planDisplayTitle(plan);

        Future<void> openCheckoutForMethod(List<String>? methods) async {
          Navigator.of(modalContext).pop();
          await _openPaidCheckout(
            context: context,
            appState: appState,
            plan: plan,
            billingCycle: plan.billingCycle,
            paymentMethodTypes: methods,
          );
        }

        Widget paymentLogoTile({
          required String assetPath,
          required String label,
          required List<String> methods,
        }) {
          return Expanded(
            child: InkWell(
              onTap: () async {
                await openCheckoutForMethod(methods);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 112,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.payments_rounded,
                          size: 38,
                          color: AppPalette.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        color: AppPalette.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 18 + bottomPadding),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'PAYMENT OPTIONS',
                    style: GoogleFonts.redHatDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Philippine Nurses Licensure Exam (PNLE) Review',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$displayTitle - ${plan.priceLabel}',
                    style: GoogleFonts.manrope(
                      color: AppPalette.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Billing: ${plan.billingLabel}',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      paymentLogoTile(
                        assetPath: 'assets/images/gcash.png',
                        label: 'GCASH',
                        methods: const <String>['gcash'],
                      ),
                      const SizedBox(width: 10),
                      paymentLogoTile(
                        assetPath: 'assets/images/maya.jpg',
                        label: 'MAYA',
                        methods: const <String>['paymaya'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await openCheckoutForMethod(const <String>['card']);
                          },
                          child: Text(
                            'DEBIT CARD',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await openCheckoutForMethod(const <String>['card']);
                          },
                          child: Text(
                            'CREDIT CARD',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        await openCheckoutForMethod(null);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.secondary,
                      ),
                      child: Text(
                        'PAY NOW',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmPlanChange({
    required BuildContext context,
    required PlanOption currentPlan,
    required PlanOption nextPlan,
  }) async {
    final String message = currentPlan.isPaid
        ? 'Your current plan (${currentPlan.title}) will be cancelled '
              'and replaced with ${nextPlan.title}. Continue?'
        : 'You are currently on ${currentPlan.title}. '
              'Switching will replace it with ${nextPlan.title}. Continue?';

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(
                'Switch Plan?',
                style: GoogleFonts.redHatDisplay(
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                ),
              ),
              content: Text(
                message,
                style: GoogleFonts.manrope(
                  color: AppPalette.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Keep Current',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.secondary,
                  ),
                  child: Text(
                    'Switch Plan',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _openPaidCheckout({
    required BuildContext context,
    required AppState appState,
    required PlanOption plan,
    required String billingCycle,
    List<String>? paymentMethodTypes,
  }) async {
    final checkoutResponse = await appState.createCheckout(
      plan: plan,
      billingCycle: billingCycle,
      paymentMethodTypes: paymentMethodTypes,
    );

    if (!context.mounted) {
      return;
    }

    if (!checkoutResponse.ok || checkoutResponse.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            checkoutResponse.message ?? 'Unable to create payment checkout.',
          ),
        ),
      );
      return;
    }

    final Uri? checkoutUri = Uri.tryParse(checkoutResponse.data!.checkoutUrl);
    if (checkoutUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout URL from server is invalid.')),
      );
      return;
    }

    if (kIsWeb) {
      final bool opened = await openExternalUrl(checkoutUri);

      if (!context.mounted) {
        return;
      }

      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open payment checkout URL.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Payment page opened. Finish payment, then refresh plan status.',
          ),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Refresh Plan',
            onPressed: () {
              _refreshPlanStatus(context: context, appState: appState);
            },
          ),
        ),
      );
      return;
    }

    final PaymentResult? result = await Navigator.of(context)
        .push<PaymentResult>(
          MaterialPageRoute<PaymentResult>(
            builder: (_) => PaymentWebView(initialUrl: checkoutUri.toString()),
          ),
        );

    if (!context.mounted) {
      return;
    }

    if (result == PaymentResult.success) {
      final String? refreshError = await appState.refreshCurrentUser();
      if (!context.mounted) {
        return;
      }
      if (refreshError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully chose ${plan.name}.')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(refreshError)));
      }
      return;
    }

    if (result == PaymentResult.cancel) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment cancelled.')));
    }
  }

  Future<void> _refreshPlanStatus({
    required BuildContext context,
    required AppState appState,
  }) async {
    final String? error = await appState.refreshCurrentUser();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Plan status refreshed.')));

    if (error == null) {
      setState(() {
        _previewPlanId = appState.currentPlan.id;
      });
    }
  }

  Future<bool> _confirmCancelPlan({
    required BuildContext context,
    required String? formattedEndDate,
  }) async {
    final String message = formattedEndDate == null
        ? 'Your premium access will end immediately and you will return to the free plan.'
        : 'Your premium access is valid until $formattedEndDate, '
            'but cancelling will end it immediately and return you to the free plan.';

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(
                'Cancel Plan?',
                style: GoogleFonts.redHatDisplay(
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                ),
              ),
              content: Text(
                message,
                style: GoogleFonts.manrope(
                  color: AppPalette.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Keep Plan',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.secondary,
                  ),
                  child: Text(
                    'Cancel Plan',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _cancelPlan({
    required BuildContext context,
    required AppState appState,
    required String? formattedEndDate,
  }) async {
    if (appState.selectingPlan || appState.creatingCheckout) {
      return;
    }

    final bool confirmed = await _confirmCancelPlan(
      context: context,
      formattedEndDate: formattedEndDate,
    );
    if (!confirmed) {
      return;
    }

    final String? error = await appState.cancelCurrentPlan();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Plan cancelled. You are now on the Free Plan.'),
      ),
    );

    if (error == null) {
      setState(() {
        _previewPlanId = appState.currentPlan.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final PlanOption featuresPlan = _resolvePreviewPlan(appState);
    final DateTime? endDate = appState.subscriptionEndDate;
    final String? formattedEndDate = endDate == null
        ? null
        : DateFormat('MMM d, yyyy').format(endDate);
    final bool lockFreePlan =
        appState.currentPlan.isPaid && !appState.isSubscriptionExpired;
    final bool hasActivePaidPlan = appState.hasActivePaidPlan;
    final List<String> featureItems = _planDisplayFeatures(featuresPlan);
    final String lastScoreLabel = (appState.lastScore != null &&
            appState.lastScoreTotal != null)
        ? '${appState.lastScore}/${appState.lastScoreTotal}'
        : (appState.records.isEmpty
              ? '--'
              : '${appState.records.first.score}/${appState.records.first.total}');
    final DateFormat historyFormatter = DateFormat('MMM dd, yyyy');
    final DateFormat referralFormatter = DateFormat('MMM dd, yyyy');

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: <Widget>[
                ClipOval(
                  child: appState.userAvatarUrl != null &&
                          appState.userAvatarUrl!.trim().isNotEmpty
                      ? Image.network(
                          appState.userAvatarUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/boardmaster.png',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/boardmaster.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Board Master Review',
                        style: GoogleFonts.redHatDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primary,
                        ),
                      ),
                      Text(
                        'Philippine Nurses Licensure Exam (PNLE) Review',
                        style: GoogleFonts.manrope(
                          color: AppPalette.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 450.ms).slideX(begin: -0.05, end: 0),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF243362), Color(0xFF39559E)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'SUBSCRIPTION',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _planDisplayTitle(appState.currentPlan),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.redHatDisplay(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${appState.currentPlan.priceLabel} ${appState.currentPlan.billingLabel}',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (formattedEndDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        appState.isSubscriptionExpired
                            ? 'Expired on $formattedEndDate'
                            : 'Expires on $formattedEndDate',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (appState.isSubscriptionExpired)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Subscription expired. Renew to unlock premium access.',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: widget.onOpenPractice,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppPalette.primary,
                      ),
                      child: Text(
                        'click to START THE TEST NOW',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (hasActivePaidPlan) ...<Widget>[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: appState.selectingPlan ||
                                appState.creatingCheckout
                            ? null
                            : () => _cancelPlan(
                                  context: context,
                                  appState: context.read<AppState>(),
                                  formattedEndDate: formattedEndDate,
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.cancel_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Cancel Plan',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!hasActivePaidPlan) ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Explore your OPTIONS.',
                    style: GoogleFonts.redHatDisplay(
                      color: AppPalette.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '3 days FREE trial available for Nursing Concepts (limited access).',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 248,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                scrollDirection: Axis.horizontal,
                itemCount: appState.plans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  final PlanOption plan = appState.plans[index];
                  final bool selected = plan.id == appState.currentPlan.id;
                  final bool previewed = _previewPlanId == plan.id;
                  final bool isFreePlan = !plan.isPaid;
                  final String displayTitle = _planDisplayTitle(plan);
                  final String displayDescription = _planDisplayDescription(plan);
                  final bool lockedFreePlan = lockFreePlan && isFreePlan;
                  final bool lockedByActivePlan =
                      hasActivePaidPlan && !selected;
                  final bool canRenew =
                      selected && plan.isPaid && appState.isSubscriptionExpired;
                  final bool busy =
                      appState.selectingPlan || appState.creatingCheckout;
                  final bool disabled =
                      busy ||
                      (selected && !canRenew) ||
                      lockedFreePlan ||
                      lockedByActivePlan;
                  final String buttonLabel = selected
                      ? (canRenew ? 'Renew Plan' : 'Selected')
                      : (lockedByActivePlan
                          ? 'Cancel current plan first'
                          : (lockedFreePlan
                                ? 'Unavailable'
                                : (plan.isPaid
                                      ? 'PAY NOW'
                                      : 'Choose Plan')));

                return GestureDetector(
                  onTap: lockedFreePlan ? null : () => _setPreviewPlan(plan),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: selected ? 1.02 : 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: 258,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                      border: Border.all(
                        color: selected
                            ? AppPalette.success
                            : (previewed
                                ? AppPalette.secondary
                                : AppPalette.primary.withValues(alpha: 0.1)),
                        width: selected || previewed ? 2 : 1,
                      ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                        Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.redHatDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                              color: AppPalette.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.priceLabel,
                            style: GoogleFonts.redHatDisplay(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.secondary,
                            ),
                          ),
                          Text(
                            plan.billingLabel,
                            style: GoogleFonts.manrope(
                              color: AppPalette.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayDescription,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: AppPalette.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 42,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: disabled
                                  ? null
                                  : () => _handleChoosePlan(
                                        context: context,
                                        appState: context.read<AppState>(),
                                        plan: plan,
                                      ),
                              style: FilledButton.styleFrom(
                                backgroundColor: selected && !canRenew
                                    ? AppPalette.success
                                    : AppPalette.primary,
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      buttonLabel,
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child:
                Container(
                      key: ValueKey<int>(featuresPlan.id),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppPalette.primary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Subscription Coverage',
                            style: GoogleFonts.redHatDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...featureItems.map(
                            (String feature) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppPalette.success.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: AppPalette.success,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: GoogleFonts.manrope(
                                        color: AppPalette.textDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate(key: ValueKey<int>(featuresPlan.id))
                    .fadeIn(duration: 280.ms)
                    .slideX(begin: 0.12, end: 0, duration: 280.ms),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    title: 'Referral Joins',
                    value: '${appState.referralJoinedCount}',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFFEEF3FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    title: 'Last Score',
                    value: lastScoreLabel,
                    icon: Icons.emoji_events_rounded,
                    color: const Color(0xFFFFF2F3),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Subscription History',
              style: GoogleFonts.redHatDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.textDark,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppPalette.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (appState.subscriptionHistory.isEmpty)
                    Text(
                      'No subscription history yet.',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ...appState.subscriptionHistory.map(
                    (SubscriptionHistoryItem item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.planName,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'PHP ${item.price.toStringAsFixed(0)} • ${item.billingCycle.toUpperCase()}',
                                  style: GoogleFonts.manrope(
                                    color: AppPalette.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Start: ${historyFormatter.format(item.startDate)}',
                                  style: GoogleFonts.manrope(
                                    color: AppPalette.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                if (item.endDate != null)
                                  Text(
                                    'End: ${historyFormatter.format(item.endDate!)}',
                                    style: GoogleFonts.manrope(
                                      color: AppPalette.muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                Text(
                                  'Status: ${item.status}',
                                  style: GoogleFonts.manrope(
                                    color: AppPalette.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (appState.loadingSubscriptionHistory)
                    const Center(child: CircularProgressIndicator()),
                  if (!appState.loadingSubscriptionHistory &&
                      appState.hasMoreSubscriptionHistory)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          appState.loadSubscriptionHistory(loadMore: true);
                        },
                        child: Text(
                          'Show more',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Referral History',
              style: GoogleFonts.redHatDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.textDark,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppPalette.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (appState.referralEntries.isEmpty)
                    Text(
                      'No referral history yet.',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ...appState.referralEntries.map(
                    (ReferralEntry entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.verified_rounded,
                            color: AppPalette.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.invitedName,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  entry.invitedEmail,
                                  style: GoogleFonts.manrope(
                                    color: AppPalette.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                if (entry.createdAt != null)
                                  Text(
                                    referralFormatter.format(entry.createdAt!),
                                    style: GoogleFonts.manrope(
                                      color: AppPalette.muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (appState.loadingReferrals)
                    const Center(child: CircularProgressIndicator()),
                  if (!appState.loadingReferrals && appState.hasMoreReferrals)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          appState.loadReferrals(loadMore: true);
                        },
                        child: Text(
                          'Show more',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppPalette.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.redHatDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppPalette.primary,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.manrope(
              color: AppPalette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
