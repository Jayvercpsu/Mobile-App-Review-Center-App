import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../login_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final DateFormat formatter = DateFormat('MMM dd, yyyy hh:mm a');

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              'Profile',
              style: GoogleFonts.redHatDisplay(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppPalette.primary,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppPalette.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: <Widget>[
                  ClipOval(
                    child: Image.asset(
                      'assets/images/boardmaster-square.png',
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          appState.userName,
                          style: GoogleFonts.redHatDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.primary,
                          ),
                        ),
                        Text(
                          appState.userEmail.isEmpty
                              ? 'boardmaster@app.local'
                              : appState.userEmail,
                          style: GoogleFonts.manrope(
                            color: AppPalette.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppPalette.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Plan: ${appState.currentPlan.title}',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Billing: ${(appState.subscriptionBillingCycle ?? appState.currentPlan.billingCycle).toUpperCase()}',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    appState.subscriptionEndDate == null
                        ? 'No end date'
                        : 'Valid until ${DateFormat('MMM dd, yyyy').format(appState.subscriptionEndDate!)}',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (appState.isSubscriptionExpired)
                    Text(
                      'Subscription expired. Renew in Home > Choose Plan.',
                      style: GoogleFonts.manrope(
                        color: AppPalette.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage plan from Home tab.',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'Recent Attempts',
              style: GoogleFonts.redHatDisplay(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: AppPalette.primary,
              ),
            ),
          ),
        ),
        if (appState.records.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'No attempts yet. Start a practice set to see your results.',
                  style: GoogleFonts.manrope(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: appState.records.length,
          itemBuilder: (BuildContext context, int index) {
            final QuizRecord item = appState.records[index];
            final int percent = item.total == 0
                ? 0
                : ((item.score / item.total) * 100).round();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.primary.withValues(alpha: 0.12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.subjectCode,
                        style: GoogleFonts.manrope(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${item.score}/${item.total}  $percent%',
                            style: GoogleFonts.redHatDisplay(
                              color: AppPalette.textDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            item.subjectTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: AppPalette.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            formatter.format(item.completedAt),
                            style: GoogleFonts.manrope(
                              color: AppPalette.muted,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () async {
                  final bool? shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: Text(
                          'Logout',
                          style: GoogleFonts.redHatDisplay(
                            fontWeight: FontWeight.w800,
                            color: AppPalette.primary,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to logout from your account?',
                          style: GoogleFonts.manrope(
                            color: AppPalette.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.manrope(
                                color: AppPalette.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.secondary,
                            ),
                            child: Text(
                              'Logout',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (shouldLogout != true || !context.mounted) {
                    return;
                  }
                  context.read<AppState>().logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppPalette.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Logout',
                  style: GoogleFonts.manrope(
                    color: AppPalette.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
