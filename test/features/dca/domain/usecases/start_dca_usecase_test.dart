import 'package:bull_exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../core/exchange/fake_exchange_users.dart';

class MockExchangeUserRepository extends Mock
    implements ExchangeUserOperations {}

class MockSettingsRepository extends Mock implements Preferences {}

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
      exchange: fakeExchangeUsers(mainnetUsers, testnetUsers),
    );
    when(() => settings.fetch()).thenAnswer((_) async => Ok(mainnetSettings));
  });

  DcaFailure failureOf(Result<DcaStartData, DcaFailure> result) {
    expect(result, isA<Err<DcaStartData, DcaFailure>>());
    return (result as Err<DcaStartData, DcaFailure>).failure;
  }

  group('StartDcaUsecase', () {
    test('regtest refuses DCA before backend IO', () async {
      when(settings.fetch).thenAnswer(
        (_) async =>
            Ok(mainnetSettings.copyWith(environment: Environment.regtest)),
      );
      expect(await usecase.execute(), isA<Err>());
      verifyZeroInteractions(mainnetUsers);
      verifyZeroInteractions(testnetUsers);
    });

    test('maps a not-logged-in repository failure to '
        'AccountUnavailableFailure', () async {
      when(
        () => mainnetUsers.getUserSummary(),
      ).thenAnswer((_) async => const Err(ExchangeNotAuthenticatedFailure()));

      final failure = failureOf(await usecase.execute());
      expect(failure, isA<DcaAccountUnavailableFailure>());
    });

    test('maps a throwing user-summary fetch to AccountUnavailableFailure '
        'without carrying the raw reason', () async {
      when(() => mainnetUsers.getUserSummary()).thenAnswer(
        (_) async => const Err(
          ExchangeAccountUnavailableFailure(
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
