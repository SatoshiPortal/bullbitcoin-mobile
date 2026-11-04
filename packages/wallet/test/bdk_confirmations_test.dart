import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/src/data/bdk/bdk_wallet_datasource.dart'
    show confirmationsFromTip;

void main() {
  // Exercises the real helper used by `BdkWalletDatasource.getUtxos` (D2):
  // `max(0, tip - height + 1)`, with unconfirmed utxos reporting 0.
  group('confirmationsFromTip — max(0, tip - height + 1)', () {
    test('a utxo in the tip block has 1 confirmation', () {
      expect(confirmationsFromTip(tip: 100, height: 100), 1);
    });

    test('counts depth correctly below the tip', () {
      expect(confirmationsFromTip(tip: 100, height: 96), 5);
    });

    test('unconfirmed utxo (no height) reports 0', () {
      expect(confirmationsFromTip(tip: 100, height: null), 0);
    });

    test('clamps to 0 when tip < height (reorg / mid-sync)', () {
      expect(confirmationsFromTip(tip: 100, height: 105), 0);
    });
  });
}
