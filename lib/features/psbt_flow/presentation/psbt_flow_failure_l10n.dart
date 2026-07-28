import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:flutter/widgets.dart';

extension PsbtFlowFailureL10n on PsbtFlowFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PsbtFlowInvalidPsbtFailure() => context.loc.psbtFlowInvalidPsbtError,
    PsbtFlowQrEncodingFailure() => context.loc.psbtFlowQrEncodingError,
    PsbtFlowUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
