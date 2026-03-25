import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/app_theme.dart';
import '../models/app_models.dart';

class RationalizationScreen extends StatelessWidget {
  const RationalizationScreen({
    super.key,
    required this.subject,
    required this.questions,
    required this.answers,
  });

  final SubjectItem subject;
  final List<QuestionItem> questions;
  final Map<int, String> answers;

  Future<void> _printRationalization(BuildContext context) async {
    final int wrongCount = questions.asMap().entries.where((
      MapEntry<int, QuestionItem> entry,
    ) {
      final String? selected = answers[entry.key];
      return selected != entry.value.correctKey;
    }).length;

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

    try {
      final pw.Font baseFont = await PdfGoogleFonts.manropeRegular();
      final pw.Font boldFont = await PdfGoogleFonts.manropeBold();
      final pw.TextStyle titleStyle = pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
      );
      final pw.TextStyle sectionStyle = pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
      );
      final pw.TextStyle bodyStyle = const pw.TextStyle(fontSize: 11);

      final pw.Document doc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
        ),
      );

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return <pw.Widget>[
              pw.Text('Overall Rationalization', style: titleStyle),
              pw.SizedBox(height: 6),
              pw.Text('Subject: ${subject.code}', style: sectionStyle),
              pw.Text(
                'Wrong answers: $wrongCount of ${questions.length}',
                style: bodyStyle,
              ),
              pw.SizedBox(height: 14),
              ...questions.asMap().entries.map((entry) {
                final int index = entry.key;
                final QuestionItem question = entry.value;
                final String? selected = answers[index];
                final bool isCorrect = selected == question.correctKey;
                final List<String> keys =
                    question.choices.keys.toList()..sort();

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      'Question ${index + 1} • ${isCorrect ? 'Correct' : 'Wrong'}',
                      style: sectionStyle,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(question.question, style: bodyStyle),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      selected == null
                          ? 'Your answer: No answer selected'
                          : 'Your answer: $selected. ${choiceText(question, selected)}',
                      style: bodyStyle,
                    ),
                    pw.Text(
                      'Correct answer: ${question.correctKey}. ${question.choices[question.correctKey] ?? ''}',
                      style: bodyStyle.copyWith(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (!isCorrect && selected != null) ...<pw.Widget>[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Why your answer is wrong:',
                        style: bodyStyle.copyWith(
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        rationaleText(question, selected),
                        style: bodyStyle,
                      ),
                    ],
                    pw.SizedBox(height: 8),
                    pw.Text('Option Rationalization', style: sectionStyle),
                    pw.SizedBox(height: 6),
                    ...keys.map((String key) {
                      final String optionText = question.choices[key] ?? '';
                      final String optionRationale =
                          question.rationales[key] ?? '';

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          '$key. $optionText\n$optionRationale',
                          style: bodyStyle,
                        ),
                      );
                    }),
                    pw.Divider(),
                    pw.SizedBox(height: 6),
                  ],
                );
              }),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'overall_rationalization_${subject.code}.pdf',
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start printing.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int wrongCount = questions.asMap().entries.where((
      MapEntry<int, QuestionItem> entry,
    ) {
      final String? selected = answers[entry.key];
      return selected != entry.value.correctKey;
    }).length;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overall Rationalization'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Print',
            onPressed: () => _printRationalization(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            splashRadius: 22,
            icon: const Icon(Icons.print_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
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
                  Text(
                    'Subject: ${subject.code}',
                    style: GoogleFonts.redHatDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wrong answers: $wrongCount of ${questions.length}',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...questions.asMap().entries.map((
              MapEntry<int, QuestionItem> item,
            ) {
              final int index = item.key;
              final QuestionItem question = item.value;
              final String? selected = answers[index];
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
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: optionIsCorrect
                              ? AppPalette.success.withValues(alpha: 0.08)
                              : AppPalette.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: optionSelected
                                ? AppPalette.secondary.withValues(alpha: 0.35)
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
