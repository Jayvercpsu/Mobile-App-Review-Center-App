import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_theme.dart';
import '../models/app_models.dart';
import 'home_shell.dart';
import 'rationalization_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.subject,
    required this.score,
    required this.total,
    required this.questions,
    required this.answers,
  });

  final SubjectItem subject;
  final int score;
  final int total;
  final List<QuestionItem> questions;
  final Map<int, String> answers;

  @override
  Widget build(BuildContext context) {
    final double percent = total == 0 ? 0 : (score / total) * 100;
    final int rounded = percent.round();

    String headline = 'Keep Going!';
    String detail =
        'You are building momentum. Review the rationalizations and tackle another set.';

    if (percent >= 90) {
      headline = 'You are crushing it!';
      detail =
          'You did an excellent job on this set and demonstrated strong understanding.';
    } else if (percent >= 75) {
      headline = 'Great Progress!';
      detail =
          'Solid performance. A few more focused sets will push you even higher.';
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Container(
                width: 138,
                height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.success.withValues(alpha: 0.16),
                ),
                child: Container(
                  margin: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.success,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 16),
              Text(
                '$rounded%',
                style: GoogleFonts.redHatDisplay(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: AppPalette.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Score: $score / $total',
                textAlign: TextAlign.center,
                style: GoogleFonts.redHatDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You got $score of $total questions right in ${subject.code}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: GoogleFonts.redHatDisplay(
                  fontSize: 33,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RationalizationScreen(
                          subject: subject,
                          questions: questions,
                          answers: answers,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppPalette.secondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'View Overall Rationalization',
                    style: GoogleFonts.manrope(
                      color: AppPalette.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const HomeShell(initialIndex: 1),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                  ),
                  child: Text(
                    'Try Another Set',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const HomeShell(initialIndex: 0),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppPalette.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.manrope(
                      color: AppPalette.primary,
                      fontWeight: FontWeight.w800,
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
