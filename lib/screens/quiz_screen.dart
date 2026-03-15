import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.subject, required this.questions});

  final SubjectItem subject;
  final List<QuestionItem> questions;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final Map<int, String> _answers = <int, String>{};
  late Duration _remaining;
  Timer? _timer;
  int _index = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _remaining = Duration(seconds: max(180, widget.questions.length * 35));
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        _remaining = Duration.zero;
        _finish();
      } else {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _timeLabel(Duration value) {
    final String hours = value.inHours.toString().padLeft(2, '0');
    final String minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _select(String key) {
    setState(() {
      _answers[_index] = key;
      if (_index < widget.questions.length - 1) {
        _index += 1;
      }
    });
  }

  void _goBack() {
    if (_index > 0) {
      setState(() {
        _index -= 1;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_submitting) {
      return;
    }

    _submitting = true;
    _timer?.cancel();

    final int score = widget.questions.asMap().entries.where((entry) {
      final String? selected = _answers[entry.key];
      return selected == entry.value.correctKey;
    }).length;

    final AppState appState = context.read<AppState>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    appState.saveRecord(
      subject: widget.subject,
      score: score,
      total: widget.questions.length,
    );

    final submitResponse = await appState.submitQuizAttempt(
      subject: widget.subject,
      questions: widget.questions,
      answers: Map<int, String>.from(_answers),
    );

    if (mounted && !submitResponse.ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            submitResponse.message ?? 'Unable to save quiz attempt to server.',
          ),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          subject: widget.subject,
          score: score,
          total: widget.questions.length,
          questions: List<QuestionItem>.from(widget.questions),
          answers: Map<int, String>.from(_answers),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Questions')),
        body: Center(
          child: Text(
            'No questions available for this subject yet.',
            style: GoogleFonts.manrope(
              color: AppPalette.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final QuestionItem question = widget.questions[_index];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Text(
                    widget.subject.code,
                    style: GoogleFonts.redHatDisplay(
                      fontWeight: FontWeight.w900,
                      fontSize: 31,
                      color: AppPalette.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _timeLabel(_remaining),
                      style: GoogleFonts.manrope(
                        color: AppPalette.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_index + 1} of ${widget.questions.length}',
                    style: GoogleFonts.manrope(
                      color: AppPalette.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (_index + 1) / widget.questions.length,
                color: AppPalette.primary,
                backgroundColor: AppPalette.primary.withValues(alpha: 0.13),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        question.question,
                        style: GoogleFonts.redHatDisplay(
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.textDark,
                        ),
                      ).animate().fadeIn(duration: 320.ms),
                      const SizedBox(height: 16),
                      ...question.choices.entries.map((entry) {
                        final String key = entry.key;
                        final bool selected = _answers[_index] == key;

                        Color background = Colors.white;
                        Color border = AppPalette.primary.withValues(
                          alpha: 0.08,
                        );
                        if (selected) {
                          background = AppPalette.primary.withValues(
                            alpha: 0.1,
                          );
                          border = AppPalette.primary;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _select(key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: background,
                                border: Border.all(color: border, width: 1.6),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '$key.',
                                    style: GoogleFonts.manrope(
                                      color: AppPalette.textDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: GoogleFonts.manrope(
                                        color: AppPalette.textDark,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goBack,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppPalette.primary.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.manrope(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _index == widget.questions.length - 1
                          ? () {
                              if (_answers[_index] == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Select an answer for the last question first.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _finish();
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _index == widget.questions.length - 1
                            ? 'Submit Answers'
                            : 'Select option to continue',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
