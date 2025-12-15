import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/bottom_sheet/instructions_bottom_sheet.dart';
import 'package:flutter/material.dart';

class ColdcardQInstructionsBottomSheet {
  static Future<void> show(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: context.loc.importColdcardInstructionsTitle,
      instructions: [
        context.loc.importColdcardInstructionsStep1,
        context.loc.importColdcardInstructionsStep2,
        context.loc.importColdcardInstructionsStep3,
        context.loc.importColdcardInstructionsStep4,
        context.loc.importColdcardInstructionsStep5,
        context.loc.importColdcardInstructionsStep6,
        context.loc.importColdcardInstructionsStep7,
        context.loc.importColdcardInstructionsStep8,
        context.loc.importColdcardInstructionsStep9,
        context.loc.importColdcardInstructionsStep10,
      ],
    );
  }
}
