import 'package:bb_mobile/core/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

extension ColdcardFirmwareFailureL10n on ColdcardFirmwareFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ColdcardFirmwareNetworkFailure() => context.loc.coldcardUpdateErrorNetwork,
    ColdcardFirmwareDiscoveryFailure() =>
      context.loc.coldcardUpdateErrorDiscovery,
    ColdcardFirmwareVerificationFailure() =>
      context.loc.coldcardUpdateErrorVerification,
    ColdcardFirmwareSaveFailure() => context.loc.coldcardUpdateErrorSave,
    ColdcardFirmwareUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
