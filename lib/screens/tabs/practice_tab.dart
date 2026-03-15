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

  Future<void> _openQuestionCountModal({
    required SubjectItem subject,
    required AppState appState,
  }) async {
    final int maxBySubject = subject.totalQuestions;
    final int maxByPlan = appState.maxQuestionPerSet;
    final int maxCount = min(maxBySubject, maxByPlan);

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
                      appState.selectedTier == PlanTier.free
                          ? 'Free plan limit: up to ${appState.maxQuestionPerSet} questions per set.'
                          : 'Subscription active: up to ${appState.maxQuestionPerSet} questions per set.',
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
                            onPressed: () {
                              Navigator.of(modalContext).pop();
                              if (!mounted) {
                                return;
                              }
                              final List<QuestionItem> quizQuestions = appState
                                  .buildQuiz(
                                    subject: subject,
                                    count: sliderValue.round(),
                                  );
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => QuizScreen(
                                    subject: subject,
                                    questions: quizQuestions,
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                            ),
                            child: Text(
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
    _selected ??= subjects.first;

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
