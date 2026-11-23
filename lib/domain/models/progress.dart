import 'dart:convert';

import 'package:flutter/material.dart';

import 'library.dart';

class TeacherProfile {
  const TeacherProfile({
    this.teacherName = '',
    this.schoolName = '',
    this.directorate = 'المديرية العامة للتربية',
  });

  final String teacherName;
  final String schoolName;
  final String directorate;

  TeacherProfile copyWith({
    String? teacherName,
    String? schoolName,
    String? directorate,
  }) =>
      TeacherProfile(
        teacherName: teacherName ?? this.teacherName,
        schoolName: schoolName ?? this.schoolName,
        directorate: directorate ?? this.directorate,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'teacherName': teacherName,
        'schoolName': schoolName,
        'directorate': directorate,
      };

  factory TeacherProfile.fromJson(Map<String, dynamic> json) => TeacherProfile(
        teacherName: (json['teacherName'] as String?) ?? '',
        schoolName: (json['schoolName'] as String?) ?? '',
        directorate:
            (json['directorate'] as String?) ?? 'المديرية العامة للتربية',
      );
}

enum BookmarkKind { unit, topic, lesson }

class BookmarkItem {
  const BookmarkItem({
    required this.key,
    required this.kind,
    required this.targetId,
    required this.title,
    this.subtitle = '',
    this.topicId,
  });

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
        key: json['key'] as String,
        kind: BookmarkKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => BookmarkKind.unit,
        ),
        targetId: json['targetId'] as String,
        title: json['title'] as String,
        subtitle: (json['subtitle'] as String?) ?? '',
        topicId: json['topicId'] as String?,
      );

  final String key;
  final BookmarkKind kind;
  final String targetId;
  final String title;
  final String subtitle;
  final String? topicId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'kind': kind.name,
        'targetId': targetId,
        'title': title,
        'subtitle': subtitle,
        'topicId': topicId,
      };
}

class QuizScore {
  const QuizScore({
    required this.scopeLabel,
    required this.correct,
    required this.total,
    required this.timestampIso,
  });

  factory QuizScore.fromJson(Map<String, dynamic> json) => QuizScore(
        scopeLabel: json['scopeLabel'] as String,
        correct: json['correct'] as int,
        total: json['total'] as int,
        timestampIso: json['timestampIso'] as String,
      );

  final String scopeLabel;
  final int correct;
  final int total;
  final String timestampIso;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'scopeLabel': scopeLabel,
        'correct': correct,
        'total': total,
        'timestampIso': timestampIso,
      };
}

class StudyProgress {
  const StudyProgress({
    this.selectedPart,
    this.onboardingCompleted = false,
    this.teacherProfile = const TeacherProfile(),
    this.themeMode = ThemeMode.light,
    this.textScale = 1.0,
    this.lastUnitId,
    this.readUnitIds = const <String>{},
    this.bookmarks = const <BookmarkItem>[],
    this.quizHistory = const <QuizScore>[],
  });

  final CurriculumPart? selectedPart;
  final bool onboardingCompleted;
  final TeacherProfile teacherProfile;
  final ThemeMode themeMode;
  final double textScale;
  final String? lastUnitId;
  final Set<String> readUnitIds;
  final List<BookmarkItem> bookmarks;
  final List<QuizScore> quizHistory;

  StudyProgress copyWith({
    CurriculumPart? selectedPart,
    bool? onboardingCompleted,
    TeacherProfile? teacherProfile,
    ThemeMode? themeMode,
    double? textScale,
    String? lastUnitId,
    Set<String>? readUnitIds,
    List<BookmarkItem>? bookmarks,
    List<QuizScore>? quizHistory,
  }) =>
      StudyProgress(
        selectedPart: selectedPart ?? this.selectedPart,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        teacherProfile: teacherProfile ?? this.teacherProfile,
        themeMode: themeMode ?? this.themeMode,
        textScale: textScale ?? this.textScale,
        lastUnitId: lastUnitId ?? this.lastUnitId,
        readUnitIds: readUnitIds ?? this.readUnitIds,
        bookmarks: bookmarks ?? this.bookmarks,
        quizHistory: quizHistory ?? this.quizHistory,
      );

  String encode() => jsonEncode(<String, dynamic>{
        'selectedPart': selectedPart?.id,
        'onboardingCompleted': onboardingCompleted,
        'teacherProfile': teacherProfile.toJson(),
        'themeMode': themeMode.name,
        'textScale': textScale,
        'lastUnitId': lastUnitId,
        'readUnitIds': readUnitIds.toList(growable: false),
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(growable: false),
        'quizHistory':
            quizHistory.map((q) => q.toJson()).toList(growable: false),
      });

  static StudyProgress decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const StudyProgress();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final modeName = map['themeMode'] as String?;
      final mode = ThemeMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => ThemeMode.light,
      );
      final scale = ((map['textScale'] as num?)?.toDouble() ?? 1.0)
          .clamp(0.85, 1.40);
      return StudyProgress(
        selectedPart: CurriculumPart.fromId(map['selectedPart'] as String?),
        onboardingCompleted: (map['onboardingCompleted'] as bool?) ?? false,
        teacherProfile: map['teacherProfile'] is Map<String, dynamic>
            ? TeacherProfile.fromJson(
                map['teacherProfile'] as Map<String, dynamic>,
              )
            : const TeacherProfile(),
        themeMode: mode,
        textScale: scale,
        lastUnitId: map['lastUnitId'] as String?,
        readUnitIds: ((map['readUnitIds'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => e as String)
            .toSet(),
        bookmarks: ((map['bookmarks'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => BookmarkItem.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        quizHistory:
            ((map['quizHistory'] as List<dynamic>?) ?? const <dynamic>[])
                .map((e) => QuizScore.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
      );
    } catch (_) {
      return const StudyProgress();
    }
  }
}
