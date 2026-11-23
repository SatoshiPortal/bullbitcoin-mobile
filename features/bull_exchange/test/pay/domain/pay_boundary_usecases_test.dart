import 'package:sync/sync.dart' show WalletKey, SyncStorageFailure;
import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:bull_exchange/src/payin/payin_account.dart';
import 'package:preferences/preferences.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_user_summary_usecase.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockOrders extends Mock implements ExchangeOrders {}

class _MockPreferences extends Mock implements Preferences {}

class _MockGetNetworkFees extends Mock implements Fees {}

class _MockGetAddressAtIndex extends Mock implements PayinWallets {}

class _MockSellOrder extends Mock implements SellOrder {}

void main() {
  group('LoadPayUserSummaryUsecase', () {
    test('a summary read failure is a value, not a throw', () async {
      final preferences = _MockPreferences();
      when(preferences.fetch)
          .thenAnswer((_) async => const Err(PreferencesReadFailure()));
      final result = await LoadPayUserSummaryUsecase(
        PayinAccount(exchangeForTesting(), preferences),
      ).execute();

      final failure = (result as Err<UserSummary, PayFailure>).failure;
      expect(failure, isA<PayUnexpectedFailure>());
      expect(failure.logMessage, contains('ExchangeAccountUnavailableFailure'));
    });
  });

  group('GetPayOrderUsecase', () {
    test('a read failure is sanitized', () async {
      final orders = _MockOrders();
      final preferences = _MockPreferences();
      when(preferences.fetch).thenAnswer(
        (_) async => const Ok(
          SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(() => orders.getOrder(any()))
          .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      final result = await GetPayOrderUsecase(
        PayinAccount(exchangeForTesting(orders: (_) => orders), preferences),
      ).execute(orderId: 'order-1');

      expect(
        (result as Err<FiatPaymentOrder, PayFailure>).failure,
        isA<PayUnexpectedFailure>(),
      );
    });

    test('an order of the wrong type is refused, never cast', () async {
      // The shared use-case returns the whole Order family; adopting a
      // non-payment order here would show the wrong thing on the pay screens.
      final orders = _MockOrders();
      final preferences = _MockPreferences();
      when(preferences.fetch).thenAnswer(
        (_) async => const Ok(
          SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(() => orders.getOrder(any()))
          .thenAnswer((_) async => Ok(_MockSellOrder()));

      final result = await GetPayOrderUsecase(
        PayinAccount(exchangeForTesting(orders: (_) => orders), preferences),
      ).execute(orderId: 'order-1');

      expect(
        (result as Err<FiatPaymentOrder, PayFailure>).failure,
        isA<PayUnexpectedFailure>(),
      );
    });
  });

  group('LoadPayNetworkFeesUsecase', () {
    test('an unreachable mempool is actionable, not a generic oops', () async {
      final fees = _MockGetNetworkFees();
      final preferences = _MockPreferences();
      when(preferences.fetch).thenAnswer(
        (_) async => const Ok(
          SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(() => fees.estimate(BitcoinNetwork.mainnet))
          .thenAnswer((_) async => const Err(FeeSourceReadFailure()));

      final result = await LoadPayNetworkFeesUsecase(
        fees: fees,
        preferences: preferences,
      ).execute(isLiquid: false);

      final failure = (result as Err<FeeOptions, PayFailure>).failure;
      expect(failure, isA<PayFeesUnavailableFailure>());
      expect(failure.logMessage, contains('FeeSourceReadFailure'));
    });
  });

  group('GetPayPayinAddressUsecase', () {
    test('a derivation failure is sanitized', () async {
      final addresses = _MockGetAddressAtIndex();
      when(
        () => addresses.addressAt(
          WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
          0,
        ),
      ).thenAnswer((_) async => const Err(SyncStorageFailure()));

      final result = await GetPayPayinAddressUsecase(addresses).execute(
        walletKey: WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
      );

      expect(
        (result as Err<String, PayFailure>).failure,
        isA<PayUnexpectedFailure>(),
      );
    });

    test('the derived address is unwrapped for the caller', () async {
      final addresses = _MockGetAddressAtIndex();
      when(
        () => addresses.addressAt(
          WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
          0,
        ),
      ).thenAnswer((_) async => const Ok('bc1qown'));

      final result = await GetPayPayinAddressUsecase(addresses).execute(
        walletKey: WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
      );

      expect((result as Ok<String, PayFailure>).value, 'bc1qown');
    });
  });
}
