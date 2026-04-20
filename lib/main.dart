import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/runtime_env.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RuntimeEnv.load();
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

class BoardMasterApp extends StatefulWidget {
  const BoardMasterApp({super.key});

  @override
  State<BoardMasterApp> createState() => _BoardMasterAppState();
}

class _BoardMasterAppState extends State<BoardMasterApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<AppState>().refreshDeviceDateValidation());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<AppState>().refreshDeviceDateValidation());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BoardMasters Review',
      theme: AppTheme.light,
      home: const SplashScreen(),
      builder: (BuildContext context, Widget? child) {
        final AppState appState = context.watch<AppState>();
        final String? message = appState.deviceDateOutdatedMessage;
        final Widget content = child ?? const SizedBox.shrink();

        if (message == null) {
          return content;
        }

        return Stack(
          children: <Widget>[
            content,
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.5),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.schedule_rounded,
                              size: 40,
                              color: Color(0xFF1E2B57),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Device date is outdated',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: appState.checkingDeviceDate
                                    ? null
                                    : () {
                                        unawaited(
                                          appState
                                              .refreshDeviceDateValidation(),
                                        );
                                      },
                                child: appState.checkingDeviceDate
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : const Text('I fixed my date/time'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
