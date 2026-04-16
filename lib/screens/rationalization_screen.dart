import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_theme.dart';
import '../core/screen_security.dart';
import '../models/app_models.dart';
import '../widgets/pass_fail_pill.dart';

class RationalizationScreen extends StatefulWidget {
  const RationalizationScreen({
    super.key,
    required this.subject,
    required this.questions,
    required this.answers,
  });

  final SubjectItem subject;
  final List<QuestionItem> questions;
  final Map<int, String> answers;

  @override
  State<RationalizationScreen> createState() => _RationalizationScreenState();
}

class _RationalizationScreenState extends State<RationalizationScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ScreenSecurity.enable());
  }

  @override
  void dispose() {
    unawaited(ScreenSecurity.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int wrongCount = widget.questions.asMap().entries.where((
      MapEntry<int, QuestionItem> entry,
    ) {
      final String? selected = widget.answers[entry.key];
      return selected != entry.value.correctKey;
    }).length;
    final int correctCount = widget.questions.length - wrongCount;
    final int percent = widget.questions.isEmpty
        ? 0
        : ((correctCount / widget.questions.length) * 100).round();

    String choiceText(QuestionItem question, String? key) {
      if (key == null) {
        return '';
      }
      return question.choices[key] ?? '';
    }

    String rationaleText(QuestionItem question, String? key) {
      if (key == null) {
        return 'No rationale provided.';
      }
      return question.rationales[key] ?? 'No rationale provided.';
    }

    final String subjectLabel = widget.subject.title.trim().isNotEmpty
        ? widget.subject.title
        : widget.subject.code;

    final bool passed = percent >= 75;
    final Color barColor = passed ? AppPalette.success : AppPalette.secondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Overall Rationalization')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppPalette.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Subject: $subjectLabel',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.redHatDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      PassFailPill(percent: percent, showPercent: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Score: $correctCount / ${widget.questions.length}',
                    style: GoogleFonts.manrope(
                      color: AppPalette.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 10,
                      color: barColor,
                      backgroundColor: barColor.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...widget.questions.asMap().entries.map((
              MapEntry<int, QuestionItem> item,
            ) {
              final int index = item.key;
              final QuestionItem question = item.value;
              final String? selected = widget.answers[index];
              final bool isCorrect = selected == question.correctKey;
              final List<String> keys = question.choices.keys.toList()..sort();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCorrect
                        ? AppPalette.success.withValues(alpha: 0.35)
                        : AppPalette.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Question ${index + 1}',
                            style: GoogleFonts.redHatDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: isCorrect
                                ? AppPalette.success.withValues(alpha: 0.15)
                                : AppPalette.secondary.withValues(alpha: 0.12),
                          ),
                          child: Text(
                            isCorrect ? 'Correct' : 'Wrong',
                            style: GoogleFonts.manrope(
                              color: isCorrect
                                  ? AppPalette.success
                                  : AppPalette.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      question.question,
                      style: GoogleFonts.manrope(
                        color: AppPalette.textDark,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selected == null
                          ? 'Your answer: No answer selected'
                          : 'Your answer: $selected. ${choiceText(question, selected)}',
                      style: GoogleFonts.manrope(
                        color: AppPalette.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Correct answer: ${question.correctKey}. ${question.choices[question.correctKey] ?? ''}',
                      style: GoogleFonts.manrope(
                        color: AppPalette.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isCorrect && selected != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppPalette.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Why your answer is wrong:\n${rationaleText(question, selected)}',
                          style: GoogleFonts.manrope(
                            color: AppPalette.textDark,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Option Rationalization',
                      style: GoogleFonts.redHatDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...keys.map((String key) {
                      final bool optionIsCorrect = key == question.correctKey;
                      final bool optionSelected = key == selected;

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: optionIsCorrect
                              ? AppPalette.success.withValues(alpha: 0.08)
                              : AppPalette.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: optionSelected
                                ? (optionIsCorrect
                                      ? AppPalette.success.withValues(
                                          alpha: 0.35,
                                        )
                                      : AppPalette.secondary.withValues(
                                          alpha: 0.35,
                                        ))
                                : AppPalette.primary.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          '$key. ${question.choices[key]}\n${question.rationales[key] ?? ''}',
                          style: GoogleFonts.manrope(
                            color: AppPalette.textDark,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
