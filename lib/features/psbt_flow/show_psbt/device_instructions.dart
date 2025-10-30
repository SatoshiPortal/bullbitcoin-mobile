import 'package:bb_mobile/core/widgets/bottom_sheet/instructions_bottom_sheet.dart';
import 'package:flutter/material.dart';

class QrDeviceInstructions {
  static Future<void> showKruxInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'Krux Instructions',
      instructions: const [
        'Login to your Krux device',
        'Click Sign',
        'Click PSBT',
        'Click Load from camera',
        'Scan the QR code shown in the Bull wallet',
        'If you have trouble scanning:',
        '   - Increase screen brightness on your device',
        '   - Move the red laser up and down over QR code',
        '   - Try moving your device back a little bit',
        'Once the transaction is imported in your Krux, review the destination address and the amount.',
        'Click the buttons to sign the transaction on your Krux.',
        'The Krux will then show you its own QR code.',
        'Click "I\'m done" in the Bull Bitcoin wallet.',
        'The Bull Bitcoin wallet will ask you to scan the QR code on the Krux. Scan it.',
        'The transaction will be imported in the Bull Bitcoin wallet.',
        "It's now ready to broadcast! As soon as you click broadcast, the transaction will be published on the Bitcoin network and the funds will be sent.",
      ],
    );
  }

  static Future<void> showKeystoneInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'Keystone Instructions',
      instructions: const [
        'Login to your Keystone device',
        'Click Scan',
        'Scan the QR code shown in the Bull wallet',
        'If you have trouble scanning:',
        '   - Increase screen brightness on your device',
        '   - Move the red laser up and down over QR code',
        '   - Try moving your device back a little bit',
        'Once the transaction is imported in your Keystone, review the destination address and the amount.',
        'Click the buttons to sign the transaction on your Keystone.',
        'The Keystone will then show you its own QR code.',
        'Click "I\'m done" in the Bull Bitcoin wallet.',
        'The Bull Bitcoin wallet will ask you to scan the QR code on the Keystone. Scan it.',
        'The transaction will be imported in the Bull Bitcoin wallet.',
        "It's now ready to broadcast! As soon as you click broadcast, the transaction will be published on the Bitcoin network and the funds will be sent.",
      ],
    );
  }

  static Future<void> showPassportInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'Foundation Passport Instructions',
      instructions: const [
        'Login to your Passport device',
        'Click Sign with QR Code',
        'Scan the QR code shown in the Bull wallet',
        'If you have trouble scanning:',
        '   - Increase screen brightness on your device',
        '   - Move the red laser up and down over QR code',
        '   - Try moving your device back a little bit',
        'Once the transaction is imported in your Passport, review the destination address and the amount.',
        'Click the buttons to sign the transaction on your Passport.',
        'The Passport will then show you its own QR code.',
        'Click "I\'m done" in the Bull Bitcoin wallet.',
        'The Bull Bitcoin wallet will ask you to scan the QR code on the Passport. Scan it.',
        'The transaction will be imported in the Bull Bitcoin wallet.',
        "It's now ready to broadcast! As soon as you click broadcast, the transaction will be published on the Bitcoin network and the funds will be sent.",
      ],
    );
  }

  static Future<void> showSeedSignerInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'SeedSigner Instructions',
      instructions: const [
        'Turn on your SeedSigner device',
        'Click Scan',
        'Scan the QR code shown in the Bull wallet',
        'If you have trouble scanning:',
        '   - Increase screen brightness on your device',
        '   - Move the red laser up and down over QR code',
        '   - Try moving your device back a little bit',
        'Once the transaction is imported in your SeedSigner, you should select the seed you wish to sign with.',
        'Review the destination address and the amount, and confirm the signing on your SeedSigner.',
        'The SeedSigner will then show you its own QR code.',
        'Click "I\'m done" in the Bull Bitcoin wallet.',
        'The Bull Bitcoin wallet will ask you to scan the QR code on the SeedSigner. Scan it.',
        'The transaction will be imported in the Bull Bitcoin wallet.',
        "It's now ready to broadcast! As soon as you click broadcast, the transaction will be published on the Bitcoin network and the funds will be sent.",
      ],
    );
  }

  static Future<void> showSpecterInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'Specter Instructions',
      instructions: const [
        'Turn on your Specter device',
        'Click Scan',
        'Scan the QR code shown in the Bull wallet',
        'If you have trouble scanning:',
        '   - Increase screen brightness on your device',
        '   - Move the red laser up and down over QR code',
        '   - Try moving your device back a little bit',
        'Once the transaction is imported in your Specter, you should select the seed you wish to sign with.',
        'Review the destination address and the amount, and confirm the signing on your Specter.',
        'The Specter will then show you its own QR code.',
        'Click "I\'m done" in the Bull Bitcoin wallet.',
        'The Bull Bitcoin wallet will ask you to scan the QR code on the Specter. Scan it.',
        'The transaction will be imported in the Bull Bitcoin wallet.',
        "It's now ready to broadcast! As soon as you click broadcast, the transaction will be published on the Bitcoin network and the funds will be sent.",
      ],
    );
  }

  static Future<void> showColdcardInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'Coldcard Q Instructions',
      instructions: const [
        'Login to your Coldcard Q device',
        'Add a passphrase if you have one (optional)',
        'Select "Scan any QR code" option',
        'Scan the QR code shown in the Bull wallet',
        'If you have trouble scanning:',
        '   - Increase screen brightness on your device',
        '   - Move the red laser up and down over QR code',
        '   - Try moving your device back a little bit',
        'Once the transaction is imported in your Coldcard, review the destination address and the amount.',
        'Click the buttons to sign the transaction on your Coldcard.',
        'The Coldcard Q will then show you its own QR code.',
        'Click "I\'m done" in the Bull Bitcoin wallet.',
        'The Bull Bitcoin wallet will ask you to scan the QR code on the Coldcard. Scan it.',
        'The transaction will be imported in the Bull Bitcoin wallet.',
        "It's now ready to broadcast! As soon as you click broadcast, the transaction will be published on the Bitcoin network and the funds will be sent.",
      ],
    );
  }

  static Future<void> showJadeInstructions(BuildContext context) {
    return InstructionsBottomSheet.show(
      context,
      title: 'Blockstream Jade PSBT Instructions',
      instructions: const [
        'Login to your Jade device',
        'Add a passphrase if you have one (optional)',
        'Select "Scan QR" option',
        'Scan the QR code shown in the Bull wallet',
        'If you have trouble scanning:',
        '   - Increase screen brightness on your device',
        '   - Hold the QR code steady and centered',
        '   - Try moving your device closer or further away',
        'Once the transaction is imported in your Jade, review the destination address and the amount.',
        'Click the buttons to sign the transaction on your Jade.',
        'The Jade will then show you its own QR code.',
        'Click "I\'m done" in the Bull Bitcoin wallet.',
        'The Bull Bitcoin wallet will ask you to scan the QR code on the Jade. Scan it.',
        'The transaction will be imported in the Bull Bitcoin wallet.',
        "It's now ready to broadcast! As soon as you click broadcast, the transaction will be published on the Bitcoin network and the funds will be sent.",
      ],
    );
  }
}
