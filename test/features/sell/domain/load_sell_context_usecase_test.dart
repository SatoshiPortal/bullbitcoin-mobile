import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/features/sell/domain/load_sell_context_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../fake_index_price_reader.dart';

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

class _MockGetNetworkFees extends Mock implements GetNetworkFeesUsecase {}

class _MockGetAddressAtIndex extends Mock implements GetAddressAtIndexUsecase {}

class _MockGetOrder extends Mock implements GetOrderUsecase {}

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
  late _MockGetUserSummary getUserSummary;
  late _MockGetSettings getSettings;
  late _MockGetNetworkFees getNetworkFees;
  late _MockGetAddressAtIndex getAddressAtIndex;
  late FakeIndexPriceReader getIndexPrice;
  late _MockGetOrder getOrder;
  late LoadSellContextUsecase usecase;

  setUp(() {
    getUserSummary = _MockGetUserSummary();
    getSettings = _MockGetSettings();
    getNetworkFees = _MockGetNetworkFees();
    getAddressAtIndex = _MockGetAddressAtIndex();
    getIndexPrice = FakeIndexPriceReader();
    getOrder = _MockGetOrder();
    usecase = LoadSellContextUsecase(
      getExchangeUserSummaryUsecase: getUserSummary,
      getSettingsUsecase: getSettings,
      getNetworkFeesUsecase: getNetworkFees,
      getAddressAtIndexUsecase: getAddressAtIndex,
      getIndexPrice: getIndexPrice.call,
      getOrderUsecase: getOrder,
    );
  });

  group('userSummaryAndSettings', () {
    // Only the failure path is asserted here: UserSummary is a sealed entity
    // with a large required surface, and the happy path is already exercised
    // end-to-end by the bloc tests.
    test('sanitizes a lookup failure and keeps the reason for logs', () async {
      when(getUserSummary.execute).thenThrow(Exception(_rawReason));

      final result = await usecase.userSummaryAndSettings();

      switch (result) {
        case Ok():
          fail('a failed summary lookup must not produce a summary');
        case Err(:final failure):
          expect(failure, isA<SellUnexpectedFailure>());
          expect(failure.logMessage, contains('secret123'));
      }
    });
  });

  group('networkFees', () {
    test('returns the fee options', () async {
      final fees = _MockFeeOptions();
      when(() => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')))
          .thenAnswer((_) async => fees);

      final result = await usecase.networkFees(isLiquid: false);

      expect((result as Ok<FeeOptions, SellFailure>).value, fees);
    });

    test('names the failure so the message stays actionable', () async {
      when(() => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')))
          .thenThrow(Exception(_rawReason));

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
      final address = WalletAddress(
        walletId: 'wallet-1',
        index: 0,
        address: 'bc1qaddress',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => getAddressAtIndex.execute(
          walletId: any(named: 'walletId'),
          index: any(named: 'index'),
        ),
      ).thenAnswer((_) async => address);

      final result = await usecase.addressAtIndex(
        walletId: 'wallet-1',
        index: 0,
      );

      expect((result as Ok<WalletAddress, SellFailure>).value, address);
    });

    test('sanitizes a derivation failure', () async {
      when(
        () => getAddressAtIndex.execute(
          walletId: any(named: 'walletId'),
          index: any(named: 'index'),
        ),
      ).thenThrow(Exception(_rawReason));

      expect(
        await usecase.addressAtIndex(walletId: 'wallet-1', index: 0),
        isA<Err<WalletAddress, SellFailure>>(),
      );
    });
  });

  group('satsToCurrency', () {
    setUp(() => when(getSettings.execute).thenAnswer((_) async => _settings()));

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
      when(getSettings.execute)
          .thenAnswer((_) async => _settings(environment: Environment.testnet));

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
      when(getSettings.execute).thenThrow(Exception(_rawReason));

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
      when(() => getOrder.execute(orderId: any(named: 'orderId')))
          .thenAnswer((_) async => order);

      final result = await usecase.order(orderId: 'order-1');

      expect((result as Ok<Order, SellFailure>).value, order);
    });

    test('sanitizes a fetch failure', () async {
      when(() => getOrder.execute(orderId: any(named: 'orderId')))
          .thenThrow(Exception(_rawReason));

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
