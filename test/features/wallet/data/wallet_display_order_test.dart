import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show ScriptType, SignerEntity;

Wallet wallet(String origin, Network network, {bool isDefault = false}) =>
    Wallet(
      origin: origin,
      network: network,
      isDefault: isDefault,
      xpubFingerprint: origin,
      scriptType: ScriptType.bip84,
      xpub: 'xpub',
      externalPublicDescriptor: 'external',
      internalPublicDescriptor: 'internal',
      signer: SignerEntity.local,
      signerDevice: null,
      balanceSat: BigInt.zero,
    );

void main() {
  test('Secure Bitcoin, then Instant payments, then the rest in order', () {
    final imported = wallet('imported', Network.bitcoinRegtest);
    final instant = wallet('instant', Network.liquidRegtest, isDefault: true);
    final watchOnly = wallet('watch-only', Network.bitcoinRegtest);
    final secure = wallet('secure', Network.bitcoinRegtest, isDefault: true);
    expect(
      walletDisplayOrder([imported, instant, watchOnly, secure])
          .map((w) => w.origin),
      ['secure', 'instant', 'imported', 'watch-only'],
    );
  });

  test('without default wallets the store order is kept', () {
    final a = wallet('a', Network.bitcoinRegtest);
    final b = wallet('b', Network.liquidRegtest);
    expect(walletDisplayOrder([a, b]).map((w) => w.origin), ['a', 'b']);
  });
}
