import 'package:spend/spend.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/swap/domain/usecases/load_transfer_preferences_usecase.dart';

import 'domain/usecases/get_swap_amount_quotes_usecase.dart';

import 'package:bull_ark/bull_ark.dart' show ArkTransferFacade;

import 'domain/usecases/load_internal_ark_transfer_usecase.dart';
import 'domain/usecases/review_internal_ark_transfer_usecase.dart';
import 'presentation/internal_ark_transfer_cubit.dart';

import 'package:bb_mobile/features/swap/domain/usecases/load_transfer_network_fees_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/swap/data/order_swaps_database.dart';
import 'package:bb_mobile/features/swap/domain/usecases/schedule_order_swap_refresh_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:swaps/setup.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:transactions/transactions.dart';
import 'package:send/send.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/wallet/public/detect_bitcoin_string_usecase.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:swaps/swaps.dart';
import 'package:bb_mobile/features/swap/data/datasources/exchange_public_api_datasource.dart';
import 'package:bb_mobile/features/swap/data/datasources/order_swap_local_datasource.dart';
import 'package:bb_mobile/features/swap/data/order_swap_repository_impl.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/usecases/check_swap_spend_admission_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/create_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/apply_completed_order_swap_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_quote_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_pending_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_app_update_required_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_exchange_rate_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_route_usecase.dart';
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
import 'package:bb_mobile/features/swap/domain/usecases/watch_swap_app_update_required_usecase.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:dio/dio.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';

class SwapLocator {
  static const _testnetExchangeDatasource = 'testnetExchangeDatasource';
  static const _mainnetExchangeDatasource = 'mainnetExchangeDatasource';

  static void setup(GetIt locator) {
    locator.registerFactory<LoadInternalArkTransferUsecase>(
      () => LoadInternalArkTransferUsecase(
        () => locator.isRegistered<ArkTransferFacade>()
            ? locator<ArkTransferFacade>()
            : null,
      ),
    );
    locator.registerFactory<ReviewInternalArkTransferUsecase>(
      () => ReviewInternalArkTransferUsecase(
        locator<LoadInternalArkTransferUsecase>(),
        locator<WalletFacade>(),
      ),
    );
    locator.registerFactory<InternalArkTransferCubit>(
      () => InternalArkTransferCubit(
        locator<LoadInternalArkTransferUsecase>(),
        locator<ReviewInternalArkTransferUsecase>(),
      ),
    );
    registerOrderSwapFoundation(locator);
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerOrderSwapFoundation(GetIt locator) {
    locator.registerLazySingleton<ExchangePublicApiDatasource>(
      () => ExchangePublicApiDatasource(
        Dio(
          BaseOptions(
            baseUrl: SwapServiceDefaults.swapApiStagingUrl,
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
            baseUrl: SwapServiceDefaults.swapApiMainnetUrl,
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
        OrderSwapLocalDatasource(locator<OrderSwapsDatabase>()),
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
        locator<Transactions>(),
        locator<Labels>(),
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
    locator.registerFactory<GetSwapAppUpdateRequiredUsecase>(
      () => GetSwapAppUpdateRequiredUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<WatchSwapAppUpdateRequiredUsecase>(
      () => WatchSwapAppUpdateRequiredUsecase(locator<OrderSwapRepository>()),
    );
    locator.registerFactory<GetSwapExchangeRateUsecase>(
      () => GetSwapExchangeRateUsecase(
        getSettingsUsecase: locator<Preferences>(),
        getIndexPrice: Pricer.getIndexPrice,
      ),
    );
    locator.registerFactory<GetSwapRouteUsecase>(
      () => GetSwapRouteUsecase(locator<SwapRouting>()),
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
        locator<ReplacePreparedOrderSwapPayinUsecase>(),
        locator<MarkOrderSwapBroadcastUnknownUsecase>(),
        locator<MarkOrderSwapPayinBroadcastUsecase>(),
        locator<MarkOrderSwapLabelsAppliedUsecase>(),
        locator<WatchOrderSwapUsecase>(),
        locator<RefreshOrderSwapsUsecase>(),
        locator<GetSwapAppUpdateRequiredUsecase>(),
        locator<WatchSwapAppUpdateRequiredUsecase>(),
        locator<RetryOngoingSwapsUsecase>(),
      ),
    );
    locator.registerFactory<ScheduleOrderSwapRefreshUsecase>(
      () => ScheduleOrderSwapRefreshUsecase(locator<SwapSyncPort>()),
    );
    locator.registerLazySingleton<OrderSwapWatcher>(
      () => OrderSwapWatcher(
        locator<ScheduleOrderSwapRefreshUsecase>(),
        isAppUpdateRequired: () => locator<SwapFacade>().isAppUpdateRequired,
      ),
      dispose: (watcher) => watcher.dispose(),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<CheckSwapSpendAdmissionUsecase>(
      () => CheckSwapSpendAdmissionUsecase(locator<WalletFacade>()),
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
        getSwapAmountQuotesUsecase: GetSwapAmountQuotesUsecase(
          settings: locator<Preferences>(),
          read: Pricer.getIndexPrices,
        ),
        loadPreferencesUsecase: LoadTransferPreferencesUsecase(
          locator<Preferences>(),
        ),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        loadNetworkFeesUsecase: LoadTransferNetworkFeesUsecase(fees: locator()),
        getWalletUsecase: locator<GetWalletUsecase>(),
        verifyChainSwapAmountSendUsecase:
            locator<VerifyChainSwapAmountSendUsecase>(),
        spend: locator<Spend>(),
        getOrderSwapQuoteUsecase: locator<GetOrderSwapQuoteUsecase>(),
        getPendingOrderSwapsUsecase: locator<GetPendingOrderSwapsUsecase>(),
        createOrderSwapUsecase: locator<CreateOrderSwapUsecase>(),
        checkSwapSpendAdmissionUsecase:
            locator<CheckSwapSpendAdmissionUsecase>(),
        savePreparedOrderSwapPayinUsecase:
            locator<SavePreparedOrderSwapPayinUsecase>(),
        replacePreparedOrderSwapPayinUsecase:
            locator<ReplacePreparedOrderSwapPayinUsecase>(),
        refreshOrderSwapUsecase: locator<RefreshOrderSwapUsecase>(),
        markOrderSwapBroadcastUnknownUsecase:
            locator<MarkOrderSwapBroadcastUnknownUsecase>(),
        markOrderSwapPayinBroadcastUsecase:
            locator<MarkOrderSwapPayinBroadcastUsecase>(),
        watchOrderSwapUsecase: locator<WatchOrderSwapUsecase>(),
        detectBitcoinStringUsecase: locator<DetectBitcoinStringUsecase>(),
        getReceiveAddressUsecase: locator<AddressView>(),
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
        getSwapExchangeRateUsecase: locator<GetSwapExchangeRateUsecase>(),
        consolidation: Consolidation.open(locator<Spend>()),
        getSwapRouteUsecase: locator<GetSwapRouteUsecase>(),
        getSwapLimitsAndFeesUsecase: locator<GetSwapLimitsAndFeesUsecase>(),
        createBitcoinToLiquidSwapUsecase:
            locator<CreateBitcoinToLiquidSwapUsecase>(),
        createLiquidToBitcoinSwapUsecase:
            locator<CreateLiquidToBitcoinSwapUsecase>(),
        recordSwapLockupUsecase: locator<RecordSwapLockupUsecase>(),
        recordPendingSwapLockupUsecase:
            locator<RecordPendingSwapLockupUsecase>(),
        dropPendingSwapLockupUsecase: locator<DropPendingSwapLockupUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
      ),
    );
  }
}
