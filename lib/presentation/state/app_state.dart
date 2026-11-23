import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/progress_store.dart';
import '../../data/local/saved_exam_store.dart';
import '../../domain/models/exam_paper.dart';
import '../../domain/models/library.dart';
import '../../domain/models/progress.dart';
import '../../domain/services/search_engine.dart';
import 'saved_exam_library.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.library,
    required this.examBank,
    required ProgressStore store,
    StudyProgress? initialProgress,
    SavedExamLibrary? savedExams,
  })  : _store = store,
        _progress = initialProgress ?? store.read(),
        searchEngine = CurriculumSearchEngine(library),
        savedExams = savedExams ?? SavedExamLibrary(MemorySavedExamStore());

  final StudyLibrary library;
  final ExamBank examBank;

  /// Exam papers created by the teacher, autosaved by the composer.
  final SavedExamLibrary savedExams;
  final CurriculumSearchEngine searchEngine;
  final ProgressStore _store;

  StudyProgress _progress;
  int _selectedNavIndex = 0;

  StudyProgress get progress => _progress;
  int get selectedNavIndex => _selectedNavIndex;

  bool get needsOnboarding =>
      !_progress.onboardingCompleted || _progress.selectedPart == null;

  CurriculumPart get activePart =>
      _progress.selectedPart ?? CurriculumPart.part1;

  String get partTitle => activePart.title;

  TeacherProfile get teacherProfile => _progress.teacherProfile;
  ThemeMode get themeMode => _progress.themeMode;
  double get textScale => _progress.textScale;

  /// Units belonging to the currently active semester (`part1` or `part2`).
  List<Unit> get partUnits => library.unitsForPart(activePart);

  /// All units visible in the current context (intro + active part + orthography).
  List<Unit> get visibleUnits {
    final intro = library.unitById('intro');
    final ortho = library.unitById('orthography-expression');
    return <Unit>[
      if (intro != null) intro,
      ...partUnits,
      if (ortho != null) ortho,
    ];
  }

  List<GrammarLesson> get partLessons => library.lessonsForPart(activePart);

  List<GlossaryTerm> get partGlossary => library.glossaryForPart(activePart);

  Unit? get resumeUnit {
    final lastId = _progress.lastUnitId;
    if (lastId != null) {
      final found = library.unitById(lastId);
      if (found != null &&
          (found.part == activePart.id || found.part == 'both')) {
        return found;
      }
    }
    return partUnits.isNotEmpty ? partUnits.first : null;
  }

  void setNavIndex(int index) {
    if (_selectedNavIndex == index) {
      return;
    }
    _selectedNavIndex = index;
    notifyListeners();
  }

  void completeOnboarding({
    required CurriculumPart part,
    String teacherName = '',
    String schoolName = '',
    String directorate = 'المديرية العامة للتربية',
  }) {
    _update(
      _progress.copyWith(
        selectedPart: part,
        onboardingCompleted: true,
        teacherProfile: TeacherProfile(
          teacherName: teacherName.trim(),
          schoolName: schoolName.trim(),
          directorate: directorate.trim().isEmpty
              ? 'المديرية العامة للتربية'
              : directorate.trim(),
        ),
      ),
    );
  }

  void selectPart(CurriculumPart part) {
    _update(
      _progress.copyWith(
        selectedPart: part,
        onboardingCompleted: true,
      ),
    );
  }

  void updateTeacherProfile(TeacherProfile profile) {
    _update(_progress.copyWith(teacherProfile: profile));
  }

  void setThemeMode(ThemeMode mode) {
    _update(_progress.copyWith(themeMode: mode));
  }

  void setTextScale(double scale) {
    final clamped = scale.clamp(0.85, 1.40);
    _update(_progress.copyWith(textScale: clamped));
  }

  void adjustTextScale(double delta) {
    setTextScale(double.parse((_progress.textScale + delta).toStringAsFixed(2)));
  }

  void markUnitVisited(String unitId) {
    final updatedRead = Set<String>.from(_progress.readUnitIds)..add(unitId);
    _update(
      _progress.copyWith(
        lastUnitId: unitId,
        readUnitIds: updatedRead,
      ),
    );
  }

  bool isUnitRead(String unitId) => _progress.readUnitIds.contains(unitId);

  bool isBookmarked(String key) =>
      _progress.bookmarks.any((b) => b.key == key);

  void toggleBookmark(BookmarkItem item) {
    final list = List<BookmarkItem>.from(_progress.bookmarks);
    final idx = list.indexWhere((b) => b.key == item.key);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.insert(0, item);
    }
    _update(_progress.copyWith(bookmarks: list));
  }

  void recordQuizScore({
    required String scopeLabel,
    required int correct,
    required int total,
  }) {
    final next = <QuizScore>[
      QuizScore(
        scopeLabel: scopeLabel,
        correct: correct,
        total: total,
        timestampIso: DateTime.now().toIso8601String(),
      ),
      ..._progress.quizHistory,
    ];
    _update(
      _progress.copyWith(
        quizHistory: next.take(25).toList(growable: false),
      ),
    );
  }

  Future<void> resetStudyProgress() async {
    _progress = StudyProgress(
      selectedPart: _progress.selectedPart,
      onboardingCompleted: _progress.onboardingCompleted,
      teacherProfile: _progress.teacherProfile,
      themeMode: _progress.themeMode,
      textScale: _progress.textScale,
    );
    notifyListeners();
    await _store.write(_progress);
  }

  void _update(StudyProgress next) {
    _progress = next;
    notifyListeners();
    unawaited(_store.write(_progress));
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null && scope.notifier != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
