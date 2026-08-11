import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
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
import 'package:bb_mobile/core/widgets/fees/fee_modal_controller.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/create_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_quote_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_broadcast_unknown_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_payin_broadcast_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/replace_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/save_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/watch_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dio/dio.dart';

part 'transfer_event.dart';
part 'transfer_state.dart';

part 'transfer_bloc.freezed.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState>
    implements FeeModalActions, FeeModalViewState {
  TransferBloc({
    required this._getSettingsUsecase,
    required this._getWalletsUsecase,
    required this._getNetworkFeesUsecase,
    required this._prepareBitcoinSendUsecase,
    required this._prepareLiquidSendUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
    required this._getWalletUsecase,
    required this._signBitcoinTxUsecase,
    required this._signLiquidTxUsecase,
    required this._broadcastBitcoinTxUsecase,
    required this._broadcastLiquidTxUsecase,
    required this._verifyChainSwapAmountSendUsecase,
    required this._getOrderSwapQuoteUsecase,
    required this._createOrderSwapUsecase,
    required this._savePreparedOrderSwapPayinUsecase,
    required this._replacePreparedOrderSwapPayinUsecase,
    required this._refreshOrderSwapUsecase,
    required this._markOrderSwapBroadcastUnknownUsecase,
    required this._markOrderSwapPayinBroadcastUsecase,
    required this._watchOrderSwapUsecase,
    required this._detectBitcoinStringUsecase,
    required this._getReceiveAddressUsecase,
    required this._getWalletUtxosUsecase,
    required this._convertSatsToCurrencyAmountUsecase,
    required this._previewBitcoinFeeUsecase,
    required this._previewBitcoinFeePresetsUsecase,
    required this._checkLiquidConsolidationUsecase,
  }) : super(const TransferState()) {
    on<TransferStarted>(_onStarted);
    on<TransferWalletsChanged>(_onWalletsChanged);
    on<TransferAmountChanged>(_onAmountChanged);
    on<TransferSwapCreated>(_onSwapCreated);
    on<TransferConfirmed>(_onConfirmed);
    on<TransferSendToExternalToggled>(_onSendToExternalToggled);
    on<TransferExternalAddressChanged>(_onExternalAddressChanged);
    on<TransferReceiveExactAmountToggled>(_onReceiveExactAmountToggled);
    on<TransferReplaceByFeeChanged>(_onReplaceByFeeChanged);
    on<TransferUtxosSelected>(_onUtxosSelected);
    on<TransferLoadUtxos>(_onLoadUtxos);
    on<TransferFeeOptionSelected>(_onFeeOptionSelected);
    on<TransferCustomFeeChanged>(_onCustomFeeChanged);
    on<TransferCustomFeeArmed>(_onCustomFeeArmed);
    on<TransferCustomFeeDisarmed>(_onCustomFeeDisarmed);
    on<TransferCustomFeeFinalized>(_onCustomFeeFinalized);
    on<TransferCustomFeePreviewRequested>(_onCustomFeePreviewRequested);
    on<TransferPresetFeesPreviewRequested>(_onPresetFeesPreviewRequested);
    on<TransferOrderSwapUpdated>(_onOrderSwapUpdated);
  }

  final GetSettingsUsecase _getSettingsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;
  final GetWalletUsecase _getWalletUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;
  final VerifyChainSwapAmountSendUsecase _verifyChainSwapAmountSendUsecase;
  final GetOrderSwapQuoteUsecase _getOrderSwapQuoteUsecase;
  final CreateOrderSwapUsecase _createOrderSwapUsecase;
  final SavePreparedOrderSwapPayinUsecase _savePreparedOrderSwapPayinUsecase;
  final ReplacePreparedOrderSwapPayinUsecase
  _replacePreparedOrderSwapPayinUsecase;
  final RefreshOrderSwapUsecase _refreshOrderSwapUsecase;
  final MarkOrderSwapBroadcastUnknownUsecase
  _markOrderSwapBroadcastUnknownUsecase;
  final MarkOrderSwapPayinBroadcastUsecase _markOrderSwapPayinBroadcastUsecase;
  final WatchOrderSwapUsecase _watchOrderSwapUsecase;
  StreamSubscription<OrderSwapRecord>? _orderSwapSubscription;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final PreviewBitcoinFeeUsecase _previewBitcoinFeeUsecase;
  final PreviewBitcoinFeePresetsUsecase _previewBitcoinFeePresetsUsecase;
  final CheckLiquidConsolidationUsecase _checkLiquidConsolidationUsecase;

  /// Bumped by [_clearBitcoinFeePreviews]; a preview build captures it
  /// before its `await` and re-checks before writing back, so an
  /// input-shape change mid-build discards the stale result instead of
  /// repopulating an emptied cache. Mirrors `SendCubit`.
  int _bitcoinPreviewEpoch = 0;

  @override
  Future<void> close() async {
    await Future.wait([_orderSwapSubscription?.cancel() ?? Future.value()]);
    return super.close();
  }

  Future<void> _onStarted(
    TransferStarted event,
    Emitter<TransferState> emit,
  ) async {
    emit(state.copyWith(isStarting: true));
    try {
      final settings = await _getSettingsUsecase.execute();
      final (
        wallets,
        liquidNetworkFees,
        bitcoinNetworkFees,
        exchangeRate,
      ) = await (
        _getWalletsUsecase.execute(),
        _getNetworkFeesUsecase.execute(isLiquid: true),
        _getNetworkFeesUsecase.execute(isLiquid: false),
        _convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: settings.currencyCode,
        ),
      ).wait;
      final liquidWallets = wallets
          .where(
            (wallet) =>
                wallet.isLiquid && (wallet.isDefault || wallet.signsLocally),
          )
          .toList();
      final bitcoinWallets = wallets
          .where((wallet) => !wallet.isLiquid && wallet.signsLocally)
          .toList();

      final fromWallet = liquidWallets.isNotEmpty
          ? (liquidWallets.where((wallet) => wallet.isDefault).firstOrNull ??
                liquidWallets.first)
          : null;
      final toWallet = bitcoinWallets.isNotEmpty
          ? (bitcoinWallets.where((wallet) => wallet.isDefault).firstOrNull ??
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
          exchangeRate: exchangeRate,
        ),
      );

      final maxAmountSat = fromWallet != null
          ? await getMaxAmountSat(fromWallet)
          : null;

      emit(state.copyWith(maxAmountSat: maxAmountSat));
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

    final isFromWalletChanged = newFromWallet != state.fromWallet;

    // Prevent selecting the same wallet for both from and to
    if (newFromWallet.id == newToWallet.id) {
      if (isFromWalletChanged) {
        final opposite = state.wallets
            .where((w) => w.isLiquid != newFromWallet.isLiquid && w.isDefault)
            .firstOrNull;
        if (opposite != null) {
          newToWallet = opposite;
        } else {
          return;
        }
      } else {
        final opposite = state.wallets
            .where(
              (w) =>
                  w.isLiquid != newToWallet.isLiquid &&
                  w.isDefault &&
                  w.signsLocally,
            )
            .firstOrNull;
        if (opposite != null) {
          newFromWallet = opposite;
        } else {
          return;
        }
      }
    }

    // Prevent Liquid-to-Liquid transfers (not supported)
    if (newFromWallet.isLiquid && newToWallet.isLiquid) {
      if (isFromWalletChanged) {
        final btcWallet = state.wallets
            .where((w) => !w.isLiquid && w.isDefault)
            .firstOrNull;
        if (btcWallet != null) {
          newToWallet = btcWallet;
        } else {
          return;
        }
      } else {
        final btcWallet = state.wallets
            .where((w) => !w.isLiquid && w.isDefault && w.signsLocally)
            .firstOrNull;
        if (btcWallet != null) {
          newFromWallet = btcWallet;
        } else {
          return;
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
    // Wallet swap invalidates every cached preview (different UTXOs +
    // descriptor + script type). Skip when the picker landed on the
    // same fromWallet.
    if (wasFromWalletChanged) _clearBitcoinFeePreviews(emit);

    // Proactively flag consolidation when the source is a Liquid wallet with
    // too many UTXOs, so the card shows before the swap build is attempted.
    // The ConsolidationRequiredException remains the backstop on the build.
    // Routed through CheckLiquidConsolidationUsecase (the same check the
    // consolidation banner and `send` use) rather than re-deriving the
    // comparison here from this bloc's own UTXO read, so all three surfaces
    // can never disagree about whether the wallet needs consolidating.
    if (newFromWallet.isLiquid) {
      try {
        final consolidationRequired = await _checkLiquidConsolidationUsecase
            .execute(walletId: newFromWallet.id);
        emit(state.copyWith(consolidationRequired: consolidationRequired));
      } catch (_) {
        // Best-effort: leave the flag as-is on a read failure.
      }
    } else if (state.consolidationRequired) {
      emit(state.copyWith(consolidationRequired: false));
    }

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
    if (state.amount == event.amount) return;
    var updated = state.copyWith(
      amount: event.amount,
      swapCreationException: null,
      swapFailure: null,
    );
    // Sending the max drains the wallet, so an exact receivable amount can
    // not be honored — force the toggle off while max is selected. Editing
    // the amount away from max re-enables the toggle (off, user re-opts-in).
    if (updated.isMaxSelected && updated.receiveExactAmount) {
      updated = updated.copyWith(receiveExactAmount: false);
    }
    emit(updated);
    // Amount is part of the cache fingerprint (see _clearBitcoinFeePreviews).
    _clearBitcoinFeePreviews(emit);
  }

  Future<void> _onSwapCreated(
    TransferSwapCreated event,
    Emitter<TransferState> emit,
  ) async {
    emit(
      state.copyWith(
        swap: null,
        orderSwap: null,
        signedPsbt: '',
        bitcoinAbsoluteFeesSat: null,
        liquidAbsoluteFeesSat: null,
        isCreatingSwap: true,
        continueClicked: true,
        swapCreationException: null,
        swapFailure: null,
      ),
    );
    try {
      final inputAmountSat = state.bitcoinUnit == BitcoinUnit.sats
          ? int.parse(event.amount)
          : ConvertAmount.btcToSats(double.parse(event.amount));

      // Insufficient balance is surfaced as an inline form error on the
      // amount field (see SwapAmountInput); stop here so no swap is created.
      final balanceSat = state.fromWallet?.balanceSat.toInt() ?? 0;
      if (inputAmountSat > balanceSat) {
        return;
      }

      // A max transfer drains the selected wallet instead of fixing the payin.
      final isMaxSend =
          state.maxAmountSat != null && inputAmountSat == state.maxAmountSat;

      if (!state.isSameChainTransfer) {
        await _createExchangeChainTransfer(
          emit,
          inputAmountSat: inputAmountSat,
          isMaxSend: isMaxSend,
        );
        return;
      }

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
                'receive_address_lookup_failed',
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
              'receive_address_unavailable',
            ),
          ),
        );
        return;
      }

      final selectedFee =
          state.selectedFee ?? state.bitcoinNetworkFees!.fastest;
      final unsignedPsbtAndTxSize = await _prepareBitcoinSendUsecase.execute(
        walletId: bitcoinWalletId,
        address: receiveAddress,
        amountSat: isMaxSend ? null : inputAmountSat,
        networkFee: selectedFee,
        drain: isMaxSend,
        selectedInputs: state.selectedUtxos.isNotEmpty
            ? state.selectedUtxos
            : null,
        replaceByFee: state.replaceByFee,
      );

      final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
        walletId: bitcoinWalletId,
        psbt: unsignedPsbtAndTxSize.unsignedPsbt,
      );

      final signedPsbt = signedPsbtAndTxSize.signedPsbt;
      final bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase
          .execute(psbt: signedPsbt);

      emit(
        state.copyWith(
          signedPsbt: signedPsbt,
          bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
          bitcoinTxSize: signedPsbtAndTxSize.txSize,
          receiveAddress: receiveAddress,
          amount: event.amount,
        ),
      );
    } on ConsolidationRequiredException {
      emit(state.copyWith(consolidationRequired: true));
    } catch (e) {
      log.severe(
        message: '[Transfer] swap creation failed (${e.runtimeType})',
        error: e.runtimeType,
        trace: StackTrace.current,
      );
      final swapCreationException = _isInsufficientFundsException(e)
          ? InsufficientFundsSwapException()
          : SwapCreationException(e.toString());
      emit(state.copyWith(swapCreationException: swapCreationException));
    } finally {
      emit(state.copyWith(isCreatingSwap: false, continueClicked: false));
    }
  }

  Future<void> _createExchangeChainTransfer(
    Emitter<TransferState> emit, {
    required int inputAmountSat,
    required bool isMaxSend,
  }) async {
    final fromWallet = state.fromWallet;
    if (fromWallet == null) {
      throw SwapCreationException('source_wallet_required');
    }
    if (fromWallet.isHardwareWallet) {
      throw SwapCreationException('hardware_wallet_swap_unavailable');
    }
    final orderEnvironment = fromWallet.network.isTestnet
        ? OrderSwapEnvironment.testnet
        : OrderSwapEnvironment.mainnet;

    final destinationWallet = state.sendToExternal ? null : state.toWallet;
    if (!state.sendToExternal && destinationWallet == null) {
      throw SwapCreationException('destination_wallet_required');
    }
    final inNetwork = fromWallet.isLiquid
        ? OrderSwapNetwork.liquid
        : OrderSwapNetwork.bitcoin;
    final outNetwork = fromWallet.isLiquid
        ? OrderSwapNetwork.bitcoin
        : OrderSwapNetwork.liquid;
    final destinationAddress = state.sendToExternal
        ? state.externalAddress
        : (await _getReceiveAddressUsecase.execute(
            walletId: destinationWallet!.id,
          )).address;
    if (destinationAddress.isEmpty) {
      throw SwapCreationException('destination_address_required');
    }
    final fallbackAddress = (await _getReceiveAddressUsecase.execute(
      walletId: fromWallet.id,
    )).address;
    final isInAmountFixed = isMaxSend || !state.receiveExactAmount;

    final quoteResult = await _getOrderSwapQuoteUsecase.execute(
      environment: orderEnvironment,
      amountSat: BigInt.from(inputAmountSat),
      isInAmountFixed: isInAmountFixed,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
    );
    if (quoteResult case Err(:final failure)) {
      log.warning('[Transfer] quote failed (${failure.runtimeType})');
      emit(state.copyWith(swapFailure: failure));
      return;
    }
    final quote = (quoteResult as Ok<OrderSwapQuote, SwapFailure>).value;
    final availableAmountSat = state.selectedUtxos.isEmpty
        ? fromWallet.balanceSat
        : BigInt.from(state.selectedUtxoTotalSat);
    if (quote.inAmountSat > availableAmountSat) {
      throw InsufficientFundsSwapException();
    }

    final createResult = await _createOrderSwapUsecase.execute(
      amountSat: BigInt.from(inputAmountSat),
      isInAmountFixed: isInAmountFixed,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      destinationAddress: destinationAddress,
      fallbackAddress: fallbackAddress,
      purpose: OrderSwapPurpose.transfer,
      environment: orderEnvironment,
      sourceWalletId: fromWallet.id,
      destinationWalletId: destinationWallet?.id,
    );
    if (createResult case Err(:final failure)) {
      log.warning('[Transfer] create failed (${failure.runtimeType})');
      emit(state.copyWith(swapFailure: failure));
      return;
    }
    final created = (createResult as Ok<OrderSwapRecord, SwapFailure>).value;
    final order = created.order!;
    final exchangeFeeSat = order.payinAmountSat - order.payoutAmountSat;
    final displaySwap =
        Swap.chain(
              id: created.localId,
              keyIndex: 0,
              type: fromWallet.isLiquid
                  ? SwapType.liquidToBitcoin
                  : SwapType.bitcoinToLiquid,
              status: SwapStatus.pending,
              environment: fromWallet.network.isTestnet
                  ? Environment.testnet
                  : Environment.mainnet,
              creationTime: created.createdAt,
              sendWalletId: fromWallet.id,
              paymentAddress: order.payinAddress,
              paymentAmount: order.payinAmountSat.toInt(),
              receiveWalletId: destinationWallet?.id,
              receiveAddress: destinationAddress,
              refundAddress: fallbackAddress,
              fees: SwapFees(
                boltzFee: exchangeFeeSat > BigInt.zero
                    ? exchangeFeeSat.toInt()
                    : 0,
              ),
            )
            as ChainSwap;

    final String signedPayin;
    final bool isPsbt;
    int? bitcoinAbsoluteFeesSat;
    int? liquidAbsoluteFeesSat;
    int? bitcoinTxSize;
    if (fromWallet.isLiquid) {
      final selectedFee = state.selectedFee ?? state.liquidNetworkFees!.fastest;
      final unsignedPset = await _prepareLiquidSendUsecase.execute(
        walletId: fromWallet.id,
        address: order.payinAddress,
        amountSat: isMaxSend ? null : order.payinAmountSat.toInt(),
        feeRate: selectedFee as RelativeFee,
        drain: isMaxSend,
      );
      await _verifyChainSwapAmountSendUsecase.execute(
        psbtOrPset: unsignedPset,
        swap: displaySwap,
        walletId: fromWallet.id,
      );
      signedPayin = await _signLiquidTxUsecase.execute(
        walletId: fromWallet.id,
        pset: unsignedPset,
      );
      liquidAbsoluteFeesSat = await _calculateLiquidAbsoluteFeesUsecase.execute(
        pset: signedPayin,
      );
      isPsbt = false;
    } else {
      final selectedFee =
          state.selectedFee ?? state.bitcoinNetworkFees!.fastest;
      final unsigned = await _prepareBitcoinSendUsecase.execute(
        walletId: fromWallet.id,
        address: order.payinAddress,
        amountSat: isMaxSend ? null : order.payinAmountSat.toInt(),
        networkFee: selectedFee,
        drain: isMaxSend,
        selectedInputs: state.selectedUtxos.isEmpty
            ? null
            : state.selectedUtxos,
        replaceByFee: state.replaceByFee,
      );
      await _verifyChainSwapAmountSendUsecase.execute(
        psbtOrPset: unsigned.unsignedPsbt,
        swap: displaySwap,
        walletId: fromWallet.id,
      );
      final signed = await _signBitcoinTxUsecase.execute(
        walletId: fromWallet.id,
        psbt: unsigned.unsignedPsbt,
      );
      signedPayin = signed.signedPsbt;
      bitcoinTxSize = signed.txSize;
      bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase
          .execute(psbt: signedPayin);
      if (!_builtFeeClearsRelay(
        stateToUse: state,
        builtFeeSat: bitcoinAbsoluteFeesSat,
        txSize: bitcoinTxSize,
      )) {
        throw BuildTransactionException('built_fee_below_relay_floor');
      }
      isPsbt = true;
    }

    final prepareResult = await _savePreparedOrderSwapPayinUsecase.execute(
      localId: created.localId,
      signedTransaction: signedPayin,
      isPsbt: isPsbt,
    );
    if (prepareResult case Err(:final failure)) {
      log.warning(
        '[Transfer] payin persistence failed (${failure.runtimeType})',
      );
      emit(state.copyWith(swapFailure: failure));
      return;
    }
    final prepared = (prepareResult as Ok<OrderSwapRecord, SwapFailure>).value;
    emit(
      state.copyWith(
        swap: displaySwap.copyWith(
          fees: displaySwap.fees?.copyWith(
            lockupFee: bitcoinAbsoluteFeesSat ?? liquidAbsoluteFeesSat,
          ),
        ),
        orderSwap: prepared,
        signedPsbt: signedPayin,
        bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
        liquidAbsoluteFeesSat: liquidAbsoluteFeesSat,
        bitcoinTxSize: bitcoinTxSize,
        receiveAddress: destinationAddress,
      ),
    );
    _watchExchangeOrderSwap(prepared.localId);
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
    if (state.externalAddress == event.address) return;
    // Recipient is part of the cache fingerprint — drop every cached
    // preview when the new value differs from what we had cached against.
    _clearBitcoinFeePreviews(emit);
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
        final errorMessage = fromWallet.isLiquid == true
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
            bip21AmountText = state.bitcoinUnit == BitcoinUnit.sats
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
        final errorMessage = fromWallet.isLiquid == true
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
      final errorMessage = fromWallet?.isLiquid == true
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
    if (event.enabled && state.isMaxSelected) {
      // Max send and exact receivable are mutually exclusive.
      return;
    }
    emit(state.copyWith(receiveExactAmount: event.enabled));
  }

  Future<void> _onReplaceByFeeChanged(
    TransferReplaceByFeeChanged event,
    Emitter<TransferState> emit,
  ) async {
    if (state.replaceByFee == event.replaceByFee) return;
    emit(state.copyWith(replaceByFee: event.replaceByFee));
    _clearBitcoinFeePreviews(emit);
    await _rebuildTransaction(emit);
  }

  Future<void> _onUtxosSelected(
    TransferUtxosSelected event,
    Emitter<TransferState> emit,
  ) async {
    // The UTXO set is an unordered selection — compare as sets so a
    // re-emit of the same set (different list order) doesn't invalidate.
    final utxosChanged =
        state.selectedUtxos
            .toSet()
            .difference(event.utxos.toSet())
            .isNotEmpty ||
        event.utxos.toSet().difference(state.selectedUtxos.toSet()).isNotEmpty;
    emit(state.copyWith(selectedUtxos: event.utxos));
    if (utxosChanged) _clearBitcoinFeePreviews(emit);
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
      // A wallet sync can change the available coins; any cached preview PSBT
      // was built against the prior set, so drop it — otherwise a sync landing
      // mid-flow could leave a stale PSBT staged for broadcast. Guarded so a
      // no-op refresh doesn't needlessly re-shimmer. Mirrors SendCubit.loadUtxos.
      final utxosChanged = !setEquals(
        (state.utxos ?? const <WalletUtxo>[]).toSet(),
        utxos.toSet(),
      );
      emit(state.copyWith(utxos: utxos));
      if (utxosChanged) _clearBitcoinFeePreviews(emit);
    } catch (e) {
      log.severe(
        message: 'Error loading UTXOs',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  Future<void> _onFeeOptionSelected(
    TransferFeeOptionSelected event,
    Emitter<TransferState> emit,
  ) async {
    // Clears any in-flight custom-fee arm — picking a preset is itself a
    // commit, no rollback needed.
    final updatedState = state.copyWith(
      selectedFeeOption: event.feeSelection,
      armPriorSelection: null,
      armPriorCustomFee: null,
    );
    emit(updatedState);
    await _rebuildTransactionWithState(emit, updatedState);
  }

  Future<void> _onCustomFeeChanged(
    TransferCustomFeeChanged event,
    Emitter<TransferState> emit,
  ) async {
    // Real commit — discard the arm snapshot and rebuild.
    final updatedState = state.copyWith(
      customFee: event.fee,
      selectedFeeOption: FeeSelection.custom,
      armPriorSelection: null,
      armPriorCustomFee: null,
    );
    emit(updatedState);
    await _rebuildTransactionWithState(emit, updatedState);
  }

  /// See [TransferEvent.customFeeArmed]. Snapshots the pre-arm selection on
  /// the first call so [_onCustomFeeDisarmed] can roll back. Subsequent calls
  /// only update `customFee` — snapshot stays pinned to the pre-arm state.
  Future<void> _onCustomFeeArmed(
    TransferCustomFeeArmed event,
    Emitter<TransferState> emit,
  ) async {
    // Mirrors SendCubit.armCustomFee — clear the cached custom-slot
    // PSBT (it was built for the OLD typed rate) so commit can't reuse
    // it. Without this, dismissing within the debounce window would
    // broadcast the previous rate's PSBT while showing the new rate.
    // Same divergence class the PR fixes elsewhere.
    //
    // Bump the epoch so an in-flight preview for the prior rate (which
    // captured the old epoch) is discarded on return instead of
    // overwriting the slot for the new rate.
    _bitcoinPreviewEpoch++;
    final cleared = state.feePreviewCache.withSlot(
      FeeSelection.custom,
      const BitcoinFeePreviewSlot(),
    );
    if (state.armPriorSelection == null) {
      emit(
        state.copyWith(
          armPriorSelection: state.selectedFeeOption,
          armPriorCustomFee: state.customFee,
          selectedFeeOption: FeeSelection.custom,
          customFee: event.fee,
          bitcoinAbsoluteFeesSat: null,
          feePreviewCache: cleared,
        ),
      );
    } else {
      emit(
        state.copyWith(
          customFee: event.fee,
          bitcoinAbsoluteFeesSat: null,
          feePreviewCache: cleared,
        ),
      );
    }
  }

  /// See [TransferEvent.customFeeDisarmed]. No-op if no arm is active.
  Future<void> _onCustomFeeDisarmed(
    TransferCustomFeeDisarmed event,
    Emitter<TransferState> emit,
  ) async {
    if (state.armPriorSelection == null) return;
    emit(
      state.copyWith(
        selectedFeeOption: state.armPriorSelection!,
        customFee: state.armPriorCustomFee,
        armPriorSelection: null,
        armPriorCustomFee: null,
      ),
    );
  }

  /// See [TransferEvent.customFeeFinalized]. If armed and the typed rate
  /// is above the 0.1 sat/vB floor → commit via [_onCustomFeeChanged];
  /// otherwise roll back. No-op if not armed (user never typed in the
  /// custom field).
  Future<void> _onCustomFeeFinalized(
    TransferCustomFeeFinalized event,
    Emitter<TransferState> emit,
  ) async {
    if (state.armPriorSelection == null) return;
    final fee = state.customFee;
    final txSize = state.bitcoinTxSize ?? 140;
    if (fee != null &&
        fee.aboveMinRelay(
          txSize: txSize,
          floorSatPerKwu: state.bitcoinNetworkFees?.minRelay.satPerKwu,
        )) {
      await _onCustomFeeChanged(TransferCustomFeeChanged(fee), emit);
    } else {
      await _onCustomFeeDisarmed(const TransferCustomFeeDisarmed(), emit);
    }
  }

  /// Builds an unsigned PSBT at the typed rate via
  /// [PreviewBitcoinFeeUsecase] and writes the resulting slot into the
  /// shared [BitcoinFeePreviewCache]. Mirrors
  /// `SendCubit.previewBitcoinCustomFee` — debounced from the widget.
  Future<void> _onCustomFeePreviewRequested(
    TransferCustomFeePreviewRequested event,
    Emitter<TransferState> emit,
  ) async {
    if (state.fromWallet == null) return;
    if (state.fromWallet!.isLiquid) return;
    final shape = _previewBitcoinShape();
    if (shape == null) return;
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache.copyWith(customLoading: true),
      ),
    );
    final epoch = _bitcoinPreviewEpoch;
    final slot = await _previewBitcoinFeeUsecase.execute(
      walletId: state.fromWallet!.id,
      address: shape.address,
      networkFee: event.fee,
      amountSat: shape.amountSat,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
      drain: state.isMaxSelected,
    );
    // Discard if an input-shape change emptied the cache mid-build.
    if (epoch != _bitcoinPreviewEpoch) return;
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache
            .withSlot(FeeSelection.custom, slot)
            .copyWith(customLoading: false),
      ),
    );
  }

  /// Three parallel unsigned-PSBT builds for Fastest/Economic/Slow via
  /// [PreviewBitcoinFeePresetsUsecase], which dedupes by rate so a quiet
  /// mempool can't make Slow look more expensive than Economic at the
  /// same rate.
  Future<void> _onPresetFeesPreviewRequested(
    TransferPresetFeesPreviewRequested event,
    Emitter<TransferState> emit,
  ) async {
    if (state.fromWallet == null) return;
    if (state.fromWallet!.isLiquid) return;
    final presets = state.bitcoinNetworkFees;
    if (presets == null) return;
    final shape = _previewBitcoinShape();
    if (shape == null) return;
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache.copyWith(presetsLoading: true),
      ),
    );
    final epoch = _bitcoinPreviewEpoch;
    final slots = await _previewBitcoinFeePresetsUsecase.execute(
      presets: presets,
      walletId: state.fromWallet!.id,
      address: shape.address,
      amountSat: shape.amountSat,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
      drain: state.isMaxSelected,
    );
    // Discard if an input-shape change emptied the cache mid-build.
    if (epoch != _bitcoinPreviewEpoch) return;
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache.copyWith(
          fastest: slots[FeeSelection.fastest] ?? const BitcoinFeePreviewSlot(),
          economic:
              slots[FeeSelection.economic] ?? const BitcoinFeePreviewSlot(),
          slow: slots[FeeSelection.slow] ?? const BitcoinFeePreviewSlot(),
          presetsLoading: false,
        ),
      ),
    );
  }

  /// Recipient + amount for preview builds — derived from the active
  /// transfer context. Two flows have a usable shape:
  /// - chain swap (state.swap set): use the swap's payment address/amount;
  /// - same-chain transfer: use the user-supplied receive address and the
  ///   input amount, mirroring what _rebuildTransactionWithState builds.
  /// Returns null when neither is ready.
  ({String address, int amountSat})? _previewBitcoinShape() {
    final swap = state.swap;
    if (swap != null) {
      return (address: swap.paymentAddress, amountSat: swap.paymentAmount);
    }
    if (state.isSameChainTransfer) {
      final receive = state.receiveAddress;
      final amount = state.inputAmountSat;
      if (receive != null && receive.isNotEmpty && amount > 0) {
        return (address: receive, amountSat: amount);
      }
    }
    return null;
  }

  /// Drop every cached preview when input shape changes. The cache is
  /// keyed implicitly by (wallet, address, amount, utxos, rbf); any of
  /// those moving invalidates the cached PSBTs we'd otherwise broadcast.
  void _clearBitcoinFeePreviews(Emitter<TransferState> emit) {
    _bitcoinPreviewEpoch++;
    emit(state.copyWith(feePreviewCache: BitcoinFeePreviewCache.empty));
  }

  /// Belt-and-suspenders relay-floor re-assert, mirroring
  /// `SendCubit.createTransaction`. The pre-build gate in
  /// [_onCustomFeeFinalized] checks an absolute custom fee against the
  /// *previous* `bitcoinTxSize`; if the real tx is larger, an absolute fee
  /// that cleared that gate can land below the floor at the actual vsize.
  /// Re-checking the freshly built fee against the freshly built vsize closes
  /// the only below-relay-broadcast vector on the swap surface — don't rely on
  /// BDK rejecting sub-minrelay itself.
  bool _builtFeeClearsRelay({
    required TransferState stateToUse,
    required int builtFeeSat,
    required int txSize,
  }) {
    return NetworkFee.absolute(builtFeeSat).aboveMinRelay(
      txSize: txSize,
      floorSatPerKwu: stateToUse.bitcoinNetworkFees?.minRelay.satPerKwu,
    );
  }

  Future<void> _rebuildTransactionWithState(
    Emitter<TransferState> emit,
    TransferState stateToUse,
  ) async {
    if (stateToUse.fromWallet == null) return;
    if (!stateToUse.shouldShowAdvancedOptions) return;
    if (stateToUse.signedPsbt.isEmpty &&
        stateToUse.swap == null &&
        !stateToUse.isSameChainTransfer) {
      return;
    }

    try {
      final fromWallet = stateToUse.fromWallet!;
      if (fromWallet.isLiquid) return;

      // Reuse the modal-preview PSBT for the user's selected fee tile.
      // BDK's coin selection is randomized — rebuilding here would
      // broadcast a different fee than the modal displayed.
      final cachedSlot = stateToUse.feePreviewCache.slotFor(
        stateToUse.selectedFeeOption,
      );
      final canUseCache = cachedSlot.isCacheReady;
      if (stateToUse.isSameChainTransfer) {
        final receiveAddress = stateToUse.receiveAddress;
        if (receiveAddress == null || receiveAddress.isEmpty) return;

        final inputAmountSat = stateToUse.inputAmountSat;
        final isMaxSend =
            stateToUse.maxAmountSat != null &&
            inputAmountSat == stateToUse.maxAmountSat;
        final selectedFee =
            stateToUse.selectedFee ?? stateToUse.bitcoinNetworkFees!.fastest;

        final unsignedPsbtAndTxSize = canUseCache
            ? (
                unsignedPsbt: cachedSlot.unsignedPsbt!,
                txSize: cachedSlot.txSize!,
                isToSelf: true,
              )
            : await _prepareBitcoinSendUsecase.execute(
                walletId: fromWallet.id,
                address: receiveAddress,
                amountSat: isMaxSend ? null : inputAmountSat,
                networkFee: selectedFee,
                drain: isMaxSend,
                selectedInputs: stateToUse.selectedUtxos.isNotEmpty
                    ? stateToUse.selectedUtxos
                    : null,
                replaceByFee: stateToUse.replaceByFee,
              );

        final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
          walletId: fromWallet.id,
          psbt: unsignedPsbtAndTxSize.unsignedPsbt,
        );

        final bitcoinAbsoluteFeesSat =
            await _calculateBitcoinAbsoluteFeesUsecase.execute(
              psbt: signedPsbtAndTxSize.signedPsbt,
            );

        if (!_builtFeeClearsRelay(
          stateToUse: stateToUse,
          builtFeeSat: bitcoinAbsoluteFeesSat,
          txSize: signedPsbtAndTxSize.txSize,
        )) {
          log.warning(
            'Rebuild aborted — built fee $bitcoinAbsoluteFeesSat sats at '
            '${signedPsbtAndTxSize.txSize} vbytes is below the relay floor',
          );
          emit(
            stateToUse.copyWith(
              signedPsbt: '',
              buildTransactionException: BuildTransactionException(
                'built_fee_below_relay_floor',
              ),
            ),
          );
          return;
        }

        emit(
          stateToUse.copyWith(
            signedPsbt: signedPsbtAndTxSize.signedPsbt,
            bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
            bitcoinTxSize: signedPsbtAndTxSize.txSize,
            buildTransactionException: null,
          ),
        );
      } else if (stateToUse.orderSwap != null && stateToUse.swap is ChainSwap) {
        final swap = stateToUse.swap as ChainSwap;
        final orderSwap = stateToUse.orderSwap!;
        final inputAmountSat = stateToUse.inputAmountSat;
        final isMaxSend =
            stateToUse.maxAmountSat != null &&
            inputAmountSat == stateToUse.maxAmountSat;
        final selectedFee =
            stateToUse.selectedFee ?? stateToUse.bitcoinNetworkFees!.fastest;

        final unsignedPsbtAndTxSize = canUseCache
            ? (
                unsignedPsbt: cachedSlot.unsignedPsbt!,
                txSize: cachedSlot.txSize!,
                isToSelf: false,
              )
            : await _prepareBitcoinSendUsecase.execute(
                walletId: fromWallet.id,
                address: swap.paymentAddress,
                amountSat: isMaxSend ? null : swap.paymentAmount,
                networkFee: selectedFee,
                drain: isMaxSend,
                selectedInputs: stateToUse.selectedUtxos.isNotEmpty
                    ? stateToUse.selectedUtxos
                    : null,
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

        final bitcoinAbsoluteFeesSat =
            await _calculateBitcoinAbsoluteFeesUsecase.execute(
              psbt: signedPsbtAndTxSize.signedPsbt,
            );

        if (!_builtFeeClearsRelay(
          stateToUse: stateToUse,
          builtFeeSat: bitcoinAbsoluteFeesSat,
          txSize: signedPsbtAndTxSize.txSize,
        )) {
          log.warning(
            'Rebuild aborted — built fee $bitcoinAbsoluteFeesSat sats at '
            '${signedPsbtAndTxSize.txSize} vbytes is below the relay floor',
          );
          emit(
            stateToUse.copyWith(
              signedPsbt: '',
              buildTransactionException: BuildTransactionException(
                'built_fee_below_relay_floor',
              ),
            ),
          );
          return;
        }

        final replaceResult = await _replacePreparedOrderSwapPayinUsecase
            .execute(
              localId: orderSwap.localId,
              signedTransaction: signedPsbtAndTxSize.signedPsbt,
              isPsbt: true,
            );
        final prepared = switch (replaceResult) {
          Ok(:final value) => value,
          Err(:final failure) => throw BuildTransactionException(
            failure.logMessage ?? failure.runtimeType.toString(),
          ),
        };

        emit(
          stateToUse.copyWith(
            swap: swap.copyWith(
              fees: swap.fees?.copyWith(lockupFee: bitcoinAbsoluteFeesSat),
            ),
            orderSwap: prepared,
            signedPsbt: signedPsbtAndTxSize.signedPsbt,
            bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
            bitcoinTxSize: signedPsbtAndTxSize.txSize,
            buildTransactionException: null,
          ),
        );
      }
    } catch (e) {
      log.severe(
        message: 'Error rebuilding transaction',
        error: e,
        trace: StackTrace.current,
      );
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
        swapFailure: null,
      ),
    );
    try {
      final signedPsbt = state.signedPsbt;
      if (signedPsbt.isEmpty) return;

      String txId;
      final orderSwap = state.orderSwap;
      if (orderSwap != null) {
        if (orderSwap.localStatus == OrderSwapLocalStatus.broadcastUnknown) {
          final refreshed = switch (await _refreshOrderSwapUsecase.execute(
            orderSwap.localId,
          )) {
            Ok(:final value) => value,
            Err(:final failure) => throw ConfirmTransactionException(
              failure.logMessage ?? failure.runtimeType.toString(),
            ),
          };
          final payinStatus = refreshed.order?.payinStatus.trim().toLowerCase();
          if (payinStatus == 'completed') {
            emit(state.copyWith(orderSwap: refreshed));
            return;
          }
        }
        final broadcasting = switch (await _markOrderSwapBroadcastUnknownUsecase
            .execute(orderSwap.localId)) {
          Ok(:final value) => value,
          Err(:final failure) => throw ConfirmTransactionException(
            failure.logMessage ?? failure.runtimeType.toString(),
          ),
        };
        if (state.fromWallet?.isLiquid == true) {
          txId = await _broadcastLiquidTxUsecase.execute(
            broadcasting.signedPayinTransaction!,
          );
        } else {
          txId = await _broadcastBitcoinTxUsecase.execute(
            broadcasting.signedPayinTransaction!,
            isPsbt: broadcasting.payinIsPsbt!,
          );
        }
        final broadcast = switch (await _markOrderSwapPayinBroadcastUsecase
            .execute(localId: orderSwap.localId, transactionId: txId)) {
          Ok(:final value) => value,
          Err(:final failure) => throw ConfirmTransactionException(
            failure.logMessage ?? failure.runtimeType.toString(),
          ),
        };
        final displaySwap = state.swap as ChainSwap;
        emit(
          state.copyWith(
            orderSwap: broadcast,
            swap: displaySwap.copyWith(status: SwapStatus.paid, sendTxid: txId),
          ),
        );
        await _getWalletUsecase.execute(state.fromWallet!.id, sync: true);
      } else if (state.isSameChainTransfer) {
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
        return;
      }
      emit(state.copyWith(txId: txId));
    } catch (e) {
      emit(
        state.copyWith(
          confirmTransactionException: null,
          swapFailure: _swapFailureFromException(e),
        ),
      );
    } finally {
      emit(state.copyWith(isConfirming: false));
    }
  }

  SwapFailure _swapFailureFromException(Object exception) {
    if (exception is DioException) {
      return switch (exception.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => const SwapTimeoutFailure(),
        _ => const SwapNetworkFailure(),
      };
    }
    return const SwapUnexpectedFailure();
  }

  Future<int?> getMaxAmountSat(Wallet fromWallet) async {
    try {
      if (fromWallet.balanceSat <= BigInt.zero) return 0;
      final networkFee = fromWallet.isLiquid
          ? state.liquidNetworkFees!.fastest
          : state.bitcoinNetworkFees!.fastest;
      final receiveAddress = await _getReceiveAddressUsecase.execute(
        walletId: fromWallet.id,
      );

      // Create a dummy drain transaction to calculate the absolute fees
      int absoluteFees;
      if (!fromWallet.isLiquid) {
        final dummyDrainTxInfo = await _prepareBitcoinSendUsecase.execute(
          walletId: fromWallet.id,
          address: receiveAddress.address,
          networkFee: networkFee,
          drain: true,
        );

        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: dummyDrainTxInfo.unsignedPsbt,
        );

        log.info("Absolute fees: $absoluteFees");
      } else {
        final dummyPset = await _prepareLiquidSendUsecase.execute(
          walletId: fromWallet.id,
          address: receiveAddress.address,
          // networkFee was selected from the Liquid FeeOptions, always RelativeFee.
          feeRate: networkFee as RelativeFee,
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
      log.severe(
        message: 'Error getting max amount sat in transfer bloc',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }

  bool _isInsufficientFundsException(Object e) {
    return e is InsufficientFundsSwapException ||
        e.toString().contains('InsufficientFundsException');
  }

  Future<void> _onOrderSwapUpdated(
    TransferOrderSwapUpdated event,
    Emitter<TransferState> emit,
  ) async {
    final orderSwap = event.orderSwap;
    final currentSwap = state.swap;
    if (currentSwap is! ChainSwap) return;
    final status = transferSwapStatusForOrderSwap(orderSwap.localStatus);
    emit(
      state.copyWith(
        orderSwap: orderSwap,
        swap: currentSwap.copyWith(
          status: status,
          sendTxid: orderSwap.localPayinTransactionId,
          receiveTxid: switch (orderSwap.outNetwork) {
            OrderSwapNetwork.bitcoin => orderSwap.order?.bitcoinTransactionId,
            OrderSwapNetwork.liquid => orderSwap.order?.liquidTransactionId,
            OrderSwapNetwork.lightning => null,
          },
        ),
      ),
    );
    if (orderSwap.localStatus.isTerminal) {
      unawaited(_getWalletUsecase.execute(state.fromWallet!.id, sync: true));
      final destinationWalletId = orderSwap.destinationWalletId;
      if (destinationWalletId != null) {
        unawaited(_getWalletUsecase.execute(destinationWalletId, sync: true));
      }
    }
  }

  void _watchExchangeOrderSwap(String localId) {
    _orderSwapSubscription?.cancel();
    _orderSwapSubscription = _watchOrderSwapUsecase
        .execute(localId)
        .listen(
          (orderSwap) => add(TransferEvent.orderSwapUpdated(orderSwap)),
          onError: (Object error) {
            log.warning('Exchange transfer watcher failed: $error');
          },
        );
  }

  // ────── FeeModalViewState + FeeModalActions adoption ──────
  // Mirrors SendCubit's adoption. The shared modal sees an identical
  // [FeeModalSnapshot] / action surface regardless of whether it's
  // mounted by send or swap; differences in state-field naming and
  // event-vs-method dispatch all collapse here.

  static FeeModalSnapshot _modalSnapshotFromState(TransferState s) =>
      FeeModalSnapshot(
        feePresets: s.bitcoinNetworkFees,
        customFee: s.customFee,
        selectedFeeOption: s.selectedFeeOption,
        feePreviewCache: s.feePreviewCache,
        exchangeRate: s.exchangeRate ?? 0.0,
        fiatCurrencyCode: s.fiatCurrencyCode ?? 'CAD',
        txSize: s.bitcoinTxSize ?? 140,
      );

  @override
  FeeModalSnapshot get snapshot => _modalSnapshotFromState(state);

  @override
  Stream<FeeModalSnapshot> get snapshots => stream.map(_modalSnapshotFromState);

  @override
  void requestPresetPreviews() =>
      add(const TransferEvent.presetFeesPreviewRequested());

  @override
  void requestCustomFeePreview(NetworkFee fee) =>
      add(TransferEvent.customFeePreviewRequested(fee));

  @override
  void armCustomFee(NetworkFee fee) => add(TransferEvent.customFeeArmed(fee));

  @override
  void disarmCustomFee() => add(const TransferEvent.customFeeDisarmed());

  @override
  void finalizeArmedCustomFee() =>
      add(const TransferEvent.customFeeFinalized());

  @override
  void selectFeeOption(FeeSelection selection) =>
      add(TransferEvent.feeOptionSelected(selection));
}
