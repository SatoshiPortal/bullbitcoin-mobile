import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/instructions_bottom_sheet.dart';
import 'package:flutter/material.dart';

class QrDeviceInstructions {
  static Future<void> showKruxInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.kruxInstructionsTitle,
      instructions: [
        context.loc.kruxStep1,
        context.loc.kruxStep2,
        context.loc.kruxStep3,
        context.loc.kruxStep4,
        context.loc.kruxStep5,
        context.loc.kruxStep6,
        context.loc.kruxStep7,
        context.loc.kruxStep8,
        context.loc.kruxStep9,
        context.loc.kruxStep10,
        context.loc.kruxStep11,
        context.loc.kruxStep12,
        context.loc.kruxStep13,
        context.loc.kruxStep14,
        context.loc.kruxStep15,
        context.loc.kruxStep16,
      ],
    );
  }

  static Future<void> showKeystoneInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.keystoneInstructionsTitle,
      instructions: [
        context.loc.keystoneStep1,
        context.loc.keystoneStep2,
        context.loc.keystoneStep3,
        context.loc.keystoneStep4,
        context.loc.keystoneStep5,
        context.loc.keystoneStep6,
        context.loc.keystoneStep7,
        context.loc.keystoneStep8,
        context.loc.keystoneStep9,
        context.loc.keystoneStep10,
        context.loc.keystoneStep11,
        context.loc.keystoneStep12,
        context.loc.keystoneStep13,
        context.loc.keystoneStep14,
      ],
    );
  }

  static Future<void> showPassportInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.passportInstructionsTitle,
      instructions: [
        context.loc.passportStep1,
        context.loc.passportStep2,
        context.loc.passportStep3,
        context.loc.passportStep4,
        context.loc.passportStep5,
        context.loc.passportStep6,
        context.loc.passportStep7,
        context.loc.passportStep8,
        context.loc.passportStep9,
        context.loc.passportStep10,
        context.loc.passportStep11,
        context.loc.passportStep12,
        context.loc.passportStep13,
        context.loc.passportStep14,
      ],
    );
  }

  static Future<void> showSeedSignerInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.seedsignerInstructionsTitle,
      instructions: [
        context.loc.seedsignerStep1,
        context.loc.seedsignerStep2,
        context.loc.seedsignerStep3,
        context.loc.seedsignerStep4,
        context.loc.seedsignerStep5,
        context.loc.seedsignerStep6,
        context.loc.seedsignerStep7,
        context.loc.seedsignerStep8,
        context.loc.seedsignerStep9,
        context.loc.seedsignerStep10,
        context.loc.seedsignerStep11,
        context.loc.seedsignerStep12,
        context.loc.seedsignerStep13,
        context.loc.seedsignerStep14,
      ],
    );
  }

  static Future<void> showSpecterInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.psbtFlowSpecterTitle,
      instructions: [
        context.loc.psbtFlowTurnOnDevice('Specter'),
        context.loc.psbtFlowClickScan,
        context.loc.psbtFlowScanQrShown,
        context.loc.psbtFlowTroubleScanningTitle,
        '   - ${context.loc.psbtFlowIncreaseBrightness}',
        '   - ${context.loc.psbtFlowMoveLaser}',
        '   - ${context.loc.psbtFlowMoveBack}',
        context.loc.psbtFlowSelectSeed('Specter'),
        context.loc.psbtFlowReviewTransaction('Specter'),
        context.loc.psbtFlowSignTransactionOnDevice('Specter'),
        context.loc.psbtFlowDeviceShowsQr('Specter'),
        context.loc.psbtFlowClickDone,
        context.loc.psbtFlowScanDeviceQr('Specter'),
        context.loc.psbtFlowTransactionImported,
        context.loc.psbtFlowReadyToBroadcast,
      ],
    );
  }

  static Future<void> showColdcardInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.coldcardInstructionsTitle,
      instructions: [
        context.loc.coldcardStep1,
        context.loc.coldcardStep2,
        context.loc.coldcardStep3,
        context.loc.coldcardStep4,
        context.loc.coldcardStep5,
        context.loc.coldcardStep6,
        context.loc.coldcardStep7,
        context.loc.coldcardStep8,
        context.loc.coldcardStep9,
        context.loc.coldcardStep10,
        context.loc.coldcardStep11,
        context.loc.coldcardStep12,
        context.loc.coldcardStep13,
        context.loc.coldcardStep14,
        context.loc.coldcardStep15,
      ],
    );
  }

  static Future<void> showJadeInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.jadeInstructionsTitle,
      instructions: [
        context.loc.jadeStep1,
        context.loc.jadeStep2,
        context.loc.jadeStep3,
        context.loc.jadeStep4,
        context.loc.jadeStep5,
        context.loc.jadeStep6,
        context.loc.jadeStep7,
        context.loc.jadeStep8,
        context.loc.jadeStep9,
        context.loc.jadeStep10,
        context.loc.jadeStep11,
        context.loc.jadeStep12,
        context.loc.jadeStep13,
        context.loc.jadeStep14,
        context.loc.jadeStep15,
      ],
    );
  }
}
