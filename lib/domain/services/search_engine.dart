import '../../core/utils/arabic_text.dart';
import '../models/library.dart';

enum SearchResultKind {
  unit('وحدة'),
  topic('درس'),
  grammar('قواعد وتقويم'),
  question('سؤال'),
  glossary('معجم');

  const SearchResultKind(this.label);

  final String label;
}

class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    required this.snippet,
    required this.badge,
    required this.unitId,
    this.topicId,
    this.lessonId,
  });

  final SearchResultKind kind;
  final String title;
  final String snippet;
  final String badge;
  final String unitId;
  final String? topicId;
  final String? lessonId;
}

class CurriculumSearchEngine {
  CurriculumSearchEngine(this._library);

  final StudyLibrary _library;

  List<SearchHit> search(
    String rawQuery, {
    CurriculumPart? partFilter,
    int limit = 60,
  }) {
    final query = normalizeArabicForSearch(rawQuery);
    if (query.isEmpty) {
      return const <SearchHit>[];
    }
    final tokens =
        query.split(' ').where((t) => t.isNotEmpty).toList(growable: false);
    if (tokens.isEmpty) {
      return const <SearchHit>[];
    }

    final hits = <SearchHit>[];

    bool matchesAll(String candidate) {
      final norm = normalizeArabicForSearch(candidate);
      for (final token in tokens) {
        if (!norm.contains(token)) {
          return false;
        }
      }
      return true;
    }

    bool allowedPart(String itemPart) {
      if (partFilter == null || itemPart == 'both') {
        return true;
      }
      return itemPart == partFilter.id;
    }

    // 1. Units & topics
    for (final unit in _library.units) {
      if (!allowedPart(unit.part)) {
        continue;
      }
      if (matchesAll('${unit.title} ${unit.grammarTitle} ${unit.readingTitle}')) {
        hits.add(
          SearchHit(
            kind: SearchResultKind.unit,
            title: unit.title,
            snippet: '${unit.readingTitle} • ${unit.grammarTitle}',
            badge: '${unit.grade} • ${unit.pageRange}',
            unitId: unit.id,
          ),
        );
      }
      for (final topic in unit.topics) {
        if (hits.length >= limit) {
          return hits;
        }
        if (matchesAll(topic.title)) {
          hits.add(
            SearchHit(
              kind: SearchResultKind.topic,
              title: topic.title,
              snippet: topic.bullets.isNotEmpty ? topic.bullets.first : unit.title,
              badge: '${unit.displayTitle} • ${topic.lessonBadge}',
              unitId: unit.id,
              topicId: topic.id,
            ),
          );
          continue;
        }
        // Check bullets, side notes, and تقويم اللسان
        for (final bullet in topic.bullets) {
          if (matchesAll(bullet)) {
            hits.add(
              SearchHit(
                kind: SearchResultKind.topic,
                title: topic.title,
                snippet: _trimSnippet(bullet),
                badge: unit.displayTitle,
                unitId: unit.id,
                topicId: topic.id,
              ),
            );
            break;
          }
        }
        for (final tq in topic.taqwim) {
          final pairText = 'قل: ${tq.say} ولا تقل: ${tq.dontSay}';
          if (matchesAll(pairText)) {
            hits.add(
              SearchHit(
                kind: SearchResultKind.grammar,
                title: 'تقويم اللسان — ${unit.grammarTitle}',
                snippet: pairText,
                badge: unit.displayTitle,
                unitId: unit.id,
                topicId: topic.id,
              ),
            );
            break;
          }
        }
      }

      // Questions
      for (final question in unit.questions) {
        if (hits.length >= limit) {
          return hits;
        }
        final fullQ = '${question.prompt} ${question.displayAnswer}';
        if (matchesAll(fullQ)) {
          hits.add(
            SearchHit(
              kind: SearchResultKind.question,
              title: question.prompt,
              snippet: 'الإجابة: ${question.displayAnswer}',
              badge: unit.displayTitle,
              unitId: unit.id,
            ),
          );
        }
      }
    }

    // 2. Grammar lessons
    for (final lesson in _library.lessons) {
      if (!allowedPart(lesson.part)) {
        continue;
      }
      if (hits.length >= limit) {
        return hits;
      }
      final bodyText = lesson.plans
          .expand((p) => p.body.map((b) => b.text))
          .join(' ');
      if (matchesAll('${lesson.title} ${lesson.summary} $bodyText')) {
        hits.add(
          SearchHit(
            kind: SearchResultKind.grammar,
            title: 'ملخص القواعد: ${lesson.title}',
            snippet: lesson.summary,
            badge: lesson.partLabel,
            unitId: lesson.unitId,
            lessonId: lesson.id,
          ),
        );
      }
    }

    // 3. Glossary
    for (final term in _library.glossary) {
      if (!allowedPart(term.part)) {
        continue;
      }
      if (hits.length >= limit) {
        return hits;
      }
      if (matchesAll('${term.term} ${term.definition}')) {
        hits.add(
          SearchHit(
            kind: SearchResultKind.glossary,
            title: term.term,
            snippet: term.definition,
            badge: term.part == 'part1' ? 'معجم الجزء الأول' : 'معجم الجزء الثاني',
            unitId: term.unitId,
            topicId: term.topicId,
          ),
        );
      }
    }

    return hits;
  }

  String _trimSnippet(String text) {
    if (text.length <= 150) {
      return text;
    }
    return '${text.substring(0, 147)}…';
  }
}
