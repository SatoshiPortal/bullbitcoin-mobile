import 'package:bb_mobile/core/widgets/bottom_sheet/instructions_bottom_sheet.dart';
import 'package:flutter/material.dart';

class ColdcardQInstructionsBottomSheet {
  static Future<void> show(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'Coldcard Q Instructions',
      instructions: const [
        'Login to your Coldcard Q device',
        'Add a passphrase if you have one (optional)',
        'Select the advanced/settings menu',
        'Click "export wallet"',
        'Select "descriptor" as export type',
        'Press "Enter" on first screen',
        'Press "Enter" on second screen',
        'Select your address type (use Segwit if unsure)',
        'For QR, click the QR code button on the device. It will show you a QR code on the device',
        'For NFC, click the NFC button on the device',
        'Click the "Open the camera" / "Scan via NFC" button',
        'Scan the QR code you see on your device or put the phone NFC on top of the Coldcard NFC',
        "That's it!",
      ],
    );
  }
}

class ColdcardMk4InstructionsBottomSheet {
  static Future<void> show(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'Coldcard Mk4 Instructions',
      instructions: const [
        'Login to your Coldcard Mk4 device',
        'Add a passphrase if you have one (optional)',
        'Select the advanced/settings menu',
        'Click "export wallet"',
        'Select "descriptor" as export type',
        'Press "Enter" on first screen',
        'Press "Enter" on second screen',
        'Select your address type (use Segwit if unsure)',
        'Click the number 3 to start the Coldcard NFC',
        'Click "Scan via NFC" button',
        'Put the phone NFC on top of the Coldcard NFC',
        "That's it!",
      ],
    );
  }
}
