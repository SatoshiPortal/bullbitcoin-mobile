import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_failure.dart';
import 'package:flutter/widgets.dart';

extension PsbtSigningFailureL10n on PsbtSigningFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PsbtSigningWalletUnavailableFailure() =>
      context.loc.psbtSigningWalletUnavailable,
    PsbtSigningInvalidPsbtFailure() => context.loc.psbtSigningInvalidPsbt,
    PsbtSigningWalletMismatchFailure() => context.loc.psbtSigningWalletMismatch,
    PsbtSigningMissingLocalKeyFailure() =>
      context.loc.psbtSigningMissingLocalKey,
    PsbtSigningMissingUtxoFailure() => context.loc.psbtSigningMissingUtxo,
    PsbtSigningFrozenUtxoFailure() => context.loc.psbtSigningFrozenUtxo,
    PsbtSigningUnsupportedSighashFailure() =>
      context.loc.psbtSigningUnsupportedSighash,
    PsbtSigningUnsupportedSpendModeFailure() =>
      context.loc.psbtSigningUnsupportedSpendMode,
    PsbtSigningNoSignatureAddedFailure() =>
      context.loc.psbtSigningNoSignatureAdded,
    PsbtSigningUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
