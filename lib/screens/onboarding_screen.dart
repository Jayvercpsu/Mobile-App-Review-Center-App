import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../core/app_theme.dart';
import '../state/app_state.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardItem> _items = const <_OnboardItem>[
    _OnboardItem(
      icon: Icons.school_rounded,
      title: 'Master Every Subject',
      subtitle:
          'Practice with focused sets across Nursing, FAR, AFAR, TAX, AUD, and more.',
      color: Color(0xFF2B447E),
    ),
    _OnboardItem(
      icon: Icons.price_change_rounded,
      title: 'Choose Your Plan',
      subtitle:
          'Compare Free and Subscription plans and unlock only the features you need.',
      color: Color(0xFFC53D57),
    ),
    _OnboardItem(
      icon: Icons.quiz_rounded,
      title: 'Instant Rationalization',
      subtitle:
          'Get why A is wrong, why B is wrong, why C is correct, and keep improving fast.',
      color: Color(0xFF208C72),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<AppState>().finishOnboarding();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_index == _items.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF8FAFE), Color(0xFFEAF0FB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const SizedBox(width: 60),
                    Hero(
                      tag: 'boardmaster-logo',
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/boardmaster-square.png',
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.manrope(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (int value) {
                    setState(() {
                      _index = value;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final _OnboardItem item = _items[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(26, 20, 26, 16),
                      child: Column(
                        children: <Widget>[
                          const Spacer(),
                          Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: <Color>[
                                  item.color.withValues(alpha: 0.95),
                                  item.color.withValues(alpha: 0.55),
                                ],
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: item.color.withValues(alpha: 0.35),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Icon(item.icon, size: 92, color: Colors.white),
                          ).animate().fadeIn(duration: 500.ms).scale(
                                duration: 580.ms,
                                curve: Curves.easeOutBack,
                              ),
                          const SizedBox(height: 34),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.redHatDisplay(
                              fontSize: 33,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            item.subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.muted,
                              height: 1.5,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SmoothPageIndicator(
                controller: _controller,
                count: _items.length,
                effect: WormEffect(
                  dotHeight: 9,
                  dotWidth: 20,
                  spacing: 10,
                  dotColor: AppPalette.primary.withValues(alpha: 0.22),
                  activeDotColor: AppPalette.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _index == _items.length - 1 ? 'Start Now' : 'Next',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardItem {
  const _OnboardItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

