import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullInstructionsSheet;

class DeviceInstructionsBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> instructions,
  }) {
    return BullInstructionsSheet.show(
      context,
      title: title,
      instructions: instructions,
    );
  }
}
