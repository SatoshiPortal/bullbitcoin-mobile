import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/load_buy_context_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../fake_index_price_reader.dart';

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockGetReceiveAddress extends Mock implements GetReceiveAddressUsecase {}

class _MockGetNetworkFees extends Mock implements GetNetworkFeesUsecase {}

class _MockFeeOptions extends Mock implements FeeOptions {}

/// A reason of the shape these core reads produce, quoting a key.
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
  late _MockGetWallets getWallets;
  late _MockGetReceiveAddress getReceiveAddress;
  late _MockGetNetworkFees getNetworkFees;
  late FakeIndexPriceReader getIndexPrice;
  late LoadBuyContextUsecase usecase;

  setUp(() {
    getUserSummary = _MockGetUserSummary();
    getSettings = _MockGetSettings();
    getWallets = _MockGetWallets();
    getReceiveAddress = _MockGetReceiveAddress();
    getNetworkFees = _MockGetNetworkFees();
    getIndexPrice = FakeIndexPriceReader();
    usecase = LoadBuyContextUsecase(
      getExchangeUserSummaryUsecase: getUserSummary,
      getSettingsUsecase: getSettings,
      getWalletsUsecase: getWallets,
      getReceiveAddressUsecase: getReceiveAddress,
      getNetworkFeesUsecase: getNetworkFees,
      getIndexPrice: getIndexPrice.call,
    );
  });

  // Every method here wraps a core use-case that still throws. The point of
  // the wrapper is that nothing raw escapes into the bloc.
  test('a failed summary read is sanitized, reason kept for logs', () async {
    when(getUserSummary.execute).thenThrow(Exception(_rawReason));

    final result = await usecase.userSummaryAndSettings();

    switch (result) {
      case Ok():
        fail('a failed read must not produce a summary');
      case Err(:final failure):
        expect(failure, isA<BuyUnexpectedFailure>());
        expect(failure.logMessage, contains('secret123'));
    }
  });

  test('returns the wallets', () async {
    when(getWallets.execute).thenAnswer((_) async => Ok(<Wallet>[]));

    final result = await usecase.wallets();

    expect((result as Ok<List<Wallet>, BuyFailure>).value, isEmpty);
  });

  test('a failed wallet read is sanitized', () async {
    // The wallet use case returns a failure now rather than throwing: the
    // repository is the try/catch boundary (#1895).
    when(getWallets.execute).thenAnswer(
      (_) async => const Err<List<Wallet>, WalletFailure>(
        WalletStorageFailure(_rawReason),
      ),
    );

    final result = await usecase.wallets();

    final failure = (result as Err<List<Wallet>, BuyFailure>).failure;
    expect(failure, isA<BuyUnexpectedFailure>());
    // The wallet layer's reason must not survive into this feature's family.
    expect(failure.logMessage, isNot(contains(_rawReason)));
  });

  test('returns the payout address', () async {
    final address = WalletAddress(
      walletId: 'wallet-1',
      index: 0,
      address: 'bc1qpayoutaddress',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    when(
      () => getReceiveAddress.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => address);

    final result = await usecase.receiveAddress(walletId: 'wallet-1');

    expect((result as Ok<WalletAddress, BuyFailure>).value, address);
  });

  test('a failed address derivation is sanitized, never raw', () async {
    when(
      () => getReceiveAddress.execute(walletId: any(named: 'walletId')),
    ).thenThrow(Exception(_rawReason));

    final result = await usecase.receiveAddress(walletId: 'wallet-1');

    switch (result) {
      case Ok():
        fail('a failed derivation must not report an address');
      case Err(:final failure):
        expect(failure, isA<BuyUnexpectedFailure>());
    }
  });

  test('returns the network fees', () async {
    final fees = _MockFeeOptions();
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => fees);

    final result = await usecase.networkFees(isLiquid: false);

    expect((result as Ok<FeeOptions, BuyFailure>).value, fees);
  });

  test('a failed fee read is sanitized', () async {
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenThrow(Exception(_rawReason));

    expect(
      await usecase.networkFees(isLiquid: false),
      isA<Err<FeeOptions, BuyFailure>>(),
    );
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

        expect((result as Ok<double, BuyFailure>).value, 50);
        expect(getIndexPrice.requests.single, (
          network: BitcoinNetwork.mainnet,
          currency: SupportedCurrency.usd,
        ));
      },
    );

    test('without an amount, gives the price of one bitcoin', () async {
      getIndexPrice.fiatAmount = 100000;

      final result = await usecase.satsToCurrency(currencyCode: 'CAD');

      expect((result as Ok<double, BuyFailure>).value, 100000);
      expect(getIndexPrice.requests.single.currency, SupportedCurrency.cad);
    });

    test('asks the testnet price in the testnet environment', () async {
      when(
        getSettings.execute,
      ).thenAnswer((_) async => _settings(environment: Environment.testnet));

      final result = await usecase.satsToCurrency();

      expect(result, isA<Ok<double, BuyFailure>>());
      expect(getIndexPrice.requests.single.network, BitcoinNetwork.testnet);
    });

    test('no price is an unavailable quote, not a zero rate', () async {
      getIndexPrice.failure = const PricerNetworkFailure('offline');

      final result = await usecase.satsToCurrency(currencyCode: 'CAD');

      expect(
        (result as Err<double, BuyFailure>).failure,
        isA<BuyQuoteUnavailableFailure>(),
      );
    });

    test('a currency without a price is unexpected, never asked', () async {
      final result = await usecase.satsToCurrency(currencyCode: 'JPY');

      expect(
        (result as Err<double, BuyFailure>).failure,
        isA<BuyUnexpectedFailure>(),
      );
      expect(getIndexPrice.requests, isEmpty);
    });

    test('a failed settings read is sanitized', () async {
      when(getSettings.execute).thenThrow(Exception(_rawReason));

      expect(
        await usecase.satsToCurrency(currencyCode: 'CAD'),
        isA<Err<double, BuyFailure>>(),
      );
      expect(getIndexPrice.requests, isEmpty);
    });
  });
}
