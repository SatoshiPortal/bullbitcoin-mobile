import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';

import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/pay/domain/broadcast_pay_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/calculate_pay_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/create_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/estimate_pay_payin_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_user_summary_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/sign_pay_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';

import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:get_it/get_it.dart';

class PayLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<SendWithPayjoinUsecase>(
      () => SendWithPayjoinUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<GetPayjoinUsecase>(
      () => GetPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<PlacePayOrderUsecase>(
      () => PlacePayOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator(),
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
      ),
    );

    locator.registerFactory<RefreshPayOrderUsecase>(
      () => RefreshPayOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator(),
      ),
    );

    locator.registerFactory<PreparePayBitcoinPayinUsecase>(
      () => PreparePayBitcoinPayinUsecase(
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
      ),
    );
    locator.registerFactory<PreparePayLiquidPayinUsecase>(
      () => PreparePayLiquidPayinUsecase(
        prepareLiquidSendUsecase: locator<PrepareLiquidSendUsecase>(),
      ),
    );
    locator.registerFactory<SignPayPayinUsecase>(
      () => SignPayPayinUsecase(
        signBitcoinTxUsecase: locator<SignBitcoinTxUsecase>(),
        signLiquidTxUsecase: locator<SignLiquidTxUsecase>(),
      ),
    );
    locator.registerFactory<BroadcastPayPayinUsecase>(
      () => BroadcastPayPayinUsecase(
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        broadcastLiquidTransactionUsecase:
            locator<BroadcastLiquidTransactionUsecase>(),
      ),
    );
    locator.registerFactory<LoadPayWalletUtxosUsecase>(
      () => LoadPayWalletUtxosUsecase(
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
      ),
    );
    locator.registerFactory<LoadPayUserSummaryUsecase>(
      () => LoadPayUserSummaryUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );
    locator.registerFactory<GetPayOrderUsecase>(
      () => GetPayOrderUsecase(getOrderUsecase: locator<GetOrderUsecase>()),
    );
    locator.registerFactory<LoadPayNetworkFeesUsecase>(
      () => LoadPayNetworkFeesUsecase(
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
      ),
    );
    locator.registerFactory<GetPayPayinAddressUsecase>(
      () => GetPayPayinAddressUsecase(
        getAddressAtIndexUsecase: locator<GetAddressAtIndexUsecase>(),
      ),
    );
    locator.registerFactory<CalculatePayAbsoluteFeesUsecase>(
      () => CalculatePayAbsoluteFeesUsecase(
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
        calculateLiquidAbsoluteFeesUsecase:
            locator<CalculateLiquidAbsoluteFeesUsecase>(),
      ),
    );
    locator.registerFactory<EstimatePayPayinFeesUsecase>(
      () => EstimatePayPayinFeesUsecase(
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getPayPayinAddressUsecase: locator<GetPayPayinAddressUsecase>(),
        loadPayNetworkFeesUsecase: locator<LoadPayNetworkFeesUsecase>(),
        preparePayBitcoinPayinUsecase: locator<PreparePayBitcoinPayinUsecase>(),
        preparePayLiquidPayinUsecase: locator<PreparePayLiquidPayinUsecase>(),
        calculatePayAbsoluteFeesUsecase:
            locator<CalculatePayAbsoluteFeesUsecase>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<PayBloc>(
      () => PayBloc(
        loadPayUserSummaryUsecase: locator<LoadPayUserSummaryUsecase>(),
        placePayOrderUsecase: locator<PlacePayOrderUsecase>(),
        refreshPayOrderUsecase: locator<RefreshPayOrderUsecase>(),
        getPayOrderUsecase: locator<GetPayOrderUsecase>(),
        estimatePayPayinFeesUsecase: locator<EstimatePayPayinFeesUsecase>(),
        preparePayBitcoinPayinUsecase: locator<PreparePayBitcoinPayinUsecase>(),
        preparePayLiquidPayinUsecase: locator<PreparePayLiquidPayinUsecase>(),
        signPayPayinUsecase: locator<SignPayPayinUsecase>(),
        broadcastPayPayinUsecase: locator<BroadcastPayPayinUsecase>(),
        loadPayWalletUtxosUsecase: locator<LoadPayWalletUtxosUsecase>(),
        loadPayNetworkFeesUsecase: locator<LoadPayNetworkFeesUsecase>(),
        calculatePayAbsoluteFeesUsecase:
            locator<CalculatePayAbsoluteFeesUsecase>(),
        getPayPayinAddressUsecase: locator<GetPayPayinAddressUsecase>(),
        sendWithPayjoinUsecase: locator<SendWithPayjoinUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        getPayjoinUsecase: locator<GetPayjoinUsecase>(),
        previewBitcoinFeeUsecase: locator<PreviewBitcoinFeeUsecase>(),
        previewBitcoinFeePresetsUsecase:
            locator<PreviewBitcoinFeePresetsUsecase>(),
      ),
    );
  }
}
