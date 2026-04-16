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
  const QuizScreen({
    super.key,
    required this.subject,
    required this.questions,
    this.secondsPerQuestion = 60,
  });

  final SubjectItem subject;
  final List<QuestionItem> questions;
  final int secondsPerQuestion;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final Map<int, String> _answers = <int, String>{};
  late Duration _remaining;
  Timer? _timer;
  int _index = 0;
  bool _submitting = false;
  bool _nextLoading = false;

  Future<bool> _confirmExitQuiz() async {
    if (!mounted) {
      return false;
    }
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Exit quiz?',
            style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'You may lose your current progress.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Stay',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
              ),
              child: Text(
                'Exit',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  void initState() {
    super.initState();
    final int safeSecondsPerQuestion = widget.secondsPerQuestion < 15
        ? 15
        : widget.secondsPerQuestion;
    _remaining = Duration(
      seconds: max(
        safeSecondsPerQuestion,
        widget.questions.length * safeSecondsPerQuestion,
      ),
    );
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

  String _questionTimeLabel() {
    final int seconds = widget.secondsPerQuestion;
    if (seconds <= 0) {
      return '1 minute';
    }
    if (seconds % 60 == 0) {
      final int minutes = seconds ~/ 60;
      return minutes == 1 ? '1 minute' : '$minutes minutes';
    }
    return '$seconds seconds';
  }

  void _select(String key) {
    setState(() {
      _answers[_index] = key;
    });
  }

  bool _isAnsweredIndex(int idx) {
    return _answers[idx] != null;
  }

  bool _allAnswered() {
    for (int i = 0; i < widget.questions.length; i++) {
      if (_answers[i] == null) {
        return false;
      }
    }
    return true;
  }

  void _goBack() {
    if (_submitting) {
      return;
    }
    if (_index > 0) {
      setState(() {
        _index -= 1;
      });
      return;
    }
    _confirmExitQuiz().then((bool exit) {
      if (exit && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _finish() async {
    if (_submitting) {
      return;
    }

    _submitting = true;
    _timer?.cancel();
    if (mounted) {
      setState(() {});
    }

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
      questions: List<QuestionItem>.from(widget.questions),
      answers: Map<int, String>.from(_answers),
    );

    final submitResponse = await appState.submitQuizAttempt(
      subject: widget.subject,
      questions: widget.questions,
      answers: Map<int, String>.from(_answers),
    );

    await appState.loadQuizAttempts(loadMore: false);

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
    final bool hasSelection = _answers[_index] != null;
    final bool isLast = _index == widget.questions.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (_submitting) {
          return;
        }
        if (_index > 0) {
          setState(() {
            _index -= 1;
          });
          return;
        }
        final NavigatorState navigator = Navigator.of(context);
        _confirmExitQuiz().then((bool exit) {
          if (exit && mounted) {
            navigator.pop();
          }
        });
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Padding(
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
                        _TimePill(
                          label: _timeLabel(_remaining),
                          isUrgent: _remaining.inSeconds <= 30,
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
                      backgroundColor: AppPalette.primary.withValues(
                        alpha: 0.13,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.questions.length} items, ${_questionTimeLabel()} each question',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontWeight: FontWeight.w700,
                      ),
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
                                  alpha: 0.12,
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
                                      border: Border.all(
                                        color: border,
                                        width: 1.6,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        if (selected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppPalette.primary,
                                            size: 18,
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
                                color: AppPalette.primary.withValues(
                                  alpha: 0.2,
                                ),
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
                            onPressed: hasSelection && !_nextLoading && !_submitting
                                ? () {
                                    if (isLast) {
                                      if (_allAnswered()) {
                                        _finish();
                                        return;
                                      }
                                      setState(() {
                                        _nextLoading = true;
                                      });
                                      Future.delayed(const Duration(milliseconds: 500), () {
                                        if (!mounted) return;
                                        setState(() {
                                          _nextLoading = false;
                                        });
                                        _finish();
                                      });
                                    } else {
                                      final int target = _index + 1;
                                      if (_isAnsweredIndex(target)) {
                                        setState(() {
                                          _index = target;
                                        });
                                        return;
                                      }
                                      setState(() {
                                        _nextLoading = true;
                                      });
                                      Future.delayed(const Duration(milliseconds: 500), () {
                                        if (!mounted) return;
                                        setState(() {
                                          _index = target;
                                          _nextLoading = false;
                                        });
                                      });
                                    }
                                  }
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 10,
                              ),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: _nextLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  )
                                : Text(
                                    isLast ? 'Submit Answers' : 'Next Question',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_submitting)
                Container(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label, required this.isUrgent});

  final String label;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = isUrgent
        ? const Color(0xFFFF5A5F)
        : AppPalette.secondary.withValues(alpha: 0.15);
    final Color textColor = isUrgent ? Colors.white : AppPalette.primary;

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (!isUrgent) {
      return pill;
    }

    return pill
        .animate(onPlay: (AnimationController c) => c.repeat())
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.06, 1.06),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1.06, 1.06),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        )
        .fade(
          begin: 1,
          end: 0.92,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
  }
}
