import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class ReplaceByFeeError extends BullException {
  ReplaceByFeeError(super.message);
}

class NoFeeRateSelectedError extends ReplaceByFeeError {
  NoFeeRateSelectedError(BuildContext context)
      : super(context.loc.replaceByFeeErrorNoFeeRateSelected);
}

class TransactionAlreadyConfirmedError extends ReplaceByFeeError {
  TransactionAlreadyConfirmedError(BuildContext context)
      : super(context.loc.replaceByFeeErrorTransactionConfirmed);
}

class FeeRateTooLowError extends ReplaceByFeeError {
  FeeRateTooLowError(BuildContext context)
      : super(context.loc.replaceByFeeErrorFeeRateTooLow);
}
