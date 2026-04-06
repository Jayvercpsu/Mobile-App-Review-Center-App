import 'package:flutter/material.dart';
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

  void _showTopRightToast(String message) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    const Duration toastDuration = Duration(seconds: 2);
    final double top = MediaQuery.of(context).padding.top + 12;
    final double maxWidth = MediaQuery.of(context).size.width - 24;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          top: top,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth > 360 ? 360 : maxWidth,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  color: AppPalette.success.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1, end: 0),
                        duration: toastDuration,
                        builder: (BuildContext context, double value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 3,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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
        _showTopRightToast(message);
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

