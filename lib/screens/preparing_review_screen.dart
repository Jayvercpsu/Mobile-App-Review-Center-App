import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import 'quiz_screen.dart';

class PreparingReviewScreen extends StatefulWidget {
  const PreparingReviewScreen({
    super.key,
    required this.subject,
    required this.count,
    required this.secondsPerQuestion,
  });

  final SubjectItem subject;
  final int count;
  final int secondsPerQuestion;

  @override
  State<PreparingReviewScreen> createState() => _PreparingReviewScreenState();
}

class _PreparingReviewScreenState extends State<PreparingReviewScreen> {
  static const Duration _minDelay = Duration(seconds: 10);

  bool _minDelayPassed = false;
  bool _navigated = false;
  String? _errorMessage;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _delayTimer?.cancel();
    _minDelayPassed = false;
    _navigated = false;
    _errorMessage = null;

    _delayTimer = Timer(_minDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _minDelayPassed = true;
      });
    });

    final AppState appState = context.read<AppState>();
    final response = await appState.generateQuiz(
      subject: widget.subject,
      count: widget.count,
    );

    if (!mounted) {
      return;
    }

    if (!response.ok || response.data == null) {
      setState(() {
        _errorMessage =
            response.message ?? 'Unable to load review from server.';
      });
      return;
    }

    final List<QuestionItem> questions = response.data!;
    final int requestedCount = widget.count;
    final int servedCount = questions.length;

    if (servedCount < requestedCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plan limit applied: $servedCount of $requestedCount questions served.',
          ),
        ),
      );
    }

    while (mounted && !_minDelayPassed) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted || _navigated) {
      return;
    }
    _navigated = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(
          subject: widget.subject,
          questions: questions,
          secondsPerQuestion: widget.secondsPerQuestion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = 'Preparing your review…';
    final String subtitle = _errorMessage == null
        ? 'Warming up questions for ${widget.subject.title}.'
        : _errorMessage!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Start Review',
          style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              _ReviewPrepAnimation(error: _errorMessage != null),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.redHatDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_errorMessage == null) ...<Widget>[
                const SizedBox(height: 14),
                const _LoadingDots(),
              ] else ...<Widget>[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Try again',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.primary,
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewPrepAnimation extends StatelessWidget {
  const _ReviewPrepAnimation({required this.error});

  final bool error;

  @override
  Widget build(BuildContext context) {
    final Widget icon = Icon(
      error ? Icons.error_outline_rounded : Icons.fact_check_rounded,
      size: 42,
      color: error ? AppPalette.secondary : AppPalette.primary,
    );

    final Widget orb = Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: <Color>[
            AppPalette.secondary,
            AppPalette.accent,
            AppPalette.primary,
            AppPalette.secondary,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
      ),
    );

    if (error) {
      return orb
          .animate()
          .fadeIn(duration: 250.ms)
          .shake(duration: 600.ms, hz: 3);
    }

    return orb
        .animate(onPlay: (controller) => controller.repeat())
        .rotate(duration: 1600.ms)
        .then()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.03, 1.03),
          duration: 900.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1.03, 1.03),
          end: const Offset(1, 1),
          duration: 900.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    Widget dot(int index) {
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppPalette.primary.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
      )
          .animate(onPlay: (controller) => controller.repeat())
          .fade(
            begin: 0.25,
            end: 1,
            duration: 650.ms,
            delay: Duration(milliseconds: 180 * index),
          )
          .then()
          .fade(
            begin: 1,
            end: 0.25,
            duration: 650.ms,
            delay: Duration(milliseconds: 180 * index),
          );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[dot(0), dot(1), dot(2)],
    );
  }
}
