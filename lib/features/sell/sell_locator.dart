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
import 'package:bb_mobile/features/sell/domain/usecases/confirm_sell_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/estimate_sell_payin_fees_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/get_sell_order_status_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/load_sell_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/recalculate_sell_payin_fees_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/start_sell_usecase.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:get_it/get_it.dart';

class SellLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<StartSellUsecase>(
      () => StartSellUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
      ),
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
      ),
    );

    locator.registerFactory<GetSellOrderStatusUsecase>(
      () => GetSellOrderStatusUsecase(
        getOrderUsecase: locator<GetOrderUsecase>(),
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

    locator.registerFactory<GetAddressAtIndexUsecase>(
      () => GetAddressAtIndexUsecase(walletAddressRepository: locator()),
    );

    locator.registerFactory<LoadSellUtxosUsecase>(
      () => LoadSellUtxosUsecase(
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
      ),
    );

    locator.registerFactory<EstimateSellPayinFeesUsecase>(
      () => EstimateSellPayinFeesUsecase(
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getAddressAtIndexUsecase: locator<GetAddressAtIndexUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        prepareLiquidSendUsecase: locator<PrepareLiquidSendUsecase>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
        calculateLiquidAbsoluteFeesUsecase:
            locator<CalculateLiquidAbsoluteFeesUsecase>(),
      ),
    );

    locator.registerFactory<ConfirmSellPayinUsecase>(
      () => ConfirmSellPayinUsecase(
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        prepareLiquidSendUsecase: locator<PrepareLiquidSendUsecase>(),
        signBitcoinTxUsecase: locator<SignBitcoinTxUsecase>(),
        signLiquidTxUsecase: locator<SignLiquidTxUsecase>(),
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        broadcastLiquidTransactionUsecase:
            locator<BroadcastLiquidTransactionUsecase>(),
        labelsFacade: locator<LabelsFacade>(),
      ),
    );

    locator.registerFactory<RecalculateSellPayinFeesUsecase>(
      () => RecalculateSellPayinFeesUsecase(
        getAddressAtIndexUsecase: locator<GetAddressAtIndexUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        prepareLiquidSendUsecase: locator<PrepareLiquidSendUsecase>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
        calculateLiquidAbsoluteFeesUsecase:
            locator<CalculateLiquidAbsoluteFeesUsecase>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<SellBloc>(
      () => SellBloc(
        startSellUsecase: locator<StartSellUsecase>(),
        confirmSellPayinUsecase: locator<ConfirmSellPayinUsecase>(),
        createSellOrderUsecase: locator<CreateSellOrderUsecase>(),
        refreshSellOrderUsecase: locator<RefreshSellOrderUsecase>(),
        estimateSellPayinFeesUsecase: locator<EstimateSellPayinFeesUsecase>(),
        recalculateSellPayinFeesUsecase:
            locator<RecalculateSellPayinFeesUsecase>(),
        loadSellUtxosUsecase: locator<LoadSellUtxosUsecase>(),
        getSellOrderStatusUsecase: locator<GetSellOrderStatusUsecase>(),
      ),
    );
  }
}
