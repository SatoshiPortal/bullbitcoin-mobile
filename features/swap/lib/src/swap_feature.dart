import 'package:send/send.dart';

import 'domain/usecases/refresh_pending_order_swaps_usecase.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:address_view/address_view.dart';
import 'package:address_view/payment_destination.dart';
import 'package:bull_ark/bull_ark.dart' show ArkTransferFacade;
import 'package:bull_pricer/bull_pricer.dart';
import 'package:fees/fees.dart';
import 'package:labels/labels.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart';
import 'package:secrets/secrets.dart';
import 'package:signers/storage.dart';
import 'package:spend/spend.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart' show SyncFailure, WalletKey;
import 'package:sync/write.dart';
import 'package:transactions/transactions.dart';

import 'autoswap/autoswap_watcher.dart';
import 'autoswap/data/boltz_autoswap_provider.dart';
import 'autoswap/data/exchange_autoswap_provider.dart';
import 'autoswap/domain/usecases/load_autoswap_settings_usecase.dart';
import 'autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'autoswap/presentation/autoswap_settings_cubit.dart';
import 'autoswap/ui/screens/autoswap_settings_screen.dart';
import 'domain/swap_sync_port.dart';
import 'domain/usecases/apply_completed_order_swap_labels_usecase.dart';
import 'domain/usecases/check_swap_spend_admission_usecase.dart';
import 'domain/usecases/create_receive_order_swap_usecase.dart';
import 'domain/usecases/get_swap_amount_quotes_usecase.dart';
import 'domain/usecases/get_swap_exchange_rate_usecase.dart';
import 'domain/usecases/get_swap_route_usecase.dart';
import 'domain/usecases/load_internal_ark_transfer_usecase.dart';
import 'domain/usecases/load_swap_wallets_usecase.dart';
import 'domain/usecases/load_transfer_network_fees_usecase.dart';
import 'domain/usecases/load_transfer_preferences_usecase.dart';
import 'domain/usecases/read_swap_coins_usecase.dart';
import 'domain/usecases/refresh_order_swaps_usecase.dart';
import 'domain/usecases/review_internal_ark_transfer_usecase.dart';
import 'domain/usecases/schedule_order_swap_refresh_usecase.dart';
import 'domain/usecases/verify_transfer_lockup_usecase.dart';
import 'order_swap_watcher.dart';
import 'presentation/internal_ark_transfer_cubit.dart';
import 'presentation/transfer_bloc.dart';
import 'ui/swap_router.dart';
import 'rescue/swap_rescue_routes.dart';

import 'domain/usecases/get_swap_route_settings_usecase.dart';
import 'domain/usecases/get_swap_server_usecase.dart';
import 'domain/usecases/set_swap_exchange_fallback_usecase.dart';
import 'domain/usecases/set_swap_route_override_usecase.dart';
import 'domain/usecases/set_swap_server_usecase.dart';
import 'presentation/swap_settings_cubit.dart';
import 'swap_l10n.dart';
import 'ui/swap_settings_page.dart';

const _settingsRoute = 'swapSettings';

const _autoswapRoute = 'autoswapSettings';
const _autoswapPath = 'autoswap-settings';

/// The two swap refresh entry points used by foreground wallet sync.
abstract interface class SwapActivity {
  Future<void> retryOngoingSwaps();
  Future<Result<OrderSwapRefreshBatch, SwapFailure>> refreshOrdersWithOutcome();
}

abstract interface class SwapFeature implements SwapActivity {
  List<GoRoute> get routes;

  /// Swap restore and rescue, mounted under the settings home.
  List<GoRoute> get rescueRoutes;
  GoRoute get autoswapSettingsRoute;
  bool get isWatchingOrders;
  bool get isWatchingAutoswap;
  Future<Result<OrderSwapRecord, ReceiveFailure>> createReceiveOrder({
    required ReceiveWallet wallet,
    required int amountSat,
    String? note,
  });
  void start({required bool watchOrders, required bool watchAutoswap});
  Future<void> dispose();

  factory SwapFeature.mount({
    required Swaps swaps,
    required OrderSwaps orders,
    required WalletInventory inventory,
    required WalletNativeRuntime sync,
    required Future<Result<void, SyncFailure>> Function(WalletKey) synchronize,
    required Stream<WalletKey> finished,
    required SignerDevices Function() signerDevices,
    required Preferences preferences,
    required Fees fees,
    required Spend spend,
    required AddressView addresses,
    required Receive receive,
    required Labels labels,
    required Transactions transactions,
    required SwapSyncPort Function() scheduler,
    required ArkTransferFacade? Function() ark,
  }) {
    final wallets = LoadSwapWalletsUsecase(inventory, sync, signerDevices);
    final limits = GetSwapLimitsAndFeesUsecase(swaps.boltz);
    final liquidToBitcoin = CreateLiquidToBitcoinSwapUsecase(
      swaps.boltz,
      swaps.watcher,
    );
    final bitcoinToLiquid = CreateBitcoinToLiquidSwapUsecase(
      swaps.boltz,
      swaps.watcher,
    );
    final recordLockup = RecordSwapLockupUsecase(swaps.resolver, swaps.watcher);
    final recordPending = RecordPendingSwapLockupUsecase(swaps.resolver);
    final dropPending = DropPendingSwapLockupUsecase(swaps.resolver);
    final boltzAutoswap = BoltzAutoswapProvider(
      limits,
      liquidToBitcoin,
      recordLockup,
      recordPending,
      dropPending,
      wallets,
      preferences,
      spend,
      addresses,
      labels,
    );
    final exchangeAutoswap = ExchangeAutoswapProvider(
      wallets,
      preferences,
      spend,
      addresses,
      orders,
      labels,
    );
    final autoswap = Autoswap.open(
      readSettings: () async => (await swaps.readAutoSwap()).mapErr(
        (failure) => switch (failure) {
          SwapsUnsupportedNetworkFailure() =>
            const AutoswapUnsupportedNetworkFailure(),
          _ => AutoswapSettingsUnavailableFailure(
            failure.runtimeType.toString(),
          ),
        },
      ),
      resolveRoute: swaps.resolveRoute,
      runBoltz: boltzAutoswap.execute,
      runExchange: exchangeAutoswap.execute,
    );
    final loadArk = LoadInternalArkTransferUsecase(ark);
    final routes = [
      SwapRouter.route(
        createTransfer: () => TransferBloc(
          getSwapAmountQuotesUsecase: GetSwapAmountQuotesUsecase(
            settings: preferences,
            read: Pricer.getIndexPrices,
          ),
          loadPreferencesUsecase: LoadTransferPreferencesUsecase(preferences),
          getWalletsUsecase: wallets,
          loadNetworkFeesUsecase: LoadTransferNetworkFeesUsecase(fees: fees),
          synchronizeWallet: synchronize,
          verifyChainSwapAmountSendUsecase: VerifyTransferLockupUsecase(sync),
          spend: spend,
          consolidation: Consolidation.open(spend),
          orders: orders,
          checkSwapSpendAdmissionUsecase: CheckSwapSpendAdmissionUsecase(sync),
          detectBitcoinStringUsecase: DetectBitcoinStringUsecase(),
          getReceiveAddressUsecase: addresses,
          getCoinsUsecase: ReadSwapCoinsUsecase(sync),
          getSwapExchangeRateUsecase: GetSwapExchangeRateUsecase(
            getSettingsUsecase: preferences,
            getIndexPrice: Pricer.getIndexPrice,
          ),
          getSwapRouteUsecase: GetSwapRouteUsecase(swaps),
          getSwapLimitsAndFeesUsecase: limits,
          createBitcoinToLiquidSwapUsecase: bitcoinToLiquid,
          createLiquidToBitcoinSwapUsecase: liquidToBitcoin,
          recordSwapLockupUsecase: recordLockup,
          recordPendingSwapLockupUsecase: recordPending,
          dropPendingSwapLockupUsecase: dropPending,
          watchSwapUsecase: WatchSwapUsecase(swaps.store),
        ),
        createArk: () => InternalArkTransferCubit(
          loadArk,
          ReviewInternalArkTransferUsecase(loadArk, receive),
        ),
      ),
      swapSettingsRoute(swaps, swaps),
    ];
    return _SwapFeature(
      List.unmodifiable(routes),
      List.unmodifiable(
        swapRescueRoutes(
          swaps: swaps,
          inventory: inventory,
          environment: preferences,
        ),
      ),
      GoRoute(
        name: _autoswapRoute,
        path: _autoswapPath,
        builder: (_, _) => BlocProvider(
          create: (_) => AutoSwapSettingsCubit(
            loadAutoswapSettingsUsecase: LoadAutoswapSettingsUsecase(
              autoSwapSettings: swaps,
              getSettingsUsecase: preferences,
              walletRepository: wallets,
            ),
            saveAutoswapSettingsUsecase: SaveAutoswapSettingsUsecase(swaps),
          )..loadSettings(),
          child: const AutoSwapSettingsScreen(),
        ),
      ),
      RefreshOrderSwapsUsecase(
        RefreshPendingOrderSwapsUsecase(orders),
        ApplyCompletedOrderSwapLabelsUsecase(orders, transactions, labels),
      ),
      RetryOngoingSwapsUsecase(swaps.watcher),
      CreateReceiveOrderSwapUsecase(orders, addresses),
      OrderSwapWatcher(
        ScheduleOrderSwapRefreshUsecase(scheduler),
        isAppUpdateRequired: () => orders.isAppUpdateRequired,
      ),
      AutoswapWatcher(
        finished
            .asyncMap((key) async {
              final wallet = await inventory.readWallet(key.id);
              return switch (wallet) {
                Ok(:final value) when value.network == key.network => key,
                _ => null,
              };
            })
            .where((key) => key != null)
            .cast<WalletKey>(),
        autoswap,
      ),
    );
  }
}

final class _SwapFeature implements SwapFeature {
  @override
  final List<GoRoute> routes;
  @override
  final List<GoRoute> rescueRoutes;
  @override
  final GoRoute autoswapSettingsRoute;
  final RefreshOrderSwapsUsecase _refresh;
  final RetryOngoingSwapsUsecase _retry;
  final CreateReceiveOrderSwapUsecase _createReceiveOrder;
  final OrderSwapWatcher _ordersWatcher;
  final AutoswapWatcher _autoswapWatcher;
  bool _orderWatching = false;
  bool _autoswapWatching = false;

  _SwapFeature(
    this.routes,
    this.rescueRoutes,
    this.autoswapSettingsRoute,
    this._refresh,
    this._retry,
    this._createReceiveOrder,
    this._ordersWatcher,
    this._autoswapWatcher,
  );

  @override
  bool get isWatchingOrders => _orderWatching;
  @override
  bool get isWatchingAutoswap => _autoswapWatching;

  @override
  Future<Result<OrderSwapRecord, ReceiveFailure>> createReceiveOrder({
    required ReceiveWallet wallet,
    required int amountSat,
    String? note,
  }) => _createReceiveOrder.execute(
    wallet: wallet,
    amountSat: amountSat,
    note: note,
  );

  @override
  void start({required bool watchOrders, required bool watchAutoswap}) {
    if (watchOrders) {
      _orderWatching = true;
      _ordersWatcher.start();
    }
    if (watchAutoswap) {
      _autoswapWatching = true;
      _autoswapWatcher.start();
    }
  }

  @override
  Future<void> dispose() async {
    if (_orderWatching) {
      _orderWatching = false;
      _ordersWatcher.dispose();
    }
    if (_autoswapWatching) {
      _autoswapWatching = false;
      await _autoswapWatcher.dispose();
    }
  }

  @override
  Future<void> retryOngoingSwaps() => _retry.execute();

  @override
  Future<Result<OrderSwapRefreshBatch, SwapFailure>>
  refreshOrdersWithOutcome() => _refresh.execute();
}

abstract final class SwapNavigation {
  static Future<void> open(BuildContext context) =>
      context.pushNamed<void>(TransferRoute.swap.name);

  static Future<void> openAutoswapSettings(BuildContext context) =>
      context.pushNamed<void>(_autoswapRoute);

  static String settingsTitle(String localeName) =>
      swapCopy(localeName).swapSettingsTitle;

  static Future<void> openSettings(BuildContext context) =>
      context.pushNamed<void>(_settingsRoute);

  static Future<void> openRestore(BuildContext context) =>
      context.pushNamed<void>(swapRestoreRouteName);
}

GoRoute swapSettingsRoute(SwapRouting routing, SwapServerSettings servers) =>
    GoRoute(
      name: _settingsRoute,
      path: '/swap-settings',
      builder: (_, _) => BlocProvider(
        create: (_) => SwapSettingsCubit(
          getSwapRouteSettingsUsecase: GetSwapRouteSettingsUsecase(routing),
          setSwapExchangeFallbackUsecase: SetSwapExchangeFallbackUsecase(
            routing,
          ),
          setSwapRouteOverrideUsecase: SetSwapRouteOverrideUsecase(routing),
          getSwapServerUsecase: GetSwapServerUsecase(servers),
          setSwapServerUsecase: SetSwapServerUsecase(servers),
        )..load(),
        child: const SwapSettingsPage(),
      ),
    );
