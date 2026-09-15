import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserRepository extends Mock implements ExchangeUserRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  // Legacy contract: autobuy and limit_orders catch this exception type
  // specifically, so every failure, settings included, must surface as it.
  test('a throwing settings read surfaces as the legacy exception', () async {
    final settings = _MockSettingsRepository();
    when(settings.fetch).thenThrow(Exception('database is locked'));
    final usecase = GetExchangeUserSummaryUsecase(
      mainnetExchangeUserRepository: _MockUserRepository(),
      testnetExchangeUserRepository: _MockUserRepository(),
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
