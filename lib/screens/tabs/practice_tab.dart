import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../quiz_screen.dart';

class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  SubjectItem? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppState>().loadPracticeSubjects();
    });
  }

  Future<void> _openQuestionCountModal({
    required SubjectItem subject,
    required AppState appState,
  }) async {
    final int maxBySubject = subject.totalQuestions;
    final int maxCount = maxBySubject;

    if (maxCount <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available questions for this subject.'),
        ),
      );
      return;
    }

    final int minCount = maxCount >= 10 ? 10 : 1;
    double chosenCount = max(minCount, min(20, maxCount)).toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        bool starting = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final int? divisions = maxCount > minCount
                ? (maxCount - minCount)
                : null;
            final double sliderValue = chosenCount.clamp(
              minCount.toDouble(),
              maxCount.toDouble(),
            );

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${subject.code} Question Count',
                      style: GoogleFonts.redHatDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose how many questions to test now.',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Total for this test: ${sliderValue.round()}',
                      style: GoogleFonts.manrope(
                        color: AppPalette.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppPalette.primary,
                        inactiveTrackColor: AppPalette.primary.withValues(
                          alpha: 0.12,
                        ),
                        thumbColor: AppPalette.secondary,
                        overlayColor: AppPalette.secondary.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      child: Slider(
                        min: minCount.toDouble(),
                        max: maxCount.toDouble(),
                        divisions: divisions,
                        value: sliderValue,
                        onChanged: maxCount == minCount
                            ? null
                            : (double value) {
                                setModalState(() {
                                  chosenCount = value;
                                });
                              },
                      ),
                    ),
                    Text(
                      'Plan limit for ${subject.code}: ${subject.maxQuestionsPerSet} unique questions per set.',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'If you request more, we will serve up to the plan limit.',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppPalette.primary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.manrope(
                                color: AppPalette.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: starting
                                ? null
                                : () async {
                                    setModalState(() {
                                      starting = true;
                                    });
                                    final ScaffoldMessengerState messenger =
                                        ScaffoldMessenger.of(this.context);
                                    final NavigatorState rootNavigator =
                                        Navigator.of(this.context);
                                    final NavigatorState sheetNavigator =
                                        Navigator.of(modalContext);

                                    final response = await appState.generateQuiz(
                                      subject: subject,
                                      count: sliderValue.round(),
                                    );

                                    if (!mounted) {
                                      return;
                                    }

                                    setModalState(() {
                                      starting = false;
                                    });

                                    if (!response.ok || response.data == null) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            response.message ??
                                                'Unable to load quiz from server.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final int requestedCount =
                                        sliderValue.round();
                                    final int servedCount =
                                        response.data!.length;
                                    if (servedCount < requestedCount) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Plan limit applied: $servedCount of $requestedCount questions served.',
                                          ),
                                        ),
                                      );
                                    }

                                    sheetNavigator.pop();
                                    rootNavigator.push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => QuizScreen(
                                          subject: subject,
                                          questions: response.data!,
                                        ),
                                      ),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                            ),
                            child: starting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Start Test',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final List<SubjectItem> subjects = appState.visibleSubjects;

    if (subjects.isNotEmpty &&
        (_selected == null ||
            !subjects.any((SubjectItem item) => item.id == _selected!.id))) {
      _selected = subjects.first;
    }

    if (subjects.isEmpty &&
        (appState.loadingPracticeSubjects || !appState.practiceSubjectsLoaded)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (subjects.isEmpty && appState.practiceSubjectsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                appState.practiceSubjectsError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  context.read<AppState>().loadPracticeSubjects(force: true);
                },
                child: Text(
                  'Retry',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No accessible subjects yet for your current plan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AppPalette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Practice Tests',
                  style: GoogleFonts.redHatDisplay(
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap any subject card to choose total questions in a modal.',
                  style: GoogleFonts.manrope(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.32,
            ),
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final SubjectItem subject = subjects[index];
              final bool selected = subject.id == _selected?.id;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selected = subject;
                  });
                  _openQuestionCountModal(
                    subject: subject,
                    appState: context.read<AppState>(),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: subject.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: subject.color.withValues(alpha: 0.35),
                        blurRadius: selected ? 16 : 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        subject.code,
                        style: GoogleFonts.redHatDisplay(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subject.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        NumberFormat.decimalPattern().format(
                          subject.totalQuestions,
                        ),
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: subjects.length),
          ),
        ),
      ],
    );
  }
}
