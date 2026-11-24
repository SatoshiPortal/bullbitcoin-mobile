import 'package:coins/src/domain/usecases/watch_coins_amount_display_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Reader implements AmountDisplayPreferencesReader {
  @override
  Stream<Result<AmountDisplayPreferences, PreferencesFailure>>
  watchDisplayPreferences() => Stream.fromIterable([
    const Ok((
      bitcoinUnit: BitcoinUnit.sats,
      hideAmounts: false,
      currencyCode: 'USD',
    )),
    const Err(PreferencesReadFailure()),
    const Ok((
      bitcoinUnit: BitcoinUnit.btc,
      hideAmounts: true,
      currencyCode: 'CAD',
    )),
  ]);
}

void main() {
  test('masks after failure and accepts the recovered preference', () async {
    await expectLater(
      WatchCoinsAmountDisplayUsecase(_Reader()).execute(),
      emitsInOrder([
        (
          bitcoinUnit: BitcoinUnit.sats,
          hideAmounts: false,
          currencyCode: 'USD',
        ),
        null,
        (bitcoinUnit: BitcoinUnit.btc, hideAmounts: true, currencyCode: 'CAD'),
        emitsDone,
      ]),
    );
  });
}
