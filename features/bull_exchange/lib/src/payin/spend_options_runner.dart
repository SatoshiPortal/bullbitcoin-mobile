import 'dart:async';

import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:fees/fees.dart';
import 'package:sync/sync.dart' show Coin;

/// The wallet calls the spend options need: the fee estimates, the coins
/// of a wallet and unsigned previews of the payin (never sent). Each
/// answers null / an empty slot when the wallet can't tell.
typedef SpendOptionsCalls = ({
  Future<FeeOptions?> Function() fees,
  Future<List<Coin>?> Function(String walletId) coins,
  Future<Map<FeeSelection, BitcoinFeePreviewSlot>> Function(
    SpendPreviewShape shape,
    FeeOptions fees,
  )
  presets,
  Future<BitcoinFeePreviewSlot> Function(
    SpendPreviewShape shape,
    NetworkFee fee,
  )
  custom,
});

/// Runs the spend options' effects; every answer carries the attempt or
/// epoch of its effect.
final class SpendOptionsRunner {
  final SpendOptionsCalls _calls;
  final void Function(SpendOptionsEvent event) _emit;
  bool _closed = false;

  SpendOptionsRunner(this._calls, this._emit);

  void run(List<SpendOptionsEffect> effects) {
    for (final effect in effects) {
      switch (effect) {
        case SpendLoadFees(:final attempt):
          _answer(
            _calls.fees().then(
              (fees) => fees == null
                  ? SpendFeesFailed(attempt)
                  : SpendFeesLoaded(attempt, fees),
            ),
          );
        case SpendLoadCoins(:final walletId):
          _answer(_calls.coins(walletId).then(SpendCoinsRead.new));
        case SpendPreviewPresets(:final epoch, :final fees, :final shape):
          _answer(
            _calls
                .presets(shape, fees)
                .then((slots) => SpendPresetsPreviewed(epoch, slots)),
          );
        case SpendPreviewCustom(:final epoch, :final fee, :final shape):
          _answer(
            _calls
                .custom(shape, fee)
                .then((slot) => SpendCustomPreviewed(epoch, fee, slot)),
          );
      }
    }
  }

  void _answer(Future<SpendOptionsEvent> answer) => unawaited(
    answer.then((event) {
      if (!_closed) _emit(event);
    }),
  );

  void close() => _closed = true;
}
