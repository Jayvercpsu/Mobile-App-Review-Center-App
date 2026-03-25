import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../home_shell.dart';
import '../quiz_screen.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
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
      CurvedAnimation(
        parent: _flickerController,
        curve: Curves.easeInOut,
      ),
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
                    Text(
                      'Number of items: ${sliderValue.round()}',
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
                    const SizedBox(height: 10),
                    Text(
                      'Time allotted for each question',
                      style: GoogleFonts.manrope(
                        color: AppPalette.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: secondOptions.map((int seconds) {
                        final bool selected = chosenSecondsPerQuestion == seconds;
                        final String label = switch (seconds) {
                          30 => '30 sec',
                          45 => '45 sec',
                          60 => '1 min',
                          90 => '1m 30s',
                          120 => '2 mins',
                          _ => '$seconds sec',
                        };
                        return ChoiceChip(
                          selected: selected,
                          onSelected: (bool value) {
                            if (!value) {
                              return;
                            }
                            setModalState(() {
                              chosenSecondsPerQuestion = seconds;
                            });
                          },
                          label: Text(
                            label,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : AppPalette.textDark,
                            ),
                          ),
                          selectedColor: AppPalette.primary,
                          backgroundColor: AppPalette.primary.withValues(
                            alpha: 0.08,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: selected
                                  ? AppPalette.primary
                                  : AppPalette.primary.withValues(alpha: 0.2),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Column(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
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
                                      'click to START THE TEST NOW',
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

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final List<SubjectItem> subjects = appState.practiceSubjects;
    final Set<String> accessibleIds = subjects
        .where((SubjectItem item) => item.isAccessible)
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
      final Set<int> attemptIds =
          attempts.map((QuizAttemptItem item) => item.id).toSet();
      if (_selectedAttemptIds.any((int id) => !attemptIds.contains(id))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedAttemptIds
                .removeWhere((int id) => !attemptIds.contains(id));
          });
        });
      }
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

    return CustomScrollView(
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
              final bool isLocked = !accessibleIds.contains(subject.id);
              final bool selected = !isLocked && subject.id == _selected?.id;
              return GestureDetector(
                onTap: isLocked
                    ? () {
                        showDialog<void>(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            final PlanOption currentPlan =
                                appState.currentPlan;
                            final List<PlanOption> paidPlans = appState.plans
                                .where((PlanOption plan) => plan.isPaid)
                                .toList()
                              ..sort(
                                (PlanOption a, PlanOption b) =>
                                    a.price.compareTo(b.price),
                              );
                            final PlanOption recommendedPlan =
                                paidPlans.isNotEmpty
                                    ? paidPlans.first
                                    : currentPlan;
                            return AlertDialog(
                              title: const Text('Upgrade required'),
                              content: Text(
                                'Upgrade your plan to unlock ${subject.title}.',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('Not now'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            HomeShell(
                                              initialIndex: 0,
                                              initialPlanId:
                                                  recommendedPlan.id,
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
            }, childCount: subjects.length),
          ),
        ),
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
                              color: AppPalette.primary.withValues(alpha: 0.25),
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
                          onPressed: !_hasSelectedAttempts ||
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
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          )
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

                          final result =
                              await appState.loadQuizAttemptDetails(item.id);
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
                              color:
                                  AppPalette.primary.withValues(alpha: 0.08),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${item.score}/${item.total}  $percent%',
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
    );
  }
}
