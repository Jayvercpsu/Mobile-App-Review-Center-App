import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../../widgets/skeleton_widgets.dart';
import '../home_shell.dart';
import '../preparing_review_screen.dart';
import '../rationalization_screen.dart';

class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab>
    with SingleTickerProviderStateMixin {
  SubjectItem? _selected;
  final Set<int> _selectedAttemptIds = <int>{};
  late final AnimationController _flickerController;
  late final Animation<double> _flickerOpacity;

  bool get _hasSelectedAttempts => _selectedAttemptIds.isNotEmpty;

  Future<void> _confirmDeleteSelected(AppState appState) async {
    if (!_hasSelectedAttempts) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete attempts'),
          content: Text(
            'Delete ${_selectedAttemptIds.length} selected attempts?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final List<int> ids = _selectedAttemptIds.toList();
    final String? error = await appState.deleteQuizAttempts(ids);
    if (!mounted) {
      return;
    }

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      _selectedAttemptIds.clear();
    });
  }

  Future<void> _confirmClearAll(AppState appState) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear recent attempts'),
          content: const Text('This will remove all your recent attempts.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear all'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final String? error = await appState.clearQuizAttempts();
    if (!mounted) {
      return;
    }

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      _selectedAttemptIds.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _flickerOpacity = Tween<double>(begin: 0.08, end: 0.18).animate(
      CurvedAnimation(parent: _flickerController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppState>().loadPracticeSubjects();
      context.read<AppState>().loadQuizAttempts(loadMore: false);
    });
  }

  @override
  void dispose() {
    _flickerController.dispose();
    super.dispose();
  }

  Future<void> _openQuestionCountModal({
    required SubjectItem subject,
    required AppState appState,
  }) async {
    final int maxBySubject = subject.maxQuestionsPerSet > 0
        ? (subject.maxQuestionsPerSet < subject.totalQuestions
              ? subject.maxQuestionsPerSet
              : subject.totalQuestions)
        : subject.totalQuestions;
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

    const List<int> preferredItemCounts = <int>[10, 25, 50, 75, 100];
    final List<int> itemCountOptions = preferredItemCounts
        .where((int count) => count <= maxCount)
        .toList();
    if (itemCountOptions.isEmpty) {
      itemCountOptions.add(maxCount);
    }
    int chosenCount = itemCountOptions.contains(25)
        ? 25
        : itemCountOptions.first;
    int chosenSecondsPerQuestion = 60;
    const List<int> secondOptions = <int>[30, 45, 60, 90, 120];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        bool starting = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                      subject.title,
                      style: GoogleFonts.redHatDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Number of items and time allotted for each question.',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _SelectorColumn(
                            title: 'Number of Items',
                            titleColor: const Color(0xFF13A44A),
                            options: itemCountOptions
                                .map(
                                  (int count) => _SelectorOption(
                                    value: count,
                                    label: '$count',
                                  ),
                                )
                                .toList(),
                            selectedValue: chosenCount,
                            onChanged: (int value) {
                              setModalState(() {
                                chosenCount = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SelectorColumn(
                            title: 'Time allotted for each question',
                            titleColor: AppPalette.primary,
                            options: secondOptions
                                .map(
                                  (int seconds) => _SelectorOption(
                                    value: seconds,
                                    label: switch (seconds) {
                                      30 => '30 seconds',
                                      45 => '45 seconds',
                                      60 => '1 minute',
                                      90 => '1 minute & 30 seconds',
                                      120 => '2 minutes',
                                      _ => '$seconds seconds',
                                    },
                                  ),
                                )
                                .toList(),
                            selectedValue: chosenSecondsPerQuestion,
                            onChanged: (int value) {
                              setModalState(() {
                                chosenSecondsPerQuestion = value;
                              });
                            },
                          ),
                        ),
                      ],
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
                    Column(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: starting
                                ? null
                                : () => Navigator.of(modalContext).pop(),
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
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: starting
                                ? null
                                : () async {
                                    setModalState(() {
                                      starting = true;
                                    });

                                    final NavigatorState rootNavigator =
                                        Navigator.of(this.context);
                                    final NavigatorState sheetNavigator =
                                        Navigator.of(modalContext);

                                    sheetNavigator.pop();
                                    rootNavigator.push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PreparingReviewScreen(
                                          subject: subject,
                                          count: chosenCount,
                                          secondsPerQuestion:
                                              chosenSecondsPerQuestion,
                                        ),
                                      ),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              minimumSize: const Size.fromHeight(50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Start Review',
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                      ),
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

  Future<void> _refreshReview(AppState appState) async {
    await appState.loadPracticeSubjects(force: true);
    await appState.loadQuizAttempts(loadMore: false);
  }

  List<MapEntry<String, List<SubjectItem>>> _groupSubjects(
    List<SubjectItem> subjects,
  ) {
    final Map<String, List<SubjectItem>> grouped =
        <String, List<SubjectItem>>{};
    final List<String> order = <String>[];

    for (final SubjectItem subject in subjects) {
      final String label = subject.groupLabel.trim().isNotEmpty
          ? subject.groupLabel.trim()
          : 'Subjects';
      if (!grouped.containsKey(label)) {
        grouped[label] = <SubjectItem>[];
        order.add(label);
      }
      grouped[label]!.add(subject);
    }

    final List<MapEntry<String, List<SubjectItem>>> result = order
        .map(
          (String label) => MapEntry<String, List<SubjectItem>>(
            label,
            grouped[label] ?? <SubjectItem>[],
          ),
        )
        .where(
          (MapEntry<String, List<SubjectItem>> entry) => entry.value.isNotEmpty,
        )
        .toList();

    for (final MapEntry<String, List<SubjectItem>> entry in result) {
      final List<SubjectItem> accessible = entry.value
          .where((SubjectItem item) => item.isAccessible)
          .toList();
      final List<SubjectItem> locked = entry.value
          .where((SubjectItem item) => !item.isAccessible)
          .toList();
      entry.value
        ..clear()
        ..addAll(accessible)
        ..addAll(locked);
    }

    return result;
  }

  Widget _buildSubjectCard({
    required BuildContext context,
    required SubjectItem subject,
    required bool isLocked,
    required bool selected,
    required AppState appState,
  }) {
    return GestureDetector(
      onTap: isLocked
          ? () {
              showDialog<void>(
                context: context,
                builder: (BuildContext dialogContext) {
                  final PlanOption currentPlan = appState.currentPlan;
                  final List<PlanOption> paidPlans =
                      appState.plans
                          .where((PlanOption plan) => plan.isPaid)
                          .toList()
                        ..sort(
                          (PlanOption a, PlanOption b) =>
                              a.price.compareTo(b.price),
                        );
                  final PlanOption recommendedPlan = paidPlans.isNotEmpty
                      ? paidPlans.first
                      : currentPlan;
                  return AlertDialog(
                    title: const Text('Upgrade required'),
                    content: Text(
                      'Upgrade your plan to unlock ${subject.title}.',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Not now'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                              builder: (_) => HomeShell(
                                initialIndex: 0,
                                initialPlanId: recommendedPlan.id,
                              ),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        child: const Text('View Plans'),
                      ),
                    ],
                  );
                },
              );
            }
          : () {
              setState(() {
                _selected = subject;
              });
              _openQuestionCountModal(
                subject: subject,
                appState: context.read<AppState>(),
              );
            },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLocked
                  ? subject.color.withValues(alpha: 0.35)
                  : subject.color,
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
            child: Opacity(
              opacity: isLocked ? 0.65 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    subject.groupLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subject.code,
                    style: GoogleFonts.redHatDisplay(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        subject.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
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
          ),
          if (isLocked)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _flickerOpacity,
                builder: (BuildContext context, Widget? child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: _flickerOpacity.value,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: child,
                  );
                },
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 20,
                      color: AppPalette.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool planExpired =
        appState.isFreeTrialExpired || appState.isSubscriptionExpired;
    final bool blockSubjectAccess = planExpired && !appState.hasActivePaidPlan;
    final List<SubjectItem> subjects = appState.practiceSubjects;
    final List<MapEntry<String, List<SubjectItem>>> groupedSubjects =
        _groupSubjects(subjects);
    final Set<String> accessibleIds = subjects
        .where((SubjectItem item) => item.isAccessible && !blockSubjectAccess)
        .map((SubjectItem item) => item.id)
        .toSet();
    final List<QuizAttemptItem> attempts = appState.quizAttempts;
    final int visibleCount = attempts.length;
    final bool canLoadMore = appState.hasMoreQuizAttempts;
    final DateFormat formatter = DateFormat('MMM dd, yyyy hh:mm a');
    String formatAttemptDate(DateTime value) {
      try {
        return formatter.format(value);
      } catch (_) {
        return value.toIso8601String();
      }
    }

    final List<SubjectItem> unlockedSubjects = subjects
        .where((SubjectItem item) => accessibleIds.contains(item.id))
        .toList();

    if (subjects.isNotEmpty &&
        (_selected == null ||
            !subjects.any((SubjectItem item) => item.id == _selected!.id))) {
      _selected = unlockedSubjects.isNotEmpty ? unlockedSubjects.first : null;
    }

    if (_selectedAttemptIds.isNotEmpty) {
      final Set<int> attemptIds = attempts
          .map((QuizAttemptItem item) => item.id)
          .toSet();
      if (_selectedAttemptIds.any((int id) => !attemptIds.contains(id))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedAttemptIds.removeWhere(
              (int id) => !attemptIds.contains(id),
            );
          });
        });
      }
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

    if (subjects.isEmpty &&
        (appState.loadingPracticeSubjects ||
            !appState.practiceSubjectsLoaded)) {
      return const _PracticeSkeletonList();
    }

    if (subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No subjects available yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AppPalette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshReview(appState),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (appState.loadingPracticeSubjects)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: LinearProgressIndicator(),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Explore your OPTIONS.',
                    style: GoogleFonts.redHatDisplay(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Philippine Nurses Licensure Exam (PNLE) Review',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (blockSubjectAccess)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppPalette.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    appState.isFreeTrialExpired
                        ? 'Free trial expired. Choose a paid plan to unlock review subjects.'
                        : 'Subscription expired. Renew your plan to unlock review subjects.',
                    style: GoogleFonts.manrope(
                      color: AppPalette.textDark,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          for (final MapEntry<String, List<SubjectItem>> group
              in groupedSubjects) ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${group.value.length}',
                        style: GoogleFonts.manrope(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.key,
                        style: GoogleFonts.redHatDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primary,
                        ),
                      ),
                    ),
                    if (group.value.length > 4) ...<Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GroupSubjectsScreen(
                                title: group.key,
                                subjects: group.value,
                                accessibleIds: accessibleIds,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Show all',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            color: AppPalette.primary,
                            decoration: TextDecoration.underline,
                            decorationThickness: 2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    const double crossAxisSpacing = 10;
                    const double mainAxisSpacing = 10;
                    const int crossAxisCount = 2;
                    const double childAspectRatio = 1.2;
                    const double groupHorizontalPadding = 10;
                    final List<SubjectItem> previewSubjects = group.value
                        .take(4)
                        .toList();

                    if (previewSubjects.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final double availableWidth =
                        constraints.maxWidth - (groupHorizontalPadding * 2);
                    final double tileWidth =
                        (availableWidth - crossAxisSpacing) / crossAxisCount;
                    final double tileHeight = tileWidth / childAspectRatio;
                    final int rows = (previewSubjects.length / crossAxisCount)
                        .ceil();
                    final double gridHeight =
                        (tileHeight * rows) +
                        (rows > 1 ? mainAxisSpacing * (rows - 1) : 0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: groupHorizontalPadding,
                      ),
                      child: SizedBox(
                        height: gridHeight,
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: crossAxisSpacing,
                                mainAxisSpacing: mainAxisSpacing,
                                childAspectRatio: childAspectRatio,
                              ),
                          itemCount: previewSubjects.length,
                          itemBuilder: (BuildContext context, int index) {
                            final SubjectItem subject = previewSubjects[index];
                            final bool isLocked = !accessibleIds.contains(
                              subject.id,
                            );
                            final bool selected =
                                !isLocked && subject.id == _selected?.id;
                            return _buildSubjectCard(
                              context: context,
                              subject: subject,
                              isLocked: isLocked,
                              selected: selected,
                              appState: appState,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                'Recent Attempts',
                style: GoogleFonts.redHatDisplay(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                ),
              ),
            ),
          ),
          if (attempts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: <Widget>[
                    if (_hasSelectedAttempts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_selectedAttemptIds.length} selected',
                            style: GoogleFonts.manrope(
                              color: AppPalette.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: appState.loadingQuizAttempts
                                ? null
                                : () => _confirmClearAll(appState),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppPalette.primary.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Clear all',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                color: AppPalette.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                !_hasSelectedAttempts ||
                                    appState.loadingQuizAttempts
                                ? null
                                : () => _confirmDeleteSelected(appState),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Delete selected',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (attempts.isEmpty && appState.loadingQuizAttempts)
            const SliverToBoxAdapter(child: _AttemptsSkeletonList())
          else if (attempts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'No attempts yet. Start a practice set to see your results.',
                    style: GoogleFonts.manrope(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (attempts.isNotEmpty)
            SliverList.builder(
              itemCount: visibleCount,
              itemBuilder: (BuildContext context, int index) {
                final QuizAttemptItem item = attempts[index];
                final int percent = item.total == 0
                    ? 0
                    : ((item.score / item.total) * 100).round();
                final bool passed = percent >= 75;
                final Color percentColor =
                    passed ? AppPalette.success : AppPalette.secondary;

                final bool isSelected = _selectedAttemptIds.contains(item.id);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                  child: Row(
                    children: <Widget>[
                      Checkbox(
                        value: isSelected,
                        activeColor: AppPalette.primary,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedAttemptIds.add(item.id);
                            } else {
                              _selectedAttemptIds.remove(item.id);
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            final result = await appState
                                .loadQuizAttemptDetails(item.id);
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context, rootNavigator: true).pop();

                            if (!result.ok || result.data == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.message ??
                                        'Unable to load attempt details.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final QuizAttemptDetail detail = result.data!;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RationalizationScreen(
                                  subject: detail.subject,
                                  questions: detail.questions,
                                  answers: detail.answers,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppPalette.primary.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppPalette.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    item.subjectCode,
                                    style: GoogleFonts.manrope(
                                      color: AppPalette.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text.rich(
                                        TextSpan(
                                          children: <InlineSpan>[
                                            TextSpan(
                                              text:
                                                  '${item.score}/${item.total}  ',
                                            ),
                                            TextSpan(
                                              text: '$percent%',
                                              style: TextStyle(
                                                color: percentColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.redHatDisplay(
                                          color: AppPalette.textDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20,
                                        ),
                                      ),
                                      Text(
                                        item.subjectTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          color: AppPalette.muted,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        formatAttemptDate(item.completedAt),
                                        style: GoogleFonts.manrope(
                                          color: AppPalette.muted,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppPalette.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (canLoadMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: OutlinedButton(
                  onPressed: appState.loadingQuizAttempts
                      ? null
                      : () {
                          context.read<AppState>().loadQuizAttempts(
                            loadMore: true,
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppPalette.primary.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: appState.loadingQuizAttempts
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Load 5 more attempts',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.primary,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GroupSubjectsScreen extends StatefulWidget {
  const GroupSubjectsScreen({
    super.key,
    required this.title,
    required this.subjects,
    required this.accessibleIds,
  });

  final String title;
  final List<SubjectItem> subjects;
  final Set<String> accessibleIds;

  @override
  State<GroupSubjectsScreen> createState() => _GroupSubjectsScreenState();
}

class _GroupSubjectsScreenState extends State<GroupSubjectsScreen>
    with SingleTickerProviderStateMixin {
  SubjectItem? _selected;
  late final AnimationController _flickerController;
  late final Animation<double> _flickerOpacity;

  @override
  void initState() {
    super.initState();
    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _flickerOpacity = Tween<double>(begin: 0.08, end: 0.18).animate(
      CurvedAnimation(parent: _flickerController, curve: Curves.easeInOut),
    );
    final List<SubjectItem> unlocked = widget.subjects
        .where((SubjectItem item) => widget.accessibleIds.contains(item.id))
        .toList();
    _selected = unlocked.isNotEmpty ? unlocked.first : null;
  }

  @override
  void dispose() {
    _flickerController.dispose();
    super.dispose();
  }

  Future<void> _openQuestionCountModal({
    required SubjectItem subject,
    required AppState appState,
  }) async {
    final int maxBySubject = subject.maxQuestionsPerSet > 0
        ? (subject.maxQuestionsPerSet < subject.totalQuestions
              ? subject.maxQuestionsPerSet
              : subject.totalQuestions)
        : subject.totalQuestions;
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

    const List<int> preferredItemCounts = <int>[10, 25, 50, 75, 100];
    final List<int> itemCountOptions = preferredItemCounts
        .where((int count) => count <= maxCount)
        .toList();
    if (itemCountOptions.isEmpty) {
      itemCountOptions.add(maxCount);
    }
    int chosenCount = itemCountOptions.contains(25)
        ? 25
        : itemCountOptions.first;
    int chosenSecondsPerQuestion = 60;
    const List<int> secondOptions = <int>[30, 45, 60, 90, 120];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        bool starting = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                      subject.title,
                      style: GoogleFonts.redHatDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Number of items and time allotted for each question.',
                      style: GoogleFonts.manrope(
                        color: AppPalette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _SelectorColumn(
                            title: 'Number of Items',
                            titleColor: const Color(0xFF13A44A),
                            options: itemCountOptions
                                .map(
                                  (int count) => _SelectorOption(
                                    value: count,
                                    label: '$count',
                                  ),
                                )
                                .toList(),
                            selectedValue: chosenCount,
                            onChanged: (int value) {
                              setModalState(() {
                                chosenCount = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SelectorColumn(
                            title: 'Time allotted for each question',
                            titleColor: AppPalette.primary,
                            options: secondOptions
                                .map(
                                  (int seconds) => _SelectorOption(
                                    value: seconds,
                                    label: switch (seconds) {
                                      30 => '30 seconds',
                                      45 => '45 seconds',
                                      60 => '1 minute',
                                      90 => '1 minute & 30 seconds',
                                      120 => '2 minutes',
                                      _ => '$seconds seconds',
                                    },
                                  ),
                                )
                                .toList(),
                            selectedValue: chosenSecondsPerQuestion,
                            onChanged: (int value) {
                              setModalState(() {
                                chosenSecondsPerQuestion = value;
                              });
                            },
                          ),
                        ),
                      ],
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
                    Column(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: starting
                                ? null
                                : () => Navigator.of(modalContext).pop(),
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
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: starting
                                ? null
                                : () async {
                                    setModalState(() {
                                      starting = true;
                                    });

                                    final NavigatorState rootNavigator =
                                        Navigator.of(this.context);
                                    final NavigatorState sheetNavigator =
                                        Navigator.of(modalContext);

                                    sheetNavigator.pop();
                                    rootNavigator.push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PreparingReviewScreen(
                                          subject: subject,
                                          count: chosenCount,
                                          secondsPerQuestion:
                                              chosenSecondsPerQuestion,
                                        ),
                                      ),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              minimumSize: const Size.fromHeight(50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Start Review',
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                      ),
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

  Widget _buildSubjectCard({
    required BuildContext context,
    required SubjectItem subject,
    required bool isLocked,
    required bool selected,
    required AppState appState,
  }) {
    return GestureDetector(
      onTap: isLocked
          ? () {
              showDialog<void>(
                context: context,
                builder: (BuildContext dialogContext) {
                  final PlanOption currentPlan = appState.currentPlan;
                  final List<PlanOption> paidPlans =
                      appState.plans
                          .where((PlanOption plan) => plan.isPaid)
                          .toList()
                        ..sort(
                          (PlanOption a, PlanOption b) =>
                              a.price.compareTo(b.price),
                        );
                  final PlanOption recommendedPlan = paidPlans.isNotEmpty
                      ? paidPlans.first
                      : currentPlan;
                  return AlertDialog(
                    title: const Text('Upgrade required'),
                    content: Text(
                      'Upgrade your plan to unlock ${subject.title}.',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Not now'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                              builder: (_) => HomeShell(
                                initialIndex: 0,
                                initialPlanId: recommendedPlan.id,
                              ),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        child: const Text('View Plans'),
                      ),
                    ],
                  );
                },
              );
            }
          : () {
              setState(() {
                _selected = subject;
              });
              _openQuestionCountModal(
                subject: subject,
                appState: context.read<AppState>(),
              );
            },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLocked
                  ? subject.color.withValues(alpha: 0.35)
                  : subject.color,
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
            child: Opacity(
              opacity: isLocked ? 0.65 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    subject.groupLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subject.code,
                    style: GoogleFonts.redHatDisplay(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        subject.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
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
          ),
          if (isLocked)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _flickerOpacity,
                builder: (BuildContext context, Widget? child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: _flickerOpacity.value,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: child,
                  );
                },
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 20,
                      color: AppPalette.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    const double crossAxisSpacing = 12;
    const double mainAxisSpacing = 12;
    const int crossAxisCount = 2;
    const double childAspectRatio = 1.2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.redHatDisplay(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: widget.subjects.length,
            itemBuilder: (BuildContext context, int index) {
              final SubjectItem subject = widget.subjects[index];
              final bool isLocked = !widget.accessibleIds.contains(subject.id);
              final bool selected = !isLocked && subject.id == _selected?.id;
              return _buildSubjectCard(
                context: context,
                subject: subject,
                isLocked: isLocked,
                selected: selected,
                appState: appState,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SelectorOption {
  const _SelectorOption({required this.value, required this.label});

  final int value;
  final String label;
}

class _SelectorColumn extends StatelessWidget {
  const _SelectorColumn({
    required this.title,
    required this.titleColor,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final String title;
  final Color titleColor;
  final List<_SelectorOption> options;
  final int selectedValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: GoogleFonts.manrope(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        ...options.map((option) {
          final bool selected = option.value == selectedValue;
          return InkWell(
            onTap: () => onChanged(option.value),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF5FA741)
                            : const Color(0xFF5FA741),
                        width: 2,
                      ),
                      color: selected
                          ? const Color(0xFF5FA741).withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    child: selected
                        ? const Icon(
                            Icons.circle,
                            size: 8,
                            color: Color(0xFF5FA741),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.label,
                      style: GoogleFonts.manrope(
                        color: AppPalette.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PracticeSkeletonList extends StatelessWidget {
  const _PracticeSkeletonList();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: <Widget>[
          const SkeletonBox(height: 14, width: 120, borderRadius: 8),
          const SizedBox(height: 10),
          const SkeletonBox(height: 32, width: 260, borderRadius: 14),
          const SizedBox(height: 8),
          const SkeletonBox(height: 14, width: 220, borderRadius: 10),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List<Widget>.generate(
                  6,
                  (int index) => Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppPalette.primary.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SkeletonBox(
                          height: 12,
                          width: 80,
                          borderRadius: 8,
                        ),
                        const SizedBox(height: 10),
                        const SkeletonBox(
                          height: 10,
                          width: 120,
                          borderRadius: 8,
                        ),
                        const SizedBox(height: 6),
                        const SkeletonBox(
                          height: 8,
                          width: 90,
                          borderRadius: 8,
                        ),
                        const SizedBox(height: 14),
                        const SkeletonBox(
                          height: 32,
                          width: double.infinity,
                          borderRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AttemptsSkeletonList extends StatelessWidget {
  const _AttemptsSkeletonList();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: List<Widget>.generate(
            3,
            (int index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppPalette.primary.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const SkeletonBox.circle(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SkeletonBox(
                          height: 12,
                          width: double.infinity,
                          borderRadius: 8,
                        ),
                        const SizedBox(height: 8),
                        const SkeletonBox(
                          height: 10,
                          width: 160,
                          borderRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SkeletonBox(height: 22, width: 54, borderRadius: 999),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
