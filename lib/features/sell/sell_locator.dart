import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/sell/domain/label_completed_sell_order_usecase.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_payjoin_trading_enabled_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/set_payjoin_trading_enabled_usecase.dart';
import 'package:bb_mobile/features/sell/domain/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
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

class SellLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<GetPayjoinUsecase>(
      () => GetPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<SetPayjoinTradingEnabledUsecase>(
      () => SetPayjoinTradingEnabledUsecase(locator<PayjoinPolicyAccess>()),
    );
    locator.registerFactory<SendWithPayjoinUsecase>(
      () => SendWithPayjoinUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<CreateSellOrderUsecase>(
      () => CreateSellOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
      ),
    );

    locator.registerFactory<RefreshSellOrderUsecase>(
      () => RefreshSellOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<LabelCompletedSellOrderUsecase>(
      () => LabelCompletedSellOrderUsecase(
        transactionsFacade: locator<TransactionsFacade>(),
      ),
    );

    locator.registerFactory<GetAddressAtIndexUsecase>(
      () => GetAddressAtIndexUsecase(walletAddressRepository: locator()),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<SellBloc>(
      () => SellBloc(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        createSellOrderUsecase: locator<CreateSellOrderUsecase>(),
        refreshSellOrderUsecase: locator<RefreshSellOrderUsecase>(),
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        prepareLiquidSendUsecase: locator<PrepareLiquidSendUsecase>(),
        signBitcoinTxUsecase: locator<SignBitcoinTxUsecase>(),
        signLiquidTxUsecase: locator<SignLiquidTxUsecase>(),
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        broadcastLiquidTransactionUsecase:
            locator<BroadcastLiquidTransactionUsecase>(),
        sendWithPayjoinUsecase: locator<SendWithPayjoinUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        getPayjoinUsecase: locator<GetPayjoinUsecase>(),
        getPayjoinTradingEnabledUsecase:
            locator<GetPayjoinTradingEnabledUsecase>(),
        setPayjoinTradingEnabledUsecase:
            locator<SetPayjoinTradingEnabledUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        calculateLiquidAbsoluteFeesUsecase:
            locator<CalculateLiquidAbsoluteFeesUsecase>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getAddressAtIndexUsecase: locator<GetAddressAtIndexUsecase>(),
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
        getOrderUsecase: locator<GetOrderUsecase>(),
        labelsFacade: locator<LabelsFacade>(),
        labelCompletedSellOrderUsecase:
            locator<LabelCompletedSellOrderUsecase>(),
        previewBitcoinFeeUsecase: locator<PreviewBitcoinFeeUsecase>(),
        previewBitcoinFeePresetsUsecase:
            locator<PreviewBitcoinFeePresetsUsecase>(),
      ),
    );
  }
}
