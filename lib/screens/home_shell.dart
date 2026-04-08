import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/practice_tab.dart';
import 'tabs/referrals_tab.dart';
import 'tabs/profile_tab.dart';
import '../state/app_state.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.initialIndex = 0,
    this.initialPlanId,
    this.showOnlineMessageOnStart = false,
    this.startupMessage,
  });

  final int initialIndex;
  final int? initialPlanId;
  final bool showOnlineMessageOnStart;
  final String? startupMessage;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  late final PageController _pageController;
  bool? _lastOffline;
  bool _pendingOnlineMessage = false;
  String? _pendingStartupMessage;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _pendingOnlineMessage = widget.showOnlineMessageOnStart;
    final String startupMessage = (widget.startupMessage ?? '').trim();
    _pendingStartupMessage = startupMessage.isEmpty ? null : startupMessage;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshOnTabSwitch(int index) async {
    final AppState appState = context.read<AppState>();

    if (appState.signedIn) {
      if (index == 2) {
        await appState.loadReferrals(loadMore: false);
        return;
      }

      await appState.refreshCurrentUser();
      return;
    }

    await appState.loadPlans(force: true);
  }

  void _switchTo(int index) {
    if (index == _index) {
      return;
    }
    setState(() {
      _index = index;
    });

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showWelcomeCelebration(String userName) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    const Duration toastDuration = Duration(seconds: 5);
    final double topInset = MediaQuery.of(context).padding.top + 16;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: SizedBox(
                    width: double.infinity,
                    child: _CelebrationCard(userName: userName),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    Future<void>.delayed(toastDuration, () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool isOffline = appState.isOffline;
    final bool? previousOffline = _lastOffline;
    if (previousOffline == null) {
      _lastOffline = isOffline;
    } else if (previousOffline != isOffline) {
      _lastOffline = isOffline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        if (isOffline && previousOffline == false) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No internet connection. The app may not work properly.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        } else if (!isOffline && previousOffline == true && appState.signedIn) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Back online.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }

    if (_pendingOnlineMessage && appState.signedIn && !isOffline) {
      _pendingOnlineMessage = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Back online.'),
            duration: Duration(seconds: 3),
          ),
        );
      });
    }

    if (_pendingStartupMessage != null && appState.signedIn) {
      final String message = _pendingStartupMessage!;
      _pendingStartupMessage = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (message.isNotEmpty) {
          _showWelcomeCelebration(appState.userName);
        }
      });
    }

    final List<Widget> pages = <Widget>[
      DashboardTab(
        onOpenPractice: () {
          _switchTo(1);
        },
        initialPlanId: widget.initialPlanId,
      ),
      const PracticeTab(),
      const ReferralsTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (int value) {
            if (_index != value) {
              setState(() {
                _index = value;
              });
            }
            _refreshOnTabSwitch(value);
          },
          physics: const BouncingScrollPhysics(),
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          _switchTo(value);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Reviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard_rounded),
            label: 'Offers',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final String name = userName.trim().isEmpty ? 'there' : userName.trim();
    final Widget card = SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: AppPalette.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    AppPalette.primary.withValues(alpha: 0.12),
                    AppPalette.accent.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'WELCOME',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome $name!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Let’s make today a great review session.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppPalette.muted,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 260.ms, curve: Curves.easeOut)
        .slideY(begin: -0.1, end: 0, duration: 300.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 360.ms,
          curve: Curves.easeOutBack,
        );

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
        Positioned(
          top: -6,
          left: 16,
          child: _ConfettiDot(
            color: AppPalette.accent,
            size: 8,
            drift: const Offset(-6, -6),
          ),
        ),
        Positioned(
          top: 6,
          right: 18,
          child: _ConfettiDot(
            color: AppPalette.primary,
            size: 6,
            drift: const Offset(6, -4),
          ),
        ),
        Positioned(
          bottom: -6,
          right: 22,
          child: _ConfettiDot(
            color: AppPalette.secondary,
            size: 7,
            drift: const Offset(5, 6),
          ),
        ),
        Positioned(
          bottom: -8,
          left: 22,
          child: _ConfettiDot(
            color: AppPalette.success,
            size: 6,
            drift: const Offset(-5, 6),
          ),
        ),
        Positioned(
          left: -12,
          child: _FlyerStrip(
            color: AppPalette.accent.withValues(alpha: 0.85),
            angle: -0.4,
          ),
        ),
        Positioned(
          right: -12,
          child: _FlyerStrip(
            color: AppPalette.primary.withValues(alpha: 0.85),
            angle: 0.4,
          ),
        ),
        Positioned(
          top: -8,
          right: 22,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: AppPalette.accent,
            size: 22,
          )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: 300.ms)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.15, 1.15),
                duration: 700.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .scale(
                begin: const Offset(1.15, 1.15),
                end: const Offset(0.85, 0.85),
                duration: 700.ms,
                curve: Curves.easeInOut,
              ),
        ),
        Positioned(
          bottom: -10,
          left: 26,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: AppPalette.primary.withValues(alpha: 0.7),
            size: 18,
          )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: 300.ms)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.1, 1.1),
                duration: 800.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .scale(
                begin: const Offset(1.1, 1.1),
                end: const Offset(0.85, 0.85),
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
        ),
        card,
        ],
      ),
    );
  }
}

class _FlyerStrip extends StatelessWidget {
  const _FlyerStrip({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 28,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.06, 1.06),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1.06, 1.06),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
        );
  }
}

class _ConfettiDot extends StatelessWidget {
  const _ConfettiDot({
    required this.color,
    required this.size,
    required this.drift,
  });

  final Color color;
  final double size;
  final Offset drift;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .move(
          begin: Offset.zero,
          end: drift,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        )
        .then()
        .move(
          begin: drift,
          end: Offset.zero,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
  }
}

