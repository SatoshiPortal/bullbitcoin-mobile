import 'package:preferences/preferences.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_order_usecase.dart';
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_user_summary_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockGetOrder extends Mock implements GetOrderUsecase {}

class _MockPreferences extends Mock implements Preferences {}

class _MockGetNetworkFees extends Mock implements Fees {}

class _MockGetAddressAtIndex extends Mock implements GetAddressAtIndexUsecase {}

class _MockSellOrder extends Mock implements SellOrder {}

/// The shape these boundaries actually leak when left unwrapped.
const _rawReason = 'DioException 500 apiKey=live_secret_abc';

void main() {
  group('LoadPayUserSummaryUsecase', () {
    test('a summary read failure is a value, not a throw', () async {
      final summary = _MockGetUserSummary();
      when(summary.execute)
          .thenThrow(GetExchangeUserSummaryException(_rawReason));

      final result = await LoadPayUserSummaryUsecase(
        getExchangeUserSummaryUsecase: summary,
      ).execute();

      final failure = (result as Err<UserSummary, PayFailure>).failure;
      expect(failure, isA<PayUnexpectedFailure>());
      expect(failure.logMessage, contains(_rawReason));
    });
  });

  group('GetPayOrderUsecase', () {
    test('a read failure is sanitized', () async {
      final orders = _MockGetOrder();
      when(() => orders.execute(orderId: any(named: 'orderId')))
          .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      final result = await GetPayOrderUsecase(getOrderUsecase: orders)
          .execute(orderId: 'order-1');

      expect(
        (result as Err<FiatPaymentOrder, PayFailure>).failure,
        isA<PayUnexpectedFailure>(),
      );
    });

    test('an order of the wrong type is refused, never cast', () async {
      // The shared use-case returns the whole Order family; adopting a
      // non-payment order here would show the wrong thing on the pay screens.
      final orders = _MockGetOrder();
      when(() => orders.execute(orderId: any(named: 'orderId')))
          .thenAnswer((_) async => Ok(_MockSellOrder()));

      final result = await GetPayOrderUsecase(getOrderUsecase: orders)
          .execute(orderId: 'order-1');

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
        () => addresses.execute(
          walletId: any(named: 'walletId'),
          index: any(named: 'index'),
        ),
      ).thenThrow(GetAddressAtIndexException(_rawReason));

      final result = await GetPayPayinAddressUsecase(
        getAddressAtIndexUsecase: addresses,
      ).execute(walletId: 'wallet-1');

      expect(
        (result as Err<String, PayFailure>).failure,
        isA<PayUnexpectedFailure>(),
      );
    });

    test('the derived address is unwrapped for the caller', () async {
      final addresses = _MockGetAddressAtIndex();
      final address = WalletAddress(
        walletId: 'wallet-1',
        index: 0,
        address: 'bc1qown',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => addresses.execute(
          walletId: any(named: 'walletId'),
          index: any(named: 'index'),
        ),
      ).thenAnswer((_) async => address);

      final result = await GetPayPayinAddressUsecase(
        getAddressAtIndexUsecase: addresses,
      ).execute(walletId: 'wallet-1');

      expect((result as Ok<String, PayFailure>).value, 'bc1qown');
    });
  });
}
