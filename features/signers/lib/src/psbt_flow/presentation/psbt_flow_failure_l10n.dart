import 'package:signers/src/signers_l10n.dart';
import 'package:signers/src/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:flutter/widgets.dart';

extension PsbtFlowFailureL10n on PsbtFlowFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PsbtFlowInvalidPsbtFailure() => context.loc.psbtFlowInvalidPsbtError,
    PsbtFlowQrEncodingFailure() => context.loc.psbtFlowQrEncodingError,
  };
}
