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

  test('a session that is not current is refused without a read', () async {
    const ended = ExchangeSession(
      environment: ExchangeEnvironment.mainnet,
      epoch: 0,
      sessionId: 'ended',
    );
    final result = await GetExchangeAnnouncementsUsecase(
      exchange: fakeExchangeUsers(mainnetUsers, testnetUsers),
      access: access,
    ).execute(ended);
    expect(_failureOf(result), isA<ExchangeOperationStaleFailure>());
    verifyZeroInteractions(mainnetUsers);
    verifyZeroInteractions(testnetUsers);
  });

  test('regtest refuses the exchange web settings', () async {
    when(settings.readExchangeWebPreferences).thenAnswer(
      (_) async => Ok((
        environment: Environment.regtest,
        exchangeTestnetBasicAuthUsername: null,
        exchangeTestnetBasicAuthPassword: null,
      )),
    );
    final result = await GetExchangeWebSettingsUsecase(preferences: settings)
        .execute();
    expect(_failureOf(result), isA<ExchangeUnsupportedNetworkFailure>());
  });

  group('GetExchangeAnnouncementsUsecase', () {
    GetExchangeAnnouncementsUsecase build() => GetExchangeAnnouncementsUsecase(
      exchange: fakeExchangeUsers(mainnetUsers, testnetUsers),
      access: access,
    );

    test('a repository failure is lifted into the feature family', () async {
      when(mainnetUsers.listAnnouncements).thenAnswer(
        (_) async => const Err(ExchangeAnnouncementsUnavailableFailure()),
      );

      expect(
        _failureOf(await build().execute(_testSession)),
        isA<ExchangeAnnouncementsUnavailableFailure>(),
      );
    });

    test('a successful load is forwarded', () async {
      when(mainnetUsers.listAnnouncements)
          .thenAnswer((_) async => const Ok(<Announcement>[]));

      expect(
        await build().execute(_testSession),
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
      access: access,
    ).execute(_testSession);
    await Future<void>.delayed(Duration.zero);
    epoch++;
    pending.complete(const Err(ExchangeAnnouncementsUnavailableFailure()));
    expect(_failureOf(await operation), isA<ExchangeOperationStaleFailure>());
  });
}
