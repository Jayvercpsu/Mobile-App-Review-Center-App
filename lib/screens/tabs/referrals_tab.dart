import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../state/app_state.dart';

class ReferralsTab extends StatefulWidget {
  const ReferralsTab({super.key});

  @override
  State<ReferralsTab> createState() => _ReferralsTabState();
}

class _ReferralsTabState extends State<ReferralsTab> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppState>().loadReferrals(loadMore: false);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _redeemOffer(
    AppState appState,
    ReferralOfferItem offer,
  ) async {
    final String? error = await appState.redeemReferralOffer(offer);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Offer redeemed. You can now access new questions!',
        ),
      ),
    );
  }

  Future<void> _applyReferral(AppState appState) async {
    final String code = _codeController.text.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid referral code.')),
      );
      return;
    }

    final String? error = await appState.applyReferralCode(code);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _codeController.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Referral applied successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final ReferralPoints points = appState.referralPoints ??
        const ReferralPoints(
          earned: 0,
          spent: 0,
          available: 0,
          perReferral: 0,
        );
    final List<ReferralOfferItem> offers = appState.referralOffers;
    final String query = _searchQuery.trim().toLowerCase();
    final List<ReferralOfferItem> filteredOffers = query.isEmpty
        ? offers
        : offers.where((ReferralOfferItem offer) {
            final String haystack = [
              offer.title,
              offer.brand ?? '',
              offer.category ?? '',
              offer.subject ?? '',
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();
    final List<ReferralOfferItem> featured = filteredOffers
        .where((offer) => offer.isFeatured)
        .toList();
    final List<ReferralOfferItem> recommended =
        featured.isNotEmpty ? featured : filteredOffers.take(4).toList();

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Referral Points',
                  style: GoogleFonts.redHatDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Invite friends and unlock extra review access.',
                  style: GoogleFonts.manrope(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppPalette.primary,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppPalette.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Available Points',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${points.available}',
                        style: GoogleFonts.redHatDisplay(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Earn ${points.perReferral} points per successful referral.',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                appState.referralCode ?? '---',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: appState.referralCode == null
                                ? null
                                : () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: appState.referralCode!,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Referral code copied.'),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.copy_rounded),
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (appState.referredBy == null)
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: 'Enter a friend\'s referral code',
                      prefixIcon: const Icon(Icons.card_giftcard_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => _applyReferral(appState),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppPalette.primary.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.verified_rounded,
                          color: AppPalette.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Referral already applied.',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                              color: AppPalette.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search brand, reward, category, etc.',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Recommended',
                  style: GoogleFonts.redHatDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final ReferralOfferItem offer = recommended[index];
                final bool canRedeem = points.available >= offer.pointsCost;
                return _OfferCard(
                  offer: offer,
                  canRedeem: canRedeem,
                  onRedeem: () => _redeemOffer(appState, offer),
                );
              },
              childCount: recommended.length,
            ),
          ),
        ),
        if (appState.referralCategories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Categories',
                    style: GoogleFonts.redHatDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: appState.referralCategories
                        .map(
                          (category) => Chip(
                            label: Text(
                              category,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor:
                                AppPalette.primary.withValues(alpha: 0.1),
                            labelStyle: TextStyle(color: AppPalette.primary),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        if (appState.referralBrands.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Brands',
                    style: GoogleFonts.redHatDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: appState.referralBrands
                        .map(
                          (brand) => Chip(
                            label: Text(
                              brand,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        if (appState.activeRewards.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Active Rewards',
                    style: GoogleFonts.redHatDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...appState.activeRewards.map(
                    (reward) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                          const Icon(Icons.check_circle, color: AppPalette.success),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Subject access unlocked (limit ${reward.questionLimit ?? 'No limit'})',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                                color: AppPalette.textDark,
                              ),
                            ),
                          ),
                          if (reward.expiresAt != null)
                            Text(
                              '${reward.expiresAt!.month}/${reward.expiresAt!.day}/${reward.expiresAt!.year}',
                              style: GoogleFonts.manrope(
                                color: AppPalette.muted,
                                fontSize: 12,
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
        SliverToBoxAdapter(
          child: const SizedBox(height: 20),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.canRedeem,
    required this.onRedeem,
  });

  final ReferralOfferItem offer;
  final bool canRedeem;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: offer.imageUrl == null || offer.imageUrl!.isEmpty
                  ? const Icon(
                      Icons.school_rounded,
                      color: AppPalette.primary,
                      size: 30,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        offer.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            offer.brand ?? 'Board Masters',
            style: GoogleFonts.manrope(
              color: AppPalette.muted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          Text(
            offer.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: AppPalette.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${offer.pointsCost} Points',
            style: GoogleFonts.manrope(
              color: AppPalette.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canRedeem ? onRedeem : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
              ),
              child: Text(
                canRedeem ? 'Redeem' : 'Not enough',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
