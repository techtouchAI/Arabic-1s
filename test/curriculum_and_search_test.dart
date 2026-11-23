import 'package:bayan/core/utils/arabic_text.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/services/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads complete Part 1 (10 units) and Part 2 (9 units) curriculum', () async {
    final content = await loadTestContent();
    final lib = content.library;

    final p1 = lib.unitsForPart(CurriculumPart.part1);
    final p2 = lib.unitsForPart(CurriculumPart.part2);

    expect(p1.length, 10);
    expect(p2.length, 9);
    expect(lib.unitById('intro'), isNotNull);
    expect(lib.unitById('orthography-expression'), isNotNull);

    expect(lib.lessonsForPart(CurriculumPart.part1).length, 10);
    expect(lib.lessonsForPart(CurriculumPart.part2).length, 9);
    expect(lib.glossary.length, greaterThanOrEqualTo(50));

    final totalQuestions =
        lib.units.fold<int>(0, (sum, u) => sum + u.questions.length);
    expect(totalQuestions, 114);
  });

  test('diacritic-insensitive search finds vocalized texts, grammar, and taqwim', () async {
    final content = await loadTestContent();
    final engine = CurriculumSearchEngine(content.library);

    expect(engine.search('اقسام الكلام'), isNotEmpty);
    expect(engine.search('الافعال الخمسه'), isNotEmpty);
    expect(engine.search('الف التفريق'), isNotEmpty);
    expect(engine.search('ان واخواتها'), isNotEmpty);
    expect(engine.search('كتاب شائق'), isNotEmpty);

    // Part filter restricts results strictly to the requested semester
    final p1Only = engine.search('كعب بن زهير', partFilter: CurriculumPart.part1);
    final p2Only = engine.search('كعب بن زهير', partFilter: CurriculumPart.part2);
    expect(p1Only, isEmpty);
    expect(p2Only, isNotEmpty);
  });

  test('parseUnderlinedSegments splits balanced _markers_ cleanly', () {
    final spans = parseUnderlinedSegments(
      'قال تعالى : ( _فَسَقَى لَهُمَا_ ثُمَّ _تَوَلَّى_ إِلَى الظِّلِّ )',
    );
    expect(spans.where((s) => s.underlined).map((s) => s.text).toList(), <String>[
      'فَسَقَى لَهُمَا',
      'تَوَلَّى',
    ]);
    for (final span in spans) {
      expect(span.text.contains('_'), isFalse);
    }
  });
}
