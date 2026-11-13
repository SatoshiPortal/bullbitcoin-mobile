import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/features/exchange/data/exchange_access_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_notification_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_notifications_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

class _MockNotificationRepository extends Mock
    implements ExchangeNotificationRepository {}

class _Access extends Mock implements ExchangeAccessRepository {}

class _Keys extends Mock implements ExchangeApiKeyRepository {}

NotificationMessage _message(NotificationMessageKind kind) =>
    NotificationMessage(kind: kind, rawData: const {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(() async => const Ok<void, ExchangeFailure>(null));
  });
  late _MockNotificationRepository repository;
  late _Access access;
  late StreamController<NotificationMessage> messages;

  WatchExchangeNotificationsUsecase build() =>
      WatchExchangeNotificationsUsecase(
        exchangeNotificationRepository: repository,
        access: access,
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

  // The repository is the boundary; the use-case only lifts the family so no
  // core type reaches the cubit.
  test('a connect failure is lifted into the feature family', () async {
    when(repository.connect).thenAnswer(
      (_) async =>
          const Err(ExchangeNotificationConnectFailure('connect failed: Type')),
    );

    final failure = _failureOf(await build().connect());

    expect(failure, isA<ExchangeNotificationsUnavailableFailure>());
    expect(
      failure,
      isNot(isA<ExchangeNotificationFailure>()),
      reason: 'the core family must not escape the use-case',
    );
    expect(failure.logMessage, 'connect failed: Type');
  });

  test('a reconnect failure is lifted into the feature family', () async {
    when(
      repository.reconnect,
    ).thenAnswer((_) async => const Err(ExchangeNotificationConnectFailure()));

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
    'sign out waits for a pending native connection to finish and close',
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
      final pending = Completer<Result<void, ExchangeNotificationFailure>>();
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
        exchangeNotificationRepository: repository,
        access: realAccess,
      );
      final connection = usecase.connect();
      await Future<void>.delayed(Duration.zero);
      final beforeSignOut = disconnects;
      var signedOut = false;
      final logout = realAccess.signOut().then((result) {
        signedOut = true;
        return result;
      });
      await Future<void>.delayed(Duration.zero);
      final finishedBeforeConnection = signedOut;
      final cutBeforeConnectionFinished = disconnects > beforeSignOut;
      pending.complete(const Ok(null));
      final connectionResult = await connection;
      final logoutResult = await logout;
      expect(finishedBeforeConnection, isFalse);
      expect(cutBeforeConnectionFinished, isTrue);
      expect(
        _failureOf(connectionResult),
        isA<ExchangeOperationStaleFailure>(),
      );
      expect(logoutResult, isA<Ok>());
      expect(disconnects, greaterThanOrEqualTo(1));
    },
  );

  test('an old connection cannot close a new environment connection', () async {
    SharedPreferences.setMockInitialValues({
      'exchange_access': '{"enabled":true,"signOutPending":false}',
    });
    final keys = _Keys();
    when(
      () => keys.readActiveApiKey(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => const Ok('active'));
    when(
      () => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => const Ok(null));
    final pending = Completer<Result<void, ExchangeNotificationFailure>>();
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
      exchangeNotificationRepository: repository,
      access: realAccess,
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

  test('disconnect is forwarded', () {
    when(repository.disconnect).thenReturn(null);

    build().disconnect();

    verify(repository.disconnect).called(1);
  });
}
