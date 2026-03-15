import 'package:flutter/material.dart';

enum PlanTier { free, premium }

class PlanOption {
  const PlanOption({
    required this.id,
    required this.name,
    required this.tier,
    required this.title,
    required this.price,
    required this.priceLabel,
    required this.billingCycle,
    required this.billingLabel,
    required this.description,
    required this.features,
  });

  final int id;
  final String name;
  final PlanTier tier;
  final String title;
  final double price;
  final String priceLabel;
  final String billingCycle;
  final String billingLabel;
  final String description;
  final List<String> features;

  bool get isPaid => price > 0;
}

class SubjectItem {
  const SubjectItem({
    required this.id,
    required this.code,
    required this.title,
    required this.totalQuestions,
    required this.color,
  });

  final String id;
  final String code;
  final String title;
  final int totalQuestions;
  final Color color;
}

class QuestionItem {
  const QuestionItem({
    required this.subjectId,
    required this.question,
    required this.choices,
    required this.correctKey,
    required this.rationales,
  });

  final String subjectId;
  final String question;
  final Map<String, String> choices;
  final String correctKey;
  final Map<String, String> rationales;
}

class QuizRecord {
  const QuizRecord({
    required this.subjectCode,
    required this.subjectTitle,
    required this.score,
    required this.total,
    required this.completedAt,
  });

  final String subjectCode;
  final String subjectTitle;
  final int score;
  final int total;
  final DateTime completedAt;
}
