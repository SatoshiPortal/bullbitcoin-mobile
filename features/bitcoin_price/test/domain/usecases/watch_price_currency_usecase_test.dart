import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:bitcoin_price/src/domain/usecases/watch_price_currency_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Preferences extends Mock implements RuntimeDisplayPreferencesReader {}

void main() {
  test('failed notification is typed and observation resumes', () async {
    final preferences = _Preferences();
    when(() => preferences.currencyChangeStream).thenAnswer(
      (_) => Stream.fromIterable([
        const Ok('USD'),
        const Err(PreferencesReadFailure()),
        const Ok('CAD'),
      ]),
    );
    await expectLater(
      WatchPriceCurrencyUsecase(preferences).execute(),
      emitsInOrder([
        isA<Ok<String, BitcoinPriceFailure>>().having(
          (result) => result.value,
          'value',
          'USD',
        ),
        isA<Err<String, BitcoinPriceFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<BitcoinPricePreferencesFailure>(),
        ),
        isA<Ok<String, BitcoinPriceFailure>>().having(
          (result) => result.value,
          'value',
          'CAD',
        ),
        emitsDone,
      ]),
    );
  });
}
