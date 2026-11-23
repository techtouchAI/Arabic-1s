import 'package:flutter/foundation.dart';

import '../../domain/models/saved_exam.dart';
import 'exam_composer_state.dart';
import 'saved_exam_library.dart';

/// Stores a new version of the composer's paper in the [SavedExamLibrary]
/// after every edit.
///
/// A fresh composer session gets its record on the first edit, so merely
/// opening the composer does not clutter the saved list; a reopened paper keeps
/// updating its own record.
class ExamAutosaver {
  ExamAutosaver({
    required ExamComposerController controller,
    required SavedExamLibrary library,
    String? savedId,
  })  : _controller = controller,
        _library = library,
        _savedId = savedId {
    _controller.addListener(_onPaperChanged);
  }

  final ExamComposerController _controller;
  final SavedExamLibrary _library;
  String? _savedId;
  bool _disposed = false;

  /// The id of the record this session writes to, once it exists.
  String? get savedId => _savedId;

  /// Whether the current paper is stored (it has been edited or saved).
  bool get hasSavedCopy => _savedId != null && _library.byId(_savedId!) != null;

  /// Stores the current paper immediately, e.g. before it is exported.
  SavedExamPaper saveNow() {
    assert(!_disposed, 'saveNow() called after dispose()');
    final record = _library.save(_controller.paper, id: _savedId);
    _savedId = record.id;
    return record;
  }

  void _onPaperChanged() => saveNow();

  @mustCallSuper
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _controller.removeListener(_onPaperChanged);
  }
}
