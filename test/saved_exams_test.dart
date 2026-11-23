import 'dart:convert';

import 'package:bayan/data/local/docx/exam_docx_builder.dart';
import 'package:bayan/data/local/saved_exam_store.dart';
import 'package:bayan/domain/models/exam_paper.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/models/progress.dart';
import 'package:bayan/domain/models/saved_exam.dart';
import 'package:bayan/presentation/state/exam_autosaver.dart';
import 'package:bayan/presentation/state/exam_composer_state.dart';
import 'package:bayan/presentation/state/saved_exam_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// A clock that advances one minute per reading, so ordering is deterministic.
DateTime Function() _steppingClock() {
  var now = DateTime.utc(2026, 11, 23, 9);
  return () => now = now.add(const Duration(minutes: 1));
}

ArabicExamPaper _customPaper(ArabicExamPaper base) => base.copyWith(
      header: base.header.copyWith(
        schoolName: 'متوسطة الحلة للبنين',
        teacherName: 'أمير حسن',
        showAdditionalHeaderLines: true,
        includeStudentFields: true,
        examDate: '2026/11/23',
        studentNameLabel: 'اسم المتعلم :',
      ),
      composition: base.composition.copyWith(
        topics: <String>['موضوع "مقتبس" & رموز < >', 'سطر أول\nسطر ثانٍ'],
      ),
      typography: const ExamTypography(
        font: ExamFontChoice.amiri,
        bodySizePt: 12,
        headingSizePt: 13,
        useWesternDigits: false,
        spacing: ExamSpacing(
          lineHeight: 1.35, itemGapPt: 2.5, branchGapPt: 7, questionGapPt: 11,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exam papers round-trip through JSON without losing anything', () async {
    final content = await loadTestContent();
    for (final template in content.examBank.officialTemplates) {
      final paper = _customPaper(template.toExamPaper());
      final encoded = jsonEncode(paper.toJson());
      final restored = ArabicExamPaper.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(jsonEncode(restored.toJson()), encoded);
      // The restored paper exports byte-for-byte the same Word file.
      expect(ExamDocxBuilder.build(restored), ExamDocxBuilder.build(paper));
      expect(restored.typography.font, ExamFontChoice.amiri);
      expect(restored.typography.spacing.questionGapPt, 11);
      expect(restored.header.studentNameLabel, 'اسم المتعلم :');
      final firstBranch = restored.grammar.questions.first.branches.first;
      final sourceBranch = paper.grammar.questions.first.branches.first;
      expect(firstBranch.branch, sourceBranch.branch);
      expect(firstBranch.itemLayout, sourceBranch.itemLayout);
    }
  });

  test('a standalone branch keeps its empty letter after a round trip', () {
    const paper = ArabicExamPaper(
      header: ExamHeader(),
      composition: ExamCompositionSection(topics: <String>[]),
      grammar: ExamQuestionSection(degree: 10, questions: <ExamQuestionBlock>[
        ExamQuestionBlock(number: 1, branches: <ExamBranch>[
          ExamBranch(branch: '', prompt: 'أ', degree: 5, items: <String>[]),
          ExamBranch(branch: '', prompt: 'ب', degree: 5, items: <String>[],
              itemLayout: ExamItemLayout.prose),
        ]),
      ]),
      orthography: ExamQuestionSection(degree: 0, questions: <ExamQuestionBlock>[]),
    );
    final restored = ArabicExamPaper.fromJson(
      jsonDecode(jsonEncode(paper.toJson())) as Map<String, dynamic>,
    );
    final branches = restored.grammar.questions.single.branches;
    expect(branches.map((b) => b.branch), <String>['', '']);
    expect(branches.last.itemLayout, ExamItemLayout.prose);
  });

  test('damaged or out-of-range values are clamped instead of crashing', () {
    final typography = ExamTypography.fromJson(<String, dynamic>{
      'font': 'no-such-font',
      'bodySizePt': 99,
      'spacing': <String, dynamic>{
        'lineHeight': 9, 'itemGapPt': -4, 'branchGapPt': 100,
      },
    });
    expect(typography.font, ExamFontChoice.arial);
    expect(typography.bodySizePt, 18);
    expect(typography.headingSizePt, 19);
    expect(typography.spacing.lineHeight, 2);
    expect(typography.spacing.itemGapPt, 0);
    expect(typography.spacing.branchGapPt, 18);
    expect(typography.spacing.questionGapPt, const ExamSpacing().questionGapPt);
    expect(ExamHeader.fromJson(const <String, dynamic>{}).studentNameLabel,
        const ExamHeader().studentNameLabel);
  });

  test('the store skips damaged records and duplicate ids, keeping the rest', () async {
    final content = await loadTestContent();
    final paper = content.examBank.officialTemplates.first.toExamPaper();
    final good = SavedExamPaper(
      id: 'a', paper: paper,
      createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026, 2),
      customTitle: 'نصف السنة', revision: 4,
    );
    final raw = jsonEncode(<String, dynamic>{
      'version': 1,
      'papers': <dynamic>[
        good.toJson(),
        <String, dynamic>{'id': 'broken'},
        'not a record',
        good.toJson(),
      ],
    });
    final decoded = SavedExamStore.decode(raw);
    expect(decoded, hasLength(1));
    expect(decoded.single.id, 'a');
    expect(decoded.single.revision, 4);
    expect(decoded.single.displayTitle, 'نصف السنة');
    expect(decoded.single.updatedAt, DateTime.utc(2026, 2));
    expect(SavedExamStore.decode('{not json'), isEmpty);
    expect(SavedExamStore.decode('[1,2]'), isEmpty);
    expect(SavedExamStore.decode(null), isEmpty);
  });

  test('the library creates, versions, reorders, copies, renames and deletes', () async {
    final content = await loadTestContent();
    final templates = content.examBank.officialTemplates;
    final store = MemorySavedExamStore();
    final library = SavedExamLibrary(store, clock: _steppingClock());
    var notifications = 0;
    library.addListener(() => notifications++);

    final first = library.save(templates[0].toExamPaper());
    final second = library.save(templates[1].toExamPaper());
    expect(library.papers.map((p) => p.id), <String>[second.id, first.id]);
    expect(first.revision, 1);
    expect(first.displayTitle, contains(templates[0].examTitle));

    // A new version updates the same record and moves it to the top.
    final edited = templates[0].toExamPaper().copyWith(
      composition: templates[0].composition.copyWith(degree: 25),
    );
    final updated = library.save(edited, id: first.id);
    expect(updated.id, first.id);
    expect(updated.revision, 2);
    expect(updated.createdAt, first.createdAt);
    expect(updated.updatedAt.isAfter(first.updatedAt), isTrue);
    expect(library.papers.first.id, first.id);
    expect(library.papers, hasLength(2));

    // Saving the identical paper object again is a no-op.
    final before = notifications;
    expect(library.save(edited, id: first.id).revision, 2);
    expect(notifications, before);

    final copy = library.duplicate(first.id)!;
    expect(copy.id, isNot(first.id));
    expect(copy.paper.composition.degree, 25);
    expect(copy.displayTitle, endsWith('(نسخة)'));
    expect(library.rename(second.id, '  ورقة الدور الثاني  '), isTrue);
    expect(library.byId(second.id)!.displayTitle, 'ورقة الدور الثاني');
    expect(library.rename(second.id, ''), isTrue);
    expect(library.byId(second.id)!.displayTitle, contains(templates[1].examTitle));
    expect(library.delete(copy.id), isTrue);
    expect(library.delete(copy.id), isFalse);
    expect(library.duplicate('missing'), isNull);
    expect(library.rename('missing', 'x'), isFalse);

    // Everything reaches the store and is restored newest first.
    await library.flush();
    final reopened = SavedExamLibrary(store);
    expect(reopened.papers.map((p) => p.id), library.papers.map((p) => p.id));
    expect(reopened.byId(first.id)!.revision, 2);
    expect(reopened.byId(first.id)!.paper.composition.degree, 25);
  });

  test('bursts of edits coalesce into few writes and the last one wins', () async {
    final content = await loadTestContent();
    final store = MemorySavedExamStore();
    final library = SavedExamLibrary(store);
    var paper = content.examBank.officialTemplates.first.toExamPaper();
    final id = library.save(paper).id;
    for (var i = 0; i < 50; i++) {
      paper = paper.copyWith(header: paper.header.copyWith(schoolName: 'مدرسة $i'));
      library.save(paper, id: id);
    }
    await library.flush();
    expect(store.writeCount, lessThanOrEqualTo(2));
    expect(store.read().single.paper.header.schoolName, 'مدرسة 49');
    expect(store.read().single.revision, 51);
    expect(library.lastWriteError, isNull);
  });

  test('a failing store is reported without losing the in-memory papers', () async {
    final content = await loadTestContent();
    final library = SavedExamLibrary(_FailingStore());
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    library.save(content.examBank.officialTemplates.first.toExamPaper());
    await library.flush();
    expect(library.papers, hasLength(1));
    expect(library.lastWriteError, isA<StateError>());
    expect(errors, hasLength(1));
  });

  test('the autosaver stores the first edit and every later version', () async {
    final content = await loadTestContent();
    final library = SavedExamLibrary(MemorySavedExamStore());
    final controller = ExamComposerController(
      examBank: content.examBank,
      teacherProfile: const TeacherProfile(teacherName: 'أمير حسن'),
      activePart: CurriculumPart.part2,
    );
    final autosaver = ExamAutosaver(controller: controller, library: library);
    addTearDown(controller.dispose);

    // Opening the composer alone does not create a record.
    expect(library.isEmpty, isTrue);
    expect(autosaver.hasSavedCopy, isFalse);

    controller.updateGrammarDegree(30);
    final id = autosaver.savedId!;
    expect(library.byId(id)!.paper.grammar.degree, 30);
    controller.updateHeader(controller.paper.header.copyWith(schoolName: 'متوسطة بابل'));
    controller.loadOfficialTemplate(content.examBank.officialTemplates.first);
    expect(library.papers, hasLength(1));
    expect(library.byId(id)!.revision, 3);
    expect(library.byId(id)!.paper.header.schoolName, 'متوسطة بابل');
    expect(identical(library.byId(id)!.paper, controller.paper), isTrue);
    expect(autosaver.saveNow().revision, 3, reason: 'unchanged paper');

    autosaver.dispose();
    controller.updateGrammarDegree(35);
    expect(library.byId(id)!.revision, 3, reason: 'no saves after dispose');

    // Reopening continues the same record from its saved paper.
    final reopenedController = ExamComposerController(
      examBank: content.examBank,
      teacherProfile: const TeacherProfile(),
      activePart: CurriculumPart.part1,
      initialPaper: library.byId(id)!.paper,
    );
    addTearDown(reopenedController.dispose);
    final reopened = ExamAutosaver(
      controller: reopenedController, library: library, savedId: id,
    );
    addTearDown(reopened.dispose);
    expect(reopenedController.paper.header.schoolName, 'متوسطة بابل');
    reopenedController.updateOrthographyDegree(20);
    expect(library.papers, hasLength(1));
    expect(library.byId(id)!.revision, 4);
    expect(library.byId(id)!.paper.orthography.degree, 20);
  });
}

class _FailingStore implements SavedExamStore {
  @override
  List<SavedExamPaper> read() => const <SavedExamPaper>[];

  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    throw StateError('disk full');
  }
}
