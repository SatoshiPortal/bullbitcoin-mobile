import 'package:flutter_test/flutter_test.dart';
import 'package:sync/src/data/read/wallet_frame_mapper.dart';

void main() {
  // The helper the Bitcoin frame uses for every coin:
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
