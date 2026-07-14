import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:flutter/widgets.dart';

extension BtcpayFailureL10n on BtcpayFailure {
  String toTranslated(BuildContext context) => switch (this) {
    InvalidBtcpayPairingRequestFailure() =>
      context.loc.btcpayPairingInvalidRequestError,
    BtcpayPairingRejectedFailure() => context.loc.btcpayPairingRejectedError,
    BtcpayPairingUncertainFailure() => context.loc.btcpayPairingUncertainError,
    BtcpayWalletPreparationFailure() ||
    BtcpayPayloadFailure() ||
    BtcpayStorageFailure() ||
    BtcpayRollbackFailure() ||
    BtcpayUnexpectedFailure() => context.loc.btcpayPairingGenericError,
  };
}
