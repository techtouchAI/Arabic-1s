import 'exam_paper.dart';

/// One exam paper created by the teacher, stored locally and kept up to date
/// by the composer's autosave.
class SavedExamPaper {
  const SavedExamPaper({
    required this.id,
    required this.paper,
    required this.createdAt,
    required this.updatedAt,
    this.customTitle = '',
    this.revision = 1,
  });

  /// Restores a record written by [toJson]. Throws on a structurally invalid
  /// record so the store can skip it without discarding the others.
  factory SavedExamPaper.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['createdAt'] as String);
    return SavedExamPaper(
      id: json['id'] as String,
      customTitle: (json['customTitle'] as String?) ?? '',
      createdAt: created,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          created,
      revision: ((json['revision'] as int?) ?? 1).clamp(1, 1 << 30),
      paper: ArabicExamPaper.fromJson(json['paper'] as Map<String, dynamic>),
    );
  }

  final String id;
  final ArabicExamPaper paper;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Name chosen by the teacher; empty means "derive it from the header".
  final String customTitle;

  /// Number of autosaved versions written for this paper.
  final int revision;

  String get displayTitle {
    final custom = customTitle.trim();
    if (custom.isNotEmpty) {
      return custom;
    }
    final parts = <String>[
      paper.header.examTitleLine.trim(),
      paper.header.roundLine.trim(),
    ].where((p) => p.isNotEmpty).toList(growable: false);
    return parts.isEmpty ? 'ورقة أسئلة بدون عنوان' : parts.join(' — ');
  }

  SavedExamPaper copyWith({
    ArabicExamPaper? paper,
    DateTime? updatedAt,
    String? customTitle,
    int? revision,
  }) =>
      SavedExamPaper(
        id: id,
        paper: paper ?? this.paper,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        customTitle: customTitle ?? this.customTitle,
        revision: revision ?? this.revision,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'customTitle': customTitle,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'revision': revision,
        'paper': paper.toJson(),
      };
}
