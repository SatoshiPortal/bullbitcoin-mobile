import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/instructions_bottom_sheet.dart';
import 'package:flutter/material.dart';

class ColdcardQInstructionsBottomSheet {
  static Future<void> show(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.importColdcardQInstructionsTitle,
      instructions: [
        context.loc.importColdcardQStep1,
        context.loc.importColdcardQStep2,
        context.loc.importColdcardQStep3,
        context.loc.importColdcardQStep4,
        context.loc.importColdcardQStep5,
        context.loc.importColdcardQStep6,
        context.loc.importColdcardQStep7,
        context.loc.importColdcardQStep8,
        context.loc.importColdcardQStep9,
        context.loc.importColdcardQStep10,
        context.loc.importColdcardQStep11,
        context.loc.importColdcardQStep12,
        context.loc.importColdcardQStep13,
      ],
    );
  }
}

class ColdcardMk4InstructionsBottomSheet {
  static Future<void> show(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.importColdcardMk4InstructionsTitle,
      subtitle: context.loc.coldcardMk4Mk5NfcReliabilityNotice,
      instructions: [
        context.loc.importColdcardMk4Step1,
        context.loc.importColdcardMk4Step2,
        context.loc.importColdcardMk4Step3,
        context.loc.importColdcardMk4Step4,
        context.loc.importColdcardMk4Step5,
        context.loc.importColdcardMk4Step6,
        context.loc.importColdcardMk4Step7,
        context.loc.importColdcardMk4Step8,
        context.loc.importColdcardMk4Step9,
        context.loc.importColdcardMk4Step10,
        context.loc.importColdcardMk4Step11,
        context.loc.importColdcardMk4Step12,
      ],
    );
  }
}
