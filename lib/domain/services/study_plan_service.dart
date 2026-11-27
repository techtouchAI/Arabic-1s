/// Service behind the daily and annual study-plan sheets (الخطة اليومية
/// والخطة السنوية): deterministic generation, editable content, A4 print
/// and persistent storage.
///
/// The service owns three concerns that must stay coordinated:
/// - **Content**: the plan data (annual rows / daily entries / settings).
/// - **Print**: the plan content handed to [StudyPlanPdf], honouring
///   per-column visibility so the teacher keeps full control of the sheet.
/// - **Storage**: versioned JSON in SharedPreferences, with the same
///   fallback-to-regeneration behaviour used by the exam composer so the
///   app never loses the plan for a corrupt record.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/library.dart';
import '../models/study_plan.dart';

class StudyPlanService {
  StudyPlanService({
    required StudyLibrary library,
    required StudyPlanRepository repository,
  })  : _library = library,
        _repository = repository;

  static const String key = 'bayan.study_plans.v1';

  final StudyLibrary _library;
  final StudyPlanRepository _repository;
  StudyPlans? _plans;

  bool get isLoaded => _plans != null;

  StudyPlans get plans => _plans ?? buildDefaultAnnual();

  StudyPlans? get cachedPlans => _plans;

  /// Builds the default annual plan from the curriculum library. The method
  /// is deterministic: it does not depend on unseeded randomness so CI can
  /// compare two generations.
  StudyPlans buildDefaultAnnual() => StudyPlans(
        annualRows: buildDefaultAnnualPlan(_library),
        dailyEntries: buildDefaultDailyPlan(
          _library,
          CurriculumPart.part1,
        ),
      );

  /// Builds the default daily plan for [part] (each unit gets the official
  /// six-day teaching sequence).
  StudyPlans buildDefaultDaily(CurriculumPart part) => StudyPlans(
        annualRows: buildDefaultAnnualPlan(_library),
        dailyEntries: buildDefaultDailyPlan(_library, part),
      );

  /// Regenerates the current plan set, resetting daily entries to the
  /// standard sequence for [mode].
  StudyPlans regenerateFor(StudyPlanMode mode) {
    final generated = mode == StudyPlanMode.daily
        ? buildDefaultDaily(CurriculumPart.part1)
        : buildDefaultAnnual();
    _plans = generated;
    unawaited(persist(generated));
    return generated;
  }

  Future<StudyPlans> load({String? rawJson}) async {
    final decoded = rawJson ?? await _repository.loadString(key);
    if (decoded == null || decoded.trim().isEmpty) {
      _plans = buildDefaultAnnual();
      await persist(_plans!);
      return _plans!;
    }

    Map<String, dynamic> json;
    try {
      final parsed = jsonDecode(decoded);
      if (parsed is Map<String, dynamic>) {
        json = parsed;
      } else {
        throw const FormatException('study plan document must be a map');
      }
    } catch (_) {
      _plans = buildDefaultAnnual();
      await persist(_plans!);
      return _plans!;
    }

    final loaded = StudyPlans.fromJson(json).sanitize(_library);
    _plans = loaded;
    return loaded;
  }

  Future<bool> persist(StudyPlans plans) =>
      _repository.setString(key, jsonEncode(plans.toJson()));

  /// Restores a backup document produced by [exportBackupJson], ignoring the
  /// envelope and reusing the same sanitize/load path as a normal load.
  Future<StudyPlans> restoreFromBackup(String backupJson) async {
    Map<String, dynamic> json;
    try {
      final parsed = jsonDecode(backupJson);
      if (parsed is Map<String, dynamic> &&
          parsed['plans'] is Map<String, dynamic>) {
        json = parsed['plans'] as Map<String, dynamic>;
      } else if (parsed is Map<String, dynamic>) {
        json = parsed;
      } else {
        throw const FormatException('plan backup must be a map');
      }
    } catch (_) {
      return load();
    }

    final restored = StudyPlans.fromJson(json).sanitize(_library);
    _plans = restored;
    await persist(restored);
    return restored;
  }

  /// Serializes the plan set as a human-readable backup document.
  String exportBackupJson() =>
      jsonEncode(<String, dynamic>{'version': 1, 'plans': plans.toJson()});

  // ---- Edit operations ---------------------------------------------------

  void updateAnnualRow(AnnualPlanRow row) {
    final plans = _plans ?? buildDefaultAnnual();
    _plans = plans.copyWith(
      annualRows: plans.annualRows
          .map((r) => r.id == row.id ? row : r)
          .toList(growable: false),
    );
    unawaited(persist(_plans!));
  }

  void appendAnnualRow(AnnualPlanRow row) {
    final plans = _plans ?? buildDefaultAnnual();
    _plans = plans.copyWith(
      annualRows: <AnnualPlanRow>[...plans.annualRows, row],
    );
    unawaited(persist(_plans!));
  }

  void removeAnnualRow(String id) {
    final plans = _plans ?? buildDefaultAnnual();
    _plans = plans.copyWith(
      annualRows: plans.annualRows
          .where((r) => r.id != id)
          .toList(growable: false),
    );
    unawaited(persist(_plans!));
  }

  void updateDailyEntry(DailyPlanEntry entry) {
    final plans = _plans ?? buildDefaultAnnual();
    _plans = plans.copyWith(
      dailyEntries: plans.dailyEntries
          .map((e) => e.id == entry.id ? entry : e)
          .toList(growable: false),
    );
    unawaited(persist(_plans!));
  }

  void appendDailyEntry(DailyPlanEntry entry) {
    final plans = _plans ?? buildDefaultAnnual();
    _plans = plans.copyWith(
      dailyEntries: <DailyPlanEntry>[...plans.dailyEntries, entry],
    );
    unawaited(persist(_plans!));
  }

  void removeDailyEntry(String id) {
    final plans = _plans ?? buildDefaultAnnual();
    _plans = plans.copyWith(
      dailyEntries: plans.dailyEntries
          .where((e) => e.id != id)
          .toList(growable: false),
    );
    unawaited(persist(_plans!));
  }

  void updateSettings(StudyPlanSettings settings) {
    final plans = _plans ?? buildDefaultAnnual();
    _plans = plans.copyWith(settings: settings);
    unawaited(persist(_plans!));
  }

  void setAnnualColumnVisible(String columnId, bool visible) {
    final plans = _plans ?? buildDefaultAnnual();
    final columns = plans.settings.visibleAnnualColumns.toSet()
      ..remove(columnId);
    if (visible) {
      columns.add(columnId);
    }
    _plans = plans.copyWith(
      settings: plans.settings.copyWith(visibleAnnualColumns: columns),
    );
    unawaited(persist(_plans!));
  }

  void setDailyColumnVisible(String columnId, bool visible) {
    final plans = _plans ?? buildDefaultAnnual();
    final columns = plans.settings.visibleDailyColumns.toSet()
      ..remove(columnId);
    if (visible) {
      columns.add(columnId);
    }
    _plans = plans.copyWith(
      settings: plans.settings.copyWith(visibleDailyColumns: columns),
    );
    unawaited(persist(_plans!));
  }

  Future<void> resetToDefaults() async {
    _plans = buildDefaultAnnual();
    await persist(_plans!);
  }
}

/// Versioned persistence for the study plans. Mirrors the saved-exam
/// repository contract: a JSON envelope plus a corrupt-data fallback.
abstract class StudyPlanRepository {
  Future<String?> loadString(String key);
  Future<bool> setString(String key, String value);
}

class SharedPreferencesStudyPlanRepository implements StudyPlanRepository {
  SharedPreferencesStudyPlanRepository(this._preferred);

  final SharedPreferences _preferred;

  @override
  Future<String?> loadString(String key) async =>
      _preferred.getString(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferred.setString(key, value);
}

/// In-memory repository used by widget/unit tests and as a safe fallback
/// when no SharedPreferences instance is available.
class MemoryStudyPlanRepository implements StudyPlanRepository {
  MemoryStudyPlanRepository({String? initial}) {
    if (initial != null) {
      _data[StudyPlanService.key] = initial;
    }
  }

  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> loadString(String key) async => _data[key];

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }
}
