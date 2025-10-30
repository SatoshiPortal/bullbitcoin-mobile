import 'package:bb_mobile/core/entities/signer_device_entity.dart';

class DeviceConfig {
  final SignerDeviceEntity device;
  final String name;
  final String instructionsTitle;
  final List<String> instructions;

  const DeviceConfig({
    required this.device,
    required this.name,
    required this.instructionsTitle,
    required this.instructions,
  });

  static const Map<SignerDeviceEntity, DeviceConfig> configs = {
    SignerDeviceEntity.jade: DeviceConfig(
      device: SignerDeviceEntity.jade,
      name: 'Blockstream Jade',
      instructionsTitle: 'Blockstream Jade Instructions',
      instructions: [
        'Turn on your Jade device',
        'Select "QR Mode" from the main menu',
        'Follow the device instructions to unlock the Jade',
        'Select "Options" from the main menu',
        'Select "Wallet" from the options list',
        'Select "Export Xpub" from the wallet menu',
        'If needed, select "Options" to change the address type',
        'Click the "open camera" button',
        'Scan the QR code you see on your device.',
        "That's it!",
      ],
    ),
    SignerDeviceEntity.krux: DeviceConfig(
      device: SignerDeviceEntity.krux,
      name: 'Krux',
      instructionsTitle: 'Krux Instructions',
      instructions: [
        'Turn on your Krux device',
        'Click Extended Public Key',
        'Click XPUB - QR Code',
        'Click the "open camera" button',
        'Scan the QR code you see on your device.',
        "That's it!",
      ],
    ),
    SignerDeviceEntity.keystone: DeviceConfig(
      device: SignerDeviceEntity.keystone,
      name: 'Keystone',
      instructionsTitle: 'Keystone Instructions',
      instructions: [
        'Turn on your Keystone device',
        'Click the 3 dots at the top right',
        'Select Connect Software Wallet',
        'Click the "open camera" button',
        'Scan the QR code you see on your device.',
        "That's it!",
      ],
    ),
    SignerDeviceEntity.passport: DeviceConfig(
      device: SignerDeviceEntity.passport,
      name: 'Foundation Passport',
      instructionsTitle: 'Foundation Passport Instructions',
      instructions: [
        'Turn on your Passport device',
        'Select Manage Account',
        'Select Connect Wallet',
        'Select Sparrow',
        'Select Single-sig',
        'Select QR Code',
        'Click the "open camera" button',
        'Scan the QR code you see on your device.',
        "That's it!",
      ],
    ),
    SignerDeviceEntity.seedsigner: DeviceConfig(
      device: SignerDeviceEntity.seedsigner,
      name: 'SeedSigner',
      instructionsTitle: 'SeedSigner Instructions',
      instructions: [
        'Power on your SeedSigner device',
        'Open the "Seeds" menu',
        'Scan a SeedQR or enter your 12- or 24-word seed phrase',
        'Select "Export Xpub"',
        'Choose "Single Sig", then select your preferred script type (choose Native Segwit if unsure).',
        'Select "Sparrow" as the export option',
        'On your mobile device, tap Open Camera',
        'Scan the QR code displayed on your SeedSigner',
        'Enter a label for your SeedSigner wallet and tap Import',
        'Setup complete',
      ],
    ),
    SignerDeviceEntity.specter: DeviceConfig(
      device: SignerDeviceEntity.specter,
      name: 'Specter',
      instructionsTitle: 'Specter Instructions',
      instructions: [
        'Power on your Specter device',
        'Enter your PIN',
        'Enter your seed/key (chose which ever option suits you)',
        'Follow the prompts according to your chosen method',
        'Select "Master public keys"',
        'Choose "Single key"',
        'Disable "Use SLIP-132"',
        'On your mobile device, tap Open Camera',
        'Scan the QR code displayed on your Specter',
        'Enter a label for your Specter wallet and tap Import',
        'Setup is complete',
      ],
    ),
  };
}
