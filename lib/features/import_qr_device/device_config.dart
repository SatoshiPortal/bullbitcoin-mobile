import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class DeviceConfig {
  final SignerDeviceEntity device;
  final String Function(BuildContext) getName;
  final String Function(BuildContext) getInstructionsTitle;
  final List<String> Function(BuildContext) getInstructions;

  const DeviceConfig({
    required this.device,
    required this.getName,
    required this.getInstructionsTitle,
    required this.getInstructions,
  });

  static final Map<SignerDeviceEntity, DeviceConfig> configs = {
    SignerDeviceEntity.jade: DeviceConfig(
      device: SignerDeviceEntity.jade,
      getName: (context) => context.loc.importQrDeviceJadeName,
      getInstructionsTitle: (context) =>
          context.loc.importQrDeviceJadeInstructionsTitle,
      getInstructions: (context) => [
        context.loc.importQrDeviceJadeStep1,
        context.loc.importQrDeviceJadeStep2,
        context.loc.importQrDeviceJadeStep3,
        context.loc.importQrDeviceJadeStep4,
        context.loc.importQrDeviceJadeStep5,
        context.loc.importQrDeviceJadeStep6,
        context.loc.importQrDeviceJadeStep7,
        context.loc.importQrDeviceJadeStep8,
        context.loc.importQrDeviceJadeStep9,
        context.loc.importQrDeviceJadeStep10,
      ],
    ),
    SignerDeviceEntity.krux: DeviceConfig(
      device: SignerDeviceEntity.krux,
      getName: (context) => context.loc.importQrDeviceKruxName,
      getInstructionsTitle: (context) =>
          context.loc.importQrDeviceKruxInstructionsTitle,
      getInstructions: (context) => [
        context.loc.importQrDeviceKruxStep1,
        context.loc.importQrDeviceKruxStep2,
        context.loc.importQrDeviceKruxStep3,
        context.loc.importQrDeviceKruxStep4,
        context.loc.importQrDeviceKruxStep5,
        context.loc.importQrDeviceKruxStep6,
      ],
    ),
    SignerDeviceEntity.keystone: DeviceConfig(
      device: SignerDeviceEntity.keystone,
      getName: (context) => context.loc.importQrDeviceKeystoneName,
      getInstructionsTitle: (context) =>
          context.loc.importQrDeviceKeystoneInstructionsTitle,
      getInstructions: (context) => [
        context.loc.importQrDeviceKeystoneStep1,
        context.loc.importQrDeviceKeystoneStep2,
        context.loc.importQrDeviceKeystoneStep3,
        context.loc.importQrDeviceKeystoneStep4,
        context.loc.importQrDeviceKeystoneStep5,
        context.loc.importQrDeviceKeystoneStep6,
        context.loc.importQrDeviceKeystoneStep7,
        context.loc.importQrDeviceKeystoneStep8,
        context.loc.importQrDeviceKeystoneStep9,
        context.loc.importQrDeviceKeystoneStep10,
      ],
    ),
    SignerDeviceEntity.passport: DeviceConfig(
      device: SignerDeviceEntity.passport,
      getName: (context) => context.loc.importQrDevicePassportName,
      getInstructionsTitle: (context) =>
          context.loc.importQrDevicePassportInstructionsTitle,
      getInstructions: (context) => [
        context.loc.importQrDevicePassportStep1,
        context.loc.importQrDevicePassportStep2,
        context.loc.importQrDevicePassportStep3,
        context.loc.importQrDevicePassportStep4,
        context.loc.importQrDevicePassportStep5,
        context.loc.importQrDevicePassportStep6,
        context.loc.importQrDevicePassportStep7,
        context.loc.importQrDevicePassportStep8,
        context.loc.importQrDevicePassportStep9,
        context.loc.importQrDevicePassportStep10,
        context.loc.importQrDevicePassportStep11,
        context.loc.importQrDevicePassportStep12,
      ],
    ),
    SignerDeviceEntity.seedsigner: DeviceConfig(
      device: SignerDeviceEntity.seedsigner,
      getName: (context) => context.loc.importQrDeviceSeedsignerName,
      getInstructionsTitle: (context) =>
          context.loc.importQrDeviceSeedsignerInstructionsTitle,
      getInstructions: (context) => [
        context.loc.importQrDeviceSeedsignerStep1,
        context.loc.importQrDeviceSeedsignerStep2,
        context.loc.importQrDeviceSeedsignerStep3,
        context.loc.importQrDeviceSeedsignerStep4,
        context.loc.importQrDeviceSeedsignerStep5,
        context.loc.importQrDeviceSeedsignerStep6,
        context.loc.importQrDeviceSeedsignerStep7,
        context.loc.importQrDeviceSeedsignerStep8,
        context.loc.importQrDeviceSeedsignerStep9,
        context.loc.importQrDeviceSeedsignerStep10,
      ],
    ),
    SignerDeviceEntity.specter: DeviceConfig(
      device: SignerDeviceEntity.specter,
      getName: (context) => context.loc.importQrDeviceSpecterName,
      getInstructionsTitle: (context) =>
          context.loc.importQrDeviceSpecterInstructionsTitle,
      getInstructions: (context) => [
        context.loc.importQrDeviceSpecterStep1,
        context.loc.importQrDeviceSpecterStep2,
        context.loc.importQrDeviceSpecterStep3,
        context.loc.importQrDeviceSpecterStep4,
        context.loc.importQrDeviceSpecterStep5,
        context.loc.importQrDeviceSpecterStep6,
        context.loc.importQrDeviceSpecterStep7,
        context.loc.importQrDeviceSpecterStep8,
        context.loc.importQrDeviceSpecterStep9,
        context.loc.importQrDeviceSpecterStep10,
        context.loc.importQrDeviceSpecterStep11,
      ],
    ),
  };
}
