import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/models/exam_paper.dart';
import '../../domain/models/library.dart';
import '../../domain/models/progress.dart';

/// Mutable controller for composing, customizing, and exporting official
/// First Intermediate Arabic Word (`.docx`) exam papers.
class ExamComposerController extends ChangeNotifier {
  ExamComposerController({
    required this.examBank,
    required TeacherProfile teacherProfile,
    required CurriculumPart activePart,
  }) {
    _paper = _initialPaper(teacherProfile, activePart);
  }

  final ExamBank examBank;
  late ArabicExamPaper _paper;
  final Random _rng = Random();

  ArabicExamPaper get paper => _paper;

  ArabicExamPaper _initialPaper(
    TeacherProfile profile,
    CurriculumPart activePart,
  ) {
    if (examBank.officialTemplates.isNotEmpty) {
      // Load the 2025 First-Round official template by default, personalized
      // with the teacher's saved school, directorate, and name.
      final preferred = examBank.officialTemplates.firstWhere(
        (t) => t.id == 'tpl-final-r1',
        orElse: () => examBank.officialTemplates.first,
      );
      final base = preferred.toExamPaper(
        schoolName: profile.schoolName,
        directorate: profile.directorate,
        teacherName: profile.teacherName,
      );
      if (activePart == CurriculumPart.part1) {
        return _buildSmartGeneratedPaper(
          scope: 'part1',
          baseHeader: base.header.copyWith(
            examTitleLine: 'أسئلة امتحان نصف السنة',
            roundLine: 'نصف السنة',
          ),
          typography: base.typography,
        );
      }
      return base;
    }
    return _buildSmartGeneratedPaper(
      scope: 'both',
      baseHeader: ExamHeader(
        directorateLine: profile.directorate,
        schoolName: profile.schoolName.isEmpty
            ? 'متوسطة ........ للبنين'
            : profile.schoolName,
        teacherName: profile.teacherName,
      ),
      typography: const ExamTypography(),
    );
  }

  /// Loads one of the 4 verbatim official Word templates (`الدور الأول`,
  /// `الدور الثاني`, `الدور الأول 2025`, `الدور الثاني 2025`), preserving the
  /// teacher's school, directorate, and signature.
  void loadOfficialTemplate(OfficialExamTemplate template) {
    final currentH = _paper.header;
    final templatePaper = template.toExamPaper(
      schoolName: currentH.schoolName,
      directorate: currentH.directorateLine,
      teacherName: currentH.teacherName,
    );
    _paper = templatePaper.copyWith(
      header: templatePaper.header.copyWith(
        administrationLine: currentH.administrationLine,
        showAdditionalHeaderLines: currentH.showAdditionalHeaderLines,
        studentNameLabel: currentH.studentNameLabel,
        studentNumberLabel: currentH.studentNumberLabel,
        includeStudentFields: currentH.includeStudentFields,
        countryLine: currentH.countryLine,
        ministryLine: currentH.ministryLine,
        directorateLine: currentH.directorateLine,
        schoolName: currentH.schoolName,
        subjectLine: currentH.subjectLine,
        gradeLine: currentH.gradeLine,
        examDate: currentH.examDate,
        noteLine: currentH.noteLine,
        closingWish: currentH.closingWish,
        teacherTitle: currentH.teacherTitle,
        teacherName: currentH.teacherName,
      ),
      typography: _paper.typography,
    );
    notifyListeners();
  }

  /// Auto-generates a balanced 80-mark (`30 + 35 + 15`) official paper from
  /// `exam_bank.json` for `'part1'` (نصف السنة), `'part2'`, or `'both'` (نهاية السنة).
  void generateBalancedExam({required String scope}) {
    final examTitle = scope == 'part1'
        ? 'أسئلة امتحان نصف السنة'
        : scope == 'part2'
            ? 'أسئلة امتحان الفصل الثاني'
            : 'أسئلة امتحان نهاية السنة';
    final round = scope == 'part1'
        ? 'نصف السنة'
        : scope == 'part2'
            ? 'الفصل الثاني'
            : 'الدور الأول';

    _paper = _buildSmartGeneratedPaper(
      scope: scope,
      baseHeader: _paper.header.copyWith(
        examTitleLine: examTitle,
        roundLine: round,
      ),
      typography: _paper.typography,
    );
    notifyListeners();
  }

  ArabicExamPaper _buildSmartGeneratedPaper({
    required String scope,
    required ExamHeader baseHeader,
    required ExamTypography typography,
  }) {
    bool matchPart(String p) => scope == 'both' || p == scope;

    List<T> pickRandom<T>(List<T> source, int count) {
      final copy = List<T>.from(source)..shuffle(_rng);
      return copy.take(count).toList(growable: false);
    }

    // 1. Composition (2 prompts, 30 marks)
    final compPool = examBank.compositionTopics
        .where((c) => matchPart(c.part))
        .toList(growable: false);
    final chosenComp = pickRandom(
      compPool.isNotEmpty ? compPool : examBank.compositionTopics,
      2,
    ).map((c) => c.text).toList(growable: false);

    // 2. Grammar (3 questions = 15 + 10 + 10 = 35 marks)
    final gPool = examBank.grammarItems
        .where((g) => matchPart(g.part))
        .toList(growable: false);
    final effectiveG = gPool.isNotEmpty ? gPool : examBank.grammarItems;

    List<String> byStyle(String style, int count) {
      final matching =
          effectiveG.where((g) => g.style == style).toList(growable: false);
      final src = matching.length >= count ? matching : effectiveG;
      return pickRandom(src, count).map((g) => g.text).toList(growable: false);
    }

    // Use the source papers as structural blueprints, rather than inventing a
    // second order/mark distribution that diverges from the Word references.
    final blueprints = examBank.officialTemplates.where((t) =>
        t.part == (scope == 'part1' ? 'part1' : 'part2')).toList(growable: false);
    if (blueprints.isNotEmpty) {
      final blueprint = pickRandom(blueprints, 1).single;
      ExamQuestionSection generateSection(bool grammar) {
        final base = grammar ? blueprint.grammar : blueprint.orthography;
        return base.copyWith(questions: <ExamQuestionBlock>[
          for (var qi = 0; qi < base.questions.length; qi++)
            base.questions[qi].copyWith(branches: <ExamBranch>[
              for (var bi = 0; bi < base.questions[qi].branches.length; bi++)
                _generateBlueprintBranch(
                  base.questions[qi].branches[bi],
                  blueprints.map((t) => grammar ? t.grammar : t.orthography),
                  qi, bi,
                  grammar ? effectiveG : const <GrammarBankItem>[],
                ),
            ]),
        ]);
      }
      return ArabicExamPaper(
        header: baseHeader,
        composition: blueprint.composition.copyWith(topics: chosenComp),
        grammar: generateSection(true),
        orthography: generateSection(false),
        typography: typography,
      );
    }

    // Backwards-compatible fallback for custom banks without official sources.
    final grammarSection = ExamQuestionSection(
      degree: 35,
      questions: <ExamQuestionBlock>[
        ExamQuestionBlock(
          number: 1,
          branches: <ExamBranch>[
            ExamBranch(
              branch: 'أ',
              prompt: 'أجب عن أربعة فقط مما يأتي :',
              degree: 8,
              items: byStyle('apply', 5),
            ),
            ExamBranch(
              branch: 'ب',
              prompt: 'ما الفرق بين كل تعبيرين تحتهما خط لثلاث فقط مما يأتي :',
              degree: 7,
              items: byStyle('difference', 4),
            ),
          ],
        ),
        ExamQuestionBlock(
          number: 2,
          branches: <ExamBranch>[
            ExamBranch(
              branch: 'أ',
              prompt: 'أعرب ما تحته خط لخمس فقط مما يأتي :',
              degree: 5,
              items: byStyle('irab', 6),
            ),
            ExamBranch(
              branch: 'ب',
              prompt: 'اختر الإجابة الصحيحة من بين الأقواس لخمس فقط :',
              degree: 5,
              items: byStyle('mcq', 6),
            ),
          ],
        ),
        ExamQuestionBlock(
          number: 3,
          branches: <ExamBranch>[
            ExamBranch(
              branch: '',
              prompt: 'أجب عما يأتي لخمس فقط :',
              degree: 10,
              items: <String>[
                ...byStyle('extract', 3),
                ...byStyle('taqwim', 3),
              ],
            ),
          ],
        ),
      ],
    );

    // 3. Orthography (1 question, 3 branches = 5 + 5 + 5 = 15 marks)
    final oPool = examBank.orthographyItems
        .where((o) => matchPart(o.part))
        .toList(growable: false);
    final chosenOrtho = pickRandom(
      oPool.length >= 3 ? oPool : examBank.orthographyItems,
      3,
    );
    const branchLetters = <String>['أ', 'ب', 'ج'];
    final orthoBranches = <ExamBranch>[];
    for (var i = 0; i < chosenOrtho.length; i++) {
      final item = chosenOrtho[i];
      orthoBranches.add(
        ExamBranch(
          branch: branchLetters[i],
          prompt: item.prompt,
          degree: 5,
          items: item.items,
          itemLayout: item.itemLayout,
        ),
      );
    }

    return ArabicExamPaper(
      header: baseHeader,
      composition: ExamCompositionSection(
        degree: 30,
        prompt: 'اكتب في أحد الموضوعين الآتيين :',
        topics: chosenComp,
      ),
      grammar: grammarSection,
      orthography: ExamQuestionSection(
        degree: 15,
        questions: <ExamQuestionBlock>[
          ExamQuestionBlock(number: 1, branches: orthoBranches),
        ],
      ),
      typography: typography,
    );
  }

  ExamBranch _generateBlueprintBranch(
    ExamBranch base,
    Iterable<ExamQuestionSection> sources,
    int questionIndex,
    int branchIndex,
    List<GrammarBankItem> bank,
  ) {
    final candidates = <ExamBranch>[];
    for (final section in sources) {
      if (questionIndex >= section.questions.length) continue;
      final branches = section.questions[questionIndex].branches;
      if (branchIndex >= branches.length) continue;
      final branch = branches[branchIndex];
      if (branch.degree == base.degree &&
          branch.itemLayout == base.itemLayout &&
          branch.items.length == base.items.length) {
        candidates.add(branch);
      }
    }
    final selected = candidates.isEmpty
        ? base
        : candidates[_rng.nextInt(candidates.length)];
    final prompt = selected.prompt;
    final style = prompt.contains('اعرب') || prompt.contains('أعرب')
        ? 'irab'
        : prompt.contains('اختر')
            ? 'mcq'
            : prompt.contains('الفرق')
                ? 'difference'
                : null;
    // Never silently fill a parsing/MCQ slot with an unrelated question type.
    final matching = bank.where((item) => item.style == style).toList()
      ..shuffle(_rng);
    return style != null && selected.items.isNotEmpty &&
            matching.length >= selected.items.length
        ? selected.copyWith(
            items: matching.take(selected.items.length).map((e) => e.text).toList(),
          )
        : selected;
  }

  void updateHeader(ExamHeader header) {
    _paper = _paper.copyWith(header: header);
    notifyListeners();
  }

  void updateTypography(ExamTypography typography) {
    _paper = _paper.copyWith(typography: typography);
    notifyListeners();
  }

  void updateComposition(ExamCompositionSection composition) {
    _paper = _paper.copyWith(composition: composition);
    notifyListeners();
  }

  void updateGrammarDegree(int degree) {
    _paper = _paper.copyWith(grammar: _paper.grammar.copyWith(degree: degree));
    notifyListeners();
  }

  void updateOrthographyDegree(int degree) {
    _paper = _paper.copyWith(
      orthography: _paper.orthography.copyWith(degree: degree),
    );
    notifyListeners();
  }

  void updateBranch({
    required bool isGrammar,
    required int questionIndex,
    required int branchIndex,
    required ExamBranch updated,
  }) {
    final section = isGrammar ? _paper.grammar : _paper.orthography;
    final questions = List<ExamQuestionBlock>.from(section.questions);
    final q = questions[questionIndex];
    final branches = List<ExamBranch>.from(q.branches);
    branches[branchIndex] = updated;
    questions[questionIndex] = q.copyWith(branches: branches);
    final nextSection = section.copyWith(questions: questions);
    _paper = isGrammar
        ? _paper.copyWith(grammar: nextSection)
        : _paper.copyWith(orthography: nextSection);
    notifyListeners();
  }

  void addQuestionBlock({required bool isGrammar}) {
    final section = isGrammar ? _paper.grammar : _paper.orthography;
    final questions = List<ExamQuestionBlock>.from(section.questions);
    questions.add(
      ExamQuestionBlock(
        number: questions.length + 1,
        branches: const <ExamBranch>[
          ExamBranch(
            branch: '',
            prompt: 'أجب عما يأتي :',
            degree: 5,
            items: <String>['النقطة الأولى'],
          ),
        ],
      ),
    );
    final nextSection = section.copyWith(questions: questions);
    _paper = isGrammar
        ? _paper.copyWith(grammar: nextSection)
        : _paper.copyWith(orthography: nextSection);
    notifyListeners();
  }

  void removeQuestionBlock({
    required bool isGrammar,
    required int questionIndex,
  }) {
    final section = isGrammar ? _paper.grammar : _paper.orthography;
    if (section.questions.length <= 1) {
      return;
    }
    final questions = List<ExamQuestionBlock>.from(section.questions)
      ..removeAt(questionIndex);
    for (var i = 0; i < questions.length; i++) {
      questions[i] = questions[i].copyWith(number: i + 1);
    }
    final nextSection = section.copyWith(questions: questions);
    _paper = isGrammar
        ? _paper.copyWith(grammar: nextSection)
        : _paper.copyWith(orthography: nextSection);
    notifyListeners();
  }

  void addBranchToQuestion({
    required bool isGrammar,
    required int questionIndex,
  }) {
    final section = isGrammar ? _paper.grammar : _paper.orthography;
    final questions = List<ExamQuestionBlock>.from(section.questions);
    final q = questions[questionIndex];
    const letters = <String>['أ', 'ب', 'ج', 'د'];
    final branches = List<ExamBranch>.from(q.branches);
    if (branches.length == 1 && branches.first.branch.isEmpty) {
      branches[0] = branches[0].copyWith(branch: 'أ');
    }
    final nextLetter =
        branches.length < letters.length ? letters[branches.length] : 'هـ';
    branches.add(
      ExamBranch(
        branch: nextLetter,
        prompt: 'أجب عما يأتي :',
        degree: 5,
        items: const <String>['النقطة الأولى'],
      ),
    );
    questions[questionIndex] = q.copyWith(branches: branches);
    final nextSection = section.copyWith(questions: questions);
    _paper = isGrammar
        ? _paper.copyWith(grammar: nextSection)
        : _paper.copyWith(orthography: nextSection);
    notifyListeners();
  }

  void removeBranchFromQuestion({
    required bool isGrammar,
    required int questionIndex,
    required int branchIndex,
  }) {
    final section = isGrammar ? _paper.grammar : _paper.orthography;
    final questions = List<ExamQuestionBlock>.from(section.questions);
    final q = questions[questionIndex];
    if (q.branches.length <= 1) {
      return;
    }
    final branches = List<ExamBranch>.from(q.branches)..removeAt(branchIndex);
    questions[questionIndex] = q.copyWith(branches: branches);
    final nextSection = section.copyWith(questions: questions);
    _paper = isGrammar
        ? _paper.copyWith(grammar: nextSection)
        : _paper.copyWith(orthography: nextSection);
    notifyListeners();
  }
}
