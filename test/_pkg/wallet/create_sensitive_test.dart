import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WalletSensitiveCreate createWallet;
  setUp(() {
    createWallet = WalletSensitiveCreate();
  });

  test('Bad Mnemonic - Create Wallet Error', () async {
    final (fingerprint, err) = await createWallet.getFingerprint(mnemonic: 'fdsaf dadfs');
    expect(err, isNotNull);
    expect(fingerprint, isNull);
  });
}
