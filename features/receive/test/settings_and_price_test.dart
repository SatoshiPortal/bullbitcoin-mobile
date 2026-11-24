import 'package:address_view/address_view.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLabels extends Mock implements Labels {}

class _MockGetSettingsUsecase extends Mock implements Preferences {}

const _rawReason =
    'DriftRemoteException: database is locked at /data/user/0/app.sqlite';

Receive _receive(Preferences preferences, {IndexPriceReader? readPrice}) =>
    Receive.open(
      addresses: _ReceiveAddressView(),
      labels: _MockLabels(),
      preferences: preferences,
      readPrice:
          readPrice ??
          ({required network, required currency}) =>
              throw StateError('Unexpected price read'),
      readPrices: ({required network}) =>
          throw StateError('Unexpected quote read'),
    );

/// Stands in for `Pricer.getIndexPrice`: answers [fiatAmount] in the
/// requested currency, or [failure] when set, and records each request.
class _FakeIndexPriceReader {
  double fiatAmount;
  PricerFailure? failure;
  DateTime fetchedAt = DateTime.utc(2026, 11, 4, 12);
  final List<({BitcoinNetwork network, SupportedCurrency currency})> requests =
      [];

  _FakeIndexPriceReader({required this.fiatAmount});

  Future<Result<BitcoinPrice, PricerFailure>> call({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) async {
    requests.add((network: network, currency: currency));
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Ok(
      BitcoinPrice(
        currency: currency,
        fiatAmount: fiatAmount,
        fetchedAt: fetchedAt,
      ),
    );
  }
}

void main() {
  group('settings', () {
    test('converts a throw into a sanitized failure', () async {
      final inner = _MockGetSettingsUsecase();
      when(() => inner.fetch()).thenThrow(Exception(_rawReason));

      final result = await _receive(inner).settings();

      switch (result) {
        case Ok():
          fail('a throw must not be reported as settings');
        case Err(:final failure):
          expect(failure, isA<ReceiveUnexpectedFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });

    test('forwards the settings on success', () async {
      final inner = _MockGetSettingsUsecase();
      when(() => inner.fetch()).thenAnswer(
        (_) async => Ok(
          const SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );

      final result = await _receive(inner).settings();

      expect(
        result,
        isA<Ok<ReceiveDisplayPreferences, ReceiveFailure>>().having(
          (result) => result.value.currencyCode,
          'currency',
          'USD',
        ),
      );
    });
  });

  group('convertAmount', () {
    late _MockGetSettingsUsecase getSettings;
    late _FakeIndexPriceReader getIndexPrice;
    late Receive receive;

    setUp(() {
      getSettings = _MockGetSettingsUsecase();
      when(getSettings.fetch).thenAnswer(
        (_) async => Ok(
          SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      getIndexPrice = _FakeIndexPriceReader(fiatAmount: 100000);
      receive = _receive(getSettings, readPrice: getIndexPrice.call);
    });

    test('without an amount, gives the mainnet price of one bitcoin', () async {
      final result = await receive.convertAmount();

      expect((result as Ok<double, ReceiveFailure>).value, 100000);
      expect(getIndexPrice.requests.single, (
        network: BitcoinNetwork.mainnet,
        currency: SupportedCurrency.cad,
      ));
    });

    test('values an amount in the requested currency', () async {
      final result = await receive.convertAmount(
        amountSat: BigInt.from(50000),
        currencyCode: 'EUR',
      );

      expect((result as Ok<double, ReceiveFailure>).value, 50);
      expect(getIndexPrice.requests.single.currency, SupportedCurrency.eur);
    });

    // Its own failure, so the bloc can tell it from one that stops receiving.
    test('no price is a price unavailable failure', () async {
      getIndexPrice.failure = const PricerNetworkFailure('offline');

      final result = await receive.convertAmount();

      expect(
        (result as Err<double, ReceiveFailure>).failure,
        isA<ReceivePriceUnavailableFailure>(),
      );
    });

    test('a currency without a price is a price unavailable failure, never '
        'asked', () async {
      final result = await receive.convertAmount(currencyCode: 'JPY');

      expect(
        (result as Err<double, ReceiveFailure>).failure,
        isA<ReceivePriceUnavailableFailure>(),
      );
      expect(getIndexPrice.requests, isEmpty);
    });

    test('converts a settings throw into a sanitized failure', () async {
      when(getSettings.fetch).thenThrow(Exception(_rawReason));

      final result = await receive.convertAmount();

      switch (result) {
        case Ok():
          fail('a throw must not be reported as a rate');
        case Err(:final failure):
          expect(failure, isA<ReceiveUnexpectedFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });
  });
}

class _ReceiveAddressView extends Mock implements AddressView {}
