import 'package:flutter/material.dart';

enum PlanTier { free, premium }

class PlanOption {
  const PlanOption({
    required this.id,
    required this.name,
    required this.tier,
    required this.title,
    required this.planGroup,
    required this.groupLabel,
    required this.subPlanLabel,
    required this.price,
    required this.priceLabel,
    required this.billingCycle,
    required this.billingLabel,
    required this.durationDays,
    required this.sortOrder,
    required this.description,
    required this.features,
    required this.paymentProvider,
    required this.inAppProductIdAndroid,
    required this.inAppProductIdIos,
  });

  final int id;
  final String name;
  final PlanTier tier;
  final String title;
  final String planGroup;
  final String groupLabel;
  final String subPlanLabel;
  final double price;
  final String priceLabel;
  final String billingCycle;
  final String billingLabel;
  final int durationDays;
  final int sortOrder;
  final String description;
  final List<String> features;
  final String paymentProvider;
  final String? inAppProductIdAndroid;
  final String? inAppProductIdIos;

  bool get isPaid => price > 0;
  bool get isTrial => tier == PlanTier.free;
  bool get usesInAppPurchase => paymentProvider == 'in_app_purchase';
}

class SubjectItem {
  const SubjectItem({
    required this.id,
    required this.code,
    required this.title,
    required this.groupKey,
    required this.groupLabel,
    required this.totalQuestions,
    required this.color,
    int? maxQuestionsPerSet,
    this.isAccessible = true,
  }) : maxQuestionsPerSet = maxQuestionsPerSet ?? totalQuestions;

  final String id;
  final String code;
  final String title;
  final String groupKey;
  final String groupLabel;
  final int totalQuestions;
  final Color color;
  final int maxQuestionsPerSet;
  final bool isAccessible;
}

class QuestionItem {
  const QuestionItem({
    this.id,
    required this.subjectId,
    required this.question,
    required this.choices,
    required this.correctKey,
    required this.rationales,
  });

  final int? id;
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
    this.questions = const <QuestionItem>[],
    this.answers = const <int, String>{},
  });

  final String subjectCode;
  final String subjectTitle;
  final int score;
  final int total;
  final DateTime completedAt;
  final List<QuestionItem> questions;
  final Map<int, String> answers;
}

class QuizAttemptItem {
  const QuizAttemptItem({
    required this.id,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectTitle,
    required this.score,
    required this.total,
    required this.completedAt,
  });

  final int id;
  final int? subjectId;
  final String subjectCode;
  final String subjectTitle;
  final int score;
  final int total;
  final DateTime completedAt;
}

class QuizAttemptDetail {
  const QuizAttemptDetail({
    required this.id,
    required this.subject,
    required this.score,
    required this.total,
    required this.completedAt,
    required this.questions,
    required this.answers,
  });

  final int id;
  final SubjectItem subject;
  final int score;
  final int total;
  final DateTime completedAt;
  final List<QuestionItem> questions;
  final Map<int, String> answers;
}

class SubscriptionHistoryItem {
  const SubscriptionHistoryItem({
    required this.id,
    required this.planName,
    required this.price,
    required this.billingCycle,
    required this.providerPaymentId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.paymentMethod,
  });

  final int id;
  final String planName;
  final double price;
  final String billingCycle;
  final String? providerPaymentId;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final String? paymentMethod;
}

class ReferralEntry {
  const ReferralEntry({
    required this.id,
    required this.invitedName,
    required this.invitedEmail,
    required this.createdAt,
  });

  final int id;
  final String invitedName;
  final String invitedEmail;
  final DateTime? createdAt;
}

class ReferralPoints {
  const ReferralPoints({
    required this.earned,
    required this.spent,
    required this.available,
    required this.perReferral,
  });

  final int earned;
  final int spent;
  final int available;
  final int perReferral;
}

class ReferralOfferItem {
  const ReferralOfferItem({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.subject,
    required this.subjectId,
    required this.questionLimit,
    required this.durationDays,
    required this.category,
    required this.brand,
    required this.imageUrl,
    required this.isFeatured,
  });

  final int id;
  final String title;
  final String? description;
  final int pointsCost;
  final String? subject;
  final int? subjectId;
  final int? questionLimit;
  final int? durationDays;
  final String? category;
  final String? brand;
  final String? imageUrl;
  final bool isFeatured;
}

class ReferralRewardItem {
  const ReferralRewardItem({
    required this.id,
    required this.offerId,
    required this.subjectId,
    required this.questionLimit,
    required this.expiresAt,
  });

  final int id;
  final int offerId;
  final int? subjectId;
  final int? questionLimit;
  final DateTime? expiresAt;
}
