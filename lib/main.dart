import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: const BoardMasterApp(),
    ),
  );
}

class BoardMasterApp extends StatelessWidget {
  const BoardMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Board Master Review',
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

