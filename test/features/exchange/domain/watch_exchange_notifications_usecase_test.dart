import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/features/exchange/data/exchange_access_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:preferences/preferences.dart';

import 'dart:async';

import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_notifications_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

abstract interface class _Notifications {
  Stream<NotificationMessage> get messages;
  Future<Result<void, ExchangeFailure>> connect();
  Future<Result<void, ExchangeFailure>> reconnect();
  void disconnect();
}

class _MockNotificationRepository extends Mock implements _Notifications {}

Exchange _exchange(_Notifications notifications) => exchangeForTesting(
  notifications: (
    messages: () => notifications.messages,
    connect: notifications.connect,
    reconnect: notifications.reconnect,
    disconnect: notifications.disconnect,
    close: () async {},
  ),
);

class _Access extends Mock implements ExchangeAccessRepository {}

class _Keys extends Mock implements ExchangeApiKeyRepository {}

class _MockSettings extends Mock implements Preferences {}

NotificationMessage _message(NotificationMessageKind kind) =>
    NotificationMessage(kind: kind);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(() async => const Ok<void, ExchangeFailure>(null));
  });
  late _MockNotificationRepository repository;
  late _Access access;
  late _MockSettings settings;
  late StreamController<NotificationMessage> messages;

  WatchExchangeNotificationsUsecase build() =>
      WatchExchangeNotificationsUsecase(
        exchange: _exchange(repository),
        access: access,
        settingsRepository: settings,
      );

  setUp(() {
    repository = _MockNotificationRepository();
    access = _Access();
    when(
      () => access.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    when(() => access.epoch).thenReturn(1);
    when(() => access.runAuthenticated(any())).thenAnswer((invocation) async {
      if (access.current is! ExchangeAccessEnabled) {
        return const Err(ExchangeNotAuthenticatedFailure());
      }
      final operation =
          invocation.positionalArguments.single
              as Future<Result<void, ExchangeFailure>> Function();
      return operation();
    });
    settings = _MockSettings();
    when(settings.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    messages = StreamController<NotificationMessage>.broadcast();
    when(() => repository.messages).thenAnswer((_) => messages.stream);
  });

  tearDown(() => messages.close());

  test('only account-changing message kinds are emitted', () async {
    final seen = <NotificationMessageKind>[];
    final sub = build().accountChanges().listen((m) => seen.add(m.kind));
    addTearDown(sub.cancel);

    for (final kind in NotificationMessageKind.values) {
      messages.add(_message(kind));
    }
    await Future<void>.delayed(Duration.zero);

    expect(seen, [
      NotificationMessageKind.balance,
      NotificationMessageKind.group,
      NotificationMessageKind.kyc,
      NotificationMessageKind.userPreferences,
    ], reason: 'anything else would trigger a needless account refetch');
  });

  test('a connect failure is forwarded as an Exchange failure', () async {
    when(repository.connect).thenAnswer(
      (_) async => const Err(
        ExchangeNotificationsUnavailableFailure('connect failed: Type'),
      ),
    );

    final failure = _failureOf(await build().connect());

    expect(failure, isA<ExchangeNotificationsUnavailableFailure>());
    expect(failure.logMessage, 'connect failed: Type');
  });

  test('a reconnect failure is forwarded as an Exchange failure', () async {
    when(repository.reconnect).thenAnswer(
      (_) async => const Err(ExchangeNotificationsUnavailableFailure()),
    );

    expect(
      _failureOf(await build().reconnect()),
      isA<ExchangeNotificationsUnavailableFailure>(),
    );
  });

  test('a successful connect is Ok', () async {
    when(repository.connect).thenAnswer((_) async => const Ok(null));

    expect(await build().connect(), isA<Ok<void, ExchangeFailure>>());
  });

  test('signed out access does not open a connection', () async {
    when(() => access.current).thenReturn(const ExchangeAccessDisabled());
    expect(
      _failureOf(await build().connect()),
      isA<ExchangeNotAuthenticatedFailure>(),
    );
    verifyNever(repository.connect);
  });

  test(
    'a pending native handshake holds neither sign-out nor the trading guard',
    () async {
      SharedPreferences.setMockInitialValues({
        'exchange_access': '{"enabled":true,"signOutPending":false}',
      });
      final keys = _Keys();
      when(() => keys.readActiveApiKey(isTestnet: false))
          .thenAnswer((_) async => const Ok('active'));
      when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
          .thenAnswer((_) async => const Ok(null));
      final pending = Completer<Result<void, ExchangeFailure>>();
      when(repository.connect).thenAnswer((_) => pending.future);
      var disconnects = 0;
      final realAccess = ExchangeAccessRepositoryImpl(
        apiKeyRepository: keys,
        readEnvironment: () async => false,
        platformAllowed: () async => true,
        disconnectNotifications: () async {
          disconnects++;
        },
        clearCookies: () async {},
      );
      await realAccess.resolve();
      final usecase = WatchExchangeNotificationsUsecase(
        exchange: _exchange(repository),
        access: realAccess,
        settingsRepository: settings,
      );
      final connection = usecase.connect();
      await Future<void>.delayed(Duration.zero);
      verify(repository.connect).called(1);

      // A trading guard settles while the handshake is still pending.
      final guard = await realAccess
          .runAuthenticated(() async => const Ok(null))
          .timeout(const Duration(seconds: 1));
      expect(guard, isA<Ok>());

      final beforeSignOut = disconnects;
      final logout = await realAccess.signOut().timeout(
        const Duration(seconds: 1),
      );
      expect(logout, isA<Ok>());
      expect(disconnects, greaterThan(beforeSignOut));
      expect(realAccess.current, isA<ExchangeAccessDisabled>());

      pending.complete(const Ok(null));
      expect(
        _failureOf(await connection),
        isA<ExchangeOperationStaleFailure>(),
      );
    },
  );

  test(
    'sign-out started during the environment read opens no socket',
    () async {
      final environment = Completer<SettingsEntity>();
      when(settings.fetch)
          .thenAnswer((_) => (environment.future).then((value) => Ok(value)));
      var epoch = 1;
      when(() => access.epoch).thenAnswer((_) => epoch);
      final connection = build().connect();
      await Future<void>.delayed(Duration.zero);
      epoch = 2;
      when(() => access.current)
          .thenReturn(const ExchangeAccessSignOutIncomplete());
      environment.complete(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      expect(
        _failureOf(await connection),
        isA<ExchangeOperationStaleFailure>(),
      );
      verifyNever(repository.connect);
    },
  );

  test(
    'a connection finishing after sign-out is closed rather than left open',
    () async {
      var epoch = 1;
      when(() => access.epoch).thenAnswer((_) => epoch);
      final pending = Completer<Result<void, ExchangeFailure>>();
      when(repository.connect).thenAnswer((_) => pending.future);
      when(repository.disconnect).thenReturn(null);
      final connection = build().connect();
      await Future<void>.delayed(Duration.zero);
      verify(repository.connect).called(1);

      // Sign-out lands before the service has started its native attempt,
      // so its own disconnect cannot have abandoned it.
      epoch = 2;
      when(() => access.current).thenReturn(const ExchangeAccessDisabled());
      pending.complete(const Ok(null));

      expect(
        _failureOf(await connection),
        isA<ExchangeOperationStaleFailure>(),
      );
      verify(repository.disconnect).called(1);
    },
  );

  test('an old connection cannot close a new environment connection', () async {
    SharedPreferences.setMockInitialValues({
      'exchange_access': '{"enabled":true,"signOutPending":false}',
    });
    final keys = _Keys();
    when(() => keys.readActiveApiKey(isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async => const Ok('active'));
    when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async => const Ok(null));
    final pending = Completer<Result<void, ExchangeFailure>>();
    var calls = 0;
    var connected = false;
    when(repository.connect).thenAnswer((_) async {
      if (++calls == 1) {
        await pending.future;
      }
      connected = true;
      return const Ok(null);
    });
    when(repository.disconnect).thenAnswer((_) {
      connected = false;
    });
    var testnet = false;
    final realAccess = ExchangeAccessRepositoryImpl(
      apiKeyRepository: keys,
      readEnvironment: () async => testnet,
      platformAllowed: () async => true,
      disconnectNotifications: () async {
        repository.disconnect();
      },
      clearCookies: () async {},
    );
    await realAccess.resolve();
    final usecase = WatchExchangeNotificationsUsecase(
      exchange: _exchange(repository),
      access: realAccess,
      settingsRepository: settings,
    );
    final old = usecase.connect();
    await Future<void>.delayed(Duration.zero);
    final logout = realAccess.signOut();
    testnet = true;
    final newSession = () async {
      await logout;
      await realAccess.enable();
      return usecase.connect();
    }();
    await Future<void>.delayed(Duration.zero);
    pending.complete(const Ok(null));
    await old;
    expect(await newSession, isA<Ok>());
    expect(connected, isTrue);
  });

  test(
    'regtest disconnects without opening either historical socket',
    () async {
      when(settings.fetch).thenAnswer(
        (_) async => Ok(
          const SettingsEntity(
            environment: Environment.regtest,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(repository.disconnect).thenReturn(null);
      expect(
        _failureOf(await build().connect()),
        isA<ExchangeUnsupportedNetworkFailure>(),
      );
      expect(
        _failureOf(await build().reconnect()),
        isA<ExchangeUnsupportedNetworkFailure>(),
      );
      verifyNever(repository.connect);
      verifyNever(repository.reconnect);
      verify(repository.disconnect).called(2);
    },
  );

  test('disconnect is forwarded', () {
    when(repository.disconnect).thenReturn(null);

    build().disconnect();

    verify(repository.disconnect).called(1);
  });
}
