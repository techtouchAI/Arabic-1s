import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/content_loader.dart';
import '../../data/local/progress_store.dart';
import '../../data/local/saved_exam_store.dart';
import '../../domain/services/study_plan_service.dart';
import 'app_state.dart';
import 'saved_exam_library.dart';

abstract final class AppBootstrap {
  static Future<AppState> initialize() async {
    final loader = ContentLoader();
    final contentFuture = loader.loadAll();
    final storeFuture = ProgressStore.open();
    final savedExamStoreFuture = SavedExamStore.open();
    final prefsFuture = SharedPreferences.getInstance();

    final content = await contentFuture;
    final store = await storeFuture;
    final savedExamStore = await savedExamStoreFuture;
    final prefs = await prefsFuture;

    return AppState(
      library: content.library,
      examBank: content.examBank,
      store: store,
      savedExams: SavedExamLibrary(savedExamStore),
      planRepository: SharedPreferencesStudyPlanRepository(prefs),
    );
  }
}
