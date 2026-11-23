import 'package:bull_exchange/src/payin/exchange_payin_wallet.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:bull_exchange/src/pay/domain/estimate_pay_payin_fees_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_exchange_rate_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:bull_exchange/src/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetExchangeRate extends Mock implements GetPayExchangeRateUsecase {}

class _MockGetPayinAddress extends Mock implements GetPayPayinAddressUsecase {}

class _MockLoadNetworkFees extends Mock implements LoadPayNetworkFeesUsecase {}

class _MockPrepareBitcoin extends Mock
    implements PreparePayBitcoinPayinUsecase {}

class _MockPrepareLiquid extends Mock implements PreparePayLiquidPayinUsecase {}

void main() {
  late _MockGetExchangeRate getExchangeRate;
  late _MockGetPayinAddress getPayinAddress;
  late EstimatePayPayinFeesUsecase usecase;
  late ExchangePayinWallet wallet;

  setUpAll(
    () => registerFallbackValue(
      WalletKey(id: 'fallback', network: BitcoinNetwork.mainnet),
    ),
  );

  setUp(() {
    getExchangeRate = _MockGetExchangeRate();
    getPayinAddress = _MockGetPayinAddress();
    wallet = ExchangePayinWallet(
      key: WalletKey(id: 'wallet-1', network: BitcoinNetwork.mainnet),
      balanceSat: BigInt.from(1000000),
    );
    usecase = EstimatePayPayinFeesUsecase(
      getPayExchangeRateUsecase: getExchangeRate,
      getPayPayinAddressUsecase: getPayinAddress,
      loadPayNetworkFeesUsecase: _MockLoadNetworkFees(),
      preparePayBitcoinPayinUsecase: _MockPrepareBitcoin(),
      preparePayLiquidPayinUsecase: _MockPrepareLiquid(),
    );
  });

  // The estimate converts the fiat amount to sats to check the balance and
  // build a throwaway payin. With no price there is nothing to estimate with:
  // a zero rate made every balance look sufficient for a zero-sat payin.
  test('an unavailable price fails the estimate', () async {
    when(
      () => getExchangeRate.execute(currencyCode: 'CAD'),
    ).thenAnswer((_) async => const Err(PayQuoteUnavailableFailure('offline')));

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
      () => getPayinAddress.execute(walletKey: any(named: 'walletKey')),
    );
  });
}
