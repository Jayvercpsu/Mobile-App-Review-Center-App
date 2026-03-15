import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    Future<void>.delayed(const Duration(milliseconds: 2300), () async {
      if (!mounted) {
        return;
      }
      final AppState appState = context.read<AppState>();
      await appState.restoreSession();
      if (!mounted) {
        return;
      }
      final Widget target = appState.signedIn
          ? const HomeShell()
          : (appState.onboardingDone
              ? const LoginScreen()
              : const OnboardingScreen());
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => target),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF1E2B57),
              Color(0xFF2D3C6E),
              Color(0xFFC53D57),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: -70,
              top: -60,
              child: _bubble(220),
            ),
            Positioned(
              right: -80,
              bottom: 0,
              child: _bubble(200),
            ),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.elasticOut,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Hero(
                      tag: 'boardmaster-logo',
                      child: Container(
                        width: 148,
                        height: 148,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/boardmaster.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Board Master',
                      style: GoogleFonts.redHatDisplay(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ).animate().fadeIn(duration: 650.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 6),
                    Text(
                      'Review Center',
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate(delay: 120.ms).fadeIn(duration: 500.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }
}

