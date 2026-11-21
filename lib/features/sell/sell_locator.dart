import 'package:bb_mobile/features/sell/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_order_usecase.dart';
import 'package:bb_mobile/features/fees/public/app_fee_estimates.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/usecases/broadcast_sell_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/calculate_sell_liquid_fees_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/get_adoptable_payjoin_sender_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/broadcast_payjoin_original_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/get_visible_payjoin_transaction_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/get_sell_confidential_sepa_availability_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/label_completed_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/load_sell_context_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/load_sell_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/prepare_sell_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/prepare_sell_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/read_sell_payin_txid_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/sign_sell_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/presentation/sell_bloc.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/sell/domain/usecases/store_sell_transaction_label_usecase.dart';

class SellLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<RetryPayjoinProposalUsecase>(
      () => RetryPayjoinProposalUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<GetAdoptablePayjoinSenderUsecase>(
      () => GetAdoptablePayjoinSenderUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<BroadcastPayjoinOriginalUsecase>(
      () => BroadcastPayjoinOriginalUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<GetVisiblePayjoinTransactionUsecase>(
      () => GetVisiblePayjoinTransactionUsecase(locator<PayjoinSessions>()),
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
        wallet: locator<WalletFacade>(),
        send: locator<SendFacade>(),
      ),
    );
    locator.registerFactory<LoadSellContextUsecase>(
      () => LoadSellContextUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        getSettingsUsecase: locator<Preferences>(),
        feeEstimates: locator<AppFeeEstimates>(),
        getAddressAtIndexUsecase: locator<GetAddressAtIndexUsecase>(),
        getIndexPrice: Pricer.getIndexPrice,
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
        wallet: locator<WalletFacade>(),
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<Preferences>(),
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
      ),
    );

    locator.registerFactory<GetSellConfidentialSepaAvailabilityUsecase>(
      () => GetSellConfidentialSepaAvailabilityUsecase(
        locator<RecipientsFacade>(),
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
        settingsRepository: locator<Preferences>(),
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
        getAdoptablePayjoinSenderUsecase:
            locator<GetAdoptablePayjoinSenderUsecase>(),
        broadcastPayjoinOriginalUsecase:
            locator<BroadcastPayjoinOriginalUsecase>(),
        getVisiblePayjoinTransactionUsecase:
            locator<GetVisiblePayjoinTransactionUsecase>(),
        retryPayjoinProposalUsecase: locator<RetryPayjoinProposalUsecase>(),
        calculateSellLiquidFeesUsecase:
            locator<CalculateSellLiquidFeesUsecase>(),
        loadSellWalletUtxosUsecase: locator<LoadSellWalletUtxosUsecase>(),
        readSellPayinTxidUsecase: locator<ReadSellPayinTxidUsecase>(),
        storeSellTransactionLabel: StoreSellTransactionLabelUsecase(
          locator<Labels>(),
        ),
        labelCompletedSellOrderUsecase:
            locator<LabelCompletedSellOrderUsecase>(),
        previewBitcoinFeeUsecase: locator<PreviewBitcoinFeeUsecase>(),
        previewBitcoinFeePresetsUsecase:
            locator<PreviewBitcoinFeePresetsUsecase>(),
      ),
    );
  }
}
