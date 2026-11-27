import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

class _Access extends Mock implements ExchangeAccessLifecycle {}

class _Preferences extends Mock implements Preferences {}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late Exchange exchange;
  late _Preferences preferences;
  late StreamController<ExchangeAccess> access;
  late StreamController<bool> platform;

  void stubEnvironment(Environment environment) =>
      when(preferences.readActiveEnvironment)
          .thenAnswer((_) async => Ok(environment));

  setUp(() {
    final lifecycle = _Access();
    preferences = _Preferences();
    access = StreamController<ExchangeAccess>.broadcast();
    platform = StreamController<bool>.broadcast();
    stubEnvironment(Environment.mainnet);
    when(lifecycle.watch).thenAnswer((_) => access.stream);
    when(() => lifecycle.current).thenReturn(const ExchangeAccessDisabled());
    exchange = exchangeForTesting(
      access: lifecycle,
      sessionPreferences: preferences,
      basicAuth: ExchangeCredentials.openBasicAuth(
        InMemoryExchangeCredentialStorage(),
      ),
    );
  });

  tearDown(() async {
    await access.close();
    await platform.close();
  });

  test('offers activation only while the exchange is off', () async {
    final values = <bool>[];
    final sub = exchange
        .watchActivationOffer(
          platform: ExchangePlatform.ios,
          currentSuperuser: () => true,
          superuserChanges: platform.stream,
          onlyWhileOff: true,
        )
        .listen(values.add);
    await _settle();
    expect(values, [true]);
    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await _settle();
    expect(values, [true, false]);
    access.add(const ExchangeAccessDisabled());
    await _settle();
    expect(values, [true, false, true]);
    await sub.cancel();
  });

  test('the entry stays reachable whatever the exchange access', () async {
    final values = <bool>[];
    final sub = exchange
        .watchActivationOffer(
          platform: ExchangePlatform.ios,
          currentSuperuser: () => true,
          superuserChanges: platform.stream,
          onlyWhileOff: false,
        )
        .listen(values.add);
    await _settle();
    access.add(const ExchangeAccessSignedIn(_testSession));
    await _settle();
    expect(values, [true]);
    await sub.cancel();
  });

  test('follows the platform policy', () async {
    final values = <bool>[];
    final sub = exchange
        .watchActivationOffer(
          platform: ExchangePlatform.ios,
          currentSuperuser: () => false,
          superuserChanges: platform.stream,
          onlyWhileOff: true,
        )
        .listen(values.add);
    await _settle();
    expect(values, [false]);
    platform.add(true);
    await _settle();
    expect(values, [false, true]);
    platform.add(false);
    await _settle();
    expect(values, [false, true, false]);
    await sub.cancel();
  });

  test('a network without exchange offers nothing', () async {
    stubEnvironment(Environment.regtest);
    final values = <bool>[];
    final sub = exchange
        .watchActivationOffer(
          platform: ExchangePlatform.ios,
          currentSuperuser: () => true,
          superuserChanges: platform.stream,
          onlyWhileOff: false,
        )
        .listen(values.add);
    await _settle();
    expect(values, [false]);
    await sub.cancel();
  });

  test(
    'reads the current superuser only when the offer is listened to',
    () async {
      var isSuperuser = false;
      var reads = 0;
      final offers = exchange.watchActivationOffer(
        platform: ExchangePlatform.ios,
        currentSuperuser: () {
          reads++;
          return isSuperuser;
        },
        superuserChanges: platform.stream,
        onlyWhileOff: true,
      );
      expect(reads, 0);
      isSuperuser = true;
      final values = <bool>[];
      final subscription = offers.listen(values.add);
      await _settle();
      expect(reads, 1);
      expect(values, [true]);
      await subscription.cancel();
    },
  );

  for (final trading in [false, true]) {
    test(
      '${trading ? 'trading' : 'entry'} discards out-of-order network results and cancels both sources',
      () async {
        final lifecycle = _Access();
        final checks = <Completer<Result<Environment, PreferencesFailure>>>[];
        when(preferences.readActiveEnvironment).thenAnswer((_) {
          final result = Completer<Result<Environment, PreferencesFailure>>();
          checks.add(result);
          return result.future;
        });
        final accessCancelled = Completer<void>();
        final platformCancelled = Completer<void>();
        final source = StreamController<ExchangeAccess>(
          onCancel: accessCancelled.complete,
        );
        final superuser = StreamController<bool>(
          onCancel: platformCancelled.complete,
        );
        when(() => lifecycle.current)
            .thenReturn(const ExchangeAccessSignedIn(_testSession));
        when(lifecycle.watch).thenAnswer((_) => source.stream);
        final exchange = exchangeForTesting(
          access: lifecycle,
          sessionPreferences: preferences,
          basicAuth: ExchangeCredentials.openBasicAuth(
            InMemoryExchangeCredentialStorage(),
          ),
        );
        final visibility = trading
            ? exchange.watchTradingVisibility(
                platform: ExchangePlatform.other,
                superuserChanges: superuser.stream,
              )
            : exchange.watchActivationOffer(
                platform: ExchangePlatform.other,
                currentSuperuser: () => false,
                superuserChanges: superuser.stream,
                onlyWhileOff: false,
              );
        final values = <bool>[];
        final subscription = visibility.listen(values.add);
        await _settle();
        expect(checks, hasLength(1));
        source.add(const ExchangeAccessSignedIn(_testSession));
        await _settle();
        expect(checks, hasLength(2));
        checks.last.complete(const Ok(Environment.regtest));
        await _settle();
        expect(values, [false]);
        checks.first.complete(const Ok(Environment.mainnet));
        await _settle();
        expect(values, [false]);

        superuser.add(true);
        await _settle();
        expect(checks, hasLength(2));
        expect(values, [false]);

        source.add(const ExchangeAccessSignedIn(_testSession));
        await _settle();
        expect(checks, hasLength(3));
        checks.last.complete(const Ok(Environment.mainnet));
        await _settle();
        expect(values, [false, true]);

        source.add(const ExchangeAccessSignedIn(_testSession));
        await _settle();
        expect(checks, hasLength(4));
        await subscription.cancel();
        expect(accessCancelled.isCompleted, isTrue);
        expect(platformCancelled.isCompleted, isTrue);
        checks.last.complete(const Ok(Environment.regtest));
        await _settle();
        expect(values, [false, true]);
        await source.close();
        await superuser.close();
      },
    );
  }

  test('separate observations keep independent network checks', () async {
    final lifecycle = _Access();
    final events = StreamController<ExchangeAccess>.broadcast();
    final superuser = StreamController<bool>.broadcast();
    final checks = <Completer<Result<Environment, PreferencesFailure>>>[];
    when(preferences.readActiveEnvironment).thenAnswer((_) {
      final result = Completer<Result<Environment, PreferencesFailure>>();
      checks.add(result);
      return result.future;
    });
    when(() => lifecycle.current)
        .thenReturn(const ExchangeAccessSignedIn(_testSession));
    when(lifecycle.watch).thenAnswer((_) => events.stream);
    final exchange = exchangeForTesting(
      access: lifecycle,
      sessionPreferences: preferences,
      basicAuth: ExchangeCredentials.openBasicAuth(
        InMemoryExchangeCredentialStorage(),
      ),
    );
    final trading = <bool>[];
    final entry = <bool>[];
    final tradingSubscription = exchange
        .watchTradingVisibility(
          platform: ExchangePlatform.other,
          superuserChanges: superuser.stream,
        )
        .listen(trading.add);
    final entrySubscription = exchange
        .watchActivationOffer(
          platform: ExchangePlatform.other,
          currentSuperuser: () => false,
          superuserChanges: superuser.stream,
          onlyWhileOff: false,
        )
        .listen(entry.add);
    await _settle();
    expect(checks, hasLength(2));
    checks[1].complete(const Ok(Environment.regtest));
    await _settle();
    expect(trading, isEmpty);
    expect(entry, [false]);
    checks[0].complete(const Ok(Environment.mainnet));
    await _settle();
    expect(trading, [true]);
    expect(entry, [false]);
    await tradingSubscription.cancel();
    await entrySubscription.cancel();
    await events.close();
    await superuser.close();
  });
}
