import '../models/library.dart';
import '../models/question_print_settings.dart';

/// Filters units that contain printable self-test / exam questions.
List<Unit> printableUnits(Iterable<Unit> units) =>
    units.where((unit) => unit.questions.isNotEmpty).toList(growable: false);

class QuestionPrintPlan {
  const QuestionPrintPlan({
    required this.units,
    required this.trueFalseQuestions,
    required this.choiceQuestions,
    required this.openQuestions,
    required this.settings,
  });

  factory QuestionPrintPlan.fromSelection(
    List<Unit> availableUnits,
    Set<String> selectedUnitIds, {
    QuestionPrintSettings settings = const QuestionPrintSettings(),
  }) {
    final chosen = availableUnits
        .where((u) => selectedUnitIds.contains(u.id) && u.questions.isNotEmpty)
        .toList(growable: false);
    final tf = <Question>[];
    final choice = <Question>[];
    final open = <Question>[];
    for (final unit in chosen) {
      for (final q in unit.questions) {
        switch (q.kind) {
          case QuestionKind.trueFalse:
            tf.add(q);
          case QuestionKind.choice:
            choice.add(q);
          case QuestionKind.open:
            open.add(q);
        }
      }
    }
    return QuestionPrintPlan(
      units: chosen,
      trueFalseQuestions: tf,
      choiceQuestions: choice,
      openQuestions: open,
      settings: settings,
    );
  }

  final List<Unit> units;
  final List<Question> trueFalseQuestions;
  final List<Question> choiceQuestions;
  final List<Question> openQuestions;
  final QuestionPrintSettings settings;

  int get questionCount =>
      trueFalseQuestions.length + choiceQuestions.length + openQuestions.length;

  bool get isEmpty => questionCount == 0;
}
