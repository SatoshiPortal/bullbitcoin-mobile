import 'package:exchange/testing.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

void main() {
  // Legacy contract: autobuy and limit_orders catch this exception type
  // specifically, so every failure, settings included, must surface as it.
  test('a throwing settings read surfaces as the legacy exception', () async {
    final settings = _MockSettingsRepository();
    when(settings.fetch).thenThrow(Exception('database is locked'));
    final usecase = GetExchangeUserSummaryUsecase(
      exchange: exchangeForTesting(),
      settingsRepository: settings,
    );

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<GetExchangeUserSummaryException>().having(
          (e) => e.message,
          'message',
          'settings fetch failed: _Exception',
        ),
      ),
    );
  });
}
