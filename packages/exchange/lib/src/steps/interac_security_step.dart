import 'package:meta/meta.dart';

import '../payout/payout_requirement.dart';
import '../recipients/domain/entities/interac_security_details.dart';
import 'step_next.dart';

/// The met Interac requirement: the answer the order sends, and whether the
/// user asked to save it on the recipient. Only the step makes one.
@immutable
final class InteracSecurityEvidence {
  final InteracSecurityAnswer answer;
  final bool saveAsDefault;

  const InteracSecurityEvidence._(this.answer, {required this.saveAsDefault});

  @override
  bool operator ==(Object other) =>
      other is InteracSecurityEvidence &&
      other.answer == answer &&
      other.saveAsDefault == saveAsDefault;

  @override
  int get hashCode => Object.hash(answer, saveAsDefault);

  @override
  String toString() => 'InteracSecurityEvidence(save: $saveAsDefault)';
}

/// The Interac security question/answer step (composition §4.5): asked for
/// every Interac payout, prefilled from the recipient, checked with the one
/// validator the recipient form uses.
@immutable
sealed class InteracSecurityState {
  const InteracSecurityState();
}

final class InteracEditing extends InteracSecurityState {
  final String question;
  final String answer;
  final bool saveAsDefault;

  /// The problem Continue found; cleared by typing.
  final InteracAnswerProblem? problem;

  const InteracEditing({
    required this.question,
    required this.answer,
    required this.saveAsDefault,
    this.problem,
  });

  InteracEditing _with({
    String? question,
    String? answer,
    bool? saveAsDefault,
  }) => InteracEditing(
    question: question ?? this.question,
    answer: answer ?? this.answer,
    saveAsDefault: saveAsDefault ?? this.saveAsDefault,
  );

  @override
  bool operator ==(Object other) =>
      other is InteracEditing &&
      other.question == question &&
      other.answer == answer &&
      other.saveAsDefault == saveAsDefault &&
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(InteracEditing, question, answer, saveAsDefault, problem);

  @override
  String toString() => 'InteracEditing(save: $saveAsDefault, $problem)';
}

/// Output.
final class InteracAnswered extends InteracSecurityState {
  final InteracSecurityEvidence evidence;

  const InteracAnswered(this.evidence);

  @override
  bool operator ==(Object other) =>
      other is InteracAnswered && other.evidence == evidence;

  @override
  int get hashCode => Object.hash(InteracAnswered, evidence);

  @override
  String toString() => 'InteracAnswered($evidence)';
}

@immutable
sealed class InteracSecurityEvent {
  const InteracSecurityEvent();
}

final class InteracQuestionTyped extends InteracSecurityEvent {
  final String text;

  const InteracQuestionTyped(this.text);
}

final class InteracAnswerTyped extends InteracSecurityEvent {
  final String text;

  const InteracAnswerTyped(this.text);
}

final class InteracSaveAsDefaultSet extends InteracSecurityEvent {
  final bool save;

  const InteracSaveAsDefaultSet({required this.save});
}

final class InteracContinuePressed extends InteracSecurityEvent {
  const InteracContinuePressed();
}

/// Back to the answer from the next step.
final class InteracEditPressed extends InteracSecurityEvent {
  const InteracEditPressed();
}

/// The step starts no effects; the order sends the answer.
@immutable
sealed class InteracSecurityEffect {
  const InteracSecurityEffect();
}

typedef InteracSecurityNext =
    StepNext<InteracSecurityState, InteracSecurityEffect>;

/// Saving as default is ticked when the recipient already has an answer,
/// as the withdraw screen did.
InteracSecurityNext interacSecurityStart(InteracSecurityRequired requirement) {
  final question = requirement.question?.trim() ?? '';
  final answer = requirement.answer?.trim() ?? '';
  return StepNext(
    InteracEditing(
      question: question,
      answer: answer,
      saveAsDefault: question.isNotEmpty && answer.isNotEmpty,
    ),
  );
}

InteracSecurityNext _continue(InteracEditing editing) =>
    switch (InteracSecurityAnswer.create(editing.question, editing.answer)) {
      final InteracSecurityAnswer answer => StepNext(
        InteracAnswered(
          InteracSecurityEvidence._(
            answer,
            saveAsDefault: editing.saveAsDefault,
          ),
        ),
      ),
      null => StepNext(
        InteracEditing(
          question: editing.question,
          answer: editing.answer,
          saveAsDefault: editing.saveAsDefault,
          problem: InteracSecurityAnswer.check(editing.question, editing.answer),
        ),
      ),
    };

InteracSecurityNext transitionInteracSecurity(
  InteracSecurityState state,
  InteracSecurityEvent event,
) => switch ((state, event)) {
  (final InteracEditing editing, InteracQuestionTyped(:final text)) => StepNext(
    editing._with(question: text),
  ),
  (final InteracEditing editing, InteracAnswerTyped(:final text)) => StepNext(
    editing._with(answer: text),
  ),
  (final InteracEditing editing, InteracSaveAsDefaultSet(:final save)) =>
    StepNext(editing._with(saveAsDefault: save)),
  (final InteracEditing editing, InteracContinuePressed()) => _continue(
    editing,
  ),
  (InteracEditing(), InteracEditPressed()) => StepNext.stay(state),

  (InteracAnswered(:final evidence), InteracEditPressed()) => StepNext(
    InteracEditing(
      question: evidence.answer.question,
      answer: evidence.answer.answer,
      saveAsDefault: evidence.saveAsDefault,
    ),
  ),
  (
    InteracAnswered(),
    InteracQuestionTyped() ||
        InteracAnswerTyped() ||
        InteracSaveAsDefaultSet() ||
        InteracContinuePressed(),
  ) =>
    StepNext.stay(state),
};
