import 'package:bull_exchange/src/payin/spend_options_state.dart';
import 'package:bull_exchange/src/payin/spend_options_event.dart';
import 'package:bull_exchange/src/payin/spend_options_effect.dart';
import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show Coin;
import 'package:flutter_test/flutter_test.dart';

import 'payin_fixtures.dart';
import 'payin_usecase_fakes.dart';

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
      final sessions = <ExchangeSession>[];
      final runner = SpendOptionsRunner(
        fakeSpendOptions(
          getFees: FakeGetFeeOptionsUsecase((session) async {
            sessions.add(session);
            return feesOk
                ? const Ok(_fees)
                : const Err(ExchangeFeeEstimatesUnavailableFailure());
          }),
          getCoins: FakeGetWalletCoinsUsecase(
            (walletId) async =>
                const Err(ExchangeWalletCoinsUnavailableFailure()),
          ),
          previewPresets: FakePreviewFeePresetsUsecase(
            (shape, fees) async => {FeeSelection.fastest: _slot},
          ),
          previewCustom: FakePreviewCustomFeeUsecase(
            (shape, fee) async => _slot,
          ),
        ),
        payinTestnetSession,
        events.add,
      );
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
        isA<SpendFeesRead>()
            .having((e) => e.attempt, 'attempt', 1)
            .having(
              (e) => e.fees,
              'fees',
              isA<Err<FeeOptions, ExchangeFeeEstimatesUnavailableFailure>>(),
            ),
      );
      expect(
        events[1],
        isA<SpendCoinsRead>().having(
          (e) => e.coins,
          'coins',
          isA<Err<List<Coin>, ExchangeWalletCoinsUnavailableFailure>>(),
        ),
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
        isA<SpendFeesRead>()
            .having((e) => e.attempt, 'attempt', 2)
            .having(
              (e) => e.fees,
              'fees',
              isA<Ok<FeeOptions, ExchangeFeeEstimatesUnavailableFailure>>(),
            ),
      );
      expect(sessions, [payinTestnetSession, payinTestnetSession]);
    });
  });

  test('nothing is answered after close', () {
    fakeAsync((async) {
      final events = <SpendOptionsEvent>[];
      final runner = SpendOptionsRunner(
        fakeSpendOptions(
          getFees: FakeGetFeeOptionsUsecase((session) async => const Ok(_fees)),
        ),
        payinSession,
        events.add,
      );
      runner.run(const [SpendLoadFees(1)]);
      runner.close();
      async.flushMicrotasks();
      expect(events, isEmpty);
    });
  });
}
