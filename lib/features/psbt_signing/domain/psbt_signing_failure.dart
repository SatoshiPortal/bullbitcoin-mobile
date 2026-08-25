import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';

sealed class PsbtSigningFailure extends Failure {
  const PsbtSigningFailure([super.logMessage]);

  factory PsbtSigningFailure.fromBitcoinSigning(
    BitcoinSigningFailure failure,
  ) => switch (failure.kind) {
    BitcoinSigningFailureKind.invalidPsbt =>
      const PsbtSigningInvalidPsbtFailure(),
    BitcoinSigningFailureKind.walletMismatch =>
      const PsbtSigningWalletMismatchFailure(),
    BitcoinSigningFailureKind.missingLocalOrigin =>
      const PsbtSigningMissingLocalKeyFailure(),
    BitcoinSigningFailureKind.missingUtxo =>
      const PsbtSigningMissingUtxoFailure(),
    BitcoinSigningFailureKind.frozenUtxo =>
      const PsbtSigningFrozenUtxoFailure(),
    BitcoinSigningFailureKind.unsupportedSighash =>
      const PsbtSigningUnsupportedSighashFailure(),
    BitcoinSigningFailureKind.incomplete =>
      const PsbtSigningNoSignatureAddedFailure(),
    BitcoinSigningFailureKind.unsupportedPolicyPath ||
    BitcoinSigningFailureKind.unexpected =>
      const PsbtSigningUnexpectedFailure(),
  };
}

final class PsbtSigningWalletUnavailableFailure extends PsbtSigningFailure {
  const PsbtSigningWalletUnavailableFailure([super.logMessage]);
}

final class PsbtSigningInvalidPsbtFailure extends PsbtSigningFailure {
  const PsbtSigningInvalidPsbtFailure([super.logMessage]);
}

final class PsbtSigningWalletMismatchFailure extends PsbtSigningFailure {
  const PsbtSigningWalletMismatchFailure([super.logMessage]);
}

final class PsbtSigningMissingLocalKeyFailure extends PsbtSigningFailure {
  const PsbtSigningMissingLocalKeyFailure([super.logMessage]);
}

final class PsbtSigningMissingUtxoFailure extends PsbtSigningFailure {
  const PsbtSigningMissingUtxoFailure([super.logMessage]);
}

final class PsbtSigningFrozenUtxoFailure extends PsbtSigningFailure {
  const PsbtSigningFrozenUtxoFailure([super.logMessage]);
}

final class PsbtSigningUnsupportedSighashFailure extends PsbtSigningFailure {
  const PsbtSigningUnsupportedSighashFailure([super.logMessage]);
}

final class PsbtSigningNoSignatureAddedFailure extends PsbtSigningFailure {
  const PsbtSigningNoSignatureAddedFailure([super.logMessage]);
}

final class PsbtSigningUnexpectedFailure extends PsbtSigningFailure {
  const PsbtSigningUnexpectedFailure([super.logMessage]);
}
