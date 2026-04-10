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
    this.showWelcomeBackOnStart = false,
  });

  final int initialIndex;
  final int? initialPlanId;
  final bool showOnlineMessageOnStart;
  final String? startupMessage;
  final bool showWelcomeBackOnStart;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  late final PageController _pageController;
  bool? _lastOffline;
  bool _pendingOnlineMessage = false;
  String? _pendingStartupMessage;
  bool _showWelcomeBackOnStart = false;
  bool _guideChecked = false;
  bool _guideActive = false;
  int _guideStepIndex = 0;
  String? _guideUserEmail;

  static const List<_GuideStep> _guideSteps = <_GuideStep>[
    _GuideStep(
      tabIndex: 0,
      tabLabel: 'Home',
      title: 'Home Tab',
      description:
          'This is your dashboard for plan status, subscription history, and quick progress updates.',
    ),
    _GuideStep(
      tabIndex: 1,
      tabLabel: 'Reviews',
      title: 'Reviews Tab',
      description:
          'Practice questions live here. Start quizzes, track attempts, and review your rationalizations.',
    ),
    _GuideStep(
      tabIndex: 2,
      tabLabel: 'Offers',
      title: 'Offers Tab',
      description:
          'Use referral points, view rewards, and check available referral offers and history.',
    ),
    _GuideStep(
      tabIndex: 3,
      tabLabel: 'Profile',
      title: 'Profile Tab',
      description:
          'Manage your profile details, account information, and invited users in one place.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _pendingOnlineMessage = widget.showOnlineMessageOnStart;
    _showWelcomeBackOnStart = widget.showWelcomeBackOnStart;
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

  void _showWelcomeCelebration(String userName, {required bool welcomeBack}) {
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
                    child: _CelebrationCard(
                      userName: userName,
                      welcomeBack: welcomeBack,
                    ),
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

  Future<void> _maybeStartFirstAccountGuide(AppState appState) async {
    if (_guideChecked || !appState.signedIn) {
      return;
    }
    final String email = appState.userEmail.trim().toLowerCase();
    if (email.isEmpty) {
      return;
    }

    _guideChecked = true;
    _guideUserEmail = email;
    if (appState.mobileDemoSeen) {
      return;
    }

    const Duration delay = Duration(seconds: 5);
    await Future<void>.delayed(delay);
    if (!mounted ||
        !appState.signedIn ||
        appState.mobileDemoSeen ||
        _guideUserEmail != appState.userEmail.trim().toLowerCase()) {
      return;
    }

    setState(() {
      _guideActive = true;
      _guideStepIndex = 0;
    });
    _switchTo(_guideSteps.first.tabIndex);
  }

  Future<void> _markGuideSeen(AppState appState) async {
    if (!appState.signedIn || appState.mobileDemoSeen) {
      return;
    }
    await appState.markFirstAccountGuideSeen();
  }

  Future<void> _cancelGuide() async {
    setState(() {
      _guideActive = false;
    });
    await _markGuideSeen(context.read<AppState>());
  }

  Future<void> _nextGuideStep() async {
    if (_guideStepIndex >= _guideSteps.length - 1) {
      setState(() {
        _guideActive = false;
      });
      await _markGuideSeen(context.read<AppState>());
      return;
    }
    final int nextIndex = _guideStepIndex + 1;
    setState(() {
      _guideStepIndex = nextIndex;
    });
    _switchTo(_guideSteps[nextIndex].tabIndex);
  }

  void _skipGuideStep() {
    if (_guideStepIndex >= _guideSteps.length - 1) {
      return;
    }
    final int nextIndex = _guideStepIndex + 1;
    setState(() {
      _guideStepIndex = nextIndex;
    });
    _switchTo(_guideSteps[nextIndex].tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool isOffline = appState.isOffline;

    if (!appState.signedIn) {
      _guideChecked = false;
      _guideActive = false;
      _guideStepIndex = 0;
      _guideUserEmail = null;
    } else {
      final String currentEmail = appState.userEmail.trim().toLowerCase();
      if (_guideUserEmail != currentEmail) {
        _guideChecked = false;
        _guideActive = false;
        _guideStepIndex = 0;
        _guideUserEmail = currentEmail;
      }
      if (!_guideChecked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _maybeStartFirstAccountGuide(appState);
        });
      }
    }

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
          _showWelcomeCelebration(
            appState.userName,
            welcomeBack: _showWelcomeBackOnStart,
          );
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
        child: Stack(
          children: <Widget>[
            PageView(
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
            if (_guideActive)
              Positioned.fill(
                child: _FirstAccountGuideOverlay(
                  step: _guideSteps[_guideStepIndex],
                  currentStep: _guideStepIndex + 1,
                  totalSteps: _guideSteps.length,
                  onSkip: _skipGuideStep,
                  onNext: _nextGuideStep,
                  onCancel: _cancelGuide,
                  isFinalStep: _guideStepIndex == _guideSteps.length - 1,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          if (_guideActive) {
            return;
          }
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
            icon: Icon(Icons.local_activity_outlined),
            selectedIcon: Icon(Icons.local_activity),
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
  const _CelebrationCard({required this.userName, required this.welcomeBack});

  final String userName;
  final bool welcomeBack;

  @override
  Widget build(BuildContext context) {
    final String name = userName.trim().isEmpty ? 'there' : userName.trim();
    final Widget card =
        SizedBox(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                      welcomeBack ? 'Welcome back $name' : 'Welcome $name!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Let's make today a great review session.",
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
            .slideY(
              begin: -0.1,
              end: 0,
              duration: 300.ms,
              curve: Curves.easeOut,
            )
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
            child:
                Icon(
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
            child:
                Icon(
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

class _GuideStep {
  const _GuideStep({
    required this.tabIndex,
    required this.tabLabel,
    required this.title,
    required this.description,
  });

  final int tabIndex;
  final String tabLabel;
  final String title;
  final String description;
}

class _FirstAccountGuideOverlay extends StatelessWidget {
  const _FirstAccountGuideOverlay({
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    required this.onSkip,
    required this.onNext,
    required this.onCancel,
    required this.isFinalStep,
  });

  final _GuideStep step;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final VoidCallback onCancel;
  final bool isFinalStep;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.26),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppPalette.primary.withValues(alpha: 0.14),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppPalette.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.smart_toy_rounded,
                                color: AppPalette.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Guide Bot',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppPalette.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Step $currentStep of $totalSteps - ${step.tabLabel}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppPalette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppPalette.muted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            TextButton(
                              onPressed: onCancel,
                              child: const Text('Cancel Demo'),
                            ),
                            const Spacer(),
                            if (!isFinalStep)
                              OutlinedButton(
                                onPressed: onSkip,
                                child: const Text('Skip'),
                              ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: onNext,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.primary,
                              ),
                              child: Text(isFinalStep ? 'Finish' : 'Next'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 240.ms)
                  .slideY(begin: 0.06, end: 0, duration: 260.ms),
            ],
          ),
        ),
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
