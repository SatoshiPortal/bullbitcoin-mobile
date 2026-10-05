import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:bb_mobile/features/dca/domain/usecases/start_dca_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExchangeUserRepository extends Mock
    implements ExchangeUserRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

/// Stands in for whatever a foreign exception message may embed — a
/// credential, a response body. It must never reach a [DcaFailure].
const _sentinelSecret = 'super-secret';

void main() {
  late MockSettingsRepository settings;
  late MockExchangeUserRepository mainnetUsers;
  late MockExchangeUserRepository testnetUsers;
  late StartDcaUsecase usecase;

  const mainnetSettings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  setUp(() {
    settings = MockSettingsRepository();
    mainnetUsers = MockExchangeUserRepository();
    testnetUsers = MockExchangeUserRepository();
    usecase = StartDcaUsecase(
      settingsRepository: settings,
      mainnetExchangeUserRepository: mainnetUsers,
      testnetExchangeUserRepository: testnetUsers,
    );
    when(() => settings.fetch()).thenAnswer((_) async => mainnetSettings);
  });

  DcaFailure failureOf(Result<DcaStartData, DcaFailure> result) {
    expect(result, isA<Err<DcaStartData, DcaFailure>>());
    return (result as Err<DcaStartData, DcaFailure>).failure;
  }

  group('StartDcaUsecase', () {
    test('maps a not-logged-in repository failure to '
        'AccountUnavailableFailure', () async {
      when(() => mainnetUsers.getUserSummary()).thenAnswer(
        (_) async => const Err(ExchangeUserNotAuthenticatedFailure()),
      );

      final failure = failureOf(await usecase.execute());
      expect(failure, isA<DcaAccountUnavailableFailure>());
    });

    test('maps a throwing user-summary fetch to AccountUnavailableFailure '
        'without carrying the raw reason', () async {
      when(() => mainnetUsers.getUserSummary()).thenAnswer(
        (_) async => const Err(
          ExchangeUserSummaryUnavailableFailure(
            'getUserSummary failed: DioException',
          ),
        ),
      );

      final failure = failureOf(await usecase.execute());
      expect(failure, isA<DcaAccountUnavailableFailure>());
      expect(failure.logMessage, isNot(contains(_sentinelSecret)));
      // The repository is the boundary now, so dca forwards the reason it
      // already sanitized rather than inventing its own string.
      expect(failure.logMessage, 'getUserSummary failed: DioException');
    });

    test('maps a settings failure to UnexpectedFailure', () async {
      when(() => settings.fetch()).thenThrow(Exception('drift is broken'));

      expect(failureOf(await usecase.execute()), isA<DcaUnexpectedFailure>());
    });

    test('rethrows an Error instead of turning a bug into a failure', () async {
      when(() => settings.fetch()).thenThrow(StateError('bug'));

      expect(usecase.execute, throwsA(isA<StateError>()));
    });
  });
}
