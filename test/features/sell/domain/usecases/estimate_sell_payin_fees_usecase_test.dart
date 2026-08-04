import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/usecases/estimate_sell_payin_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class MockGetAddressAtIndexUsecase extends Mock
    implements GetAddressAtIndexUsecase {}

class MockGetNetworkFeesUsecase extends Mock implements GetNetworkFeesUsecase {}

class MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareBitcoinSendUsecase {}

class MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class MockCalculateLiquidAbsoluteFeesUsecase extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class MockWallet extends Mock implements Wallet {}

class MockFeeOptions extends Mock implements FeeOptions {}

void main() {
  late MockConvertSatsToCurrencyAmountUsecase convert;
  late MockGetAddressAtIndexUsecase getAddress;
  late MockGetNetworkFeesUsecase getNetworkFees;
  late MockPrepareBitcoinSendUsecase prepareBitcoin;
  late MockPrepareLiquidSendUsecase prepareLiquid;
  late MockCalculateBitcoinAbsoluteFeesUsecase calculateBitcoin;
  late MockCalculateLiquidAbsoluteFeesUsecase calculateLiquid;
  late EstimateSellPayinFeesUsecase usecase;

  setUpAll(() {
    registerFallbackValue(const RelativeFee(1));
  });

  setUp(() {
    convert = MockConvertSatsToCurrencyAmountUsecase();
    getAddress = MockGetAddressAtIndexUsecase();
    getNetworkFees = MockGetNetworkFeesUsecase();
    prepareBitcoin = MockPrepareBitcoinSendUsecase();
    prepareLiquid = MockPrepareLiquidSendUsecase();
    calculateBitcoin = MockCalculateBitcoinAbsoluteFeesUsecase();
    calculateLiquid = MockCalculateLiquidAbsoluteFeesUsecase();
    usecase = EstimateSellPayinFeesUsecase(
      convertSatsToCurrencyAmountUsecase: convert,
      getAddressAtIndexUsecase: getAddress,
      getNetworkFeesUsecase: getNetworkFees,
      prepareBitcoinSendUsecase: prepareBitcoin,
      prepareLiquidSendUsecase: prepareLiquid,
      calculateBitcoinAbsoluteFeesUsecase: calculateBitcoin,
      calculateLiquidAbsoluteFeesUsecase: calculateLiquid,
    );
  });

  Wallet bitcoinWalletWithBalance(int balanceSat) {
    final wallet = MockWallet();
    when(() => wallet.id).thenReturn('wallet-1');
    when(() => wallet.isLiquid).thenReturn(false);
    when(() => wallet.balanceSat).thenReturn(BigInt.from(balanceSat));
    return wallet;
  }

  group('EstimateSellPayinFeesUsecase', () {
    test(
      'maps an infrastructure throw to SellPrepareTransactionFailure — raw in logMessage only, no leak',
      () async {
        when(
          () => convert.execute(currencyCode: any(named: 'currencyCode')),
        ).thenThrow(Exception('rate service boom'));

        final result = await usecase.execute(
          wallet: bitcoinWalletWithBalance(100000000),
          orderAmount: const BitcoinAmount(1),
          fiatCurrency: FiatCurrency.cad,
        );

        expect(result, isA<Err>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellPrepareTransactionFailure>());
        expect(
          (failure as SellPrepareTransactionFailure).logMessage,
          contains('rate service boom'),
        );
      },
    );

    test(
      'enforces the sufficient-balance rule → SellInsufficientBalanceFailure with the required sats',
      () async {
        when(
          () => convert.execute(currencyCode: any(named: 'currencyCode')),
        ).thenAnswer((_) async => 50000.0);

        // 1 BTC required, wallet holds 1000 sats → insufficient.
        final result = await usecase.execute(
          wallet: bitcoinWalletWithBalance(1000),
          orderAmount: const BitcoinAmount(1),
          fiatCurrency: FiatCurrency.cad,
        );

        expect(result, isA<Err>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellInsufficientBalanceFailure>());
        expect(
          (failure as SellInsufficientBalanceFailure).requiredAmountSat,
          100000000,
        );
        verifyNever(
          () => getAddress.execute(
            walletId: any(named: 'walletId'),
            index: any(named: 'index'),
          ),
        );
      },
    );

    test('returns Ok(fees, rate) on the bitcoin happy path', () async {
      const rate = 50000.0;
      when(
        () => convert.execute(currencyCode: any(named: 'currencyCode')),
      ).thenAnswer((_) async => rate);

      final address = WalletAddress(
        walletId: 'wallet-1',
        index: 0,
        address: 'bc1qtest',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      when(
        () => getAddress.execute(
          walletId: any(named: 'walletId'),
          index: any(named: 'index'),
        ),
      ).thenAnswer((_) async => address);

      final feeOptions = MockFeeOptions();
      when(() => feeOptions.fastest).thenReturn(const RelativeFee(2));
      when(
        () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => feeOptions);

      when(
        () => prepareBitcoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          networkFee: any(named: 'networkFee'),
        ),
      ).thenAnswer(
        (_) async => (unsignedPsbt: 'psbt', txSize: 110, isToSelf: false),
      );
      when(
        () => calculateBitcoin.execute(psbt: any(named: 'psbt')),
      ).thenAnswer((_) async => 220);

      final result = await usecase.execute(
        wallet: bitcoinWalletWithBalance(100000000),
        orderAmount: const BitcoinAmount(1),
        fiatCurrency: FiatCurrency.cad,
      );

      expect(result, isA<Ok>());
      final value = (result as Ok).value;
      expect(value.absoluteFees, 220);
      expect(value.exchangeRateEstimate, rate);
    });
  });
}
