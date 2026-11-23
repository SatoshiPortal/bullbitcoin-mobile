import 'package:exchange/setup.dart';

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/exchange/fake_exchange_users.dart';

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

class _MockUserRepository extends Mock implements ExchangeUserOperations {}

class _MockAccess extends Mock implements ExchangeAccessLifecycle {}

class _MockSettingsRepository extends Mock implements Preferences {}

SettingsEntity _settings(Environment environment) => SettingsEntity(
  environment: environment,
  bitcoinUnit: BitcoinUnit.btc,
  currencyCode: 'CAD',
);

void main() {
  late _MockUserRepository mainnetUsers;
  late _MockUserRepository testnetUsers;
  late _MockSettingsRepository settings;
  late _MockAccess access;

  setUp(() {
    mainnetUsers = _MockUserRepository();
    testnetUsers = _MockUserRepository();
    settings = _MockSettingsRepository();
    access = _MockAccess();
    when(() => access.current)
        .thenReturn(const ExchangeAccessSignedIn(_testSession));
    when(() => access.session)
        .thenAnswer((_) => access.current.signedInSession);
    when(settings.fetch)
        .thenAnswer((_) async => Ok(_settings(Environment.mainnet)));
  });

  // Preferences is shared core and still throws. These use-cases
  // promise a Result and the cubit has no catch left, so a throw here would
  // escape as an unhandled exception and leave the screen waiting.
  group('a throwing settings read is returned, not thrown', () {
    const reason = 'settings fetch failed: _Exception';

    setUp(() {
      when(settings.fetch).thenThrow(Exception('database is locked'));
    });

    test('GetExchangeAnnouncementsUsecase', () async {
      final failure = _failureOf(
        await GetExchangeAnnouncementsUsecase(
          exchange: fakeExchangeUsers(mainnetUsers, testnetUsers),
          settingsRepository: settings,
          access: access,
        ).execute(),
      );

      expect(failure, isA<ExchangeAnnouncementsUnavailableFailure>());
      expect(failure.logMessage, reason);
    });
  });

  test(
    'regtest refuses exchange operations without historical side effects',
    () async {
      when(settings.fetch)
          .thenAnswer((_) async => Ok(_settings(Environment.regtest)));
      when(settings.readExchangeWebPreferences).thenAnswer(
        (_) async => Ok((
          environment: Environment.regtest,
          exchangeTestnetBasicAuthUsername: null,
          exchangeTestnetBasicAuthPassword: null,
        )),
      );
      final results = [
        await GetExchangeAnnouncementsUsecase(
          exchange: fakeExchangeUsers(mainnetUsers, testnetUsers),
          settingsRepository: settings,
          access: access,
        ).execute(),
        await GetExchangeWebSettingsUsecase(preferences: settings).execute(),
      ];
      for (final result in results) {
        expect(_failureOf(result), isA<ExchangeUnsupportedNetworkFailure>());
      }
      verifyZeroInteractions(mainnetUsers);
      verifyZeroInteractions(testnetUsers);
    },
  );

  group('GetExchangeAnnouncementsUsecase', () {
    GetExchangeAnnouncementsUsecase build() => GetExchangeAnnouncementsUsecase(
      exchange: fakeExchangeUsers(mainnetUsers, testnetUsers),
      settingsRepository: settings,
      access: access,
    );

    test('a repository failure is lifted into the feature family', () async {
      when(mainnetUsers.listAnnouncements).thenAnswer(
        (_) async => const Err(ExchangeAnnouncementsUnavailableFailure()),
      );

      expect(
        _failureOf(await build().execute()),
        isA<ExchangeAnnouncementsUnavailableFailure>(),
      );
    });

    test('a successful load is forwarded', () async {
      when(mainnetUsers.listAnnouncements)
          .thenAnswer((_) async => const Ok(<Announcement>[]));

      expect(
        await build().execute(),
        isA<Ok<List<Announcement>, ExchangeFailure>>(),
      );
    });
  });

  test('a late announcement failure is stale after an access change', () async {
    var epoch = 1;
    when(() => access.session).thenAnswer(
      (_) => access.current.isSignedIn
          ? ExchangeSession(
              environment: ExchangeEnvironment.mainnet,
              epoch: epoch,
              sessionId: 'test',
            )
          : null,
    );
    final pending = Completer<Result<List<Announcement>, ExchangeFailure>>();
    when(mainnetUsers.listAnnouncements).thenAnswer((_) => pending.future);
    final operation = GetExchangeAnnouncementsUsecase(
      exchange: fakeExchangeUsers(mainnetUsers, testnetUsers),
      settingsRepository: settings,
      access: access,
    ).execute();
    await Future<void>.delayed(Duration.zero);
    epoch++;
    pending.complete(const Err(ExchangeAnnouncementsUnavailableFailure()));
    expect(_failureOf(await operation), isA<ExchangeOperationStaleFailure>());
  });
}
