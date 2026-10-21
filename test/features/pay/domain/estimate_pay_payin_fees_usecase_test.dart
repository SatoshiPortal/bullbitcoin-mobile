import 'package:bb_mobile/core/price/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/pay/domain/calculate_pay_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/estimate_pay_payin_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockConvertSatsToCurrency extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetPayinAddress extends Mock implements GetPayPayinAddressUsecase {}

class _MockLoadNetworkFees extends Mock implements LoadPayNetworkFeesUsecase {}

class _MockPrepareBitcoin extends Mock
    implements PreparePayBitcoinPayinUsecase {}

class _MockPrepareLiquid extends Mock implements PreparePayLiquidPayinUsecase {}

class _MockCalculateFees extends Mock
    implements CalculatePayAbsoluteFeesUsecase {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockConvertSatsToCurrency convertSatsToCurrency;
  late _MockGetPayinAddress getPayinAddress;
  late EstimatePayPayinFeesUsecase usecase;
  late _MockWallet wallet;

  setUp(() {
    convertSatsToCurrency = _MockConvertSatsToCurrency();
    getPayinAddress = _MockGetPayinAddress();
    wallet = _MockWallet();
    when(() => wallet.id).thenReturn('wallet-1');
    when(() => wallet.balanceSat).thenReturn(BigInt.from(1000000));
    usecase = EstimatePayPayinFeesUsecase(
      convertSatsToCurrencyAmountUsecase: convertSatsToCurrency,
      getPayPayinAddressUsecase: getPayinAddress,
      loadPayNetworkFeesUsecase: _MockLoadNetworkFees(),
      preparePayBitcoinPayinUsecase: _MockPrepareBitcoin(),
      preparePayLiquidPayinUsecase: _MockPrepareLiquid(),
      calculatePayAbsoluteFeesUsecase: _MockCalculateFees(),
    );
  });

  // The estimate converts the fiat amount to sats to check the balance and
  // build a throwaway payin. With no price there is nothing to estimate with:
  // a zero rate made every balance look sufficient for a zero-sat payin.
  test('an unavailable price fails the estimate', () async {
    // The datasource reports an unreachable pricer as a zero rate.
    when(
      () => convertSatsToCurrency.execute(currencyCode: 'CAD'),
    ).thenAnswer((_) async => 0);

    final result = await usecase.execute(
      wallet: wallet,
      fiatAmount: 30,
      currencyCode: 'CAD',
    );

    expect(result, isA<Err<PayPayinFeeEstimate, PayFailure>>());
    expect(
      (result as Err<PayPayinFeeEstimate, PayFailure>).failure,
      isA<PayQuoteUnavailableFailure>(),
    );
    verifyNever(
      () => getPayinAddress.execute(walletId: any(named: 'walletId')),
    );
  });
}
