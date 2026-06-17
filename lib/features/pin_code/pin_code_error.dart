import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter/widgets.dart';

sealed class PinCodeError extends Failure {
  const PinCodeError([super.message]);
  String toTranslated(BuildContext context);
}

class PinCodeSaveError extends PinCodeError {
  const PinCodeSaveError() : super(null);
  @override
  String toTranslated(BuildContext context) => context.loc.pinCodeSaveError;
}

class PinCodeDeleteError extends PinCodeError {
  const PinCodeDeleteError() : super(null);
  @override
  String toTranslated(BuildContext context) => context.loc.pinCodeDeleteError;
}

class PinCodeNotSetError extends PinCodeError {
  const PinCodeNotSetError() : super(null);
  @override
  String toTranslated(BuildContext context) => context.loc.pinCodeNotSetError;
}

/// Catch-all. [message] is for logs only and MUST never reach the UI —
/// `toTranslated` returns the shared generic string, not [message].
class PinCodeUnexpectedError extends PinCodeError {
  const PinCodeUnexpectedError(super.message);
  @override
  String toTranslated(BuildContext context) =>
      context.loc.oopsSomethingWentWrong;
}
