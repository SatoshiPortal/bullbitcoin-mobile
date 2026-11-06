import 'dart:async';

import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Socket extends Mock implements ExchangeNotificationDatasource {}

class _Settings extends Mock implements SettingsRepository {}

void main() {
  test('disconnect cancels a pending service reconnect', () {
    fakeAsync((time) {
      final mainnet = _Socket();
      final testnet = _Socket();
      final settings = _Settings();
      for (final socket in [mainnet, testnet]) {
        when(
          () => socket.messageStream,
        ).thenAnswer((_) => const Stream.empty());
        when(() => socket.connect()).thenAnswer((_) async {});
      }
      when(() => settings.fetch()).thenAnswer(
        (_) async => SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      final service = ExchangeNotificationService(
        mainnetDatasource: mainnet,
        testnetDatasource: testnet,
        settingsRepository: settings,
      );
      unawaited(service.reconnect());
      time.flushMicrotasks();
      service.disconnect();
      time.elapse(const Duration(seconds: 1));
      verifyNever(() => mainnet.connect());
      service.dispose();
    });
  });
  test(
    'a stale settings lookup cannot replace the latest environment',
    () async {
      final mainnet = _Socket();
      final testnet = _Socket();
      final settings = _Settings();
      for (final socket in [mainnet, testnet]) {
        when(
          () => socket.messageStream,
        ).thenAnswer((_) => const Stream.empty());
        when(() => socket.connect()).thenAnswer((_) async {});
      }
      final oldSettings = Completer<SettingsEntity>();
      final newSettings = Completer<SettingsEntity>();
      var reads = 0;
      when(() => settings.fetch()).thenAnswer(
        (_) => reads++ == 0 ? oldSettings.future : newSettings.future,
      );
      final service = ExchangeNotificationService(
        mainnetDatasource: mainnet,
        testnetDatasource: testnet,
        settingsRepository: settings,
      );
      addTearDown(service.dispose);
      final first = service.connect();
      final second = service.connect();
      newSettings.complete(
        SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      await second;
      oldSettings.complete(
        SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      await first;
      verifyNever(() => mainnet.connect());
      verify(() => testnet.connect()).called(1);
    },
  );
  test(
    'only the selected connected environment can forward messages',
    () async {
      final mainnet = _Socket();
      final testnet = _Socket();
      final mainMessages = StreamController<Map<String, dynamic>>.broadcast();
      final testMessages = StreamController<Map<String, dynamic>>.broadcast();
      when(() => mainnet.messageStream).thenAnswer((_) => mainMessages.stream);
      when(() => testnet.messageStream).thenAnswer((_) => testMessages.stream);
      for (final socket in [mainnet, testnet]) {
        when(() => socket.connect()).thenAnswer((_) async {});
      }
      final settings = _Settings();
      var environment = Environment.mainnet;
      when(() => settings.fetch()).thenAnswer(
        (_) async => SettingsEntity(
          environment: environment,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      final service = ExchangeNotificationService(
        mainnetDatasource: mainnet,
        testnetDatasource: testnet,
        settingsRepository: settings,
      );
      final seen = <String>[];
      final subscription = service.messageStream.listen(
        (m) => seen.add(m.kind.name),
      );
      addTearDown(() async {
        await subscription.cancel();
        service.dispose();
        await mainMessages.close();
        await testMessages.close();
      });
      await service.connect();
      mainMessages.add({'type': 'balance'});
      testMessages.add({'type': 'order'});
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['balance']);
      environment = Environment.testnet;
      await service.connect();
      verify(() => mainnet.disconnect()).called(1);
      mainMessages.add({'type': 'balance'});
      testMessages.add({'type': 'order'});
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['balance', 'order']);
      service.disconnect();
      mainMessages.add({'type': 'balance'});
      testMessages.add({'type': 'order'});
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['balance', 'order']);
    },
  );

  test('disconnect cancels a pending settings lookup', () async {
    final mainnet = _Socket();
    final testnet = _Socket();
    for (final socket in [mainnet, testnet]) {
      when(() => socket.messageStream).thenAnswer((_) => const Stream.empty());
      when(() => socket.connect()).thenAnswer((_) async {});
    }
    final settings = _Settings();
    final pending = Completer<SettingsEntity>();
    when(() => settings.fetch()).thenAnswer((_) => pending.future);
    final service = ExchangeNotificationService(
      mainnetDatasource: mainnet,
      testnetDatasource: testnet,
      settingsRepository: settings,
    );
    addTearDown(service.dispose);
    final connecting = service.connect();
    service.disconnect();
    pending.complete(
      SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    await connecting;
    verifyNever(() => mainnet.connect());
  });
}
