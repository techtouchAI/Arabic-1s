import 'dart:convert';
import 'dart:io';

import 'package:bayan/data/local/content_loader.dart';
import 'package:bayan/data/local/progress_store.dart';
import 'package:bayan/domain/models/exam_paper.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/models/progress.dart';
import 'package:bayan/presentation/state/app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DiskAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) {
    final bytes = File(key).readAsBytesSync();
    return SynchronousFuture<ByteData>(ByteData.sublistView(bytes));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    return SynchronousFuture<String>(File(key).readAsStringSync());
  }
}

LoadedAppContent? _cachedContent;

LoadedAppContent loadTestContentSync() {
  if (_cachedContent != null) {
    return _cachedContent!;
  }
  Map<String, dynamic> readJson(String name) =>
      jsonDecode(File('assets/content/$name').readAsStringSync())
          as Map<String, dynamic>;

  final curriculumJson = readJson('curriculum.json');
  final lessonsJson = readJson('lessons.json');
  final glossaryJson = readJson('glossary.json');
  final examBankJson = readJson('exam_bank.json');

  final library = StudyLibrary(
    title: curriculumJson['title'] as String,
    subtitle: curriculumJson['subtitle'] as String,
    sections: (curriculumJson['sections'] as List<dynamic>)
        .map((e) => SectionMeta.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    units: (curriculumJson['units'] as List<dynamic>)
        .map((e) => Unit.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    lessons: (lessonsJson['lessons'] as List<dynamic>)
        .map((e) => GrammarLesson.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    glossary: (glossaryJson['terms'] as List<dynamic>)
        .map((e) => GlossaryTerm.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  final examBank = ExamBank.fromJson(examBankJson);
  _cachedContent = LoadedAppContent(library: library, examBank: examBank);
  return _cachedContent!;
}

Future<LoadedAppContent> loadTestContent() async => loadTestContentSync();

AppState createTestAppState({
  CurriculumPart? selectedPart = CurriculumPart.part1,
  bool onboardingCompleted = true,
  String teacherName = 'حيدر محمد الكعبي',
  String schoolName = 'متوسطة المتنبي للبنين',
  double textScale = 1.0,
}) {
  final content = loadTestContentSync();
  final initial = StudyProgress(
    selectedPart: selectedPart,
    onboardingCompleted: onboardingCompleted,
    teacherProfile: TeacherProfile(
      teacherName: teacherName,
      schoolName: schoolName,
    ),
    textScale: textScale,
  );
  return AppState(
    library: content.library,
    examBank: content.examBank,
    store: MemoryProgressStore(initial),
    initialProgress: initial,
  );
}
