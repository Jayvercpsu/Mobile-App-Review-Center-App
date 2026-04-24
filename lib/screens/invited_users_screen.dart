import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';

class InvitedUsersScreen extends StatefulWidget {
  const InvitedUsersScreen({super.key});

  @override
  State<InvitedUsersScreen> createState() => _InvitedUsersScreenState();
}

class _InvitedUsersScreenState extends State<InvitedUsersScreen> {
  bool _loadingPage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadInitial();
    });
  }

  Future<void> _loadInitial() async {
    if (_loadingPage) {
      return;
    }
    setState(() {
      _loadingPage = true;
    });
    final AppState appState = context.read<AppState>();
    final String? error = await appState.loadReferrals(
      loadMore: false,
      perPage: 100,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingPage = false;
    });
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingPage) {
      return;
    }
    setState(() {
      _loadingPage = true;
    });
    final AppState appState = context.read<AppState>();
    final String? error = await appState.loadReferrals(loadMore: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingPage = false;
    });
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final DateFormat formatter = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Invited Users',
          style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInitial,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              if (_loadingPage && appState.referralEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppPalette.primary),
                  ),
                ),
              if (!_loadingPage && appState.referralEntries.isEmpty)
                Text(
                  'No invited users yet.',
                  style: GoogleFonts.manrope(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ...appState.referralEntries.map(
                (ReferralEntry entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppPalette.success,
                        ),
                        const SizedBox(width: 10),
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
                ),
              ),
              if (!_loadingPage && appState.hasMoreReferrals)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loadMore,
                      child: Text(
                        'Show more',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primary,
                          decoration: TextDecoration.underline,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_loadingPage && appState.referralEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: CircularProgressIndicator(color: AppPalette.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
