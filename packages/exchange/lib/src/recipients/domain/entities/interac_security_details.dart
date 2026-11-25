import 'package:exchange/src/domain/exchange_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

final class InteracSecurityDetails {
  const InteracSecurityDetails._({
    required this.recipientId,
    required this.email,
    required this.securityQuestion,
    required this.securityAnswer,
  });

  final String recipientId;
  final String email;
  final String? securityQuestion;
  final String? securityAnswer;

  @useResult
  static Result<InteracSecurityDetails, RecipientsFailure> create({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
  }) {
    if (recipientId.trim().isEmpty || email.trim().isEmpty) {
      return const Err(
        RecipientsInvalidSecurityDetailsFailure(
          'Invalid Interac recipient details',
        ),
      );
    }
    final question = securityQuestion?.trim();
    final answer = securityAnswer?.trim();
    if (question == null && answer == null) {
      return Ok(
        InteracSecurityDetails._(
          recipientId: recipientId.trim(),
          email: email.trim(),
          securityQuestion: null,
          securityAnswer: null,
        ),
      );
    }
    if (InteracSecurityAnswer.check(question, answer) != null) {
      return const Err(
        RecipientsInvalidSecurityDetailsFailure(
          'Invalid Interac security details',
        ),
      );
    }
    return Ok(
      InteracSecurityDetails._(
        recipientId: recipientId.trim(),
        email: email.trim(),
        securityQuestion: question,
        securityAnswer: answer,
      ),
    );
  }

  @override
  String toString() =>
      'InteracSecurityDetails(recipientId: $recipientId, email: $email)';
}

/// What is wrong with an Interac security question and answer.
enum InteracAnswerProblem {
  /// The question or the answer is empty.
  missing,

  /// The question is not 3 to 40 characters long.
  questionLength,

  /// The answer is not 3 to 40 characters long.
  answerLength,

  /// The answer has a character other than a letter, a digit or a hyphen.
  answerCharacters,
}

/// The security question and answer an Interac payout sends, checked by
/// the server's rules (API-Orders `schemas.ts`: both 3–40 characters, the
/// answer letters, digits and hyphens only). The one validator for the
/// recipient form and the payout step.
@immutable
final class InteracSecurityAnswer {
  final String question;
  final String answer;

  const InteracSecurityAnswer._(this.question, this.answer);

  static final _answerPattern = RegExp(r'^[a-zA-ZÀ-ž0-9\-]*$');

  /// The problem of [question] alone (trimmed), or null when it is valid.
  static InteracAnswerProblem? questionProblem(String? question) {
    final q = question?.trim() ?? '';
    if (q.isEmpty) return InteracAnswerProblem.missing;
    if (q.length < 3 || q.length > 40) {
      return InteracAnswerProblem.questionLength;
    }
    return null;
  }

  /// The problem of [answer] alone (trimmed), or null when it is valid.
  static InteracAnswerProblem? answerProblem(String? answer) {
    final a = answer?.trim() ?? '';
    if (a.isEmpty) return InteracAnswerProblem.missing;
    if (a.length < 3 || a.length > 40) return InteracAnswerProblem.answerLength;
    if (!_answerPattern.hasMatch(a)) {
      return InteracAnswerProblem.answerCharacters;
    }
    return null;
  }

  /// The first problem of [question] and [answer], or null when both are
  /// valid.
  static InteracAnswerProblem? check(String? question, String? answer) =>
      questionProblem(question) ?? answerProblem(answer);

  /// The answer, or null when [check] finds a problem.
  @useResult
  static InteracSecurityAnswer? create(String? question, String? answer) =>
      check(question, answer) == null
      ? InteracSecurityAnswer._(question!.trim(), answer!.trim())
      : null;

  @override
  bool operator ==(Object other) =>
      other is InteracSecurityAnswer &&
      other.question == question &&
      other.answer == answer;

  @override
  int get hashCode => Object.hash(question, answer);

  /// The answer is a secret: never printed.
  @override
  String toString() => 'InteracSecurityAnswer(***)';
}
