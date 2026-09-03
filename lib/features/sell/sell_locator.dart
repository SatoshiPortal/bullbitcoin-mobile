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
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/sell/domain/broadcast_sell_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/calculate_sell_liquid_fees_usecase.dart';
import 'package:bb_mobile/features/sell/domain/load_sell_context_usecase.dart';
import 'package:bb_mobile/features/sell/domain/prepare_sell_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/read_sell_payin_txid_usecase.dart';
import 'package:bb_mobile/features/sell/domain/load_sell_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/prepare_sell_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sign_sell_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/label_completed_sell_order_usecase.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
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
    locator.registerFactory<SendWithPayjoinUsecase>(
      () => SendWithPayjoinUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<PrepareSellLiquidPayinUsecase>(
      () => PrepareSellLiquidPayinUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<CalculateSellLiquidFeesUsecase>(
      () => CalculateSellLiquidFeesUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<SignSellPayinUsecase>(
      () => SignSellPayinUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<PrepareSellBitcoinPayinUsecase>(
      () => PrepareSellBitcoinPayinUsecase(
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
      ),
    );
    locator.registerFactory<BroadcastSellPayinUsecase>(
      () => BroadcastSellPayinUsecase(
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        broadcastLiquidTransactionUsecase:
            locator<BroadcastLiquidTransactionUsecase>(),
      ),
    );
    locator.registerFactory<LoadSellContextUsecase>(
      () => LoadSellContextUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        getAddressAtIndexUsecase: locator<GetAddressAtIndexUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getOrderUsecase: locator<GetOrderUsecase>(),
      ),
    );
    locator.registerFactory<ReadSellPayinTxidUsecase>(
      () => const ReadSellPayinTxidUsecase(),
    );
    locator.registerFactory<LoadSellWalletUtxosUsecase>(
      () => LoadSellWalletUtxosUsecase(
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
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
        loadSellContextUsecase: locator<LoadSellContextUsecase>(),
        createSellOrderUsecase: locator<CreateSellOrderUsecase>(),
        refreshSellOrderUsecase: locator<RefreshSellOrderUsecase>(),
        prepareSellBitcoinPayinUsecase:
            locator<PrepareSellBitcoinPayinUsecase>(),
        prepareSellLiquidPayinUsecase: locator<PrepareSellLiquidPayinUsecase>(),
        signSellPayinUsecase: locator<SignSellPayinUsecase>(),
        broadcastSellPayinUsecase: locator<BroadcastSellPayinUsecase>(),
        sendWithPayjoinUsecase: locator<SendWithPayjoinUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        getPayjoinUsecase: locator<GetPayjoinUsecase>(),
        calculateSellLiquidFeesUsecase:
            locator<CalculateSellLiquidFeesUsecase>(),
        loadSellWalletUtxosUsecase: locator<LoadSellWalletUtxosUsecase>(),
        readSellPayinTxidUsecase: locator<ReadSellPayinTxidUsecase>(),
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
