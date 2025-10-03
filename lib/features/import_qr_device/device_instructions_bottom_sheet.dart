import 'package:bb_mobile/core/widgets/bottom_sheet/instructions_bottom_sheet.dart';
import 'package:flutter/material.dart';

class DeviceInstructionsBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> instructions,
  }) {
    return InstructionsBottomSheet.show(
      context,
      title: title,
      instructions: instructions,
    );
  }
}
