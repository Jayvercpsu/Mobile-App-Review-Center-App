import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../state/app_state.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.onOpenPractice});

  final VoidCallback onOpenPractice;

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
  }

  Future<void> _handleChoosePlan({
    required BuildContext context,
    required AppState appState,
    required PlanOption plan,
  }) async {
    if (appState.selectingPlan) {
      return;
    }

    if (!plan.isPaid) {
      await _choosePlan(context: context, appState: appState, plan: plan);
      return;
    }

    String selectedCycle = plan.billingCycle;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext sheetContext, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Complete Payment',
                    style: GoogleFonts.redHatDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${plan.title} • ${plan.priceLabel}',
                    style: GoogleFonts.manrope(
                      color: AppPalette.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('Monthly'),
                        selected: selectedCycle == 'monthly',
                        onSelected: (_) {
                          setModalState(() {
                            selectedCycle = 'monthly';
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Yearly'),
                        selected: selectedCycle == 'yearly',
                        onSelected: (_) {
                          setModalState(() {
                            selectedCycle = 'yearly';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(modalContext).pop();
                        await _choosePlan(
                          context: context,
                          appState: appState,
                          plan: plan,
                          billingCycle: selectedCycle,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.secondary,
                      ),
                      child: Text(
                        'Pay and Activate',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: <Widget>[
                ClipOval(
                  child: Image.asset(
                    'assets/images/boardmaster-square.png',
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
                        'Hi ${appState.userName}!',
                        style: GoogleFonts.redHatDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primary,
                        ),
                      ),
                      Text(
                        'Review smarter and boost your board confidence.',
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
                    'Current Plan',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appState.currentPlan.title,
                    style: GoogleFonts.redHatDisplay(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
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
                      onPressed: onOpenPractice,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppPalette.primary,
                      ),
                      child: Text(
                        'Start Practice',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Choose Plan',
              style: GoogleFonts.redHatDisplay(
                color: AppPalette.textDark,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 236,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              scrollDirection: Axis.horizontal,
              itemCount: appState.plans.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                final PlanOption plan = appState.plans[index];
                final bool selected = plan.id == appState.currentPlan.id;
                return GestureDetector(
                  onTap: () => _handleChoosePlan(
                    context: context,
                    appState: context.read<AppState>(),
                    plan: plan,
                  ),
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
                              ? AppPalette.secondary
                              : AppPalette.primary.withValues(alpha: 0.1),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            plan.title,
                            style: GoogleFonts.redHatDisplay(
                              fontSize: 22,
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
                            plan.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: AppPalette.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 42,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: appState.selectingPlan
                                  ? null
                                  : () => _handleChoosePlan(
                                      context: context,
                                      appState: context.read<AppState>(),
                                      plan: plan,
                                    ),
                              style: FilledButton.styleFrom(
                                backgroundColor: selected
                                    ? AppPalette.success
                                    : AppPalette.primary,
                              ),
                              child: appState.selectingPlan
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      selected
                                          ? 'Selected'
                                          : (plan.isPaid
                                                ? 'Pay and Choose'
                                                : 'Choose Plan'),
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Container(
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
                    'Included Features',
                    style: GoogleFonts.redHatDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...appState.currentPlan.features.map(
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
                              color: AppPalette.success.withValues(alpha: 0.12),
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
            ),
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
                    value: appState.records.isEmpty
                        ? '--'
                        : '${appState.records.first.score}/${appState.records.first.total}',
                    icon: Icons.emoji_events_rounded,
                    color: const Color(0xFFFFF2F3),
                  ),
                ),
              ],
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
