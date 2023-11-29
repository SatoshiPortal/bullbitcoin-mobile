import 'package:bb_mobile/_model/electrum.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Create Blockchain', () {
    test('connect to bb electrum', () async {
      final walletSync = WalletSync();
      const bb = ElectrumNetwork.bullbitcoin();

      final (_, err) = await walletSync.createBlockChain(
        stopGap: bb.stopGap,
        timeout: bb.timeout,
        retry: bb.retry,
        url: bb.mainnet,
        validateDomain: bb.validateDomain,
      );

      expect(err, isNull);
    });
  });
}
