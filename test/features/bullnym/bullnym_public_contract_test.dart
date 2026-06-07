import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:test/test.dart';

void main() {
  test('public facade exports stable result and error contract', () {
    const register = BullnymRegisterResult(
      nym: 'alice',
      lightningAddress: 'alice@bullpay.ca',
    );
    const lookup = BullnymLookupResult(nym: 'alice', active: true);
    const failure = BullnymException.invalidServerResponse();

    expect(register.nym, 'alice');
    expect(lookup.active, isTrue);
    expect(failure.kind, BullnymErrorKind.invalidServerResponse);
  });
}
