import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_paid_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
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
    required CreateChainSwapUsecase createChainSwapUsecase,
    required CreateChainSwapToExternalUsecase createChainSwapToExternalUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    required GetWalletUsecase getWalletUsecase,
    required SignBitcoinTxUsecase signBitcoinTxUsecase,
    required SignLiquidTxUsecase signLiquidTxUsecase,
    required BroadcastBitcoinTransactionUsecase broadcastBitcoinTxUsecase,
    required BroadcastLiquidTransactionUsecase broadcastLiquidTxUsecase,
    required UpdatePaidChainSwapUsecase updatePaidChainSwapUsecase,
    required UpdateSendSwapLockupFeesUsecase updateSendSwapLockupFeesUsecase,
    required VerifyChainSwapAmountSendUsecase verifyChainSwapAmountSendUsecase,
    required DetectBitcoinStringUsecase detectBitcoinStringUsecase,
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
    required GetWalletUtxosUsecase getWalletUtxosUsecase,
  }) : _getSettingsUsecase = getSettingsUsecase,
       _getWalletsUsecase = getWalletsUsecase,
       _getSwapLimitsUsecase = getSwapLimitsUsecase,
       _getNetworkFeesUsecase = getNetworkFeesUsecase,
       _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
       _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
       _calculateBitcoinAbsoluteFeesUsecase =
           calculateBitcoinAbsoluteFeesUsecase,
       _calculateLiquidAbsoluteFeesUsecase = calculateLiquidAbsoluteFeesUsecase,
       _createChainSwapUsecase = createChainSwapUsecase,
       _createChainSwapToExternalUsecase = createChainSwapToExternalUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _getWalletUsecase = getWalletUsecase,
       _signBitcoinTxUsecase = signBitcoinTxUsecase,
       _signLiquidTxUsecase = signLiquidTxUsecase,
       _broadcastBitcoinTxUsecase = broadcastBitcoinTxUsecase,
       _broadcastLiquidTxUsecase = broadcastLiquidTxUsecase,
       _updatePaidChainSwapUsecase = updatePaidChainSwapUsecase,
       _updateSendSwapLockupFeesUsecase = updateSendSwapLockupFeesUsecase,
       _verifyChainSwapAmountSendUsecase = verifyChainSwapAmountSendUsecase,
       _detectBitcoinStringUsecase = detectBitcoinStringUsecase,
       _getReceiveAddressUsecase = getReceiveAddressUsecase,
       _getWalletUtxosUsecase = getWalletUtxosUsecase,
       super(const TransferState()) {
    on<TransferStarted>(_onStarted);
    on<TransferWalletsChanged>(_onWalletsChanged);
    on<TransferAmountChanged>(_onAmountChanged);
    on<TransferSwapCreated>(_onSwapCreated);
    on<TransferConfirmed>(_onConfirmed);
    on<TransferSendToExternalToggled>(_onSendToExternalToggled);
    on<TransferExternalAddressChanged>(_onExternalAddressChanged);
    on<TransferReceiveExactAmountToggled>(_onReceiveExactAmountToggled);
    on<TransferReplaceByFeeChanged>(_onReplaceByFeeChanged);
    on<TransferUtxoSelected>(_onUtxoSelected);
    on<TransferLoadUtxos>(_onLoadUtxos);
    on<TransferFeeOptionSelected>(_onFeeOptionSelected);
    on<TransferCustomFeeChanged>(_onCustomFeeChanged);
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
  final CreateChainSwapUsecase _createChainSwapUsecase;
  final CreateChainSwapToExternalUsecase _createChainSwapToExternalUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  StreamSubscription<Swap>? _swapSubscription;
  final GetWalletUsecase _getWalletUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;
  final UpdatePaidChainSwapUsecase _updatePaidChainSwapUsecase;
  final UpdateSendSwapLockupFeesUsecase _updateSendSwapLockupFeesUsecase;
  final VerifyChainSwapAmountSendUsecase _verifyChainSwapAmountSendUsecase;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;

  @override
  Future<void> close() async {
    await Future.wait([_swapSubscription?.cancel() ?? Future.value()]);
    return super.close();
  }

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
      final liquidWallets =
          wallets
              .where(
                (wallet) =>
                    wallet.isLiquid &&
                    (wallet.isDefault || wallet.signsLocally),
              )
              .toList();
      final bitcoinWallets =
          wallets
              .where((wallet) => !wallet.isLiquid && wallet.signsLocally)
              .toList();

      final fromWallet =
          liquidWallets.isNotEmpty
              ? (liquidWallets
                      .where((wallet) => wallet.isDefault)
                      .firstOrNull ??
                  liquidWallets.first)
              : null;
      final toWallet =
          bitcoinWallets.isNotEmpty
              ? (bitcoinWallets
                      .where((wallet) => wallet.isDefault)
                      .firstOrNull ??
                  bitcoinWallets.first)
              : null;
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
          fiatCurrencyCode: settings.currencyCode,
          exchangeRate: 0.0,
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

    if (newFromWallet.isWatchOnly) {
      return;
    }

    if (!newFromWallet.signsLocally) {
      return;
    }

    if (newFromWallet.isLiquid == newToWallet.isLiquid) {
      if (newFromWallet.isLiquid) {
        return;
      }
    } else {
      final isFromWalletChanged = newFromWallet != state.fromWallet;
      if (isFromWalletChanged && newFromWallet.isLiquid) {
        final bitcoinWallets = state.wallets.where((w) => !w.isLiquid).toList();
        if (bitcoinWallets.isNotEmpty) {
          newToWallet = bitcoinWallets.first;
        }
      } else if (!isFromWalletChanged && newToWallet.isLiquid) {
        final bitcoinWallets = state.wallets.where((w) => !w.isLiquid && w.signsLocally).toList();
        if (bitcoinWallets.isNotEmpty) {
          newFromWallet = bitcoinWallets.first;
        }
      }
    }

    final wasFromWalletChanged = newFromWallet != state.fromWallet;
    final hadExternalAddress = state.externalAddress.isNotEmpty;
    final externalAddressToRevalidate = state.externalAddress;
    final sendToExternal = state.sendToExternal;

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

    if (wasFromWalletChanged && sendToExternal && hadExternalAddress) {
      add(TransferEvent.externalAddressChanged(externalAddressToRevalidate));
    }
  }

  Future<void> _onAmountChanged(
    TransferAmountChanged event,
    Emitter<TransferState> emit,
  ) async {
    emit(state.copyWith(amount: event.amount));
  }

  Future<void> _onSwapCreated(
    TransferSwapCreated event,
    Emitter<TransferState> emit,
  ) async {
    emit(
      state.copyWith(
        swap: null,
        signedPsbt: '',
        bitcoinAbsoluteFeesSat: null,
        liquidAbsoluteFeesSat: null,
        isCreatingSwap: true,
        continueClicked: true,
        swapCreationException: null,
      ),
    );
    try {
      final inputAmountSat =
          state.bitcoinUnit == BitcoinUnit.sats
              ? int.parse(event.amount)
              : ConvertAmount.btcToSats(double.parse(event.amount));

      int paymentAmountSat = inputAmountSat;
      if (state.receiveExactAmount && !state.isSameChainTransfer) {
        final swapFees = state.swapFees;
        if (swapFees == null) {
          emit(
            state.copyWith(
              swapCreationException: SwapCreationException(
                'Swap fees not loaded',
              ),
            ),
          );
          return;
        }
        paymentAmountSat = swapFees.calculateSwapAmountFromReceivableAmount(
          inputAmountSat,
        );
      }
      // For max send, paymentAmountSat = inputAmountSat = maxAmountSat
      // (balance - estimatedFees), which is what we want to pass to newSwap
      final isMaxSend =
          state.maxAmountSat != null && inputAmountSat == state.maxAmountSat;

      ChainSwap swap;
      String signedPsbt;
      int? bitcoinAbsoluteFeesSat;
      int? liquidAbsoluteFeesSat;

      if (state.sendToExternal) {
        if (state.externalAddress.isEmpty) {
          emit(
            state.copyWith(
              swapCreationException: SwapCreationException(
                'Enter an external address',
              ),
            ),
          );
          return;
        }

        final swapType =
            state.fromWallet!.isLiquid
                ? SwapType.liquidToBitcoin
                : SwapType.bitcoinToLiquid;

        swap = await _createChainSwapToExternalUsecase.execute(
          sendWalletId: state.fromWallet!.id,
          receiveAddress: state.externalAddress,
          type: swapType,
          amountSat: paymentAmountSat,
        );

        if (state.fromWallet!.isLiquid) {
          final liquidWalletId = state.fromWallet!.id;
          final psbt = await _prepareLiquidSendUsecase.execute(
            walletId: liquidWalletId,
            address: swap.paymentAddress,
            amountSat: isMaxSend ? null : swap.paymentAmount,
            networkFee: state.liquidNetworkFees!.fastest,
            drain: isMaxSend,
          );

          await _verifyChainSwapAmountSendUsecase.execute(
            psbtOrPset: psbt,
            swap: swap,
            walletId: liquidWalletId,
          );

          signedPsbt = await _signLiquidTxUsecase.execute(
            walletId: liquidWalletId,
            pset: psbt,
          );
          liquidAbsoluteFeesSat = await _calculateLiquidAbsoluteFeesUsecase
              .execute(pset: signedPsbt);
          final settings = await _getSettingsUsecase.execute();
          final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
            swapId: swap.id,
            network: Network.fromEnvironment(
              isTestnet: settings.environment == Environment.testnet,
              isLiquid: true,
            ),
            lockupFees: liquidAbsoluteFeesSat,
          );
          swap = updatedSwap as ChainSwap;
          emit(
            state.copyWith(
              swap: swap,
              signedPsbt: signedPsbt,
              liquidAbsoluteFeesSat: liquidAbsoluteFeesSat,
            ),
          );
        } else {
        final bitcoinWalletId = state.fromWallet!.id;
        final selectedFee = state.selectedFee ?? state.bitcoinNetworkFees!.fastest;
        final unsignedPsbtAndTxSize = await _prepareBitcoinSendUsecase
              .execute(
                walletId: bitcoinWalletId,
                address: swap.paymentAddress,
                amountSat: isMaxSend ? null : swap.paymentAmount,
                networkFee: selectedFee,
                drain: isMaxSend,
                selectedInputs: state.selectedUtxos.isNotEmpty ? state.selectedUtxos : null,
                replaceByFee: state.replaceByFee,
              );

          await _verifyChainSwapAmountSendUsecase.execute(
            psbtOrPset: unsignedPsbtAndTxSize.unsignedPsbt,
            swap: swap,
            walletId: bitcoinWalletId,
          );

          final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
            walletId: bitcoinWalletId,
            psbt: unsignedPsbtAndTxSize.unsignedPsbt,
          );

          signedPsbt = signedPsbtAndTxSize.signedPsbt;
          bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase
              .execute(
                psbt: signedPsbtAndTxSize.signedPsbt,
                feeRate: selectedFee.value as double,
              );
          final bitcoinTxSize = signedPsbtAndTxSize.txSize;
          final settings = await _getSettingsUsecase.execute();
          final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
            swapId: swap.id,
            network: Network.fromEnvironment(
              isTestnet: settings.environment == Environment.testnet,
              isLiquid: false,
            ),
            lockupFees: bitcoinAbsoluteFeesSat,
          );
          swap = updatedSwap as ChainSwap;
          emit(
            state.copyWith(
              swap: swap,
              signedPsbt: signedPsbt,
              bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
              bitcoinTxSize: bitcoinTxSize,
            ),
          );
        }
      } else if (state.fromWallet?.isLiquid == false &&
          state.toWallet?.isLiquid == true) {
        final bitcoinWalletId = state.fromWallet!.id;
        swap = await _createChainSwapUsecase.execute(
          bitcoinWalletId: bitcoinWalletId,
          liquidWalletId: state.toWallet!.id,
          type: SwapType.bitcoinToLiquid,
          amountSat: paymentAmountSat,
        );
        final selectedFee = state.selectedFee ?? state.bitcoinNetworkFees!.fastest;
        final unsignedPsbtAndTxSize = await _prepareBitcoinSendUsecase.execute(
          walletId: bitcoinWalletId,
          address: swap.paymentAddress,
          amountSat: isMaxSend ? null : swap.paymentAmount,
          networkFee: selectedFee,
          drain: isMaxSend,
          selectedInputs: state.selectedUtxos.isNotEmpty ? state.selectedUtxos : null,
          replaceByFee: state.replaceByFee,
        );

        await _verifyChainSwapAmountSendUsecase.execute(
          psbtOrPset: unsignedPsbtAndTxSize.unsignedPsbt,
          swap: swap,
          walletId: bitcoinWalletId,
        );

        final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
          walletId: bitcoinWalletId,
          psbt: unsignedPsbtAndTxSize.unsignedPsbt,
        );

        signedPsbt = signedPsbtAndTxSize.signedPsbt;
        bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase
            .execute(
              psbt: signedPsbtAndTxSize.signedPsbt,
              feeRate: selectedFee.value as double,
            );
        final bitcoinTxSize = signedPsbtAndTxSize.txSize;
        final settings = await _getSettingsUsecase.execute();
        final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
          swapId: swap.id,
          network: Network.fromEnvironment(
            isTestnet: settings.environment == Environment.testnet,
            isLiquid: false,
          ),
          lockupFees: bitcoinAbsoluteFeesSat,
        );
        swap = updatedSwap as ChainSwap;
        emit(
          state.copyWith(
            swap: swap,
            signedPsbt: signedPsbt,
            bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
            bitcoinTxSize: bitcoinTxSize,
          ),
        );
      } else if (state.fromWallet?.isLiquid == true &&
          state.toWallet?.isLiquid == false) {
        final liquidWalletId = state.fromWallet!.id;
        swap = await _createChainSwapUsecase.execute(
          bitcoinWalletId: state.toWallet!.id,
          liquidWalletId: liquidWalletId,
          type: SwapType.liquidToBitcoin,
          amountSat: paymentAmountSat,
        );
        final psbt = await _prepareLiquidSendUsecase.execute(
          walletId: liquidWalletId,
          address: swap.paymentAddress,
          amountSat: isMaxSend ? null : swap.paymentAmount,
          networkFee: state.liquidNetworkFees!.fastest,
          drain: isMaxSend,
        );

        await _verifyChainSwapAmountSendUsecase.execute(
          psbtOrPset: psbt,
          swap: swap,
          walletId: liquidWalletId,
        );

        signedPsbt = await _signLiquidTxUsecase.execute(
          walletId: liquidWalletId,
          pset: psbt,
        );
        liquidAbsoluteFeesSat = await _calculateLiquidAbsoluteFeesUsecase
            .execute(pset: signedPsbt);
        final settings = await _getSettingsUsecase.execute();
        final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
          swapId: swap.id,
          network: Network.fromEnvironment(
            isTestnet: settings.environment == Environment.testnet,
            isLiquid: true,
          ),
          lockupFees: liquidAbsoluteFeesSat,
        );
        swap = updatedSwap as ChainSwap;
        emit(
          state.copyWith(
            swap: swap,
            signedPsbt: signedPsbt,
            liquidAbsoluteFeesSat: liquidAbsoluteFeesSat,
          ),
        );
      } else if (state.isSameChainTransfer) {
        final bitcoinWalletId = state.fromWallet!.id;
        String receiveAddress = state.receiveAddress ?? '';
        if (receiveAddress.isEmpty && state.toWallet != null) {
          try {
            final address = await _getReceiveAddressUsecase.execute(
              walletId: state.toWallet!.id,
            );
            receiveAddress = address.address;
          } catch (e) {
            emit(
              state.copyWith(
                swapCreationException: SwapCreationException(
                  'Failed to get receive address: $e',
                ),
              ),
            );
            return;
          }
        }
        if (receiveAddress.isEmpty) {
          emit(
            state.copyWith(
              swapCreationException: SwapCreationException(
                'Receive address not available',
              ),
            ),
          );
          return;
        }

        final selectedFee = state.selectedFee ?? state.bitcoinNetworkFees!.fastest;
        final unsignedPsbtAndTxSize = await _prepareBitcoinSendUsecase.execute(
          walletId: bitcoinWalletId,
          address: receiveAddress,
          amountSat: isMaxSend ? null : paymentAmountSat,
          networkFee: selectedFee,
          drain: isMaxSend,
          selectedInputs: state.selectedUtxos.isNotEmpty ? state.selectedUtxos : null,
          replaceByFee: state.replaceByFee,
        );

        final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
          walletId: bitcoinWalletId,
          psbt: unsignedPsbtAndTxSize.unsignedPsbt,
        );

        signedPsbt = signedPsbtAndTxSize.signedPsbt;
        bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: signedPsbtAndTxSize.signedPsbt,
          feeRate: selectedFee.value as double,
        );
        final bitcoinTxSize = signedPsbtAndTxSize.txSize;

        emit(
          state.copyWith(
            signedPsbt: signedPsbt,
            bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
            bitcoinTxSize: bitcoinTxSize,
            receiveAddress: receiveAddress,
            amount: event.amount,
          ),
        );
        return;
      } else {
        throw SwapCreationException(
          'From and To wallets must be of different types',
        );
      }
      _watchChainSwap(swap.id);
      emit(
        state.copyWith(
          swap: swap,
          signedPsbt: signedPsbt,
          bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
          liquidAbsoluteFeesSat: liquidAbsoluteFeesSat,
          amount: event.amount,
        ),
      );
    } catch (e) {
      final errorMessage =
          _isInsufficientFundsException(e)
              ? 'Insufficient Balance To Cover Fees And Amount'
              : e.toString();
      emit(
        state.copyWith(
          swapCreationException: SwapCreationException(errorMessage),
        ),
      );
    } finally {
      emit(state.copyWith(isCreatingSwap: false, continueClicked: false));
    }
  }

  Future<void> _onSendToExternalToggled(
    TransferSendToExternalToggled event,
    Emitter<TransferState> emit,
  ) async {
    emit(
      state.copyWith(
        sendToExternal: event.enabled,
        externalAddress: event.enabled ? state.externalAddress : '',
        externalAddressError: event.enabled ? null : null,
        receiveExactAmount: event.enabled,
      ),
    );
  }

  Future<void> _onExternalAddressChanged(
    TransferExternalAddressChanged event,
    Emitter<TransferState> emit,
  ) async {
    if (event.address.isEmpty) {
      emit(state.copyWith(externalAddress: '', externalAddressError: null));
      return;
    }

    try {
      final sanitizedText = event.address.trim().replaceAll(
        RegExp(r'^["\"]+|["\"]+$'),
        '',
      );

      final fromWallet = state.fromWallet;
      if (fromWallet == null) {
        emit(
          state.copyWith(
            externalAddress: sanitizedText,
            externalAddressError: 'Please select a wallet first',
          ),
        );
        return;
      }

      PaymentRequest paymentRequest;
      try {
        paymentRequest = await _detectBitcoinStringUsecase.execute(
          data: sanitizedText,
        );
      } catch (e) {
        final errorMessage =
            fromWallet.isLiquid == true
                ? 'Please enter a valid Bitcoin address'
                : 'Please enter a valid Liquid address';
        emit(
          state.copyWith(
            externalAddress: sanitizedText,
            externalAddressError: errorMessage,
          ),
        );
        return;
      }

      try {
        String address = '';
        int? bip21AmountSat;

        if (paymentRequest.isBip21) {
          final bip21 = paymentRequest as Bip21PaymentRequest;
          address = bip21.address;
          bip21AmountSat = bip21.amountSat;

          if (fromWallet.isLiquid) {
            if (!bip21.network.isBitcoin) {
              emit(
                state.copyWith(
                  externalAddress: sanitizedText,
                  externalAddressError: 'Please enter a valid Bitcoin address',
                ),
              );
              return;
            }
          } else {
            if (!bip21.network.isLiquid) {
              emit(
                state.copyWith(
                  externalAddress: sanitizedText,
                  externalAddressError: 'Please enter a valid Liquid address',
                ),
              );
              return;
            }
          }
        } else {
          if (fromWallet.isLiquid) {
            if (!paymentRequest.isBitcoinAddress) {
              emit(
                state.copyWith(
                  externalAddress: sanitizedText,
                  externalAddressError: 'Please enter a valid Bitcoin address',
                ),
              );
              return;
            }
            final bitcoinAddress = paymentRequest as BitcoinPaymentRequest;
            address = bitcoinAddress.address;
          } else {
            if (!paymentRequest.isLiquidAddress) {
              emit(
                state.copyWith(
                  externalAddress: sanitizedText,
                  externalAddressError: 'Please enter a valid Liquid address',
                ),
              );
              return;
            }
            final liquidAddress = paymentRequest as LiquidPaymentRequest;
            address = liquidAddress.address;
          }
        }

        String? bip21AmountText;
        if (bip21AmountSat != null) {
          try {
            bip21AmountText =
                state.bitcoinUnit == BitcoinUnit.sats
                    ? bip21AmountSat.toString()
                    : ConvertAmount.satsToBtc(bip21AmountSat).toString();
          } catch (e) {
            bip21AmountText = null;
          }
        }

        emit(
          state.copyWith(
            externalAddress: address,
            externalAddressError: null,
            receiveExactAmount:
                // ignore: avoid_bool_literals_in_conditional_expressions
                bip21AmountSat != null ? true : state.receiveExactAmount,
            amount: bip21AmountText ?? state.amount,
          ),
        );
      } catch (e) {
        final errorMessage =
            fromWallet.isLiquid == true
                ? 'Please enter a valid Bitcoin address'
                : 'Please enter a valid Liquid address';
        emit(
          state.copyWith(
            externalAddress: sanitizedText,
            externalAddressError: errorMessage,
          ),
        );
        return;
      }
    } catch (e) {
      final sanitizedText = event.address.trim().replaceAll(
        RegExp(r'^["\"]+|["\"]+$'),
        '',
      );
      final fromWallet = state.fromWallet;
      final errorMessage =
          fromWallet?.isLiquid == true
              ? 'Please enter a valid Bitcoin address'
              : 'Please enter a valid Liquid address';
      emit(
        state.copyWith(
          externalAddress: sanitizedText,
          externalAddressError: errorMessage,
        ),
      );
    }
  }

  Future<void> _onReceiveExactAmountToggled(
    TransferReceiveExactAmountToggled event,
    Emitter<TransferState> emit,
  ) async {
    emit(state.copyWith(receiveExactAmount: event.enabled));
  }

  Future<void> _onReplaceByFeeChanged(
    TransferReplaceByFeeChanged event,
    Emitter<TransferState> emit,
  ) async {
    emit(state.copyWith(replaceByFee: event.replaceByFee));
    await _rebuildTransaction(emit);
  }

  Future<void> _onUtxoSelected(
    TransferUtxoSelected event,
    Emitter<TransferState> emit,
  ) async {
    final selectedUtxos = List.of(state.selectedUtxos);
    if (selectedUtxos.contains(event.utxo)) {
      selectedUtxos.remove(event.utxo);
    } else {
      selectedUtxos.add(event.utxo);
    }
    emit(state.copyWith(selectedUtxos: selectedUtxos));
    await _rebuildTransaction(emit);
  }

  Future<void> _onLoadUtxos(
    TransferLoadUtxos event,
    Emitter<TransferState> emit,
  ) async {
    if (state.fromWallet == null) return;
    try {
      final utxos = await _getWalletUtxosUsecase.execute(
        walletId: state.fromWallet!.id,
      );
      emit(state.copyWith(utxos: utxos));
    } catch (e) {
      log.severe('Error loading UTXOs: $e');
    }
  }

  Future<void> _onFeeOptionSelected(
    TransferFeeOptionSelected event,
    Emitter<TransferState> emit,
  ) async {
    final updatedState = state.copyWith(selectedFeeOption: event.feeSelection);
    emit(updatedState);
    await _rebuildTransactionWithState(emit, updatedState);
  }

  Future<void> _onCustomFeeChanged(
    TransferCustomFeeChanged event,
    Emitter<TransferState> emit,
  ) async {
    final updatedState = state.copyWith(
      customFee: event.fee,
      selectedFeeOption: FeeSelection.custom,
    );
    emit(updatedState);
    await _rebuildTransactionWithState(emit, updatedState);
  }

  Future<void> _rebuildTransactionWithState(
    Emitter<TransferState> emit,
    TransferState stateToUse,
  ) async {
    if (stateToUse.fromWallet == null) return;
    if (!stateToUse.shouldShowAdvancedOptions) return;
    if (stateToUse.signedPsbt.isEmpty && stateToUse.swap == null && !stateToUse.isSameChainTransfer) return;

    try {
      final fromWallet = stateToUse.fromWallet!;
      if (fromWallet.isLiquid) return;

      if (stateToUse.isSameChainTransfer) {
        final receiveAddress = stateToUse.receiveAddress;
        if (receiveAddress == null || receiveAddress.isEmpty) return;

        final inputAmountSat = stateToUse.inputAmountSat;
        final isMaxSend = stateToUse.maxAmountSat != null && inputAmountSat == stateToUse.maxAmountSat;
        final selectedFee = stateToUse.selectedFee ?? stateToUse.bitcoinNetworkFees!.fastest;

        final unsignedPsbtAndTxSize = await _prepareBitcoinSendUsecase.execute(
          walletId: fromWallet.id,
          address: receiveAddress,
          amountSat: isMaxSend ? null : inputAmountSat,
          networkFee: selectedFee,
          drain: isMaxSend,
          selectedInputs: stateToUse.selectedUtxos.isNotEmpty ? stateToUse.selectedUtxos : null,
          replaceByFee: stateToUse.replaceByFee,
        );

        final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
          walletId: fromWallet.id,
          psbt: unsignedPsbtAndTxSize.unsignedPsbt,
        );

        final bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: signedPsbtAndTxSize.signedPsbt,
          feeRate: selectedFee.isAbsolute ? selectedFee.value.toDouble() : selectedFee.value as double,
        );

        emit(
          stateToUse.copyWith(
            signedPsbt: signedPsbtAndTxSize.signedPsbt,
            bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
            bitcoinTxSize: signedPsbtAndTxSize.txSize,
          ),
        );
      } else if (stateToUse.swap != null && stateToUse.swap is ChainSwap) {
        final swap = stateToUse.swap as ChainSwap;
        final inputAmountSat = stateToUse.inputAmountSat;
        final isMaxSend = stateToUse.maxAmountSat != null && inputAmountSat == stateToUse.maxAmountSat;
        final selectedFee = stateToUse.selectedFee ?? stateToUse.bitcoinNetworkFees!.fastest;

        final unsignedPsbtAndTxSize = await _prepareBitcoinSendUsecase.execute(
          walletId: fromWallet.id,
          address: swap.paymentAddress,
          amountSat: isMaxSend ? null : swap.paymentAmount,
          networkFee: selectedFee,
          drain: isMaxSend,
          selectedInputs: stateToUse.selectedUtxos.isNotEmpty ? stateToUse.selectedUtxos : null,
          replaceByFee: stateToUse.replaceByFee,
        );

        await _verifyChainSwapAmountSendUsecase.execute(
          psbtOrPset: unsignedPsbtAndTxSize.unsignedPsbt,
          swap: swap,
          walletId: fromWallet.id,
        );

        final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
          walletId: fromWallet.id,
          psbt: unsignedPsbtAndTxSize.unsignedPsbt,
        );

        final bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: signedPsbtAndTxSize.signedPsbt,
          feeRate: selectedFee.isAbsolute ? selectedFee.value.toDouble() : selectedFee.value as double,
        );

        final settings = await _getSettingsUsecase.execute();
        final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
          swapId: swap.id,
          network: Network.fromEnvironment(
            isTestnet: settings.environment == Environment.testnet,
            isLiquid: false,
          ),
          lockupFees: bitcoinAbsoluteFeesSat,
        );

        emit(
          stateToUse.copyWith(
            swap: updatedSwap as ChainSwap,
            signedPsbt: signedPsbtAndTxSize.signedPsbt,
            bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
            bitcoinTxSize: signedPsbtAndTxSize.txSize,
          ),
        );
      }
    } catch (e) {
      log.severe('Error rebuilding transaction: $e');
    }
  }

  Future<void> _rebuildTransaction(Emitter<TransferState> emit) async {
    await _rebuildTransactionWithState(emit, state);
  }

  Future<void> _onConfirmed(
    TransferConfirmed event,
    Emitter<TransferState> emit,
  ) async {
    emit(
      state.copyWith(
        txId: '',
        isConfirming: true,
        confirmTransactionException: null,
      ),
    );
    try {
      final signedPsbt = state.signedPsbt;
      if (signedPsbt.isEmpty) return;

      String txId;
      if (state.isSameChainTransfer) {
        txId = await _broadcastBitcoinTxUsecase.execute(
          signedPsbt,
          isPsbt: true,
        );
        if (state.fromWallet != null) {
          await _getWalletUsecase.execute(state.fromWallet!.id, sync: true);
        }
        if (state.toWallet != null) {
          await _getWalletUsecase.execute(state.toWallet!.id, sync: true);
        }
      } else {
        final swap = state.swap;
        if (swap == null) return;

        final settings = await _getSettingsUsecase.execute();
        final isTestnet = settings.environment == Environment.testnet;
        if (state.fromWallet?.isLiquid == false) {
          txId = await _broadcastBitcoinTxUsecase.execute(
            signedPsbt,
            isPsbt: true,
          );
          await _updatePaidChainSwapUsecase.execute(
            txid: txId,
            swapId: swap.id,
            network: Network.fromEnvironment(
              isTestnet: isTestnet,
              isLiquid: false,
            ),
          );
        } else {
          txId = await _broadcastLiquidTxUsecase.execute(signedPsbt);
          await _updatePaidChainSwapUsecase.execute(
            txid: txId,
            swapId: swap.id,
            network: Network.fromEnvironment(
              isTestnet: isTestnet,
              isLiquid: true,
            ),
          );
        }
      }
      emit(state.copyWith(txId: txId));
    } catch (e) {
      if (e is PrepareBitcoinSendException) {
        emit(
          state.copyWith(
            confirmTransactionException: ConfirmTransactionException(
              'Could not build transaction. Likely due to insufficient funds to cover fees and amount.',
            ),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            e.toString(),
          ),
        ),
      );
    } finally {
      emit(state.copyWith(isConfirming: false));
    }
  }

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

  bool _isInsufficientFundsException(Object e) {
    return e.toString().contains('InsufficientFundsException');
  }

  void _watchChainSwap(String swapId) {
    // Cancel the previous subscription if it exists
    _swapSubscription?.cancel();
    _swapSubscription = _watchSwapUsecase.execute(swapId).listen((updatedSwap) {
      log.info(
        '[SwapCubit] Watched swap ${updatedSwap.id} updated: ${updatedSwap.status}',
      );
      if (updatedSwap is ChainSwap) {
        // ignore: invalid_use_of_visible_for_testing_member
        emit(state.copyWith(swap: updatedSwap));
        if (updatedSwap.status == SwapStatus.completed) {
          // Start syncing the wallet now that the swap is completed
          _getWalletUsecase.execute(state.fromWallet!.id, sync: true);
          if (!state.sendToExternal && state.toWallet != null) {
            _getWalletUsecase.execute(state.toWallet!.id, sync: true);
          }

          // Cancel the subscription as we don't need to watch anymore
          _swapSubscription?.cancel();
          _swapSubscription = null;
        }
      }
    });
  }
}
