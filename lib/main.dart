import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the image cache smaller for low-RAM devices.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 200;
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
      title: 'BoardMasters Review',
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

