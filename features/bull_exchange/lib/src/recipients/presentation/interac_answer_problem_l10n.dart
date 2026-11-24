import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

extension InteracAnswerProblemL10n on InteracAnswerProblem {
  String toTranslated(BuildContext context) => switch (this) {
    InteracAnswerProblem.missing =>
      context.loc.recipientsValidationFieldRequired,
    InteracAnswerProblem.questionLength =>
      context.loc.withdrawInteracSecurityQuestionLengthError,
    InteracAnswerProblem.answerLength =>
      context.loc.withdrawInteracSecurityAnswerLengthError,
    InteracAnswerProblem.answerCharacters =>
      context.loc.withdrawInteracSecurityAnswerFormatError,
  };
}
