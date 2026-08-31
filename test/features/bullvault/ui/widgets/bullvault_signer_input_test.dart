import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_signer_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offers only devices that can register complex Taproot policies', () {
    expect(BullVaultSignerInput.supportedDevices, [
      SignerDeviceEntity.bitbox02,
      SignerDeviceEntity.krux,
      SignerDeviceEntity.ledgerNanoSPlus,
      SignerDeviceEntity.ledgerNanoX,
      SignerDeviceEntity.ledgerFlex,
      SignerDeviceEntity.ledgerStax,
      SignerDeviceEntity.specter,
    ]);
  });
}
