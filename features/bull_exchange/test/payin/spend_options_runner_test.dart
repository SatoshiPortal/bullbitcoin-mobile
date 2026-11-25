import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';

const _fees = FeeOptions(
  fastest: RelativeFee(2500),
  economic: RelativeFee(1250),
  slow: RelativeFee(500),
  minRelay: RelativeFee(25),
);
const _shape = SpendPreviewShape(
  'w1',
  SpendPreviewTarget('bc1q', 1000),
  true,
  {},
);
const _slot = BitcoinFeePreviewSlot(feeSat: 300, txSize: 140);

void main() {
  test('every answer carries the attempt or epoch of its effect', () {
    fakeAsync((async) {
      final events = <SpendOptionsEvent>[];
      var feesOk = false;
      final runner = SpendOptionsRunner((
        fees: () async => feesOk ? _fees : null,
        coins: (walletId) async => null,
        presets: (shape, fees) async => {FeeSelection.fastest: _slot},
        custom: (shape, fee) async => _slot,
      ), events.add);
      runner.run(const [
        SpendLoadFees(1),
        SpendLoadCoins('w1'),
        SpendPreviewPresets(3, _fees, _shape),
        SpendPreviewCustom(3, RelativeFee(800), _shape),
      ]);
      async.flushMicrotasks();
      feesOk = true;
      runner.run(const [SpendLoadFees(2)]);
      async.flushMicrotasks();
      expect(
        events[0],
        isA<SpendFeesFailed>().having((e) => e.attempt, 'attempt', 1),
      );
      expect(
        events[1],
        isA<SpendCoinsRead>().having((e) => e.coins, 'coins', isNull),
      );
      expect(
        events[2],
        isA<SpendPresetsPreviewed>().having((e) => e.epoch, 'epoch', 3),
      );
      expect(
        events[3],
        isA<SpendCustomPreviewed>()
            .having((e) => e.epoch, 'epoch', 3)
            .having((e) => e.fee, 'fee', const RelativeFee(800)),
      );
      expect(
        events[4],
        isA<SpendFeesLoaded>().having((e) => e.attempt, 'attempt', 2),
      );
    });
  });

  test('nothing is answered after close', () {
    fakeAsync((async) {
      final events = <SpendOptionsEvent>[];
      final runner = SpendOptionsRunner((
        fees: () async => _fees,
        coins: (walletId) async => const [],
        presets: (shape, fees) async => const {},
        custom: (shape, fee) async => _slot,
      ), events.add);
      runner.run(const [SpendLoadFees(1)]);
      runner.close();
      async.flushMicrotasks();
      expect(events, isEmpty);
    });
  });
}
