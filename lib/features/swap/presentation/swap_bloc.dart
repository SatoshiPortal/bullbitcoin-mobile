// ignore_for_file: unused_field

import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/swap/domain/create_chain_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/update_paid_chain_swap_usecase.dart';
import 'package:bb_mobile/features/swap/presentation/swap_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapCubit extends Cubit<SwapState> {
  SwapCubit({
    required GetSettingsUsecase getSettingsUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
    required GetNetworkFeesUsecase getNetworkFeesUsecase,
    required GetWalletUtxosUsecase getWalletUtxosUsecase,
    required GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase,
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required GetWalletsUsecase getWalletsUsecase,
    required GetWalletUsecase getWalletUsecase,
    required GetSwapLimitsUsecase getSwapLimitsUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required SignBitcoinTxUsecase signBitcoinTxUsecase,
    required SignLiquidTxUsecase signLiquidTxUsecase,
    required BroadcastBitcoinTransactionUsecase broadcastBitcoinTxUsecase,
    required BroadcastLiquidTransactionUsecase broadcastLiquidTxUsecase,
    required CalculateBitcoinAbsoluteFeesUsecase
    calculateBitcoinAbsoluteFeesUsecase,
    required CalculateLiquidAbsoluteFeesUsecase
    calculateLiquidAbsoluteFeesUsecase,
    required CreateChainSwapUsecase createChainSwapUsecase,
    required UpdatePaidChainSwapUsecase updatePaidChainSwapUsecase,
  }) : _getSettingsUsecase = getSettingsUsecase,
       _convertSatsToCurrencyAmountUsecase = convertSatsToCurrencyAmountUsecase,
       _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
       _getNetworkFeesUsecase = getNetworkFeesUsecase,
       _getWalletUtxosUsecase = getWalletUtxosUsecase,
       _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _signLiquidTxUsecase = signLiquidTxUsecase,
       _signBitcoinTxUsecase = signBitcoinTxUsecase,
       _broadcastLiquidTxUsecase = broadcastLiquidTxUsecase,
       _broadcastBitcoinTxUsecase = broadcastBitcoinTxUsecase,
       _getWalletsUsecase = getWalletsUsecase,
       _getWalletUsecase = getWalletUsecase,
       _getSwapLimitsUsecase = getSwapLimitsUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _calculateBitcoinAbsoluteFeesUsecase =
           calculateBitcoinAbsoluteFeesUsecase,
       _calculateLiquidAbsoluteFeesUsecase = calculateLiquidAbsoluteFeesUsecase,
       _createChainSwapUsecase = createChainSwapUsecase,
       _updatePaidChainSwapUsecase = updatePaidChainSwapUsecase,
       super(const SwapState());

  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetWalletUsecase _getWalletUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CreateChainSwapUsecase _createChainSwapUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTxUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  final WatchSwapUsecase _watchSwapUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final UpdatePaidChainSwapUsecase _updatePaidChainSwapUsecase;

  StreamSubscription<Swap>? _swapSubscription;
  StreamSubscription<Wallet>? _selectedWalletSyncingSubscription;

  @override
  Future<void> close() async {
    await Future.wait([
      _swapSubscription?.cancel() ?? Future.value(),
      _selectedWalletSyncingSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  void clearAllExceptions() {
    emit(
      state.copyWith(
        insufficientBalanceException: null,
        swapCreationException: null,
        swapLimitsException: null,
        invalidBitcoinStringException: null,
        buildTransactionException: null,
        confirmTransactionException: null,
      ),
    );
  }

  Future<void> init() async {
    final wallets = await _getWalletsUsecase.execute();
    final settings = await _getSettingsUsecase.execute();
    final bitcoinUnit = settings.bitcoinUnit;

    final liquidWallets = wallets.where((w) => w.isLiquid).toList();
    final bitcoinWallets = wallets.where((w) => !w.isLiquid).toList();
    final defaultBitcoinWallet = bitcoinWallets.firstWhere(
      (w) => w.isDefault,
      orElse: () => bitcoinWallets.first,
    );
    emit(
      state.copyWith(
        fromWallets: bitcoinWallets,
        toWallets: liquidWallets,
        fromWalletId: defaultBitcoinWallet.id,
        toWalletId: liquidWallets.first.id,
        loadingWallets: false,
        bitcoinUnit: bitcoinUnit,
      ),
    );

    await loadSwapLimits();
  }

  Future<void> loadSwapLimits() async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final isTestnet = settings.environment == Environment.testnet;
      final lbtcToBtcswapLimits = await _getSwapLimitsUsecase.execute(
        type: SwapType.liquidToBitcoin,
        isTestnet: isTestnet,
      );
      emit(state.copyWith(lbtcToBtcSwapLimitsAndFees: lbtcToBtcswapLimits));
      final btcToLbtcSwapLimits = await _getSwapLimitsUsecase.execute(
        type: SwapType.bitcoinToLiquid,
        isTestnet: isTestnet,
      );
      emit(state.copyWith(btcToLbtcSwapLimitsAndFees: btcToLbtcSwapLimits));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> loadFees() async {
    if (state.fromWallet == null) return;
    try {
      final fees = await _getNetworkFeesUsecase.execute(
        network: state.fromWallet!.network,
      );
      emit(
        state.copyWith(
          feesList: fees,
          customFee: null,
          selectedFee: fees.fastest,
          selectedFeeOption: FeeSelection.fastest,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void switchFromAndToWallets() {
    emit(
      state.copyWith(
        fromWallets: state.toWallets,
        toWallets: state.fromWallets,
        fromWalletNetwork: state.toWalletNetwork,
        toWalletNetwork: state.fromWalletNetwork,
        selectedFromCurrencyCode: state.selectedToCurrencyCode,
        selectedToCurrencyCode: state.selectedFromCurrencyCode,
        fromWalletId: state.toWalletId,
        toWalletId: state.fromWalletId,
      ),
    );
  }

  void updateSelectedFromWallet(String walletId) {
    emit(state.copyWith(fromWalletId: walletId));
  }

  void updateSelectedToWallet(String walletId) {
    emit(state.copyWith(toWalletId: walletId));
  }

  void backClicked() {
    if (state.step == SwapPageStep.amount) {
      emit(state.copyWith(step: SwapPageStep.amount));
    } else if (state.step == SwapPageStep.confirm) {
      emit(state.copyWith(step: SwapPageStep.amount));
    }
  }

  void amountChanged(String amount) {
    try {
      clearAllExceptions();
      String validatedAmount;

      if (amount.isEmpty) {
        validatedAmount = amount;
      } else if (state.bitcoinUnit == BitcoinUnit.btc) {
        final amountBtc = double.tryParse(amount);
        final decimals =
            amount.contains('.') ? amount.split('.').last.length : 0;
        final isDecimalPoint = amount == '.';

        validatedAmount =
            (amountBtc == null && !isDecimalPoint) ||
                    decimals > BitcoinUnit.btc.decimals
                ? state.fromAmount
                : amount;
      } else {
        final satoshis = BigInt.tryParse(amount);
        final hasDecimals = amount.contains('.');

        if (satoshis != null && !hasDecimals) {
          validatedAmount = satoshis.toString();
        } else {
          validatedAmount = state.fromAmount;
        }
      }
      emit(state.copyWith(fromAmount: validatedAmount));
      emit(state.copyWith(toAmount: state.calculateToAmount));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> continueWithAmountsClicked() async {
    try {
      emit(state.copyWith(amountConfirmedClicked: true));
      final bitcoinWalletId =
          state.fromWalletNetwork == WalletNetwork.bitcoin
              ? state.fromWalletId
              : state.toWalletId;

      final liquidWalletId =
          state.fromWalletNetwork == WalletNetwork.liquid
              ? state.fromWalletId
              : state.toWalletId;
      final swapType =
          state.fromWalletNetwork == WalletNetwork.bitcoin
              ? SwapType.bitcoinToLiquid
              : SwapType.liquidToBitcoin;
      emit(state.copyWith(creatingSwap: true));
      final swap = await _createChainSwapUsecase.execute(
        bitcoinWalletId: bitcoinWalletId!,
        liquidWalletId: liquidWalletId!,
        type: swapType,
        amountSat: state.fromAmountSat,
      );

      _watchChainSwap(swap.id);
      emit(
        state.copyWith(
          amountConfirmedClicked: false,
          confirmedFromAmountSat: state.fromAmountSat,
          step: SwapPageStep.confirm,
          swap: swap,
          creatingSwap: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          creatingSwap: false,
          swapCreationException: SwapCreationException(e.toString()),
          amountConfirmedClicked: false,
        ),
      );
    }
  }

  Future<void> confirmSwapClicked() async {
    try {
      final swap = state.swap;
      if (swap == null) return;

      final bitcoinWalletId =
          state.fromWalletNetwork == WalletNetwork.bitcoin
              ? state.fromWalletId
              : state.toWalletId;
      final liquidWalletId =
          state.fromWalletNetwork == WalletNetwork.liquid
              ? state.fromWalletId
              : state.toWalletId;

      final bitcoinWallet = await _getWalletUsecase.execute(bitcoinWalletId!);
      final liquidWallet = await _getWalletUsecase.execute(liquidWalletId!);

      if (state.fromWalletNetwork == WalletNetwork.bitcoin) {
        final psbt = await _prepareBitcoinSendUsecase.execute(
          walletId: bitcoinWalletId,
          address: swap.paymentAddress,
          amountSat: swap.paymentAmount,
          networkFee: NetworkFee.absolute(swap.fees!.claimFee!),
        );
        final signedPsbt = await _signBitcoinTxUsecase.execute(
          walletId: bitcoinWalletId,
          psbt: psbt,
        );
        final txid = await _broadcastBitcoinTxUsecase.execute(signedPsbt);
        await _updatePaidChainSwapUsecase.execute(
          txid: txid,
          swapId: swap.id,
          network: bitcoinWallet.network,
        );
      } else {
        final psbt = await _prepareLiquidSendUsecase.execute(
          walletId: liquidWalletId,
          address: swap.paymentAddress,
          amountSat: swap.paymentAmount,
          networkFee: NetworkFee.absolute(swap.fees!.claimFee!),
        );
        final signedPsbt = await _signLiquidTxUsecase.execute(
          walletId: bitcoinWalletId,
          psbt: psbt,
        );
        final txid = await _broadcastLiquidTxUsecase.execute(signedPsbt);
        await _updatePaidChainSwapUsecase.execute(
          txid: txid,
          swapId: swap.id,
          network: liquidWallet.network,
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            e.toString(),
          ),
        ),
      );
    }
  }

  // ignore: unused_element
  void _watchChainSwap(String swapId) {
    // Cancel the previous subscription if it exists
    _swapSubscription?.cancel();
    _swapSubscription = _watchSwapUsecase.execute(swapId).listen((updatedSwap) {
      debugPrint(
        '[SwapCubit] Watched swap ${updatedSwap.id} updated: ${updatedSwap.status}',
      );
      if (updatedSwap is ChainSwap) {
        emit(state.copyWith(swap: updatedSwap));
        if (updatedSwap.status == SwapStatus.completed) {
          // Start syncing the wallet now that the swap is completed
          _getWalletUsecase.execute(state.fromWalletId!, sync: true);
          _getWalletUsecase.execute(state.toWalletId!, sync: true);

          emit(state.copyWith(step: SwapPageStep.success));
        }
      }
    });
  }
}
