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
import '../../widgets/skeleton_widgets.dart';

class _CancelPlanResult {
  const _CancelPlanResult({required this.proceed, this.error});

  final bool proceed;
  final String? error;
}

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
  int? _processingPlanId;

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

  String _planDisplayTitle(PlanOption plan) {
    final String label = plan.groupLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return plan.title;
  }

  String _planDisplayDescription(PlanOption plan) {
    if (plan.description.trim().isNotEmpty) {
      return plan.description.trim();
    }
    if (plan.tier == PlanTier.free || plan.planGroup == 'free_trial') {
      return 'Limited access trial plan.';
    }
    if (plan.planGroup == 'plan_b') {
      return 'Full access including mock board exam and all concepts.';
    }
    return 'Subscription coverage is based on server plan settings.';
  }

  List<String> _planDisplayFeatures(PlanOption plan) {
    final List<String> features = plan.features
        .map((String feature) => feature.trim())
        .where((String feature) => feature.isNotEmpty)
        .toList();
    if (features.isNotEmpty) {
      return features;
    }
    return <String>[
      plan.tier == PlanTier.free
          ? 'Limited access during free trial.'
          : 'Plan coverage is managed by server settings.',
    ];
  }

  Future<void> _refreshDashboard(AppState appState) async {
    await appState.refreshCurrentUser();
    await appState.loadPlans(force: true);
    await appState.loadPracticeSubjects(force: true);
    await appState.loadDashboardMetrics(force: true);
    await appState.loadSubscriptionHistory(loadMore: false);
    await appState.loadReferrals(loadMore: false);
    await appState.loadQuizAttempts(loadMore: false);
  }

  void _showAvatarPreview(AppState appState) {
    if (appState.userAvatarUrl == null ||
        appState.userAvatarUrl!.trim().isEmpty) {
      return;
    }
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final int cacheSize = (MediaQuery.of(context).size.width * dpr).round();

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: <Widget>[
                Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        appState.userAvatarUrl!,
                        fit: BoxFit.contain,
                        cacheWidth: cacheSize,
                        cacheHeight: cacheSize,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/boardmaster.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isFreeTrialPlan(PlanOption plan) {
    return plan.planGroup == 'free_trial' ||
        plan.tier == PlanTier.free ||
        !plan.isPaid;
  }

  List<PlanOption> _sortedExplorePlans(List<PlanOption> plans) {
    final List<PlanOption> items = List<PlanOption>.from(plans);
    items.sort((PlanOption a, PlanOption b) {
      final bool aFree = _isFreeTrialPlan(a);
      final bool bFree = _isFreeTrialPlan(b);
      if (aFree != bFree) {
        return aFree ? -1 : 1;
      }
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      if (a.price != b.price) {
        return a.price.compareTo(b.price);
      }
      return a.id.compareTo(b.id);
    });
    return items;
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
      SnackBar(
        content: Text(
          error ?? 'Plan activated: ${plan.groupLabel} - ${plan.subPlanLabel}',
        ),
      ),
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
                    '${plan.subPlanLabel} - ${plan.priceLabel}',
                    style: GoogleFonts.manrope(
                      color: AppPalette.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    displayTitle,
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w700,
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
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppPalette.secondary.withValues(alpha: 0.45),
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.85),
                      ),
                      child: Text(
                        'PROCEED NOW',
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
    final String currentLabel =
        '${currentPlan.groupLabel} - ${currentPlan.subPlanLabel}';
    final String nextLabel =
        '${nextPlan.groupLabel} - ${nextPlan.subPlanLabel}';
    final String message = currentPlan.isPaid
        ? 'Your current plan ($currentLabel) will be cancelled '
              'and replaced with $nextLabel. Continue?'
        : 'You are currently on $currentLabel. '
              'Switching will replace it with $nextLabel. Continue?';

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
          SnackBar(
            content: Text(
              'Successfully chose ${plan.groupLabel} - ${plan.subPlanLabel}.',
            ),
          ),
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

  Future<_CancelPlanResult> _confirmCancelPlan({
    required BuildContext context,
    required AppState appState,
    required String? formattedEndDate,
  }) async {
    final String detail = formattedEndDate == null
        ? 'Your premium access will end immediately and you will return to the free plan.'
        : 'Your premium access is valid until $formattedEndDate, but cancelling will end it immediately and return you to the free plan.';

    final _CancelPlanResult? decision = await showDialog<_CancelPlanResult>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            bool submitting = false;
            return StatefulBuilder(
              builder: (BuildContext _, void Function(void Function()) setState) {
                return AlertDialog(
                  title: Text(
                    'Cancel Plan',
                    style: GoogleFonts.redHatDisplay(
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Do you want to proceed with cancellation?',
                        style: GoogleFonts.manrope(
                          color: AppPalette.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        style: GoogleFonts.manrope(
                          color: AppPalette.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: submitting
                          ? null
                          : () => Navigator.of(dialogContext).pop(
                                const _CancelPlanResult(proceed: false),
                              ),
                      child: Text(
                        'Keep Plan',
                        style: GoogleFonts.manrope(
                          color: AppPalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setState(() {
                                submitting = true;
                              });
                              final String? error =
                                  await appState.cancelCurrentPlan();
                              if (!dialogContext.mounted) {
                                return;
                              }
                              Navigator.of(dialogContext).pop(
                                _CancelPlanResult(
                                  proceed: true,
                                  error: error,
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.secondary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppPalette.secondary.withValues(alpha: 0.45),
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.85),
                      ),
                      child: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Cancel Plan',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );

    return decision ?? const _CancelPlanResult(proceed: false);
  }

  Future<void> _cancelPlan({
    required BuildContext context,
    required AppState appState,
    required String? formattedEndDate,
  }) async {
    if (appState.selectingPlan || appState.creatingCheckout) {
      return;
    }

    final _CancelPlanResult decision = await _confirmCancelPlan(
      context: context,
      appState: appState,
      formattedEndDate: formattedEndDate,
    );
    if (!decision.proceed) {
      return;
    }

    final String? error = decision.error;
    if (!context.mounted) {
      return;
    }

    String successMessage = 'Plan cancelled. You are now on the Free Plan.';
    if (error == null) {
      final PlanOption activePlan = appState.currentPlan;
      if (activePlan.planGroup == 'free_trial' ||
          activePlan.tier == PlanTier.free) {
        final DateTime? resumedEndDate = appState.subscriptionEndDate;
        if (resumedEndDate != null && !appState.isFreeTrialExpired) {
          final String until = DateFormat('MMM d, yyyy').format(resumedEndDate);
          successMessage = 'Free trial resumed. Valid until $until.';
        } else {
          successMessage = 'Plan cancelled. Free trial is already expired.';
        }
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? successMessage)));

    if (error == null) {
      setState(() {
        _previewPlanId = appState.currentPlan.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final PlanOption featuresPlan = _resolvePreviewPlan(appState);
    final PlanOption currentPlan = appState.currentPlan;
    final bool trialExpired = appState.isFreeTrialExpired;
    final bool isCurrentTrial = currentPlan.planGroup == 'free_trial';
    final bool currentTrialExpired = isCurrentTrial && trialExpired;
    final String subscriptionTitle = _planDisplayTitle(currentPlan);
    final String subscriptionPrice =
        '${currentPlan.priceLabel} ${currentPlan.billingLabel}';
    final DateTime? endDate = appState.subscriptionEndDate;
    final String? formattedEndDate = endDate == null
        ? null
        : () {
            final DateTime local = endDate.toLocal();
            final String formattedDate = DateFormat('MMM d, yyyy').format(local);
            final String formattedTime =
                DateFormat('h:mma').format(local).toLowerCase();
            return '$formattedDate at $formattedTime';
          }();
    final bool lockFreePlan =
        appState.currentPlan.isPaid && !appState.isSubscriptionExpired;
    final bool hasActivePaidPlan = appState.hasActivePaidPlan;
    final List<String> featureItems = _planDisplayFeatures(featuresPlan);
    final String lastScoreLabel =
        (appState.lastScore != null && appState.lastScoreTotal != null)
        ? '${appState.lastScore}/${appState.lastScoreTotal}'
        : (appState.records.isEmpty
              ? '--'
              : '${appState.records.first.score}/${appState.records.first.total}');
    final DateFormat historyFormatter = DateFormat('MMM dd, yyyy');
    final DateFormat referralFormatter = DateFormat('MMM dd, yyyy');
    const int historyPreviewLimit = 5;
    final List<SubscriptionHistoryItem> subscriptionPreview =
        appState.subscriptionHistory.take(historyPreviewLimit).toList();
    final bool hasMoreSubscriptionPreview =
        appState.subscriptionHistory.length > historyPreviewLimit ||
        appState.hasMoreSubscriptionHistory;
    final List<ReferralEntry> referralPreview =
        appState.referralEntries.take(historyPreviewLimit).toList();
    final bool hasMoreReferralPreview =
        appState.referralEntries.length > historyPreviewLimit ||
        appState.hasMoreReferrals;
    final List<PlanOption> explorePlans = _sortedExplorePlans(
      appState.isFreeTrialExpired
          ? appState.plans
              .where((PlanOption plan) => plan.planGroup != 'free_trial')
              .toList()
          : appState.plans,
    );
    final bool plansLoading = appState.loadingPlans && explorePlans.isEmpty;
    final bool busy = appState.selectingPlan || appState.creatingCheckout;

    if (!busy && _processingPlanId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _processingPlanId = null;
        });
      });
    }

    return RefreshIndicator(
      onRefresh: () => _refreshDashboard(appState),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Row(
                children: <Widget>[
                  InkWell(
                    onTap: () => _showAvatarPreview(appState),
                    borderRadius: BorderRadius.circular(999),
                    child: ClipOval(
                      child: SizedBox.square(
                        dimension: 52,
                        child:
                            appState.userAvatarUrl != null &&
                                appState.userAvatarUrl!.trim().isNotEmpty
                            ? Image.network(
                                appState.userAvatarUrl!,
                                fit: BoxFit.cover,
                                cacheWidth: (52 * dpr).round(),
                                cacheHeight: (52 * dpr).round(),
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/images/boardmaster.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/images/boardmaster.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'BoardMasters Review',
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
                    Row(
                      children: <Widget>[
                        Text(
                          'SUBSCRIPTION',
                          style: GoogleFonts.manrope(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (currentTrialExpired) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD6D6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'EXPIRED',
                              style: GoogleFonts.manrope(
                                color: const Color(0xFFB42318),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subscriptionTitle,
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
                      subscriptionPrice,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (formattedEndDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          currentTrialExpired
                              ? 'Free trial ended on $formattedEndDate'
                              : (appState.isSubscriptionExpired
                                    ? 'Expired on $formattedEndDate'
                                    : 'Expires on $formattedEndDate'),
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
                    if (currentTrialExpired)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Free trial ended. Choose a paid plan to continue.',
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
                        onPressed: (appState.isSubscriptionExpired ||
                                appState.isFreeTrialExpired)
                            ? null
                            : widget.onOpenPractice,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppPalette.primary,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.7),
                          disabledForegroundColor:
                              AppPalette.primary.withValues(alpha: 0.45),
                        ),
                        child: Text(
                          (appState.isSubscriptionExpired ||
                                  appState.isFreeTrialExpired)
                              ? 'PLAN EXPIRED'
                              : 'START THE TEST NOW',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (hasActivePaidPlan) ...<Widget>[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed:
                              appState.selectingPlan ||
                                  appState.creatingCheckout
                              ? null
                              : () => _cancelPlan(
                                  context: context,
                                  appState: context.read<AppState>(),
                                  formattedEndDate: formattedEndDate,
                                ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.75),
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.06),
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
                      trialExpired
                          ? 'Free trial already expired. Choose a paid plan to continue.'
                          : '3 days FREE trial available for Nursing Concepts (limited access).',
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
                child: plansLoading
                    ? const _ExplorePlanSkeleton()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        scrollDirection: Axis.horizontal,
                        itemCount: explorePlans.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (BuildContext context, int index) {
                          final PlanOption plan = explorePlans[index];
                          final bool selected =
                              plan.id == appState.currentPlan.id;
                          final bool previewed = _previewPlanId == plan.id;
                          final bool isFreePlan = !plan.isPaid;
                          final bool isTrialPlan =
                              plan.planGroup == 'free_trial';
                          final bool trialExpiredForPlan =
                              isTrialPlan && appState.isFreeTrialExpired;
                          final String displayTitle =
                              plan.subPlanLabel.trim().isNotEmpty
                              ? plan.subPlanLabel
                              : plan.name;
                          final String groupTitle = _planDisplayTitle(plan);
                          final String displayDescription = trialExpiredForPlan
                              ? 'Free trial expired.'
                              : _planDisplayDescription(plan);
                          final bool lockedFreePlan =
                              lockFreePlan && isFreePlan;
                          final bool lockedByActivePlan =
                              hasActivePaidPlan && !selected;
                          final bool canRenew =
                              selected &&
                              plan.isPaid &&
                              appState.isSubscriptionExpired;
                          final bool showLoading =
                              busy && _processingPlanId == plan.id;
                          final bool disabled =
                              busy ||
                              trialExpiredForPlan ||
                              (selected && !canRenew) ||
                              lockedFreePlan ||
                              lockedByActivePlan;
                          final bool selectedDisabled = selected && !canRenew;
                          final String buttonLabel = selected
                              ? (canRenew ? 'Renew Plan' : 'Selected')
                              : (lockedByActivePlan
                                    ? 'Cancel current plan first'
                                    : (lockedFreePlan
                                          ? 'Unavailable'
                                          : (trialExpiredForPlan
                                                ? 'Expired'
                                                : (plan.isPaid
                                                      ? 'PAY NOW'
                                                      : 'Choose Plan'))));

                          return GestureDetector(
                            onTap: lockedFreePlan
                                ? null
                                : () => _setPreviewPlan(plan),
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
                                              : AppPalette.primary.withValues(
                                                  alpha: 0.1,
                                                )),
                                    width: selected || previewed ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (trialExpiredForPlan)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFE3E3),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'EXPIRED',
                                          style: GoogleFonts.manrope(
                                            color: const Color(0xFFB42318),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.redHatDisplay(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppPalette.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      groupTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        color: AppPalette.muted,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
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
                                            : () async {
                                                setState(() {
                                                  _processingPlanId = plan.id;
                                                });
                                                await _handleChoosePlan(
                                                  context: context,
                                                  appState: context
                                                      .read<AppState>(),
                                                  plan: plan,
                                                );
                                              },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: selectedDisabled
                                              ? Colors.black.withValues(
                                                  alpha: 0.08,
                                                )
                                              : AppPalette.primary,
                                          foregroundColor: selectedDisabled
                                              ? AppPalette.muted
                                              : Colors.white,
                                          disabledBackgroundColor: selectedDisabled
                                              ? Colors.black.withValues(
                                                  alpha: 0.08,
                                                )
                                              : AppPalette.primary.withValues(
                                                  alpha: 0.45,
                                                ),
                                          disabledForegroundColor: selectedDisabled
                                              ? AppPalette.muted
                                              : Colors.white.withValues(
                                                  alpha: 0.85,
                                                ),
                                        ),
                                        child: showLoading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
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
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Subscription History',
                      style: GoogleFonts.redHatDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textDark,
                      ),
                    ),
                  ),
                  if (hasMoreSubscriptionPreview)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const SubscriptionHistoryScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Show all',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primary,
                          decoration: TextDecoration.underline,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                ],
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
                    if (appState.loadingSubscriptionHistory &&
                        appState.subscriptionHistory.isEmpty)
                      const _HistorySkeletonList()
                    else if (appState.subscriptionHistory.isEmpty)
                      Text(
                        'No subscription history yet.',
                        style: GoogleFonts.manrope(
                          color: AppPalette.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ...subscriptionPreview.map(
                      (SubscriptionHistoryItem item) => _SubscriptionHistoryRow(
                        item: item,
                        formatter: historyFormatter,
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
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Referral History',
                      style: GoogleFonts.redHatDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textDark,
                      ),
                    ),
                  ),
                  if (hasMoreReferralPreview)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ReferralHistoryScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Show all',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primary,
                          decoration: TextDecoration.underline,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                ],
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
                    ...referralPreview.map(
                      (ReferralEntry entry) => _ReferralHistoryRow(
                        entry: entry,
                        formatter: referralFormatter,
                      ),
                    ),
                    if (appState.loadingReferrals)
                      const _ReferralSkeletonList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

class SubscriptionHistoryScreen extends StatelessWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final DateFormat formatter = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Subscription History',
          style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            if (appState.loadingSubscriptionHistory &&
                appState.subscriptionHistory.isEmpty)
              const _HistorySkeletonList()
            else if (appState.subscriptionHistory.isEmpty)
              Text(
                'No subscription history yet.',
                style: GoogleFonts.manrope(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ...appState.subscriptionHistory.map(
              (SubscriptionHistoryItem item) => _SubscriptionHistoryRow(
                item: item,
                formatter: formatter,
              ),
            ),
            if (!appState.loadingSubscriptionHistory &&
                appState.hasMoreSubscriptionHistory)
              Center(
                child: TextButton(
                  onPressed: () {
                    appState.loadSubscriptionHistory(loadMore: true);
                  },
                  child: Text(
                    'Load more',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReferralHistoryScreen extends StatelessWidget {
  const ReferralHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final DateFormat formatter = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Referral History',
          style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
              (ReferralEntry entry) => _ReferralHistoryRow(
                entry: entry,
                formatter: formatter,
              ),
            ),
            if (appState.loadingReferrals) const _ReferralSkeletonList(),
            if (!appState.loadingReferrals && appState.hasMoreReferrals)
              Center(
                child: TextButton(
                  onPressed: () {
                    appState.loadReferrals(loadMore: true);
                  },
                  child: Text(
                    'Load more',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionHistoryRow extends StatelessWidget {
  const _SubscriptionHistoryRow({
    required this.item,
    required this.formatter,
  });

  final SubscriptionHistoryItem item;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  'Start: ${formatter.format(item.startDate)}',
                  style: GoogleFonts.manrope(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                if (item.endDate != null)
                  Text(
                    'End: ${formatter.format(item.endDate!)}',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                Text(
                  'Method: ${item.paymentMethod ?? '—'}',
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
    );
  }
}

class _ReferralHistoryRow extends StatelessWidget {
  const _ReferralHistoryRow({
    required this.entry,
    required this.formatter,
  });

  final ReferralEntry entry;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    formatter.format(entry.createdAt!),
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
    );
  }
}

class _HistorySkeletonList extends StatelessWidget {
  const _HistorySkeletonList();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: List<Widget>.generate(
          3,
          (int index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: <Widget>[
                const SkeletonBox.circle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SkeletonBox(
                        height: 12,
                        width: double.infinity,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 8),
                      const SkeletonBox(
                        height: 10,
                        width: 180,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 6),
                      const SkeletonBox(height: 8, width: 120, borderRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const SkeletonBox(height: 20, width: 60, borderRadius: 999),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferralSkeletonList extends StatelessWidget {
  const _ReferralSkeletonList();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: List<Widget>.generate(
          3,
          (int index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: <Widget>[
                const SkeletonBox.circle(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SkeletonBox(
                        height: 12,
                        width: double.infinity,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 6),
                      const SkeletonBox(
                        height: 10,
                        width: 160,
                        borderRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const SkeletonBox(height: 18, width: 54, borderRadius: 999),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplorePlanSkeleton extends StatelessWidget {
  const _ExplorePlanSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return Container(
            width: 258,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const SkeletonBox(height: 20, width: 90, borderRadius: 999),
                    const Spacer(),
                    const SkeletonBox(height: 16, width: 44, borderRadius: 999),
                  ],
                ),
                const SizedBox(height: 12),
                const SkeletonBox(height: 18, width: 140, borderRadius: 10),
                const SizedBox(height: 8),
                const SkeletonBox(
                  height: 10,
                  width: double.infinity,
                  borderRadius: 8,
                ),
                const SizedBox(height: 6),
                const SkeletonBox(height: 10, width: 160, borderRadius: 8),
                const SizedBox(height: 12),
                const SkeletonBox(height: 16, width: 90, borderRadius: 8),
                const Spacer(),
                const SkeletonBox(
                  height: 36,
                  width: double.infinity,
                  borderRadius: 12,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
