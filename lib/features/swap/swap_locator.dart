import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/features/swap/data/datasources/exchange_public_api_datasource.dart';
import 'package:bb_mobile/features/swap/data/datasources/order_swap_local_datasource.dart';
import 'package:bb_mobile/features/swap/data/order_swap_repository_impl.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/usecases/create_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/apply_completed_order_swap_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_quote_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_pending_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swaps_awaiting_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_broadcast_unknown_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_payin_broadcast_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_labels_applied_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_pending_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/replace_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/save_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/watch_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class SwapLocator {
  static const _testnetExchangeDatasource = 'testnetExchangeDatasource';
  static const _mainnetExchangeDatasource = 'mainnetExchangeDatasource';

  static void setup(GetIt locator) {
    registerOrderSwapFoundation(locator);
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerOrderSwapFoundation(GetIt locator) {
    locator.registerLazySingleton<ExchangePublicApiDatasource>(
      () => ExchangePublicApiDatasource(
        Dio(
          BaseOptions(
            baseUrl: ApiServiceConstants.swapApiStagingUrl,
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ),
      ),
      instanceName: _testnetExchangeDatasource,
    );
    locator.registerLazySingleton<ExchangePublicApiDatasource>(
      () => ExchangePublicApiDatasource(
        Dio(
          BaseOptions(
            baseUrl: ApiServiceConstants.swapApiMainnetUrl,
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ),
      ),
      instanceName: _mainnetExchangeDatasource,
    );
    locator.registerLazySingleton<OrderSwapRepository>(
      () => OrderSwapRepositoryImpl(
        locator<ExchangePublicApiDatasource>(
          instanceName: _testnetExchangeDatasource,
        ),
        locator<ExchangePublicApiDatasource>(
          instanceName: _mainnetExchangeDatasource,
        ),
        OrderSwapLocalDatasource(locator<SqliteDatabase>()),
      ),
    );
    locator.registerFactory<GetOrderSwapQuoteUsecase>(
      () => GetOrderSwapQuoteUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<CreateOrderSwapUsecase>(
      () => CreateOrderSwapUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<RefreshOrderSwapUsecase>(
      () => RefreshOrderSwapUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<RefreshPendingOrderSwapsUsecase>(
      () => RefreshPendingOrderSwapsUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<GetOrderSwapsUsecase>(
      () => GetOrderSwapsUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<GetOrderSwapUsecase>(
      () => GetOrderSwapUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<GetPendingOrderSwapsUsecase>(
      () => GetPendingOrderSwapsUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<GetOrderSwapsAwaitingLabelsUsecase>(
      () => GetOrderSwapsAwaitingLabelsUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<SavePreparedOrderSwapPayinUsecase>(
      () => SavePreparedOrderSwapPayinUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<ReplacePreparedOrderSwapPayinUsecase>(
      () =>
          ReplacePreparedOrderSwapPayinUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<MarkOrderSwapBroadcastUnknownUsecase>(
      () =>
          MarkOrderSwapBroadcastUnknownUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<MarkOrderSwapPayinBroadcastUsecase>(
      () => MarkOrderSwapPayinBroadcastUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<MarkOrderSwapLabelsAppliedUsecase>(
      () => MarkOrderSwapLabelsAppliedUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<ApplyCompletedOrderSwapLabelsUsecase>(
      () => ApplyCompletedOrderSwapLabelsUsecase(
        locator<GetOrderSwapsAwaitingLabelsUsecase>(),
        locator<MarkOrderSwapLabelsAppliedUsecase>(),
        locator<WalletTransactionRepository>(),
        locator<LabelsFacade>(),
      ),
    );
    locator.registerLazySingleton<RefreshOrderSwapsUsecase>(
      () => RefreshOrderSwapsUsecase(
        locator<RefreshPendingOrderSwapsUsecase>(),
        locator<ApplyCompletedOrderSwapLabelsUsecase>(),
      ),
    );
    locator.registerFactory<WatchOrderSwapUsecase>(
      () => WatchOrderSwapUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<SwapFacade>(
      () => SwapFacade(
        locator<GetOrderSwapQuoteUsecase>(),
        locator<CreateOrderSwapUsecase>(),
        locator<RefreshOrderSwapUsecase>(),
        locator<GetOrderSwapsUsecase>(),
        locator<GetOrderSwapUsecase>(),
        locator<GetPendingOrderSwapsUsecase>(),
        locator<GetOrderSwapsAwaitingLabelsUsecase>(),
        locator<SavePreparedOrderSwapPayinUsecase>(),
        locator<MarkOrderSwapBroadcastUnknownUsecase>(),
        locator<MarkOrderSwapPayinBroadcastUsecase>(),
        locator<MarkOrderSwapLabelsAppliedUsecase>(),
        locator<WatchOrderSwapUsecase>(),
        locator<RefreshOrderSwapsUsecase>(),
      ),
    );
    locator.registerLazySingleton<OrderSwapWatcher>(
      () => OrderSwapWatcher(locator<RefreshOrderSwapsUsecase>()),
      dispose: (watcher) => watcher.dispose(),
    );
    locator<OrderSwapWatcher>().start();
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<PrepareBitcoinSendUsecase>(
      () => PrepareBitcoinSendUsecase(
        payjoinSessions: locator<PayjoinSessions>(),
        walletUtxoRepository: locator<WalletUtxoRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<PrepareLiquidSendUsecase>(
      () => PrepareLiquidSendUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<SignLiquidTxUsecase>(
      () => SignLiquidTxUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<SignBitcoinTxUsecase>(
      () => SignBitcoinTxUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );

    locator.registerFactory<CalculateBitcoinAbsoluteFeesUsecase>(
      () => CalculateBitcoinAbsoluteFeesUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<PreviewBitcoinFeeUsecase>(
      () => PreviewBitcoinFeeUsecase(
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
      ),
    );
    locator.registerFactory<PreviewBitcoinFeePresetsUsecase>(
      () => PreviewBitcoinFeePresetsUsecase(
        previewBitcoinFeeUsecase: locator<PreviewBitcoinFeeUsecase>(),
      ),
    );
    locator.registerFactory<CalculateLiquidAbsoluteFeesUsecase>(
      () => CalculateLiquidAbsoluteFeesUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<DetectBitcoinStringUsecase>(
      () => DetectBitcoinStringUsecase(),
    );
    locator.registerFactory<VerifyChainSwapAmountSendUsecase>(
      () => VerifyChainSwapAmountSendUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<TransferBloc>(
      () => TransferBloc(
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        prepareLiquidSendUsecase: locator<PrepareLiquidSendUsecase>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
        calculateLiquidAbsoluteFeesUsecase:
            locator<CalculateLiquidAbsoluteFeesUsecase>(),
        getWalletUsecase: locator<GetWalletUsecase>(),
        signBitcoinTxUsecase: locator<SignBitcoinTxUsecase>(),
        signLiquidTxUsecase: locator<SignLiquidTxUsecase>(),
        broadcastBitcoinTxUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        broadcastLiquidTxUsecase: locator<BroadcastLiquidTransactionUsecase>(),
        verifyChainSwapAmountSendUsecase:
            locator<VerifyChainSwapAmountSendUsecase>(),
        getOrderSwapQuoteUsecase: locator<GetOrderSwapQuoteUsecase>(),
        createOrderSwapUsecase: locator<CreateOrderSwapUsecase>(),
        savePreparedOrderSwapPayinUsecase:
            locator<SavePreparedOrderSwapPayinUsecase>(),
        replacePreparedOrderSwapPayinUsecase:
            locator<ReplacePreparedOrderSwapPayinUsecase>(),
        markOrderSwapBroadcastUnknownUsecase:
            locator<MarkOrderSwapBroadcastUnknownUsecase>(),
        markOrderSwapPayinBroadcastUsecase:
            locator<MarkOrderSwapPayinBroadcastUsecase>(),
        watchOrderSwapUsecase: locator<WatchOrderSwapUsecase>(),
        detectBitcoinStringUsecase: locator<DetectBitcoinStringUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        previewBitcoinFeeUsecase: locator<PreviewBitcoinFeeUsecase>(),
        previewBitcoinFeePresetsUsecase:
            locator<PreviewBitcoinFeePresetsUsecase>(),
        checkLiquidConsolidationUsecase:
            locator<CheckLiquidConsolidationUsecase>(),
      ),
    );
  }
}
