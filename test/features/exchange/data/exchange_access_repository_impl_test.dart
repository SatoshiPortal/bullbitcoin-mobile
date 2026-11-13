import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_auth_repository.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/features/exchange/data/exchange_access_repository_impl.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Keys extends Mock implements ExchangeApiKeyRepository {}

class _Auth extends Mock implements ExchangeAuthRepository {}

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
              )
              as Ok<ExchangeApiKey, ExchangeApiKeyFailure>)
          .value,
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
        when(
          () => keys.readActiveApiKey(isTestnet: false),
        ).thenAnswer((_) async => const Ok(null));
        final auth = _Auth();
        when(auth.generateApiKey).thenAnswer(
          (_) async => const Err(ExchangeAuthenticationDeferredFailure()),
        );
        final repository = ExchangeAccessRepositoryImpl(
          apiKeyRepository: keys,
          readEnvironment: () async => false,
          platformAllowed: () async => allowed,
          disconnectNotifications: () async {},
          clearCookies: () async {},
        );
        await repository.resolve();
        expect(
          await repository.completeAuthentication(
            authRepository: auth,
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
      when(
        () => keys.deleteApiKey(isTestnet: false),
      ).thenAnswer((_) async => const Err(ExchangeApiKeyDeleteFailure()));
      when(
        () => keys.deleteApiKey(isTestnet: true),
      ).thenAnswer((_) async => const Ok(null));
      var cookiesCleared = false;
      final repository = ExchangeAccessRepositoryImpl(
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
    when(
      () => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => const Ok(null));
    var cookies = 0;
    final repository = ExchangeAccessRepositoryImpl(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {
        cookies++;
      },
    );
    await repository.resolve();
    expect(repository.current, isA<ExchangeAccessUnreadable>());
    await repository.signOut();
    expect(repository.current, isA<ExchangeAccessDisabled>());
    expect(cookies, 1);
    verify(() => keys.deleteApiKey(isTestnet: false)).called(1);
    verify(() => keys.deleteApiKey(isTestnet: true)).called(1);
  });

  test('a stale expiration does not delete credentials', () async {
    SharedPreferences.setMockInitialValues({});
    final keys = _Keys();
    when(
      () => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => const Ok(null));
    final repository = ExchangeAccessRepositoryImpl(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    final oldEpoch = repository.epoch;
    await repository.signOut();
    clearInteractions(keys);
    await repository.expireSession(epoch: oldEpoch, isTestnet: false);
    verifyNever(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')));
    expect(repository.current, isA<ExchangeAccessDisabled>());
  });

  test('resolve retries a pending sign out', () async {
    SharedPreferences.setMockInitialValues({
      'exchange_access': '{"enabled":false,"signOutPending":true}',
    });
    final keys = _Keys();
    when(
      () => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => const Ok(null));
    final repository = ExchangeAccessRepositoryImpl(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    await repository.resolve();
    expect(repository.current, isA<ExchangeAccessDisabled>());
    verify(() => keys.deleteApiKey(isTestnet: false)).called(1);
    verify(() => keys.deleteApiKey(isTestnet: true)).called(1);
  });

  test('late authentication cannot save after sign out', () async {
    SharedPreferences.setMockInitialValues({
      'exchange_access': '{"enabled":true,"signOutPending":false}',
    });
    final keys = _Keys();
    when(
      () => keys.readActiveApiKey(isTestnet: false),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => const Ok(null));
    final auth = _Auth();
    final generated = Completer<Result<ExchangeApiKey, ExchangeFailure>>();
    when(() => auth.generateApiKey()).thenAnswer((_) => generated.future);
    final repository = ExchangeAccessRepositoryImpl(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    await repository.resolve();
    final authentication = repository.completeAuthentication(
      authRepository: auth,
      isTestnet: false,
      isCurrent: () => true,
    );
    await repository.signOut();
    final key = ExchangeApiKey.create(
      id: 'id',
      key: 'test',
      name: 'name',
      userId: 'user',
      isActive: true,
      createdAt: 0,
      updatedAt: 0,
    );
    generated.complete(
      Ok((key as Ok<ExchangeApiKey, ExchangeApiKeyFailure>).value),
    );
    expect(await authentication, isA<Err>());
    verifyNever(
      () => keys.saveApiKey(any(), isTestnet: any(named: 'isTestnet')),
    );
    expect(repository.current, isA<ExchangeAccessDisabled>());
  });

  test('journal write failure still clears both keys and cookies', () async {
    SharedPreferences.setMockInitialValues({});
    final keys = _Keys();
    when(
      () => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => const Ok(null));
    var cookies = 0;
    final repository = ExchangeAccessRepositoryImpl(
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
    when(
      () => keys.readActiveApiKey(isTestnet: false),
    ).thenAnswer((_) async => const Ok(null));
    final repository = ExchangeAccessRepositoryImpl(
      apiKeyRepository: keys,
      readEnvironment: () async => false,
      platformAllowed: () async => true,
      disconnectNotifications: () async {},
      clearCookies: () async {},
    );
    await repository.resolve();
    expect(repository.current, isA<ExchangeAccessDisabled>());
    await repository.enable(onlyIfUnset: true, choice: true);
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
      when(
        () => keys.readActiveApiKey(isTestnet: false),
      ).thenAnswer((_) async => const Ok('active'));
      when(
        () => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => const Ok(null));
      var environment = false;
      var cookies = 0;
      final repository = ExchangeAccessRepositoryImpl(
        apiKeyRepository: keys,
        readEnvironment: () async => environment,
        platformAllowed: () async => true,
        disconnectNotifications: () async {},
        clearCookies: () async {
          cookies++;
        },
      );
      await repository.resolve();
      final requestEpoch = repository.epoch;
      environment = true;
      await repository.expireSession(epoch: requestEpoch, isTestnet: false);
      verifyNever(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')));
      expect(cookies, 0);
    },
  );

  test(
    'initial choice cannot invalidate an explicit activation in flight',
    () async {
      SharedPreferences.setMockInitialValues({});
      final keys = _Keys();
      when(
        () => keys.readActiveApiKey(isTestnet: false),
      ).thenAnswer((_) async => const Ok(null));
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      final repository = ExchangeAccessRepositoryImpl(
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
      final initial = repository.enable(onlyIfUnset: true, choice: false);
      releaseWrite.complete();
      expect(await explicit, isA<Ok>());
      expect(await initial, isA<Ok>());
      expect(repository.current, isA<ExchangeAccessEnabled>());
      final preferences = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(
              (preferences.getString('exchange_access') ??
                  (throw StateError('Missing preference'))),
            )
            as Map)['enabled'],
        isTrue,
      );
    },
  );
}
