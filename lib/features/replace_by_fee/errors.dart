import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

/// Base class for all Replace-by-Fee errors
abstract class ReplaceByFeeError {
  /// Convert error to localized string
  String toTranslated(BuildContext context);
}

class NoFeeRateSelectedError extends ReplaceByFeeError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.replaceByFeeErrorNoFeeRateSelected;
  }
}

class TransactionConfirmedError extends ReplaceByFeeError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.replaceByFeeErrorTransactionConfirmed;
  }
}

class FeeRateTooLowError extends ReplaceByFeeError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.replaceByFeeErrorFeeRateTooLow;
  }
}

class GenericError extends ReplaceByFeeError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.replaceByFeeErrorGeneric;
  }
}
