import 'dart:async';

import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_exchange_activation_offer_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _Exchange exchange;
  late StreamController<ExchangeAccess> access;
  late StreamController<bool> platform;

  setUp(() {
    exchange = _Exchange();
    access = StreamController<ExchangeAccess>();
    platform = StreamController<bool>();
    when(exchange.networkUnavailable).thenAnswer((_) async => false);
    when(exchange.watchAccess).thenAnswer((_) => access.stream);
    when(() => exchange.currentAccess)
        .thenReturn(const ExchangeAccessDisabled());
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
    access.add(const ExchangeAccessEnabled(ExchangeAccessSession.signedOut));
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
    access.add(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
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
    when(exchange.networkUnavailable).thenAnswer((_) async => true);
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
