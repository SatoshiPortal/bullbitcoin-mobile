import '../fixtures/legacy_access.dart';

import 'package:exchange/setup.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/guard_exchange_trading_usecase.dart';

import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/features/exchange/domain/repositories/exchange_auth_repository.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Keys extends Mock implements ExchangeCredentials {}

class _Auth extends Mock implements ExchangeAuthRepository {}

Exchange _exchange(ExchangeAccessLifecycle lifecycle) => Exchange.open(
  mainnetEndpoint: Uri.https('mainnet.example.invalid'),
  testnetEndpoint: Uri.https('testnet.example.invalid'),
  readSession: () async => throw StateError('Unexpected session read'),
  access: lifecycle,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(
      (ExchangeApiKey.create(
        id: 'id',
        key: 'test',
        name: 'name',
        userId: 'user',
        isActive: true,
        createdAt: 0,
        updatedAt: 0,
      ) as Ok<ExchangeApiKey, ExchangeFailure>).value,
    );
  });

  for (final allowed in [false, true]) {
    test(
      'authentication preflight blocks generation when platform=$allowed and access is disabled',
      () async {
        SharedPreferences.setMockInitialValues({
          'exchange_access': '{"enabled":false,"signOutPending":false}',
        });
        final keys = _Keys();
        when(() => keys.readActiveApiKey(isTestnet: false))
            .thenAnswer((_) async => const Ok(null));
        final auth = _Auth();
        when(auth.generateApiKey).thenAnswer(
          (_) async => const Err(ExchangeAuthenticationDeferredFailure()),
        );
        final repository = legacyAccessForTesting(
          apiKeyRepository: keys,
          readEnvironment: () async => false,
          platformAllowed: () async => allowed,
          disconnectNotifications: () async {},
          clearCookies: () async {},
        );
        final _ = await repository.resolve();
        expect(
          await repository.completeAuthentication(
            generateApiKey: auth.generateApiKey,
            isTestnet: false,
            isCurrent: () => true,
          ),
          isA<Err>(),
        );
        verifyNever(auth.generateApiKey);
      },
    );
  }

  test(
    'sign out attempts both keys and cookies despite a deletion failure',
    () async {
      SharedPreferences.setMockInitialValues({});
      final keys = _Keys();
      when(() => keys.deleteApiKey(isTestnet: false))
          .thenAnswer((_) async => const Err(ExchangeApiKeyDeleteFailure()));
      when(() => keys.deleteApiKey(isTestnet: true))
          .thenAnswer((_) async => const Ok(null));
      var cookiesCleared = false;
      final repository = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => false,
        platformAllowed: () async => true,
        disconnectNotifications: () async {},
        clearCookies: () async {
          cookiesCleared = true;
        },
      );
      final result = await repository.signOut();
      expect(result, isA<Err>());
      expect(repository.current, isA<ExchangeAccessSignOutIncomplete>());
      expect(cookiesCleared, isTrue);
      verify(() => keys.deleteApiKey(isTestnet: false)).called(1);
      verify(() => keys.deleteApiKey(isTestnet: true)).called(1);
    },
  );

  test('corrupt preference does not prevent explicit cleanup', () async {
    SharedPreferences.setMockInitialValues({'exchange_access': 'invalid'});
    final keys = _Keys();
    when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async => const Ok(null));
    var cookies = 0;
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {
        cookies++;
      },
    );
    final _ = await repository.resolve();
    expect(repository.current, isA<ExchangeAccessUnreadable>());
    final _ = await repository.signOut();
    expect(repository.current, isA<ExchangeAccessDisabled>());
    expect(cookies, 1);
    verify(() => keys.deleteApiKey(isTestnet: false)).called(1);
    verify(() => keys.deleteApiKey(isTestnet: true)).called(1);
  });

  test('a stale expiration does not delete credentials', () async {
    SharedPreferences.setMockInitialValues({});
    final keys = _Keys();
    when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async => const Ok(null));
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    final oldEpoch = repository.epoch;
    final _ = await repository.signOut();
    clearInteractions(keys);
    final _ = await repository.expireSession(epoch: oldEpoch, isTestnet: false);
    verifyNever(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')));
    expect(repository.current, isA<ExchangeAccessDisabled>());
  });

  test('sign out is journaled before queued work finishes', () async {
    SharedPreferences.setMockInitialValues({
      'exchange_access': '{"enabled":true,"signOutPending":false}',
    });
    final keys = _Keys();
    when(() => keys.readActiveApiKey(isTestnet: false))
        .thenAnswer((_) async => const Ok('active'));
    when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async => const Ok(null));
    final environment = Completer<bool>();
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () => environment.future,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    // Reconciliation occupies the queue until the environment is read.
    final resolving = repository.resolve();
    await Future<void>.delayed(Duration.zero);
    final signOut = repository.signOut();
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    final journal = jsonDecode(
      prefs.getString('exchange_access') ?? '{}',
    ) as Map<String, dynamic>;
    expect(journal['signOutPending'], isTrue);

    environment.complete(false);
    await resolving;
    expect(await signOut, isA<Ok>());
    expect(repository.current, isA<ExchangeAccessDisabled>());
  });

  test('resolve retries a pending sign out', () async {
    SharedPreferences.setMockInitialValues({
      'exchange_access': '{"enabled":false,"signOutPending":true}',
    });
    final keys = _Keys();
    when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async => const Ok(null));
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    final _ = await repository.resolve();
    expect(repository.current, isA<ExchangeAccessDisabled>());
    verify(() => keys.deleteApiKey(isTestnet: false)).called(1);
    verify(() => keys.deleteApiKey(isTestnet: true)).called(1);
  });

  test('late authentication cannot save after sign out', () async {
    SharedPreferences.setMockInitialValues({
      'exchange_access': '{"enabled":true,"signOutPending":false}',
    });
    final keys = _Keys();
    when(() => keys.readActiveApiKey(isTestnet: false))
        .thenAnswer((_) async => const Ok(null));
    when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async => const Ok(null));
    final auth = _Auth();
    final generated = Completer<Result<ExchangeApiKey, ExchangeFailure>>();
    when(() => auth.generateApiKey()).thenAnswer((_) => generated.future);
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    final _ = await repository.resolve();
    final authentication = repository.completeAuthentication(
      generateApiKey: auth.generateApiKey,
      isTestnet: false,
      isCurrent: () => true,
    );
    final _ = await repository.signOut();
    final key = ExchangeApiKey.create(
      id: 'id',
      key: 'test',
      name: 'name',
      userId: 'user',
      isActive: true,
      createdAt: 0,
      updatedAt: 0,
    );
    generated.complete(Ok((key as Ok<ExchangeApiKey, ExchangeFailure>).value));
    expect(await authentication, isA<Err>());
    verifyNever(
      () => keys.saveApiKey(any(), isTestnet: any(named: 'isTestnet')),
    );
    expect(repository.current, isA<ExchangeAccessDisabled>());
  });

  test('journal write failure still clears both keys and cookies', () async {
    SharedPreferences.setMockInitialValues({});
    final keys = _Keys();
    when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async => const Ok(null));
    var cookies = 0;
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {
        cookies++;
      },
      writePreference: (_) async => false,
    );
    expect(await repository.signOut(), isA<Err>());
    expect(repository.current, isA<ExchangeAccessSignOutIncomplete>());
    expect(cookies, 1);
    verify(() => keys.deleteApiKey(isTestnet: false)).called(1);
    verify(() => keys.deleteApiKey(isTestnet: true)).called(1);
  });

  test('resolving an unset preference preserves the wizard choice', () async {
    SharedPreferences.setMockInitialValues({});
    final keys = _Keys();
    when(() => keys.readActiveApiKey(isTestnet: false))
        .thenAnswer((_) async => const Ok(null));
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    final _ = await repository.resolve();
    expect(repository.current, isA<ExchangeAccessDisabled>());
    final exchange = _exchange(repository);
    addTearDown(exchange.close);
    expect(await exchange.applyInitialChoice(true), isA<Ok>());
    expect(repository.current, isA<ExchangeAccessEnabled>());
    expect(
      (repository.current as ExchangeAccessEnabled).session,
      ExchangeAccessSession.signedOut,
    );
  });

  test(
    'expiration does not clear credentials after an environment change',
    () async {
      SharedPreferences.setMockInitialValues({
        'exchange_access': '{"enabled":true,"signOutPending":false}',
      });
      final keys = _Keys();
      when(() => keys.readActiveApiKey(isTestnet: false))
          .thenAnswer((_) async => const Ok('active'));
      when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
          .thenAnswer((_) async => const Ok(null));
      var environment = false;
      var cookies = 0;
      final repository = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => environment,
        platformAllowed: () async => true,
        disconnectNotifications: () async {},
        clearCookies: () async {
          cookies++;
        },
      );
      final _ = await repository.resolve();
      final requestEpoch = repository.epoch;
      environment = true;
      final _ = await repository.expireSession(
        epoch: requestEpoch,
        isTestnet: false,
      );
      verifyNever(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')));
      expect(cookies, 0);
    },
  );

  test(
    'initial choice cannot invalidate an explicit activation in flight',
    () async {
      SharedPreferences.setMockInitialValues({});
      final keys = _Keys();
      when(() => keys.readActiveApiKey(isTestnet: false))
          .thenAnswer((_) async => const Ok(null));
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      final repository = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => false,
        platformAllowed: () async => true,
        disconnectNotifications: () async {},
        clearCookies: () async {},
        writePreference: (value) async {
          writeStarted.complete();
          await releaseWrite.future;
          final preferences = await SharedPreferences.getInstance();
          return preferences.setString('exchange_access', value);
        },
      );
      final explicit = repository.enable();
      await writeStarted.future;
      final exchange = _exchange(repository);
      addTearDown(exchange.close);
      final initial = exchange.applyInitialChoice(false);
      releaseWrite.complete();
      expect(await explicit, isA<Ok>());
      expect(await initial, isA<Ok>());
      expect(repository.current, isA<ExchangeAccessEnabled>());
      final preferences = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(
          (preferences.getString('exchange_access') ??
              (throw StateError('Missing preference'))),
        ) as Map)['enabled'],
        isTrue,
      );
    },
  );

  test(
    'an inferred session enables access in another environment after restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final keys = _Keys();
      when(() => keys.readActiveApiKey(isTestnet: false))
          .thenAnswer((_) async => const Ok('active'));
      when(() => keys.readActiveApiKey(isTestnet: true))
          .thenAnswer((_) async => const Ok(null));
      ExchangeAccessLifecycle repository(bool isTestnet) =>
          legacyAccessForTesting(
            apiKeyRepository: keys,
            readEnvironment: () async => isTestnet,
            platformAllowed: () async => true,
            disconnectNotifications: () async {},
            clearCookies: () async {},
          );
      expect(await repository(false).resolve(), isA<Ok>());
      final restarted = repository(true);
      final _ = await restarted.resolve();
      expect(
        restarted.current,
        isA<ExchangeAccessEnabled>().having(
          (state) => state.session,
          'session',
          ExchangeAccessSession.signedOut,
        ),
      );
    },
  );

  test(
    'an inferred active session survives a 401 and restart as enabled',
    () async {
      SharedPreferences.setMockInitialValues({});
      final keys = _Keys();
      var active = true;
      when(() => keys.readActiveApiKey(isTestnet: false))
          .thenAnswer((_) async => Ok(active ? 'active' : null));
      when(() => keys.deleteApiKey(isTestnet: false)).thenAnswer((_) async {
        active = false;
        return const Ok(null);
      });
      ExchangeAccessLifecycle repository() => legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => false,
        platformAllowed: () async => true,
        disconnectNotifications: () async {},
        clearCookies: () async {},
      );
      final first = repository();
      final _ = await first.resolve();
      expect(first.current, isA<ExchangeAccessEnabled>());
      expect(
        await first.expireSession(epoch: first.epoch, isTestnet: false),
        isA<Ok>(),
      );
      final restarted = repository();
      final _ = await restarted.resolve();
      expect(
        restarted.current,
        isA<ExchangeAccessEnabled>().having(
          (state) => state.session,
          'session',
          ExchangeAccessSession.signedOut,
        ),
      );
    },
  );

  test('re-resolving a known state never emits resolving', () async {
    SharedPreferences.setMockInitialValues({});
    final keys = _Keys();
    when(() => keys.readActiveApiKey(isTestnet: false))
        .thenAnswer((_) async => const Ok(null));
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    final _ = await repository.resolve();
    final events = <ExchangeAccess>[];
    final subscription = repository.watch().listen(events.add);
    await Future<void>.delayed(Duration.zero);
    events.clear();
    final _ = await repository.resolve();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(events.whereType<ExchangeAccessResolving>(), isEmpty);
  });

  test('a failed inferred-enabled preference write does not present a resolved session', () async {
    SharedPreferences.setMockInitialValues({});
    final keys = _Keys();
    when(() => keys.readActiveApiKey(isTestnet: false))
        .thenAnswer((_) async => const Ok('active'));
    final repository = legacyAccessForTesting(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
      writePreference: (_) async => false,
    );
    expect(await repository.resolve(), isA<Err>());
    expect(repository.current, isA<ExchangeAccessUnreadable>());
    verifyNever(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')));
  });

  test(
    '401 does not remove a key if the enabled preference cannot be saved',
    () async {
      SharedPreferences.setMockInitialValues({
        'exchange_access': '{"enabled":true,"signOutPending":false}',
      });
      final keys = _Keys();
      when(() => keys.readActiveApiKey(isTestnet: false))
          .thenAnswer((_) async => const Ok('active'));
      var disconnected = false;
      final repository = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => false,
        platformAllowed: () async => true,
        disconnectNotifications: () async {
          disconnected = true;
        },
        clearCookies: () async {},
        writePreference: (_) async => false,
      );
      final _ = await repository.resolve();
      disconnected = false;
      expect(
        await repository.expireSession(
          epoch: repository.epoch,
          isTestnet: false,
        ),
        isA<Err>(),
      );
      expect(disconnected, isTrue);
      verifyNever(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')));
    },
  );

  test(
    'sign out supersedes expiration while the enabled write is pending',
    () async {
      SharedPreferences.setMockInitialValues({
        'exchange_access': '{"enabled":true,"signOutPending":false}',
      });
      final keys = _Keys();
      when(() => keys.readActiveApiKey(isTestnet: false))
          .thenAnswer((_) async => const Ok('active'));
      when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
          .thenAnswer((_) async => const Ok(null));
      final started = Completer<void>();
      final release = Completer<void>();
      var writes = 0;
      final repository = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => false,
        platformAllowed: () async => true,
        disconnectNotifications: () async {},
        clearCookies: () async {},
        writePreference: (value) async {
          if (++writes == 1) {
            started.complete();
            await release.future;
          }
          final preferences = await SharedPreferences.getInstance();
          return preferences.setString('exchange_access', value);
        },
      );
      final _ = await repository.resolve();
      final expiry = repository.expireSession(
        epoch: repository.epoch,
        isTestnet: false,
      );
      await started.future;
      final signOut = repository.signOut();
      release.complete();
      await expiry;
      expect(await signOut, isA<Ok>());
      expect(repository.current, isA<ExchangeAccessDisabled>());
      verify(() => keys.deleteApiKey(isTestnet: false)).called(1);
      verify(() => keys.deleteApiKey(isTestnet: true)).called(1);
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString('exchange_access');
      expect(saved, isA<String>());
      expect((jsonDecode(saved as String) as Map)['enabled'], isFalse);
    },
  );
  test(
    'trading waits for environment reconciliation before authorizing',
    () async {
      SharedPreferences.setMockInitialValues({
        'exchange_access': '{"enabled":true,"signOutPending":false}',
      });
      final keys = _Keys();
      final readStarted = Completer<void>();
      final nextKey = Completer<Result<String?, ExchangeFailure>>();
      var isTestnet = false;
      when(() => keys.readActiveApiKey(isTestnet: false))
          .thenAnswer((_) async => const Ok('active'));
      when(() => keys.readActiveApiKey(isTestnet: true)).thenAnswer((_) {
        readStarted.complete();
        return nextKey.future;
      });
      final repository = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => isTestnet,
        platformAllowed: () async => true,
        disconnectNotifications: () async {},
        clearCookies: () async {},
      );
      final _ = await repository.resolve();
      isTestnet = true;
      final resolving = repository.resolve();
      await readStarted.future;
      var authorized = false;
      final entry = GuardExchangeTradingUsecase(repository, () async => true)
          .execute()
          .then((value) {
            authorized = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(authorized, isFalse);
      nextKey.complete(const Ok(null));
      await resolving;
      expect((await entry as Ok).value, ExchangeAvailability.signInRequired);
    },
  );
}
