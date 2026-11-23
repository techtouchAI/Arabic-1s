import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/exam_paper.dart';
import '../../domain/models/library.dart';

class LoadedAppContent {
  const LoadedAppContent({
    required this.library,
    required this.examBank,
  });

  final StudyLibrary library;
  final ExamBank examBank;
}

class ContentLoader {
  ContentLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<LoadedAppContent> loadAll() async {
    final results = await Future.wait<String>(<Future<String>>[
      _bundle.loadString('assets/content/curriculum.json'),
      _bundle.loadString('assets/content/lessons.json'),
      _bundle.loadString('assets/content/glossary.json'),
      _bundle.loadString('assets/content/exam_bank.json'),
    ]);

    final curriculumJson = jsonDecode(results[0]) as Map<String, dynamic>;
    final lessonsJson = jsonDecode(results[1]) as Map<String, dynamic>;
    final glossaryJson = jsonDecode(results[2]) as Map<String, dynamic>;
    final examBankJson = jsonDecode(results[3]) as Map<String, dynamic>;

    final sections = (curriculumJson['sections'] as List<dynamic>)
        .map((e) => SectionMeta.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final units = (curriculumJson['units'] as List<dynamic>)
        .map((e) => Unit.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final lessons = (lessonsJson['lessons'] as List<dynamic>)
        .map((e) => GrammarLesson.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final glossary = (glossaryJson['terms'] as List<dynamic>)
        .map((e) => GlossaryTerm.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final library = StudyLibrary(
      title: curriculumJson['title'] as String,
      subtitle: curriculumJson['subtitle'] as String,
      sections: sections,
      units: units,
      lessons: lessons,
      glossary: glossary,
    );

    final examBank = ExamBank.fromJson(examBankJson);
    return LoadedAppContent(library: library, examBank: examBank);
  }
}
