import 'dart:async';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_quick_actions_visibility_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _Exchange extends Mock implements ExchangeFacade {}

class _Settings extends Mock implements SettingsRepository {}

SettingsEntity _settings(bool superuser) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  isSuperuser: superuser,
);

void main() {
  test(
    'unresolved startup never flashes exchange actions for a disabled user',
    () async {
      final exchange = _Exchange();
      final settings = _Settings();
      final access = StreamController<ExchangeAccess>();
      when(
        () => exchange.currentAccess,
      ).thenReturn(const ExchangeAccessResolving());
      when(exchange.watchAccess).thenAnswer((_) => access.stream);
      final values = <bool>[];
      final sub = WatchQuickActionsVisibilityUsecase(
        exchange: exchange,
        settings: settings,
        platformChanges: const Stream.empty(),
        isIOS: false,
      ).execute().listen(values.add);
      await Future<void>.delayed(Duration.zero);
      access.add(const ExchangeAccessDisabled());
      await Future<void>.delayed(Duration.zero);
      expect(values, [false]);
      await sub.cancel();
      await access.close();
    },
  );

  test('non-iOS visibility follows exchange access', () async {
    final exchange = _Exchange();
    final settings = _Settings();
    final access = StreamController<ExchangeAccess>();
    final platform = StreamController<bool>();
    when(
      () => exchange.currentAccess,
    ).thenReturn(const ExchangeAccessDisabled());
    when(exchange.watchAccess).thenAnswer((_) => access.stream);
    final values = <bool>[];
    final sub = WatchQuickActionsVisibilityUsecase(
      exchange: exchange,
      settings: settings,
      platformChanges: platform.stream,
      isIOS: false,
    ).execute().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    access.add(const ExchangeAccessEnabled(ExchangeAccessSession.signedOut));
    access.add(const ExchangeAccessSignOutIncomplete());
    await Future<void>.delayed(Duration.zero);
    expect(values, [false, true, false]);
    verifyNever(settings.fetch);
    await sub.cancel();
    await access.close();
    await platform.close();
  });

  test(
    'new iOS platform event wins over a delayed initial settings read',
    () async {
      final exchange = _Exchange();
      final settings = _Settings();
      final pending = Completer<SettingsEntity>();
      final access = StreamController<ExchangeAccess>();
      final platform = StreamController<bool>();
      when(
        () => exchange.currentAccess,
      ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
      when(exchange.watchAccess).thenAnswer((_) => access.stream);
      when(settings.fetch).thenAnswer((_) => pending.future);
      final values = <bool>[];
      final sub = WatchQuickActionsVisibilityUsecase(
        exchange: exchange,
        settings: settings,
        platformChanges: platform.stream,
        isIOS: true,
      ).execute().listen(values.add);
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      platform.add(true);
      await Future<void>.delayed(Duration.zero);
      pending.complete(_settings(false));
      await Future<void>.delayed(Duration.zero);
      expect(values, [true]);
      await sub.cancel();
      await access.close();
      await platform.close();
    },
  );

  test('iOS settings read failure leaves exchange actions hidden', () async {
    final exchange = _Exchange();
    final settings = _Settings();
    when(
      () => exchange.currentAccess,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    when(exchange.watchAccess).thenAnswer((_) => const Stream.empty());
    when(settings.fetch).thenThrow(const FormatException('unavailable'));
    final values = <bool>[];
    final sub = WatchQuickActionsVisibilityUsecase(
      exchange: exchange,
      settings: settings,
      platformChanges: const Stream.empty(),
      isIOS: true,
    ).execute().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    expect(values, [false]);
    await sub.cancel();
  });
}
