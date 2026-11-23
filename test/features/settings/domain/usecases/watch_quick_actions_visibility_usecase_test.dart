import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_quick_actions_visibility_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Ok;

class _Access extends Mock implements ExchangeAccessLifecycle {}

class _Settings extends Mock implements Preferences {}

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
      final lifecycle = _Access();
      final settings = _Settings();
      final access = StreamController<ExchangeAccess>();
      when(() => lifecycle.current).thenReturn(const ExchangeAccessResolving());
      when(lifecycle.watch).thenAnswer((_) => access.stream);
      final values = <bool>[];
      final sub = WatchQuickActionsVisibilityUsecase(
        exchange: exchangeForTesting(access: lifecycle),
        networkUnavailable: () async => false,
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
    final lifecycle = _Access();
    final settings = _Settings();
    final access = StreamController<ExchangeAccess>();
    final platform = StreamController<bool>();
    when(() => lifecycle.current).thenReturn(const ExchangeAccessDisabled());
    when(lifecycle.watch).thenAnswer((_) => access.stream);
    final values = <bool>[];
    final sub = WatchQuickActionsVisibilityUsecase(
      exchange: exchangeForTesting(access: lifecycle),
      networkUnavailable: () async => false,
      settings: settings,
      platformChanges: platform.stream,
      isIOS: false,
    ).execute().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    access.add(const ExchangeAccessEnabled(ExchangeAccessSession.signedOut));
    await Future<void>.delayed(Duration.zero);
    expect(values, [false]);
    access.add(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
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
      final lifecycle = _Access();
      final settings = _Settings();
      final pending = Completer<SettingsEntity>();
      final access = StreamController<ExchangeAccess>();
      final platform = StreamController<bool>();
      when(
        () => lifecycle.current,
      ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
      when(lifecycle.watch).thenAnswer((_) => access.stream);
      when(settings.fetch)
          .thenAnswer((_) => (pending.future).then((value) => Ok(value)));
      final values = <bool>[];
      final sub = WatchQuickActionsVisibilityUsecase(
        exchange: exchangeForTesting(access: lifecycle),
        networkUnavailable: () async => false,
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
    final lifecycle = _Access();
    final settings = _Settings();
    when(
      () => lifecycle.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    when(lifecycle.watch).thenAnswer((_) => const Stream.empty());
    when(settings.fetch).thenThrow(const FormatException('unavailable'));
    final values = <bool>[];
    final sub = WatchQuickActionsVisibilityUsecase(
      exchange: exchangeForTesting(access: lifecycle),
      networkUnavailable: () async => false,
      settings: settings,
      platformChanges: const Stream.empty(),
      isIOS: true,
    ).execute().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    expect(values, [false]);
    await sub.cancel();
  });

  test('a network without exchange hides exchange actions', () async {
    final lifecycle = _Access();
    var unavailable = true;
    final settings = _Settings();
    final access = StreamController<ExchangeAccess>();
    when(
      () => lifecycle.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedOut));
    when(lifecycle.watch).thenAnswer((_) => access.stream);
    final values = <bool>[];
    final sub = WatchQuickActionsVisibilityUsecase(
      exchange: exchangeForTesting(access: lifecycle),
      networkUnavailable: () async => unavailable,
      settings: settings,
      platformChanges: const Stream.empty(),
      isIOS: false,
    ).execute().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    // Regtest cannot read exchange access and reports it as unreadable.
    access.add(const ExchangeAccessUnreadable());
    await Future<void>.delayed(Duration.zero);
    expect(values, [false]);

    // Switching back to a supported network reconciles access again.
    unavailable = false;
    access.add(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(values, [false, true]);
    await sub.cancel();
    await access.close();
  });
}
