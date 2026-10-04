import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

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
    if (question == null ||
        answer == null ||
        question.length < 3 ||
        question.length > 40 ||
        answer.length < 3 ||
        answer.length > 40 ||
        !_answerPattern.hasMatch(answer)) {
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

  static final _answerPattern = RegExp(r'^[a-zA-ZÀ-ž0-9\-]*$');

  @override
  String toString() =>
      'InteracSecurityDetails(recipientId: $recipientId, email: $email)';
}
