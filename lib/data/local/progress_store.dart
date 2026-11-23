import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/progress.dart';

abstract class ProgressStore {
  StudyProgress read();
  Future<void> write(StudyProgress progress);
  Future<void> clear();

  static Future<ProgressStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsProgressStore(prefs);
  }
}

class SharedPrefsProgressStore implements ProgressStore {
  SharedPrefsProgressStore(this._prefs);

  static const String _storageKey = 'bayan.progress.v1';

  final SharedPreferences _prefs;

  @override
  StudyProgress read() => StudyProgress.decode(_prefs.getString(_storageKey));

  @override
  Future<void> write(StudyProgress progress) async {
    await _prefs.setString(_storageKey, progress.encode());
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_storageKey);
  }
}

/// Synchronous in-memory store used in widget & unit tests.
class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore([this._current = const StudyProgress()]);

  StudyProgress _current;

  @override
  StudyProgress read() => _current;

  @override
  Future<void> write(StudyProgress progress) async {
    _current = progress;
  }

  @override
  Future<void> clear() async {
    _current = const StudyProgress();
  }
}
