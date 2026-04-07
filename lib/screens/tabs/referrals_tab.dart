import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../../widgets/skeleton_widgets.dart';

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

  Future<void> _redeemOffer(AppState appState, ReferralOfferItem offer) async {
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

  String _formatExpiryStatus(DateTime value) {
    final Duration diff = value.difference(DateTime.now());
    if (diff.inSeconds <= 0) {
      return 'Expires today';
    }
    final int days = (diff.inHours / 24).ceil();
    if (days <= 1) {
      return 'Expires in 1 day';
    }
    return 'Expires in $days days';
  }

  void _showOfferDetails(
    BuildContext context,
    AppState appState,
    ReferralOfferItem offer,
    ReferralPoints points,
    ReferralRewardItem? activeReward,
  ) {
    final bool alreadyRedeemed = activeReward != null;
    final bool canRedeem = points.available >= offer.pointsCost;
    final String? expiryText = activeReward?.expiresAt == null
        ? null
        : _formatExpiryStatus(activeReward!.expiresAt!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final double safeBottom = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + bottomInset + safeBottom + 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                offer.title,
                style: GoogleFonts.redHatDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textDark,
                ),
              ),
              const SizedBox(height: 6),
              if (offer.description != null && offer.description!.isNotEmpty)
                Text(
                  offer.description!,
                  style: GoogleFonts.manrope(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  _InfoChip(
                    label: _formatUnit(offer.pointsCost, 'Point'),
                    icon: Icons.card_giftcard_rounded,
                  ),
                  if (offer.durationDays != null &&
                      offer.durationDays! > 0) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                      label: _formatAccessDays(offer.durationDays!),
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (offer.subject != null && offer.subject!.isNotEmpty)
                Text(
                  'Subject: ${offer.subject}',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textDark,
                  ),
                ),
              if (offer.questionLimit != null && offer.questionLimit! > 0)
                Text(
                  'Question limit: ${offer.questionLimit}',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textDark,
                  ),
                ),
              if (expiryText != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Redeemed - $expiryText',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: AppPalette.muted,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (!alreadyRedeemed && canRedeem)
                      ? () async {
                          Navigator.of(context).pop();
                          await _redeemOffer(appState, offer);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                  ),
                  child: Text(
                    alreadyRedeemed
                        ? 'Redeemed'
                        : canRedeem
                        ? 'Redeem'
                        : 'Not enough points',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      await appState.refreshCurrentUser();
      await appState.loadReferrals(loadMore: false);
      if (!mounted) {
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Referral applied successfully.')),
    );
  }

  Future<void> _refreshReferrals(AppState appState) async {
    _codeController.clear();
    _searchController.clear();
    if (mounted) {
      setState(() {
        _searchQuery = '';
      });
    }
    FocusScope.of(context).unfocus();
    await appState.refreshCurrentUser();
    await appState.loadReferrals(loadMore: false);
    await appState.loadDashboardMetrics(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final ReferralPoints points =
        appState.referralPoints ??
        const ReferralPoints(earned: 0, spent: 0, available: 0, perReferral: 0);
    final List<ReferralOfferItem> offers = appState.referralOffers;
    final Map<int, ReferralRewardItem> activeByOffer = {
      for (final reward in appState.activeRewards) reward.offerId: reward,
    };
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
    final List<ReferralOfferItem> recommended = featured.isNotEmpty
        ? featured
        : filteredOffers.take(4).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshReferrals(appState),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Offer Points',
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
                          'Earn ${_formatUnit(points.perReferral, 'point')} per successful referral.',
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Referral code copied.',
                                          ),
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
                        suffixIcon: TextButton(
                          onPressed: () => _applyReferral(appState),
                          child: Text(
                            'Apply',
                            style: GoogleFonts.manrope(
                              color: AppPalette.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
          if (appState.loadingReferrals && recommended.isEmpty)
            const SliverToBoxAdapter(child: _OffersSkeletonGrid())
          else if (recommended.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppPalette.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    'No recommended offers right now. Please check back soon.',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final ReferralOfferItem offer = recommended[index];
                  final ReferralRewardItem? activeReward =
                      activeByOffer[offer.id];
                  final bool canRedeem =
                      points.available >= offer.pointsCost &&
                      activeReward == null;
                  return _OfferCard(
                    offer: offer,
                    canRedeem: canRedeem,
                    activeReward: activeReward,
                    onRedeem: () => _redeemOffer(appState, offer),
                    onOpenDetails: () => _showOfferDetails(
                      context,
                      appState,
                      offer,
                      points,
                      activeReward,
                    ),
                  );
                }, childCount: recommended.length),
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
                              backgroundColor: AppPalette.primary.withValues(
                                alpha: 0.1,
                              ),
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
                    ...appState.activeRewards.map((reward) {
                      final ReferralOfferItem offer = offers.firstWhere(
                        (item) => item.id == reward.offerId,
                        orElse: () => const ReferralOfferItem(
                          id: 0,
                          title: 'Referral Reward',
                          description: null,
                          pointsCost: 0,
                          subject: null,
                          subjectId: null,
                          questionLimit: null,
                          durationDays: null,
                          category: null,
                          brand: null,
                          imageUrl: null,
                          isFeatured: false,
                        ),
                      );
                      final String title = offer.id == 0
                          ? 'Referral Reward'
                          : offer.title;
                      return Container(
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
                            const Icon(
                              Icons.check_circle,
                              color: AppPalette.success,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$title (limit ${reward.questionLimit ?? 'No limit'})',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.textDark,
                                ),
                              ),
                            ),
                            if (reward.expiresAt != null)
                              Text(
                                _formatExpiryStatus(reward.expiresAt!),
                                style: GoogleFonts.manrope(
                                  color: AppPalette.muted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _OffersSkeletonGrid extends StatelessWidget {
  const _OffersSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List<Widget>.generate(
                4,
                (int index) => Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppPalette.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppPalette.primary.withValues(alpha: 0.06),
                        ),
                        child: const Center(
                          child: SkeletonBox.circle(size: 26),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SkeletonBox(height: 10, width: 90, borderRadius: 8),
                      const SizedBox(height: 6),
                      const SkeletonBox(
                        height: 12,
                        width: 130,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 10),
                      const SkeletonBox(height: 8, width: 110, borderRadius: 8),
                      const SizedBox(height: 12),
                      const SkeletonBox(
                        height: 26,
                        width: double.infinity,
                        borderRadius: 999,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.canRedeem,
    required this.activeReward,
    required this.onRedeem,
    required this.onOpenDetails,
  });

  final ReferralOfferItem offer;
  final bool canRedeem;
  final ReferralRewardItem? activeReward;
  final VoidCallback onRedeem;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final bool isRedeemed = activeReward != null;
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final String? expiryLabel = isRedeemed
        ? (activeReward?.expiresAt == null
              ? 'Redeemed'
              : _formatExpiryLabel(activeReward!.expiresAt!))
        : (offer.durationDays == null || offer.durationDays == 0
              ? null
              : _formatAccessDays(offer.durationDays!));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
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
              SizedBox(
                height: 64,
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
                            cacheWidth: (64 * dpr).round(),
                            cacheHeight: (64 * dpr).round(),
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                offer.brand ?? 'BoardMasters',
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
              if (expiryLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  expiryLabel,
                  style: GoogleFonts.manrope(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                _formatUnit(offer.pointsCost, 'Point'),
                style: GoogleFonts.manrope(
                  color: AppPalette.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canRedeem ? onRedeem : onOpenDetails,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    minimumSize: const Size.fromHeight(36),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    isRedeemed
                        ? 'Redeemed'
                        : canRedeem
                        ? 'Redeem'
                        : 'Not enough',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatExpiryLabel(DateTime value) {
  final Duration diff = value.difference(DateTime.now());
  if (diff.inSeconds <= 0) {
    return 'Redeemed - Expires today';
  }
  final int days = (diff.inHours / 24).ceil();
  if (days <= 1) {
    return 'Redeemed - Expires in 1 day';
  }
  return 'Redeemed - Expires in $days days';
}

String _formatUnit(int value, String singular) {
  if (value == 1) {
    return '1 $singular';
  }
  return '$value ${singular}s';
}

String _formatAccessDays(int days) {
  return 'Access ${_formatUnit(days, 'day')}';
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppPalette.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
              color: AppPalette.primary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
