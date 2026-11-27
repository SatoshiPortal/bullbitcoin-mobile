import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Err, Ok, Result;

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

class _Access extends Mock implements ExchangeAccessLifecycle {}

class _Settings extends Mock implements Preferences {}

SettingsEntity _settings(bool? superuser) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  isSuperuser: superuser,
);

Exchange _exchange(_Access lifecycle, _Settings settings) => exchangeForTesting(
  access: lifecycle,
  sessionPreferences: settings,
  basicAuth: ExchangeCredentials.openBasicAuth(
    InMemoryExchangeCredentialStorage(),
  ),
);

void _stubEnvironment(
  _Settings settings, [
  Environment network = Environment.mainnet,
]) => when(settings.readActiveEnvironment).thenAnswer((_) async => Ok(network));

void main() {
  test(
    'non-iOS replays an already signed-in session without fetching preferences',
    () async {
      final lifecycle = _Access();
      final preferences = _Settings();
      _stubEnvironment(preferences);
      when(() => lifecycle.current).thenReturn(const ExchangeAccessResolving());
      when(lifecycle.watch).thenAnswer(
        (_) => Stream.value(const ExchangeAccessSignedIn(_testSession)),
      );
      final changes = StreamController<bool>();
      final values = <bool>[];
      final subscription = _exchange(lifecycle, preferences)
          .watchTradingVisibility(
            platform: ExchangePlatform.other,
            superuserChanges: changes.stream,
          )
          .listen(values.add);
      await Future<void>.delayed(Duration.zero);
      expect(values, [true]);
      changes.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(values, [true]);
      verifyNever(preferences.fetch);
      verify(preferences.readActiveEnvironment).called(2);
      await subscription.cancel();
      await changes.close();
    },
  );

  test(
    'unresolved startup never flashes exchange actions for a disabled user',
    () async {
      final lifecycle = _Access();
      final settings = _Settings();
      _stubEnvironment(settings);
      final access = StreamController<ExchangeAccess>();
      when(() => lifecycle.current).thenReturn(const ExchangeAccessResolving());
      when(lifecycle.watch).thenAnswer((_) => access.stream);
      final values = <bool>[];
      final sub = _exchange(lifecycle, settings)
          .watchTradingVisibility(
            platform: ExchangePlatform.other,
            superuserChanges: const Stream.empty(),
          )
          .listen(values.add);
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
    _stubEnvironment(settings);
    final access = StreamController<ExchangeAccess>();
    final platform = StreamController<bool>();
    when(() => lifecycle.current).thenReturn(const ExchangeAccessDisabled());
    when(lifecycle.watch).thenAnswer((_) => access.stream);
    final values = <bool>[];
    final sub = _exchange(lifecycle, settings)
        .watchTradingVisibility(
          platform: ExchangePlatform.other,
          superuserChanges: platform.stream,
        )
        .listen(values.add);
    await Future<void>.delayed(Duration.zero);
    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await Future<void>.delayed(Duration.zero);
    expect(values, [false]);
    access.add(const ExchangeAccessSignedIn(_testSession));
    access.add(const ExchangeAccessSignOutIncomplete());
    await Future<void>.delayed(Duration.zero);
    expect(values, [false, true, false]);
    verifyNever(settings.fetch);
    await sub.cancel();
    await access.close();
    await platform.close();
  });

  for (final live in [true, false]) {
    test('live iOS value $live wins over a delayed opposite setting', () async {
      final lifecycle = _Access();
      final settings = _Settings();
      _stubEnvironment(settings);
      final pending = Completer<SettingsEntity>();
      final access = StreamController<ExchangeAccess>();
      final platform = StreamController<bool>();
      when(() => lifecycle.current)
          .thenReturn(const ExchangeAccessSignedIn(_testSession));
      when(lifecycle.watch).thenAnswer((_) => access.stream);
      when(settings.fetch)
          .thenAnswer((_) => (pending.future).then((value) => Ok(value)));
      final values = <bool>[];
      final sub = _exchange(lifecycle, settings)
          .watchTradingVisibility(
            platform: ExchangePlatform.ios,
            superuserChanges: platform.stream,
          )
          .listen(values.add);
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      platform.add(live);
      await Future<void>.delayed(Duration.zero);
      expect(values, [live]);
      pending.complete(_settings(!live));
      await Future<void>.delayed(Duration.zero);
      expect(values, [live]);
      await sub.cancel();
      await access.close();
      await platform.close();
    });
  }

  test('iOS settings read failure leaves exchange actions hidden', () async {
    final lifecycle = _Access();
    final settings = _Settings();
    _stubEnvironment(settings);
    when(() => lifecycle.current)
        .thenReturn(const ExchangeAccessSignedIn(_testSession));
    when(lifecycle.watch).thenAnswer((_) => const Stream.empty());
    when(settings.fetch).thenThrow(const FormatException('unavailable'));
    final values = <bool>[];
    final sub = _exchange(lifecycle, settings)
        .watchTradingVisibility(
          platform: ExchangePlatform.ios,
          superuserChanges: const Stream.empty(),
        )
        .listen(values.add);
    await Future<void>.delayed(Duration.zero);
    expect(values, [false]);
    await sub.cancel();
  });

  for (final (description, initial, allowed) in [
    (
      'stored true',
      Ok<SettingsEntity, PreferencesFailure>(_settings(true)),
      true,
    ),
    (
      'stored false',
      Ok<SettingsEntity, PreferencesFailure>(_settings(false)),
      false,
    ),
    (
      'absent flag',
      Ok<SettingsEntity, PreferencesFailure>(_settings(null)),
      false,
    ),
    (
      'typed error',
      const Err<SettingsEntity, PreferencesFailure>(PreferencesReadFailure()),
      false,
    ),
  ]) {
    test('iOS waits for Preferences and resolves $description', () async {
      final lifecycle = _Access();
      final preferences = _Settings();
      final fetch = Completer<Result<SettingsEntity, PreferencesFailure>>();
      _stubEnvironment(preferences);
      when(() => lifecycle.current)
          .thenReturn(const ExchangeAccessSignedIn(_testSession));
      when(lifecycle.watch).thenAnswer((_) => const Stream.empty());
      when(preferences.fetch).thenAnswer((_) => fetch.future);
      final values = <bool>[];
      final subscription = _exchange(lifecycle, preferences)
          .watchTradingVisibility(
            platform: ExchangePlatform.ios,
            superuserChanges: const Stream.empty(),
          )
          .listen(values.add);
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      fetch.complete(initial);
      await Future<void>.delayed(Duration.zero);
      expect(values, [allowed]);
      await subscription.cancel();
    });
  }

  test('iOS fails closed when the Exchange has no Preferences owner', () async {
    final lifecycle = _Access();
    when(() => lifecycle.current)
        .thenReturn(const ExchangeAccessSignedIn(_testSession));
    when(lifecycle.watch).thenAnswer((_) => const Stream.empty());
    expect(
      await exchangeForTesting(access: lifecycle)
          .watchTradingVisibility(
            platform: ExchangePlatform.ios,
            superuserChanges: const Stream.empty(),
          )
          .first,
      isFalse,
    );
  });

  test(
    'iOS ignores pending Preferences and network results after cancellation',
    () async {
      final lifecycle = _Access();
      final preferences = _Settings();
      final fetch = Completer<Result<SettingsEntity, PreferencesFailure>>();
      final network = Completer<Result<Environment, PreferencesFailure>>();
      final accessCancelled = Completer<void>();
      final platformCancelled = Completer<void>();
      final access = StreamController<ExchangeAccess>(
        onCancel: accessCancelled.complete,
      );
      final platform = StreamController<bool>(
        onCancel: platformCancelled.complete,
      );
      when(() => lifecycle.current)
          .thenReturn(const ExchangeAccessSignedIn(_testSession));
      when(lifecycle.watch).thenAnswer((_) => access.stream);
      when(preferences.fetch).thenAnswer((_) => fetch.future);
      when(preferences.readActiveEnvironment).thenAnswer((_) => network.future);
      final values = <bool>[];
      final subscription = _exchange(lifecycle, preferences)
          .watchTradingVisibility(
            platform: ExchangePlatform.ios,
            superuserChanges: platform.stream,
          )
          .listen(values.add);
      await Future<void>.delayed(Duration.zero);
      verify(preferences.fetch).called(1);
      verify(preferences.readActiveEnvironment).called(1);
      await subscription.cancel();
      expect(accessCancelled.isCompleted, isTrue);
      expect(platformCancelled.isCompleted, isTrue);
      fetch.complete(Ok(_settings(true)));
      network.complete(const Ok(Environment.mainnet));
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      await access.close();
      await platform.close();
    },
  );

  test('a network without exchange hides exchange actions', () async {
    final lifecycle = _Access();
    final settings = _Settings();
    _stubEnvironment(settings, Environment.regtest);
    final access = StreamController<ExchangeAccess>();
    when(() => lifecycle.current)
        .thenReturn(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    when(lifecycle.watch).thenAnswer((_) => access.stream);
    final values = <bool>[];
    final sub = _exchange(lifecycle, settings)
        .watchTradingVisibility(
          platform: ExchangePlatform.other,
          superuserChanges: const Stream.empty(),
        )
        .listen(values.add);
    await Future<void>.delayed(Duration.zero);
    // Regtest cannot read exchange access and reports it as unreadable.
    access.add(const ExchangeAccessUnreadable());
    await Future<void>.delayed(Duration.zero);
    expect(values, [false]);

    // Switching back to a supported network reconciles access again.
    _stubEnvironment(settings);
    access.add(const ExchangeAccessSignedIn(_testSession));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(values, [false, true]);
    await sub.cancel();
    await access.close();
  });
}
