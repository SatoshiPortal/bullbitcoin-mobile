import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_for_tor_initialization_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_bloc.freezed.dart';
part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required CheckWalletSyncingUsecase checkWalletSyncingUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
    required InitializeTorUsecase initializeTorUsecase,
    required CheckTorRequiredOnStartupUsecase
    checkForTorInitializationOnStartupUsecase,
    required GetPrioritizedServerUsecase getBestAvailableServerUsecase,
    required GetUnconfirmedIncomingBalanceUsecase
    getUnconfirmedIncomingBalanceUsecase,
    required GetAutoSwapSettingsUsecase getAutoSwapSettingsUsecase,
    required GetSwapLimitsUsecase getSwapLimitsUsecase,
    required CreateChainSwapUsecase createChainSwapUsecase,
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required SignLiquidTxUsecase signLiquidTxUsecase,
    required BroadcastLiquidTransactionUsecase broadcastLiquidTxUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _checkWalletSyncingUsecase = checkWalletSyncingUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _restartSwapWatcherUsecase = restartSwapWatcherUsecase,
       _initializeTorUsecase = initializeTorUsecase,
       _checkForTorInitializationOnStartupUsecase =
           checkForTorInitializationOnStartupUsecase,
       _getPrioritizedServerUsecase = getBestAvailableServerUsecase,
       _getUnconfirmedIncomingBalanceUsecase =
           getUnconfirmedIncomingBalanceUsecase,
       _getAutoSwapSettingsUsecase = getAutoSwapSettingsUsecase,
       _getSwapLimitsUsecase = getSwapLimitsUsecase,
       _createChainSwapUsecase = createChainSwapUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _signLiquidTxUsecase = signLiquidTxUsecase,
       _broadcastLiquidTxUsecase = broadcastLiquidTxUsecase,
       super(const WalletState()) {
    on<WalletStarted>(_onStarted);
    on<WalletRefreshed>(_onRefreshed);
    on<WalletSyncStarted>(_onWalletSyncStarted);
    on<WalletSyncFinished>(_onWalletSyncFinished);
    on<StartTorInitialization>(_onStartTorInitialization);
    on<CheckAllWarnings>(_onCheckAllWarnings);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final RestartSwapWatcherUsecase _restartSwapWatcherUsecase;
  final InitializeTorUsecase _initializeTorUsecase;
  final CheckTorRequiredOnStartupUsecase
  _checkForTorInitializationOnStartupUsecase;
  final GetPrioritizedServerUsecase _getPrioritizedServerUsecase;
  final GetUnconfirmedIncomingBalanceUsecase
  _getUnconfirmedIncomingBalanceUsecase;
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  final CreateChainSwapUsecase _createChainSwapUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;

  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;

  @override
  Future<void> close() {
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    WalletStarted event,
    Emitter<WalletState> emit,
  ) async {
    try {
      // Don't sync the wallets here so the wallet list is shown immediately
      // and the sync is done after that
      final wallets = await _getWalletsUsecase.execute();
      final isSyncing = _checkWalletSyncingUsecase.execute();

      emit(
        WalletState(
          status: WalletStatus.success,
          wallets: wallets,
          isSyncing: isSyncing,
        ),
      );

      // Now that the wallets are loaded, we can sync them as done by the refresh
      add(const WalletRefreshed());

      // Now subscribe to syncs starts and finishes to update the UI with the syncing indicator
      await _startedSyncsSubscription
          ?.cancel(); // cancel any previous subscription
      await _finishedSyncsSubscription
          ?.cancel(); // cancel any previous subscription
      _startedSyncsSubscription = _watchStartedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(WalletSyncStarted(wallet)));
      _finishedSyncsSubscription = _watchFinishedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(WalletSyncFinished(wallet)));
    } catch (e) {
      emit(WalletState(status: WalletStatus.failure, error: e));
    }
  }

  Future<void> _onRefreshed(
    WalletRefreshed event,
    Emitter<WalletState> emit,
  ) async {
    try {
      emit(state.copyWith(isSyncing: true));

      final wallets = await _getWalletsUsecase.execute(sync: true);
      // int unconfirmedIncomingBalance = 0;
      // if (wallets.isNotEmpty) {
      //   final walletIds = wallets.map((w) => w.id).toList();
      //   unconfirmedIncomingBalance = await _getUnconfirmedIncomingBalanceUsecase
      //       .execute(walletIds: walletIds);
      //   emit(
      //     state.copyWith(
      //       unconfirmedIncomingBalance: unconfirmedIncomingBalance,
      //     ),
      //   );
      // }
      emit(
        state.copyWith(
          isSyncing: false,
          status: WalletStatus.success,
          wallets: wallets,
          error: null,
        ),
      );
      add(const CheckAllWarnings());
      // After the wallets are synced we also restart the swap watcher.
      // We do it after the syncing of the wallets to not wait for the
      // swap watcher to be restarted before the wallets are synced.
      await _restartSwapWatcherUsecase.execute();
    } catch (e) {
      emit(
        state.copyWith(
          isSyncing: false,
          status: WalletStatus.failure,
          error: e,
        ),
      );
    }
  }

  Future<void> _onWalletSyncStarted(
    WalletSyncStarted event,
    Emitter<WalletState> emit,
  ) async {
    // Do nothing for now, since we only want to show the syncing indicator
    // when the user itself refreshes the wallets.
    final wallets = await _getWalletsUsecase.execute();

    if (wallets.isNotEmpty) {
      final walletIds = wallets.map((w) => w.id).toList();
      final unconfirmedIncomingBalance =
          await _getUnconfirmedIncomingBalanceUsecase.execute(
            walletIds: walletIds,
          );
      emit(
        state.copyWith(unconfirmedIncomingBalance: unconfirmedIncomingBalance),
      );
    }
  }

  Future<void> _onWalletSyncFinished(
    WalletSyncFinished event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final wallets = await _getWalletsUsecase.execute();
      if (wallets.isNotEmpty) {
        final walletIds = wallets.map((w) => w.id).toList();
        final unconfirmedIncomingBalance =
            await _getUnconfirmedIncomingBalanceUsecase.execute(
              walletIds: walletIds,
            );
        emit(
          state.copyWith(
            unconfirmedIncomingBalance: unconfirmedIncomingBalance,
          ),
        );
      }
      emit(state.copyWith(status: WalletStatus.success, wallets: wallets));

      // Check if the synced wallet is the default liquid wallet
      if (event.wallet.isDefault && event.wallet.isLiquid) {
        await _executeAutoSwapIfNeeded(event.wallet);
      }
    } catch (e) {
      emit(state.copyWith(status: WalletStatus.failure, error: e));
    }
  }

  Future<void> _executeAutoSwapIfNeeded(Wallet liquidWallet) async {
    final autoSwapSettings = await _getAutoSwapSettingsUsecase.execute(
      isTestnet: liquidWallet.isTestnet,
    );
    final walletBalance = liquidWallet.balanceSat.toInt();

    if (autoSwapSettings.amountThresholdExceeded(walletBalance)) {
      // Get swap limits to ensure we can create a swap
      final (swapLimits, swapFees) = await _getSwapLimitsUsecase.execute(
        type: SwapType.liquidToBitcoin,
        isTestnet: liquidWallet.isTestnet,
      );

      if (walletBalance >= swapLimits.min && walletBalance <= swapLimits.max) {
        final defaultBitcoinWallet =
            state.wallets
                .where((w) => w.isDefault && w.network.isBitcoin)
                .firstOrNull;
        if (defaultBitcoinWallet != null) {
          final swap = await _createChainSwapUsecase.execute(
            bitcoinWalletId: defaultBitcoinWallet.id,
            liquidWalletId: liquidWallet.id,
            type: SwapType.liquidToBitcoin,
            amountSat: walletBalance,
          );
          final swapFeePercent = swap.getFeeAsPercentOfAmount();
          if (autoSwapSettings.allConditionsMet(
            walletBalance,
            swapFeePercent,
          )) {
            final pset = await _prepareLiquidSendUsecase.execute(
              walletId: liquidWallet.id,
              address: swap.paymentAddress,
              amountSat: swap.paymentAmount,
              networkFee: const NetworkFee.relative(0.1),
            );
            final signedPset = await _signLiquidTxUsecase.execute(
              walletId: liquidWallet.id,
              pset: pset,
            );
            await _broadcastLiquidTxUsecase.execute(signedPset);
          }
        }
      }
    }
  }

  Future<void> _onStartTorInitialization(
    StartTorInitialization event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(status: WalletStatus.loading));
    final isTorIniatizationEnabled =
        await _checkForTorInitializationOnStartupUsecase.execute();

    if (isTorIniatizationEnabled) {
      await _initializeTorUsecase.execute();
    }
  }

  Future<void> _onCheckAllWarnings(
    CheckAllWarnings event,
    Emitter<WalletState> emit,
  ) async {
    final defaultWallets = await _getWalletsUsecase.execute(onlyDefaults: true);
    if (defaultWallets.isEmpty) {
      emit(state.copyWith(warnings: const []));
      return;
    }

    // Run all checks in parallel
    final electrumWarnings = await _checkElectrumServers(defaultWallets);

    final warnings = [if (electrumWarnings != null) electrumWarnings];

    emit(state.copyWith(warnings: warnings));
  }

  Future<WalletWarning?> _checkElectrumServers(
    List<Wallet> defaultWallets,
  ) async {
    bool bitcoinServerDown = false;
    bool liquidServerDown = false;

    await Future.wait(
      defaultWallets.map((wallet) async {
        final electrumServer = await _getPrioritizedServerUsecase.execute(
          network: wallet.network,
        );

        if (electrumServer.status != ElectrumServerStatus.online) {
          if (wallet.isLiquid) {
            liquidServerDown = true;
          } else {
            bitcoinServerDown = true;
          }
        }
      }),
    );

    if (bitcoinServerDown || liquidServerDown) {
      final title = switch ((bitcoinServerDown, liquidServerDown)) {
        (true, true) => 'Bitcoin & Liquid electrum server failure',
        (true, false) => 'Bitcoin electrum server failure',
        (false, true) => 'Liquid electrum server failure',
        _ => '',
      };
      return WalletWarning(
        title: title,
        description: 'Click to configure electrum server settings',
        actionRoute: SettingsRoute.settings.name,
        type: WarningType.error,
      );
    }
    return null;
  }
}
