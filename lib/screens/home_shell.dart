import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  });

  final int initialIndex;
  final int? initialPlanId;
  final bool showOnlineMessageOnStart;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  bool? _lastOffline;
  bool _pendingOnlineMessage = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pendingOnlineMessage = widget.showOnlineMessageOnStart;
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
    setState(() {
      _index = index;
    });
    _refreshOnTabSwitch(index);
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
        child: IndexedStack(
          index: _index,
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
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard_rounded),
            label: 'Referrals',
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

