import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transfer_event.dart';
part 'transfer_state.dart';

part 'transfer_bloc.freezed.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  TransferBloc({
    required GetSettingsUsecase getSettingsUsecase,
    required GetWalletsUsecase getWalletsUsecase,
    required GetSwapLimitsUsecase getSwapLimitsUsecase,
    required GetNetworkFeesUsecase getNetworkFeesUsecase,
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required CalculateBitcoinAbsoluteFeesUsecase
    calculateBitcoinAbsoluteFeesUsecase,
    required CalculateLiquidAbsoluteFeesUsecase
    calculateLiquidAbsoluteFeesUsecase,
  }) : _getSettingsUsecase = getSettingsUsecase,
       _getWalletsUsecase = getWalletsUsecase,
       _getSwapLimitsUsecase = getSwapLimitsUsecase,
       _getNetworkFeesUsecase = getNetworkFeesUsecase,
       _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _calculateBitcoinAbsoluteFeesUsecase =
           calculateBitcoinAbsoluteFeesUsecase,
       _calculateLiquidAbsoluteFeesUsecase = calculateLiquidAbsoluteFeesUsecase,
       super(const TransferState()) {
    on<TransferStarted>(_onStarted);
    on<TransferWalletsChanged>(_onWalletsChanged);
    on<TransferSwapCreated>(_onSwapCreated);
  }

  final GetSettingsUsecase _getSettingsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  Future<void> _onStarted(
    TransferStarted event,
    Emitter<TransferState> emit,
  ) async {
    emit(state.copyWith(isStarting: true));
    try {
      final (settings, wallets, liquidNetworkFees, bitcoinNetworkFees) =
          await (
            _getSettingsUsecase.execute(),
            _getWalletsUsecase.execute(),
            _getNetworkFeesUsecase.execute(isLiquid: true),
            _getNetworkFeesUsecase.execute(isLiquid: false),
          ).wait;
      final defaultWallets =
          wallets.where((wallet) => wallet.isDefault).toList();
      final fromWallet =
          defaultWallets.isNotEmpty ? defaultWallets.first : null;
      final toWallet = defaultWallets.length > 1 ? defaultWallets[1] : null;
      // Set the bitcoin network fees and liquid network fees already here,
      //  since they are needed for the rest of the initialization steps, like
      //  calculating the max amount.
      emit(
        state.copyWith(
          bitcoinUnit: settings.bitcoinUnit,
          wallets: wallets,
          fromWallet: fromWallet,
          toWallet: toWallet,
          bitcoinNetworkFees: bitcoinNetworkFees,
          liquidNetworkFees: liquidNetworkFees,
        ),
      );

      final isTestnet = settings.environment == Environment.testnet;
      final (
        lbtcToBtcSwapLimitsAndFees,
        btcToLbtcSwapLimitsAndFees,
        maxAmountSat,
      ) = await (
            _getSwapLimitsUsecase.execute(
              type: SwapType.liquidToBitcoin,
              isTestnet: isTestnet,
            ),
            _getSwapLimitsUsecase.execute(
              type: SwapType.bitcoinToLiquid,
              isTestnet: isTestnet,
              updateLimitsAndFees: false, // chain fees are already updated
            ),
            fromWallet != null
                ? getMaxAmountSat(fromWallet)
                : Future.value(null),
          ).wait;

      emit(
        state.copyWith(
          maxAmountSat: maxAmountSat,
          lbtcToBtcSwapLimitsAndFees: lbtcToBtcSwapLimitsAndFees,
          btcToLbtcSwapLimitsAndFees: btcToLbtcSwapLimitsAndFees,
        ),
      );
    } catch (e) {
      emit(state.copyWith(startError: Exception(e.toString())));
    } finally {
      emit(state.copyWith(isStarting: false));
    }
  }

  Future<void> _onWalletsChanged(
    TransferWalletsChanged event,
    Emitter<TransferState> emit,
  ) async {
    Wallet newFromWallet = event.fromWallet;
    Wallet newToWallet = event.toWallet;

    if (newFromWallet.isLiquid == newToWallet.isLiquid) {
      // Ensure from and to wallets are of different types
      // If one wallet is changed, adjust the other accordingly
      final isFromWalletChanged = newFromWallet != state.fromWallet;
      if (isFromWalletChanged) {
        newToWallet =
            state.wallets
                .where((wallet) => wallet.isLiquid != newFromWallet.isLiquid)
                .firstOrNull!;
      } else {
        newFromWallet =
            state.wallets
                .where((wallet) => wallet.isLiquid != newToWallet.isLiquid)
                .firstOrNull!;
      }
    }

    emit(
      state.copyWith(
        fromWallet: newFromWallet,
        toWallet: newToWallet,
        // Since the from wallet is changed, there will be a new balance and thus a
        //  new max amount to calculate. Set to null while recalculating.
        maxAmountSat: null,
      ),
    );

    final maxAmountSat = await getMaxAmountSat(newFromWallet);
    emit(state.copyWith(maxAmountSat: maxAmountSat));
  }

  void _onSwapCreated(TransferSwapCreated event, Emitter<TransferState> emit) {}

  Future<int?> getMaxAmountSat(Wallet fromWallet) async {
    try {
      final networkFee =
          fromWallet.isLiquid
              ? state.liquidNetworkFees!.fastest
              : state.bitcoinNetworkFees!.fastest;

      // Create a dummy drain transaction to calculate the absolute fees
      int absoluteFees;
      if (!fromWallet.isLiquid) {
        // we cannot use a wallet address for this
        // the swap script address is larger than a wallet single sig (by ~12 vb)
        // this leads to a fee estimation error by 1 sat
        // additionally, we never sign this transaction
        const String dummySwapAddress =
            "bc1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskq9pj5n4";

        final dummyDrainTxInfo = await _prepareBitcoinSendUsecase.execute(
          walletId: fromWallet.id,
          address: dummySwapAddress,
          networkFee: networkFee,
          drain: true,
        );

        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: dummyDrainTxInfo.unsignedPsbt,
          feeRate: networkFee.value as double,
        );

        log.info("Absolute fees: $absoluteFees");
      } else {
        // we cannot use a wallet address for this
        // the swap script address is larger than a wallet single sig (by ~12 vb)
        // this leads to a fee estimation error by 1 sat
        // additionally, we never sign this transaction

        const String dummySwapAddress =
            "lq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0we046p4uqlt24";
        final dummyPset = await _prepareLiquidSendUsecase.execute(
          walletId: fromWallet.id,
          address: dummySwapAddress,
          networkFee: networkFee,
          drain: true,
        );

        absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: dummyPset,
        );
        log.info("Absolute fees: $absoluteFees");
      }

      final balanceSat = fromWallet.balanceSat.toInt();
      final maxAmountSat = balanceSat - absoluteFees;
      return maxAmountSat;
    } catch (e) {
      log.severe('Error getting max amount sat in transfer bloc: $e');
      return null;
    }
  }
}
