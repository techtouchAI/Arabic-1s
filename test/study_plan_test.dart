import 'package:bayan/data/local/content_loader.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/models/question_print_settings.dart';
import 'package:bayan/data/study_plan_pdf.dart';
import 'package:bayan/domain/models/study_plan.dart';
import 'package:bayan/domain/services/study_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final LoadedAppContent content = loadTestContentSync();

  group('default annual plan', () {
    test('is generated in official curriculum order with balanced days', () {
      final plans = buildDefaultAnnualPlan(content.library);

      // مقدمة المنهج + 10 وحدات (جزء 1) + 9 وحدات (جزء 2) + مرجع الإملاء.
      expect(plans, hasLength(21));
      expect(plans.first.unitId, 'intro');
      expect(plans.first.sectionLabel, contains('مقدمة المنهج'));
      expect(plans.last.unitId, 'orthography-expression');
      expect(plans.last.sectionLabel, contains('مرجع الإملاء'));

      // كل وحدة أساسية ٦ أيام، المقدمة ٢ والمرجع ٤.
      expect(plans.first.teachingDays, 2);
      expect(plans.last.teachingDays, 4);
      for (final row in plans.skip(1).take(19)) {
        expect(row.teachingDays, 6);
      }
      expect(
        plans.fold(0, (sum, r) => sum + r.teachingDays),
        2 + 19 * 6 + 4,
      );

      // أسابيع البداية غير متناقصة.
      for (var i = 1; i < plans.length; i++) {
        expect(plans[i].startWeek, greaterThanOrEqualTo(plans[i - 1].startWeek));
      }
    });

    test('is deterministic across generations', () {
      final a = buildDefaultAnnualPlan(content.library);
      final b = buildDefaultAnnualPlan(content.library);
      expect(
        a.map((r) => r.toJson()),
        equals(b.map((r) => r.toJson())),
      );
    });

    test('every row carries the unit content for printing', () {
      final plans = buildDefaultAnnualPlan(content.library);
      for (final row in plans) {
        expect(row.unitLabel.isNotEmpty, isTrue);
        expect(row.readingTitle.isNotEmpty, isTrue);
        expect(row.grammarTitle.isNotEmpty, isTrue);
      }
    });
  });

  group('default daily plan', () {
    test('gives every unit the six-day teaching sequence', () {
      final entries = buildDefaultDailyPlan(content.library, CurriculumPart.part1);
      // ١٠ وحدات × ٦ أيام.
      expect(entries, hasLength(60));
      expect(entries.first.focus, 'تمهيد وقراءة');
      expect(entries[1].focus, 'تحليل النص والاستيعاب');
      expect(entries[5].focus, 'التقويم والتمرينات');
      expect(entries[6].focus, 'تمهيد وقراءة');
      expect(entries.every((e) => e.content.isNotEmpty), isTrue);
    });

    test('day labels use Arabic ordinals', () {
      expect(dayLabelFor(1), 'اليوم الأول');
      expect(dayLabelFor(2), 'اليوم الثاني');
      expect(dayLabelFor(10), 'اليوم العاشر');
      expect(dayLabelFor(11), 'اليوم ١١');
    });

    test('start-week mapping follows a five-day school week', () {
      expect(startWeekForDays(0), 1);
      expect(startWeekForDays(5), 2);
      expect(startWeekForDays(6), 3);
      expect(startWeekForDays(29), 7);
    });
  });

  group('StudyPlanSettings', () {
    test('round-trips through JSON and validates sizes', () {
      const settings = StudyPlanSettings(
        font: QuestionPrintFont.amiri,
        bodyFontSize: 11,
        headingFontSize: 15,
      );
      final json = settings.toJson();
      final restored = StudyPlanSettings.fromJson(json);

      expect(restored.font, settings.font);
      expect(restored.bodyFontSize, settings.bodyFontSize);
      expect(restored.headingFontSize, settings.headingFontSize);
      expect(restored.isValid, isTrue);
    });

    test('rejects out-of-range font sizes', () {
      const settings = StudyPlanSettings(bodyFontSize: 4, headingFontSize: 15);
      expect(settings.isValid, isFalse);
      expect(StudyPlanSettings.isValidFontSize(20), isTrue);
      expect(StudyPlanSettings.isValidFontSize(21), isFalse);
    });
  });

  group('StudyPlans.sanitize', () {
    test('fills an empty plan with defaults', () {
      final sanitized =
          const StudyPlans(annualRows: <AnnualPlanRow>[], dailyEntries: <DailyPlanEntry>[])
              .sanitize(content.library);
      expect(sanitized.annualRows, hasLength(21));
      expect(sanitized.dailyEntries, hasLength(60));
    });

    test('repairs dangling units and duplicate/empty ids', () {
      const plans = StudyPlans(
        annualRows: const <AnnualPlanRow>[
          const AnnualPlanRow(
            id: '',
            sectionLabel: 'س',
            unitId: 'intro',
            unitLabel: 'وحدة',
            unitTitle: '',
            pages: '',
            readingTitle: '',
            grammarTitle: '',
            teachingDays: 6,
            startWeek: 1,
            examFocus: '',
          ),
          const AnnualPlanRow(
            id: '',
            sectionLabel: 'س',
            unitId: 'does-not-exist',
            unitLabel: 'سطر مخصص',
            unitTitle: '',
            pages: '',
            readingTitle: '',
            grammarTitle: '',
            teachingDays: 6,
            startWeek: 1,
            examFocus: '',
          ),
        ],
        dailyEntries: <DailyPlanEntry>[
          const DailyPlanEntry(id: 'd', dayLabel: 'يوم', focus: 'x', content: ''),
          const DailyPlanEntry(id: 'd', dayLabel: 'يوم', focus: 'x', content: ''),
        ],
      );

      final sanitized = plans.sanitize(content.library);
      // كلا السطرين يُحتفظ بهما، لكن رابط الوحدة المعطل يُمسح إلى سطر مخصص.
      expect(sanitized.annualRows, hasLength(2));
      expect(sanitized.annualRows[0].unitId, 'intro');
      expect(sanitized.annualRows[1].unitId, '');
      expect(sanitized.annualRows[0].id, isNot(''));
      expect(sanitized.annualRows[0].id, isNot(sanitized.annualRows[1].id));
      expect(sanitized.dailyEntries, hasLength(2));
      expect(sanitized.dailyEntries[0].id, isNot(sanitized.dailyEntries[1].id));
    });
  });

  group('StudyPlanService', () {
    StudyPlanService _service() => StudyPlanService(
          library: content.library,
          repository: MemoryStudyPlanRepository(),
        );

    test('loads defaults on first run and persists them', () async {
      final service = _service();
      final plans = await service.load();
      expect(service.isLoaded, isTrue);
      expect(plans.annualRows, hasLength(21));
      expect(plans.dailyEntries, hasLength(60));

      final stored = service.persist(plans);
      expect(await stored, isTrue);
    });

    test('regenerates defaults when the stored document is corrupt', () async {
      final repository = MemoryStudyPlanRepository(
        initial: '{ this is not valid json',
      );
      final service = StudyPlanService(
        library: content.library,
        repository: repository,
      );
      final plans = await service.load();
      expect(plans.annualRows, hasLength(21));
    });

    test('editing rows and entries persists and keeps the sheet valid', () async {
      final service = _service();
      await service.load();
      final plans = service.plans;

      final first = plans.annualRows.first;
      service.updateAnnualRow(
        first.copyWith(unitLabel: 'مقدمة معدلة', notes: 'مراجعة'),
      );
      expect(service.plans.annualRows.first.unitLabel, 'مقدمة معدلة');
      expect(service.plans.annualRows.first.notes, 'مراجعة');

      final entry = plans.dailyEntries.first;
      service.updateDailyEntry(entry.copyWith(done: true, homework: 'واجب'));
      expect(service.plans.dailyEntries.first.done, isTrue);
      expect(service.plans.dailyEntries.first.homework, 'واجب');

      service.appendAnnualRow(
        const AnnualPlanRow(
          id: 'annual-x',
          sectionLabel: 'سطر',
          unitId: '',
          unitLabel: 'سطر جديد',
          unitTitle: '',
          pages: '',
          readingTitle: '',
          grammarTitle: '',
          teachingDays: 3,
          startWeek: 20,
          examFocus: '',
        ),
      );
      expect(service.plans.annualRows, hasLength(22));

      service.removeAnnualRow('annual-x');
      expect(service.plans.annualRows, hasLength(21));
    });

    test('column visibility and settings are applied', () async {
      final service = _service();
      await service.load();
      service.setAnnualColumnVisible('notes', false);
      expect(
        service.plans.settings.visibleAnnualColumns.contains('notes'),
        isFalse,
      );
      service.setAnnualColumnVisible('notes', true);
      expect(
        service.plans.settings.visibleAnnualColumns.contains('notes'),
        isTrue,
      );

      service.updateSettings(
        const StudyPlanSettings(bodyFontSize: 12, headingFontSize: 18),
      );
      expect(service.plans.settings.bodyFontSize, 12);
      expect(service.plans.settings.headingFontSize, 18);
    });

    test('backup export and restore round-trip', () async {
      final service = _service();
      await service.load();
      service.updateAnnualRow(
        service.plans.annualRows.first.copyWith(unitLabel: 'موحفظ'),
      );

      final backup = service.exportBackupJson();

      final restoredService = StudyPlanService(
        library: content.library,
        repository: MemoryStudyPlanRepository(),
      );
      final restored = await restoredService.restoreFromBackup(backup);
      expect(restored.annualRows.first.unitLabel, 'موحفظ');
    });
  });

  group('AppState integration', () {
    test('exposes a lazily loaded plan service with defaults', () async {
      final state = createTestAppState();
      expect(state.studyPlans.isLoaded, isFalse);

      await state.initStudyPlans();

      expect(state.studyPlans.isLoaded, isTrue);
      expect(state.studyPlans.plans.annualRows, hasLength(21));
      expect(state.studyPlans.plans.dailyEntries, hasLength(60));
    });

    test('plan edits notify listeners and persist', () async {
      final state = createTestAppState();
      await state.initStudyPlans();

      var notifications = 0;
      state.addListener(() => notifications++);

      final row = state.studyPlans.plans.annualRows.first;
      state.updateAnnualRow(row.copyWith(unitLabel: 'تغيير'));
      expect(state.studyPlans.plans.annualRows.first.unitLabel, 'تغيير');
      expect(notifications, greaterThan(0));
    });
  });

  group('A4 plan PDF', () {
    test('annual plan renders to a valid A4 PDF', () async {
      final service = StudyPlanService(
        library: content.library,
        repository: MemoryStudyPlanRepository(),
      );
      await service.load();

      final bytes = await StudyPlanPdf.buildPlanPdfBytes(
        mode: StudyPlanMode.annual,
        plans: service.plans,
        bundle: DiskAssetBundle(),
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('daily plan renders to a valid A4 PDF', () async {
      final service = StudyPlanService(
        library: content.library,
        repository: MemoryStudyPlanRepository(),
      );
      await service.load();

      final bytes = await StudyPlanPdf.buildPlanPdfBytes(
        mode: StudyPlanMode.daily,
        plans: service.plans,
        bundle: DiskAssetBundle(),
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('rejects invalid typography before rendering', () async {
      final service = StudyPlanService(
        library: content.library,
        repository: MemoryStudyPlanRepository(),
      );
      await service.load();
      service.updateSettings(
        const StudyPlanSettings(bodyFontSize: 1, headingFontSize: 1),
      );

      await expectLater(
        StudyPlanPdf.buildPlanPdfBytes(
          mode: StudyPlanMode.annual,
          plans: service.plans,
          bundle: DiskAssetBundle(),
        ),
        throwsArgumentError,
      );
    });
  });
}
