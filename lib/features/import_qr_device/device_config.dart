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
        'Turn on your SeedSigner device',
        'Select Seeds',
        'Select the seed you wish to connect',
        'Select Export Xpub',
        'Select Single Sig then select the script type to use (select Native Segwit if unsure)',
        'Click the "open camera" button',
        'Scan the QR code you see on your device.',
        "That's it!",
      ],
    ),
  };
}
