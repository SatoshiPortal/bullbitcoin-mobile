import 'package:sync/sync.dart' show WalletKey, SyncStorageFailure;
import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:bull_exchange/src/payin/payin_account.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/sell/domain/usecases/load_sell_context_usecase.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../support/fake_payin_index_price_reader.dart';

class _MockOrders extends Mock implements ExchangeOrders {}

class _MockGetSettings extends Mock implements Preferences {}

class _MockGetNetworkFees extends Mock implements Fees {}

class _MockGetAddressAtIndex extends Mock implements PayinWallets {}

class _MockFeeOptions extends Mock implements FeeOptions {}

class _MockOrder extends Mock implements SellOrder {}

/// An API reason of the shape these lookups actually produce.
const _rawReason = 'DioException 500 apikey=secret123';

SettingsEntity _settings({Environment environment = Environment.mainnet}) =>
    SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );

void main() {
  late _MockGetSettings getSettings;
  late _MockGetNetworkFees getNetworkFees;
  late _MockGetAddressAtIndex getAddressAtIndex;
  late FakeIndexPriceReader getIndexPrice;
  late _MockOrders getOrder;
  late LoadSellContextUsecase usecase;

  setUp(() {
    getSettings = _MockGetSettings();
    getNetworkFees = _MockGetNetworkFees();
    getAddressAtIndex = _MockGetAddressAtIndex();
    getIndexPrice = FakeIndexPriceReader();
    getOrder = _MockOrders();
    usecase = LoadSellContextUsecase(
      account: PayinAccount(
        exchangeForTesting(orders: (_) => getOrder),
        getSettings,
      ),
      getSettingsUsecase: getSettings,
      fees: getNetworkFees,
      wallets: getAddressAtIndex,
      getIndexPrice: getIndexPrice.call,
    );
  });

  group('userSummaryAndSettings', () {
    // Only the failure path is asserted here: UserSummary is a sealed entity
    // with a large required surface, and the happy path is already exercised
    // end-to-end by the bloc tests.
    test('sanitizes a lookup failure and keeps the reason for logs', () async {
      when(getSettings.fetch)
          .thenAnswer((_) async => const Err(PreferencesReadFailure()));

      final result = await usecase.userSummaryAndSettings();

      switch (result) {
        case Ok():
          fail('a failed summary lookup must not produce a summary');
        case Err(:final failure):
          expect(failure, isA<SellUnexpectedFailure>());
          expect(
            failure.logMessage,
            contains('ExchangeAccountUnavailableFailure'),
          );
      }
    });
  });

  group('networkFees', () {
    test('returns the fee options', () async {
      final fees = _MockFeeOptions();
      when(getSettings.fetch).thenAnswer(
        (_) async => Ok(_settings(environment: Environment.regtest)),
      );
      when(() => getNetworkFees.estimate(BitcoinNetwork.regtest))
          .thenAnswer((_) async => Ok(fees));

      final result = await usecase.networkFees(isLiquid: false);

      expect((result as Ok<FeeOptions, SellFailure>).value, fees);
    });

    test('names the failure so the message stays actionable', () async {
      when(getSettings.fetch).thenAnswer((_) async => Ok(_settings()));
      when(() => getNetworkFees.estimate(BitcoinNetwork.mainnet))
          .thenAnswer((_) async => const Err(FeeEstimateUnavailableFailure()));

      final result = await usecase.networkFees(isLiquid: false);

      switch (result) {
        case Ok():
          fail('a failed rate fetch must not report fee options');
        case Err(:final failure):
          // Not the catch-all: without rates nothing can be built, and the
          // user needs to be told to check their connection.
          expect(failure, isA<SellFeesUnavailableFailure>());
      }
    });
  });

  group('addressAtIndex', () {
    test('returns the address', () async {
      const address = 'bc1qaddress';
      when(
        () => getAddressAtIndex.addressAt(
          WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
          0,
        ),
      ).thenAnswer((_) async => const Ok(address));

      final result = await usecase.addressAtIndex(
        walletKey: WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
        index: 0,
      );

      expect((result as Ok<String, SellFailure>).value, address);
    });

    test('sanitizes a derivation failure', () async {
      when(
        () => getAddressAtIndex.addressAt(
          WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
          0,
        ),
      ).thenAnswer((_) async => const Err(SyncStorageFailure()));

      expect(
        await usecase.addressAtIndex(
          walletKey: WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
          index: 0,
        ),
        isA<Err<String, SellFailure>>(),
      );
    });
  });

  group('satsToCurrency', () {
    setUp(
      () => when(getSettings.fetch).thenAnswer((_) async => Ok(_settings())),
    );

    test(
      'values the amount at the mainnet price of the settings currency',
      () async {
        getIndexPrice.fiatAmount = 100000;

        final result = await usecase.satsToCurrency(
          amountSat: BigInt.from(50000),
        );

        expect((result as Ok<double, SellFailure>).value, 50);
        expect(getIndexPrice.requests.single, (
          network: BitcoinNetwork.mainnet,
          currency: SupportedCurrency.usd,
        ));
      },
    );

    test('without an amount, gives the price of one bitcoin', () async {
      getIndexPrice.fiatAmount = 100000;

      final result = await usecase.satsToCurrency(currencyCode: 'CAD');

      expect((result as Ok<double, SellFailure>).value, 100000);
      expect(getIndexPrice.requests.single.currency, SupportedCurrency.cad);
    });

    test('asks the testnet price in the testnet environment', () async {
      when(getSettings.fetch).thenAnswer(
        (_) async => Ok(_settings(environment: Environment.testnet)),
      );

      final result = await usecase.satsToCurrency();

      expect(result, isA<Ok<double, SellFailure>>());
      expect(getIndexPrice.requests.single.network, BitcoinNetwork.testnet);
    });

    test('no price is an unavailable quote, not a zero rate', () async {
      getIndexPrice.failure = const PricerNetworkFailure('offline');

      final result = await usecase.satsToCurrency(currencyCode: 'CAD');

      expect(
        (result as Err<double, SellFailure>).failure,
        isA<SellQuoteUnavailableFailure>(),
      );
    });

    test('a currency without a price is unexpected, never asked', () async {
      final result = await usecase.satsToCurrency(currencyCode: 'JPY');

      expect(
        (result as Err<double, SellFailure>).failure,
        isA<SellUnexpectedFailure>(),
      );
      expect(getIndexPrice.requests, isEmpty);
    });

    test('a failed settings read is sanitized', () async {
      when(getSettings.fetch).thenThrow(Exception(_rawReason));

      expect(
        await usecase.satsToCurrency(currencyCode: 'CAD'),
        isA<Err<double, SellFailure>>(),
      );
      expect(getIndexPrice.requests, isEmpty);
    });
  });

  group('order', () {
    test('returns the order', () async {
      final order = _MockOrder();
      when(getSettings.fetch).thenAnswer((_) async => Ok(_settings()));
      when(() => getOrder.getOrder(any())).thenAnswer((_) async => Ok(order));

      final result = await usecase.order(orderId: 'order-1');

      expect((result as Ok<Order, SellFailure>).value, order);
    });

    test('sanitizes a fetch failure', () async {
      when(getSettings.fetch).thenAnswer((_) async => Ok(_settings()));
      when(() => getOrder.getOrder(any()))
          .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      final result = await usecase.order(orderId: 'order-1');

      switch (result) {
        case Ok():
          fail('a failed fetch must not report an order');
        case Err(:final failure):
          expect(failure, isA<SellUnexpectedFailure>());
      }
    });
  });
}
