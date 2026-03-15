import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'tabs/dashboard_tab.dart';
import 'tabs/practice_tab.dart';
import 'tabs/profile_tab.dart';
import '../state/app_state.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  bool? _lastOffline;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  Future<void> _refreshOnTabSwitch() async {
    final AppState appState = context.read<AppState>();

    if (appState.signedIn) {
      await appState.refreshCurrentUser();
      return;
    }

    await appState.loadPlans(force: true);
  }

  void _switchTo(int index) {
    setState(() {
      _index = index;
    });
    _refreshOnTabSwitch();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOffline = context.watch<AppState>().isOffline;
    if (_lastOffline != isOffline) {
      _lastOffline = isOffline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        if (isOffline) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No internet connection. The app may not work properly.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Back online.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }

    final List<Widget> pages = <Widget>[
      DashboardTab(
        onOpenPractice: () {
          _switchTo(1);
        },
      ),
      const PracticeTab(),
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
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

