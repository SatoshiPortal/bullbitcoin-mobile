import 'dart:async';

import 'package:bb_mobile/features/settings/domain/usecases/watch_exchange_activation_offer_usecase.dart';
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
      when(preferences.readExchangeWebPreferences).thenAnswer(
        (_) async => Ok((
          environment: environment,
          exchangeTestnetBasicAuthUsername: null,
          exchangeTestnetBasicAuthPassword: null,
        )),
      );

  setUp(() {
    final lifecycle = _Access();
    preferences = _Preferences();
    access = StreamController<ExchangeAccess>();
    platform = StreamController<bool>();
    stubEnvironment(Environment.mainnet);
    when(lifecycle.watch).thenAnswer((_) => access.stream);
    when(() => lifecycle.current).thenReturn(const ExchangeAccessDisabled());
    exchange = exchangeForTesting(
      access: lifecycle,
      sessionPreferences: preferences,
    );
  });

  tearDown(() async {
    await access.close();
    await platform.close();
  });

  test('offers activation only while the exchange is off', () async {
    final values = <bool>[];
    final sub = WatchExchangeActivationOfferUsecase(
      exchange: exchange,
      platformAllowed: () => true,
      platformChanges: platform.stream,
    ).execute().listen(values.add);
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
    final sub = WatchExchangeActivationOfferUsecase(
      exchange: exchange,
      platformAllowed: () => true,
      platformChanges: platform.stream,
      onlyWhileOff: false,
    ).execute().listen(values.add);
    await _settle();
    access.add(const ExchangeAccessSignedIn(_testSession));
    await _settle();
    expect(values, [true]);
    await sub.cancel();
  });

  test('follows the platform policy', () async {
    final values = <bool>[];
    final sub = WatchExchangeActivationOfferUsecase(
      exchange: exchange,
      platformAllowed: () => false,
      platformChanges: platform.stream,
    ).execute().listen(values.add);
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
    final sub = WatchExchangeActivationOfferUsecase(
      exchange: exchange,
      platformAllowed: () => true,
      platformChanges: platform.stream,
      onlyWhileOff: false,
    ).execute().listen(values.add);
    await _settle();
    expect(values, [false]);
    await sub.cancel();
  });
}
