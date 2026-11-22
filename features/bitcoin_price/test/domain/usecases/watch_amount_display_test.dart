import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:bitcoin_price/src/domain/usecases/watch_bitcoin_price_amount_display_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

const _initial = (
  bitcoinUnit: BitcoinUnit.sats,
  hideAmounts: false,
  currencyCode: 'USD',
);

const _recovered = (
  bitcoinUnit: BitcoinUnit.btc,
  hideAmounts: true,
  currencyCode: 'CAD',
);

final class _Reader implements AmountDisplayPreferencesReader {
  const _Reader();

  @override
  Stream<Result<AmountDisplayPreferences, PreferencesFailure>>
  watchDisplayPreferences() => Stream.fromIterable([
    const Ok(_initial),
    const Err(PreferencesReadFailure()),
    const Ok(_recovered),
  ]);
}

void main() {
  test('amount display reports failure and resumes after recovery', () async {
    await expectLater(
      const WatchBitcoinPriceAmountDisplayUsecase(_Reader()).execute(),
      emitsInOrder([
        isA<Ok<AmountDisplayPreferences, BitcoinPriceFailure>>().having(
          (result) => result.value,
          'value',
          _initial,
        ),
        isA<Err<AmountDisplayPreferences, BitcoinPriceFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<BitcoinPricePreferencesFailure>(),
        ),
        isA<Ok<AmountDisplayPreferences, BitcoinPriceFailure>>().having(
          (result) => result.value,
          'value',
          _recovered,
        ),
        emitsDone,
      ]),
    );
  });
}
