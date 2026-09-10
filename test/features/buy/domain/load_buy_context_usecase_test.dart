import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/load_buy_context_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockGetReceiveAddress extends Mock implements GetReceiveAddressUsecase {}

class _MockGetNetworkFees extends Mock implements GetNetworkFeesUsecase {}

class _MockConvertSatsToCurrency extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockFeeOptions extends Mock implements FeeOptions {}

/// A reason of the shape these core reads produce, quoting a key.
const _rawReason = 'DioException 500 apikey=secret123';

void main() {
  late _MockGetUserSummary getUserSummary;
  late _MockGetSettings getSettings;
  late _MockGetWallets getWallets;
  late _MockGetReceiveAddress getReceiveAddress;
  late _MockGetNetworkFees getNetworkFees;
  late _MockConvertSatsToCurrency convertSatsToCurrency;
  late LoadBuyContextUsecase usecase;

  setUp(() {
    getUserSummary = _MockGetUserSummary();
    getSettings = _MockGetSettings();
    getWallets = _MockGetWallets();
    getReceiveAddress = _MockGetReceiveAddress();
    getNetworkFees = _MockGetNetworkFees();
    convertSatsToCurrency = _MockConvertSatsToCurrency();
    usecase = LoadBuyContextUsecase(
      getExchangeUserSummaryUsecase: getUserSummary,
      getSettingsUsecase: getSettings,
      getWalletsUsecase: getWallets,
      getReceiveAddressUsecase: getReceiveAddress,
      getNetworkFeesUsecase: getNetworkFees,
      convertSatsToCurrencyAmountUsecase: convertSatsToCurrency,
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
    when(getWallets.execute).thenAnswer((_) async => <Wallet>[]);

    final result = await usecase.wallets();

    expect((result as Ok<List<Wallet>, BuyFailure>).value, isEmpty);
  });

  test('a failed wallet read is sanitized', () async {
    when(getWallets.execute).thenThrow(Exception(_rawReason));

    expect(await usecase.wallets(), isA<Err<List<Wallet>, BuyFailure>>());
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

  test('returns the converted amount', () async {
    when(
      () => convertSatsToCurrency.execute(
        amountSat: any(named: 'amountSat'),
        currencyCode: any(named: 'currencyCode'),
      ),
    ).thenAnswer((_) async => 42.5);

    final result = await usecase.satsToCurrency(currencyCode: 'CAD');

    expect((result as Ok<double, BuyFailure>).value, 42.5);
  });

  test('a failed conversion is sanitized', () async {
    when(
      () => convertSatsToCurrency.execute(
        amountSat: any(named: 'amountSat'),
        currencyCode: any(named: 'currencyCode'),
      ),
    ).thenThrow(Exception(_rawReason));

    expect(
      await usecase.satsToCurrency(currencyCode: 'CAD'),
      isA<Err<double, BuyFailure>>(),
    );
  });
}
