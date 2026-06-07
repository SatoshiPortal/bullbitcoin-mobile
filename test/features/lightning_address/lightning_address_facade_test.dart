import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:test/test.dart';

void main() {
  test('public facade exports stable Lightning Address contract', () {
    const registration = LightningAddressRegistration(
      nym: 'alice',
      lightningAddress: 'alice@bullpay.ca',
    );
    const status = LightningAddressStatus.active(nym: 'alice');
    const registerCommand = RegisterLightningAddressCommand(
      xprvBase58: 'xprv',
      nym: 'alice',
      ctDescriptor: 'ct-desc',
    );
    const deleteCommand = DeleteLightningAddressRegistrationCommand(
      xprvBase58: 'xprv',
      nym: 'alice',
    );

    expect(registration.lightningAddress, 'alice@bullpay.ca');
    expect(status.kind, LightningAddressStatusKind.active);
    expect(registerCommand.ctDescriptor, 'ct-desc');
    expect(deleteCommand.nym, 'alice');
  });
}
