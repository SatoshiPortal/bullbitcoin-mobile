import '../fixtures/legacy_access.dart';

import 'package:exchange/setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Keys extends Mock implements ExchangeCredentials {}

NotificationMessage _message(NotificationMessageKind kind) =>
    NotificationMessage(kind: kind);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only account-changing message kinds are emitted', () async {
    final messages =
        StreamController<
          Result<NotificationMessage, ExchangeFailure>
        >.broadcast();
    addTearDown(messages.close);
    final usecase = WatchExchangeNotificationsUsecase(
      exchange: exchangeForTesting(
        notifications: (
          messages: () => messages.stream,
          connect: (_) => fail('unexpected connect'),
          reconnect: (_) => fail('unexpected reconnect'),
          disconnect: () {},
          close: () async {},
        ),
      ),
    );
    final seen = <NotificationMessageKind>[];
    final sub = usecase.accountChanges().listen((m) => seen.add(m.kind));
    addTearDown(sub.cancel);

    messages.add(const Err(ExchangeNotificationsUnavailableFailure()));
    for (final kind in NotificationMessageKind.values) {
      messages.add(Ok(_message(kind)));
    }
    await Future<void>.delayed(Duration.zero);

    expect(seen, [
      NotificationMessageKind.balance,
      NotificationMessageKind.group,
      NotificationMessageKind.kyc,
      NotificationMessageKind.userPreferences,
    ], reason: 'anything else would trigger a needless account refetch');
  });

  group('the socket follows the signed-in state', () {
    late _Keys keys;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'exchange_access': '{"enabled":true,"signOutPending":false}',
      });
      keys = _Keys();
      when(() => keys.readActiveApiKey(isTestnet: any(named: 'isTestnet')))
          .thenAnswer((_) async => const Ok('active'));
      when(() => keys.deleteApiKey(isTestnet: any(named: 'isTestnet')))
          .thenAnswer((_) async => const Ok(null));
    });

    test(
      'a pending native handshake holds neither sign-out nor the trading guard',
      () async {
        final pending = Completer<void>();
        var connects = 0;
        var disconnects = 0;
        final access = legacyAccessForTesting(
          apiKeyRepository: keys,
          readEnvironment: () async => false,
          platformAllowed: () async => true,
          disconnectNotifications: () async => disconnects++,
          clearCookies: () async {},
          connectNotifications: (_, {required reconnect}) {
            connects++;
            return pending.future;
          },
        );
        final _ = await access.resolve();
        expect(connects, 1);

        final guard = await access
            .runAuthenticated(() async => const Ok(null))
            .timeout(const Duration(seconds: 1));
        expect(guard, isA<Ok>());

        final logout = await access.signOut().timeout(
          const Duration(seconds: 1),
        );
        expect(logout, isA<Ok>());
        expect(disconnects, greaterThan(0));
        expect(access.current, isA<ExchangeAccessDisabled>());
        pending.complete();
      },
    );

    test('a new environment opens its own socket', () async {
      var testnet = false;
      final socket = <String>[];
      final access = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => testnet,
        platformAllowed: () async => true,
        disconnectNotifications: () async => socket.add('disconnect'),
        clearCookies: () async {},
        connectNotifications: (environment, {required reconnect}) async =>
            socket.add(
              '${reconnect ? 'reconnect' : 'connect'} '
              '${environment.name}',
            ),
      );
      final _ = await access.resolve();
      testnet = true;
      final _ = await access.resolve();

      expect(socket, ['connect mainnet', 'disconnect', 'connect testnet']);
    });

    test('reconnect reopens only the signed-in session', () async {
      final socket = <String>[];
      final access = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => false,
        platformAllowed: () async => true,
        disconnectNotifications: () async => socket.add('disconnect'),
        clearCookies: () async {},
        connectNotifications: (environment, {required reconnect}) async =>
            socket.add(
              '${reconnect ? 'reconnect' : 'connect'} '
              '${environment.name}',
            ),
      );
      await access.reconnectNotifications();
      expect(socket, isEmpty, reason: 'no session yet');

      final _ = await access.resolve();
      await access.reconnectNotifications();

      expect(socket, ['connect mainnet', 'reconnect mainnet']);
    });
  });
}
