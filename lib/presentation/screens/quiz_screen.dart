import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String _selectedUnitId = 'all';
  List<_QuizEntry>? _activeSession;
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _answeredCurrent = false;
  bool _lastCorrect = false;

  void _startQuiz(AppState state) {
    final units = _selectedUnitId == 'all'
        ? state.partUnits
        : state.partUnits.where((u) => u.id == _selectedUnitId).toList();
    final pool = <_QuizEntry>[];
    for (final u in units) {
      for (final q in u.questions) {
        if (q.kind == QuestionKind.trueFalse || q.kind == QuestionKind.choice) {
          pool.add(_QuizEntry(unitTitle: u.displayTitle, question: q));
        }
      }
    }
    pool.shuffle(Random());
    final selected = pool.take(10).toList(growable: false);
    if (selected.isEmpty) {
      return;
    }
    setState(() {
      _activeSession = selected;
      _currentIndex = 0;
      _correctCount = 0;
      _answeredCurrent = false;
    });
  }

  void _submitAnswer(AppState state, bool isCorrect) {
    if (_answeredCurrent) {
      return;
    }
    setState(() {
      _answeredCurrent = true;
      _lastCorrect = isCorrect;
      if (isCorrect) {
        _correctCount++;
      }
    });
  }

  void _nextQuestion(AppState state) {
    final session = _activeSession!;
    if (_currentIndex + 1 >= session.length) {
      final scopeLabel = _selectedUnitId == 'all'
          ? state.partTitle
          : (state.library.unitById(_selectedUnitId)?.displayTitle ??
                state.partTitle);
      state.recordQuizScore(
        scopeLabel: scopeLabel,
        correct: _correctCount,
        total: session.length,
      );
      setState(() {
        _activeSession = null;
      });
      return;
    }
    setState(() {
      _currentIndex++;
      _answeredCurrent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = state.partUnits;
    if (_selectedUnitId != 'all' &&
        !units.any((u) => u.id == _selectedUnitId)) {
      _selectedUnitId = 'all';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('الاختبار التفاعلي — ${state.partTitle}'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: _activeSession == null
                ? _buildLobby(context, state, units, theme, scheme)
                : _buildActiveQuiz(context, state, theme, scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby(
    BuildContext context,
    AppState state,
    List<Unit> units,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final history = state.progress.quizHistory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'اختبر إتقانك للمنهج مع التصحيح الفوري والشاهد التوضيحي',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _selectedUnitId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'نطاق الاختبار',
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'all',
                    child: Text('شامل لجميع وحدات ${state.partTitle}'),
                  ),
                  for (final u in units)
                    DropdownMenuItem<String>(
                      value: u.id,
                      child: Text('${u.displayTitle} (${u.grammarTitle})'),
                    ),
                ],
                onChanged: (String? v) {
                  if (v != null) {
                    setState(() => _selectedUnitId = v);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey<String>('start-quiz-button'),
                onPressed: () => _startQuiz(state),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('بدء جولة الاختبار'),
              ),
            ],
          ),
        ),
        if (history.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: 'سجل نتائجك السابقة',
            accent: scheme.secondary,
          ),
          for (final score in history)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${toArabicDigits(score.correct)}/${toArabicDigits(score.total)}',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                title: Text(score.scopeLabel),
                subtitle: Text(
                  'نسبة الإتقان: ${toArabicDigits(((score.correct / score.total) * 100).round())}٪',
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActiveQuiz(
    BuildContext context,
    AppState state,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final session = _activeSession!;
    final entry = session[_currentIndex];
    final q = entry.question;
    final okColor = AppColors.resolveAccent('green', theme.brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'السؤال ${toArabicDigits(_currentIndex + 1)} من ${toArabicDigits(session.length)}',
              style: theme.textTheme.labelLarge,
            ),
            TextButton(
              onPressed: () => setState(() => _activeSession = null),
              child: const Text('إنهاء الجولة'),
            ),
          ],
        ),
        LinearProgressIndicator(
          value: (_currentIndex + 1) / session.length,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(entry.unitTitle, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(q.prompt, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              if (q.kind == QuestionKind.trueFalse)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _answeredCurrent
                            ? null
                            : () => _submitAnswer(state, q.boolAnswer == true),
                        child: const Text('صح'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _answeredCurrent
                            ? null
                            : () => _submitAnswer(state, q.boolAnswer == false),
                        child: const Text('خطأ'),
                      ),
                    ),
                  ],
                )
              else
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: AlignmentDirectional.centerStart,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _answeredCurrent
                          ? null
                          : () => _submitAnswer(state, q.answerIndex == i),
                      child: Text(q.options[i]),
                    ),
                  ),
              if (_answeredCurrent) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: (_lastCorrect ? okColor : scheme.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _lastCorrect ? 'إجابة صحيحة! أحسنت.' : 'الإجابة الصحيحة:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _lastCorrect ? okColor : scheme.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(q.displayAnswer, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => _nextQuestion(state),
                  child: Text(
                    _currentIndex + 1 >= session.length
                        ? 'حفظ النتيجة وإنهاء الاختبار'
                        : 'السؤال التالي',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizEntry {
  const _QuizEntry({required this.unitTitle, required this.question});

  final String unitTitle;
  final Question question;
}
