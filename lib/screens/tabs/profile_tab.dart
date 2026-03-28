import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../../widgets/skeleton_widgets.dart';
import '../feedback_screen.dart';
import '../login_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _refreshProfile(BuildContext context) async {
    final AppState appState = context.read<AppState>();
    await appState.refreshCurrentUser();
    await appState.loadReferrals(loadMore: false);
    await appState.loadSubscriptionHistory(loadMore: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final double dpr = MediaQuery.of(context).devicePixelRatio;

    return RefreshIndicator(
      onRefresh: () => _refreshProfile(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      child: appState.userAvatarUrl == null
                          ? Image.asset(
                              'assets/images/boardmaster-square.png',
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              appState.userAvatarUrl!,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                              cacheWidth: (58 * dpr).round(),
                              cacheHeight: (58 * dpr).round(),
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/boardmaster-square.png',
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                              ),
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final String? result = await Navigator.of(context)
                        .push<String?>(
                          MaterialPageRoute<String?>(
                            builder: (_) => const ProfileSettingsScreen(),
                          ),
                        );
                    if (!context.mounted || result == null) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(result)));
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppPalette.secondary.withValues(alpha: 0.35),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    'Edit Profile',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.secondary,
                    ),
                  ),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _ReferralCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
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
                    Text(
                      'Share your feedback',
                      style: GoogleFonts.redHatDisplay(
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Share your feedback by rating the app—we’re delighted to serve you!',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        color: AppPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FeedbackScreen(),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.rate_review_rounded),
                        label: Text(
                          'Send Feedback',
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
                        builder: (_) =>
                            const LoginScreen(showLogoutMessage: true),
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
      ),
    );
  }
}

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  Future<void> _refreshProfile(BuildContext context) async {
    await context.read<AppState>().refreshCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          'Profile Settings',
          style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refreshProfile(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[_ProfileSettingsCard()],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferralCard extends StatefulWidget {
  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  final TextEditingController _codeController = TextEditingController();
  bool _applying = false;

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
    super.dispose();
  }

  Future<void> _applyReferral(AppState appState) async {
    final String code = _codeController.text.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid referral code.')),
      );
      return;
    }

    setState(() {
      _applying = true;
    });

    final String? error = await appState.applyReferralCode(code);
    if (!mounted) {
      return;
    }

    setState(() {
      _applying = false;
    });

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
    final DateFormat formatter = DateFormat('MMM dd, yyyy');
    final String referralCode = appState.referralCode ?? '--';
    final bool canApply = appState.referredBy == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Referral',
            style: GoogleFonts.redHatDisplay(
              fontWeight: FontWeight.w800,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Your code: $referralCode',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: referralCode == '--'
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Referral code copied.'),
                          ),
                        );
                      },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          Text(
            'Referral joins: ${appState.referralJoinedCount}',
            style: GoogleFonts.manrope(
              color: AppPalette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (appState.referredByName != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Referred by ${appState.referredByName} (${appState.referredByEmail ?? '--'})',
                style: GoogleFonts.manrope(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 12),
          if (canApply)
            Column(
              children: <Widget>[
                TextField(
                  controller: _codeController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Enter referral code',
                    prefixIcon: Icon(Icons.card_giftcard_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: _applying
                        ? null
                        : () {
                            _applyReferral(appState);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.secondary,
                    ),
                    child: _applying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Apply Code',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          Text(
            'Invited users',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              color: AppPalette.textDark,
            ),
          ),
          const SizedBox(height: 8),
          if (appState.loadingReferrals) const _InvitedSkeletonList(),
          if (!appState.loadingReferrals && appState.referralEntries.isEmpty)
            Text(
              'No referrals yet.',
              style: GoogleFonts.manrope(
                color: AppPalette.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (appState.referralEntries.isNotEmpty)
            ...appState.referralEntries.map(
              (ReferralEntry entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.check_circle, color: AppPalette.success),
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
          if (appState.hasMoreReferrals)
            TextButton(
              onPressed: () {
                appState.loadReferrals(loadMore: true);
              },
              child: Text(
                'Show more',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _InvitedSkeletonList extends StatelessWidget {
  const _InvitedSkeletonList();

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
              borderRadius: BorderRadius.circular(14),
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
                      const SizedBox(height: 8),
                      const SkeletonBox(
                        height: 10,
                        width: 150,
                        borderRadius: 6,
                      ),
                      const SizedBox(height: 6),
                      const SkeletonBox(height: 8, width: 90, borderRadius: 6),
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

class _ProfileSettingsCard extends StatefulWidget {
  const _ProfileSettingsCard();

  @override
  State<_ProfileSettingsCard> createState() => _ProfileSettingsCardState();
}

class _ProfileSettingsCardState extends State<_ProfileSettingsCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _birthdate;
  String? _gender;
  Uint8List? _avatarBytes;
  String? _avatarFilename;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
    _schoolController.addListener(_markDirty);
    _placeController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _schoolController.dispose();
    _placeController.dispose();
    _phoneController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_dirty) {
      return;
    }
    setState(() {
      _dirty = true;
    });
  }

  void _syncFromState(AppState appState) {
    if (_dirty) {
      return;
    }

    _setControllerText(_nameController, appState.userName);
    _setControllerText(_emailController, appState.userEmail);
    _setControllerText(_schoolController, appState.userSchool);
    _setControllerText(_placeController, appState.userPlace);
    _setControllerText(_phoneController, appState.userPhoneNumber);
    _gender = appState.userGender;

    _birthdate = appState.userBirthdate;
    _birthdateController.text = _birthdate == null
        ? ''
        : DateFormat('MMM dd, yyyy').format(_birthdate!);
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.text = value;
  }

  Future<void> _pickAvatar() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 85,
    );

    if (picked == null) {
      return;
    }

    final Uint8List bytes = await picked.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
      _avatarFilename = picked.name.isNotEmpty
          ? picked.name
          : picked.path.split('/').last;
      _dirty = true;
    });
  }

  void _showAvatarPreview(AppState appState) {
    if (_avatarBytes == null && appState.userAvatarUrl == null) {
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
                      child: _avatarBytes != null
                          ? Image.memory(_avatarBytes!, fit: BoxFit.contain)
                          : Image.network(
                              appState.userAvatarUrl!,
                              fit: BoxFit.contain,
                              cacheWidth: cacheSize,
                              cacheHeight: cacheSize,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/boardmaster-square.png',
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

  Future<void> _pickBirthdate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime latestAllowed = DateTime(now.year - 13, now.month, now.day);
    final DateTime initial = _birthdate ?? DateTime(now.year - 18, 1, 1);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: latestAllowed,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppPalette.primary,
              onPrimary: Colors.white,
              onSurface: AppPalette.textDark,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _birthdate = picked;
      _birthdateController.text = DateFormat('MMM dd, yyyy').format(picked);
      _dirty = true;
    });
  }

  Future<void> _saveProfile(AppState appState) async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final bool emailChanged =
        email.toLowerCase() != appState.userEmail.trim().toLowerCase();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_birthdate != null) {
      final DateTime now = DateTime.now();
      final DateTime minAllowed = DateTime(now.year - 13, now.month, now.day);
      if (_birthdate!.isAfter(minAllowed)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be at least 13 years old.')),
        );
        return;
      }
    }
    if (emailChanged) {
      final bool emailAvailable = await appState.isEmailAvailable(
        email: email,
        ignoreEmail: appState.userEmail,
      );
      if (!mounted) {
        return;
      }
      if (!emailAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email is already used by another account.'),
          ),
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    FocusScope.of(context).unfocus();

    final String? error = await context.read<AppState>().updateProfile(
      name: name,
      email: email,
      school: _trimOrNull(_schoolController.text),
      place: _trimOrNull(_placeController.text),
      phoneNumber: _trimOrNull(_phoneController.text),
      birthdate: _birthdate,
      gender: _gender,
      avatarBytes: _avatarBytes,
      avatarFilename: _avatarFilename,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
      _dirty = error != null;
    });

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pop(
      emailChanged
          ? 'Profile updated. Verify your new email from inbox.'
          : 'Profile updated successfully.',
    );
  }

  String? _trimOrNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isValidPhilippinesPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return true;
    }
    if (digits.length == 11 && digits.startsWith('09')) {
      return true;
    }
    if (digits.length == 12 &&
        digits.startsWith('63') &&
        digits.substring(2, 3) == '9') {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    _syncFromState(appState);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.08)),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    ClipOval(
                      child: _avatarBytes != null
                          ? Image.memory(
                              _avatarBytes!,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                            )
                          : (appState.userAvatarUrl == null
                                ? Image.asset(
                                    'assets/images/boardmaster-square.png',
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    appState.userAvatarUrl!,
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    cacheWidth: (68 * dpr).round(),
                                    cacheHeight: (68 * dpr).round(),
                                    filterQuality: FilterQuality.low,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/boardmaster-square.png',
                                      width: 68,
                                      height: 68,
                                      fit: BoxFit.cover,
                                    ),
                                  )),
                    ),
                    if (_avatarBytes != null || appState.userAvatarUrl != null)
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _showAvatarPreview(appState),
                            child: Container(
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.visibility_outlined,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Profile photo',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        onPressed: _pickAvatar,
                        child: const Text('Change Photo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.length < 2) {
                  return 'Enter your full name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                final RegExp emailPattern = RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                );
                if (!emailPattern.hasMatch(trimmed)) {
                  return 'Enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: appState.userEmailVerified
                    ? AppPalette.success.withValues(alpha: 0.12)
                    : AppPalette.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    appState.userEmailVerified
                        ? Icons.verified_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: appState.userEmailVerified
                        ? AppPalette.success
                        : AppPalette.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    appState.userEmailVerified
                        ? 'Email verified'
                        : 'Email not verified',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: appState.userEmailVerified
                          ? AppPalette.success
                          : AppPalette.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(_gender),
              value: _gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(Icons.wc_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (String? value) {
                setState(() {
                  _gender = value;
                  _dirty = true;
                });
              },
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Select gender.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schoolController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'School',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.isNotEmpty && trimmed.length < 2) {
                  return 'Enter a valid school name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _placeController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Place',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.isNotEmpty && trimmed.length < 2) {
                  return 'Enter a valid place.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.isNotEmpty && !_isValidPhilippinesPhone(trimmed)) {
                  return 'Enter a valid Philippine phone number.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _birthdateController,
              readOnly: true,
              onTap: () => _pickBirthdate(context),
              decoration: InputDecoration(
                labelText: 'Birthdate',
                prefixIcon: const Icon(Icons.cake_outlined),
                suffixIcon: _birthdate == null
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _birthdate = null;
                            _birthdateController.text = '';
                            _dirty = true;
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving
                    ? null
                    : () {
                        _saveProfile(appState);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _dirty ? 'Save Changes' : 'Save Profile',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
