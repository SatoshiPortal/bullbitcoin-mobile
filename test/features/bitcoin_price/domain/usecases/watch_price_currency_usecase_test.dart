import 'package:bb_mobile/features/bitcoin_price/domain/usecases/watch_price_currency_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Preferences extends Mock implements RuntimeDisplayPreferencesReader {}

void main() {
  test(
    'failed notification retains the currency and the next success resumes',
    () async {
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
        emitsInOrder(['USD', 'CAD', emitsDone]),
      );
    },
  );
}
