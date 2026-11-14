import 'package:bb_mobile/features/send/public/send_facade.dart'
    show
        SendConsolidationRequiredFailure,
        SendInsufficientBalanceFailure,
        SendInsufficientFundsForFeesFailure;
import 'package:primitives/primitives.dart'
    show BitcoinTransactionRecipient, BitcoinUnit, Err, Ok, Result, Sats;
import 'dart:async';

import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:swaps/swaps.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/widgets/fees/fee_modal_controller.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/swap/domain/swaps_failure_mapping.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_exchange_rate_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/check_swap_spend_admission_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_route_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/create_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_quote_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_pending_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_broadcast_unknown_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_payin_broadcast_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/replace_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/save_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/watch_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_confirm_error.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show WalletSpendBlockedException;
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
    required this._validateBitcoinSelectionUsecase,
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
    required this._getPendingOrderSwapsUsecase,
    required this._createOrderSwapUsecase,
    required this._checkSwapSpendAdmissionUsecase,
    required this._savePreparedOrderSwapPayinUsecase,
    required this._replacePreparedOrderSwapPayinUsecase,
    required this._refreshOrderSwapUsecase,
    required this._markOrderSwapBroadcastUnknownUsecase,
    required this._markOrderSwapPayinBroadcastUsecase,
    required this._watchOrderSwapUsecase,
    required this._detectBitcoinStringUsecase,
    required this._getReceiveAddressUsecase,
    required this._getWalletUtxosUsecase,
    required this._getSwapExchangeRateUsecase,
    required this._previewBitcoinFeeUsecase,
    required this._previewBitcoinFeePresetsUsecase,
    required this._checkLiquidConsolidationUsecase,
    required this._getSwapRouteUsecase,
    required this._getSwapLimitsAndFeesUsecase,
    required this._createBitcoinToLiquidSwapUsecase,
    required this._createLiquidToBitcoinSwapUsecase,
    required this._recordSwapLockupUsecase,
    required this._recordPendingSwapLockupUsecase,
    required this._dropPendingSwapLockupUsecase,
    required this._watchSwapUsecase,
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
    on<TransferBoltzSwapUpdated>(_onBoltzSwapUpdated);
  }

  final GetSettingsUsecase _getSettingsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final ValidateBitcoinSelectionUsecase _validateBitcoinSelectionUsecase;
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
  final GetPendingOrderSwapsUsecase _getPendingOrderSwapsUsecase;
  final CreateOrderSwapUsecase _createOrderSwapUsecase;
  final CheckSwapSpendAdmissionUsecase _checkSwapSpendAdmissionUsecase;
  final SavePreparedOrderSwapPayinUsecase _savePreparedOrderSwapPayinUsecase;
  final ReplacePreparedOrderSwapPayinUsecase
  _replacePreparedOrderSwapPayinUsecase;
  final RefreshOrderSwapUsecase _refreshOrderSwapUsecase;
  final MarkOrderSwapBroadcastUnknownUsecase
  _markOrderSwapBroadcastUnknownUsecase;
  final MarkOrderSwapPayinBroadcastUsecase _markOrderSwapPayinBroadcastUsecase;
  final WatchOrderSwapUsecase _watchOrderSwapUsecase;
  StreamSubscription<Result<OrderSwapRecord, SwapFailure>>?
  _orderSwapSubscription;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetSwapExchangeRateUsecase _getSwapExchangeRateUsecase;
  final PreviewBitcoinFeeUsecase _previewBitcoinFeeUsecase;
  final PreviewBitcoinFeePresetsUsecase _previewBitcoinFeePresetsUsecase;
  final CheckLiquidConsolidationUsecase _checkLiquidConsolidationUsecase;
  final GetSwapRouteUsecase _getSwapRouteUsecase;
  final GetSwapLimitsAndFeesUsecase _getSwapLimitsAndFeesUsecase;
  final CreateBitcoinToLiquidSwapUsecase _createBitcoinToLiquidSwapUsecase;
  final CreateLiquidToBitcoinSwapUsecase _createLiquidToBitcoinSwapUsecase;
  final RecordSwapLockupUsecase _recordSwapLockupUsecase;
  final RecordPendingSwapLockupUsecase _recordPendingSwapLockupUsecase;
  final DropPendingSwapLockupUsecase _dropPendingSwapLockupUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  StreamSubscription<Swap>? _boltzSwapSubscription;
  int _transactionGeneration = 0;

  /// Bumped by [_clearBitcoinFeePreviews]; a preview build captures it
  /// before its `await` and re-checks before writing back, so an
  /// input-shape change mid-build discards the stale result instead of
  /// repopulating an emptied cache. Mirrors `SendCubit`.
  int _bitcoinPreviewEpoch = 0;

  @override
  Future<void> close() async {
    await Future.wait([
      _orderSwapSubscription?.cancel() ?? Future.value(),
      _boltzSwapSubscription?.cancel() ?? Future.value(),
    ]);
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
        walletsResult,
        liquidNetworkFees,
        bitcoinNetworkFees,
        exchangeRateResult,
      ) = await (
        _getWalletsUsecase.execute(),
        _getNetworkFeesUsecase.execute(isLiquid: true),
        _getNetworkFeesUsecase.execute(isLiquid: false),
        _getSwapExchangeRateUsecase.execute(
          currencyCode: settings.currencyCode,
        ),
      ).wait;
      final double? exchangeRate;
      switch (exchangeRateResult) {
        case Ok(:final value):
          exchangeRate = value;
        // A transfer works without a price: no fiat value is shown then.
        case Err(failure: SwapPriceUnavailableFailure()):
          exchangeRate = null;
        case Err(:final failure):
          emit(
            state.copyWith(
              startError: Exception(
                'price read failed: ${failure.runtimeType}',
              ),
            ),
          );
          return;
      }
      final List<Wallet> wallets;
      switch (walletsResult) {
        case Ok(:final value):
          wallets = value;
        // Reported the same way as every other start failure in this handler,
        // with the failure type only; `finally` still clears isStarting.
        case Err(:final failure):
          emit(
            state.copyWith(
              startError: Exception(
                'wallets read failed: ${failure.runtimeType}',
              ),
            ),
          );
          return;
      }
      final liquidWallets = wallets
          .where(
            (wallet) =>
                wallet.isLiquid && (wallet.isDefault || wallet.signsLocally),
          )
          .toList();
      final bitcoinWallets = wallets
          .where((wallet) => !wallet.isLiquid && wallet.signsLocally)
          .toList();

      var fromWallet = liquidWallets.isNotEmpty
          ? (liquidWallets.where((wallet) => wallet.isDefault).firstOrNull ??
                liquidWallets.first)
          : null;
      var toWallet = bitcoinWallets.isNotEmpty
          ? (bitcoinWallets.where((wallet) => wallet.isDefault).firstOrNull ??
                bitcoinWallets.first)
          : null;
      final pendingResult = await _getPendingOrderSwapsUsecase.execute();
      if (pendingResult case Ok(:final value)) {
        final pendingTransfer = value
            .where((order) => order.purpose == OrderSwapPurpose.transfer)
            .firstOrNull;
        if (pendingTransfer != null) {
          fromWallet = wallets
              .where((wallet) => wallet.id == pendingTransfer.sourceWalletId)
              .firstOrNull;
          toWallet = wallets
              .where(
                (wallet) => wallet.id == pendingTransfer.destinationWalletId,
              )
              .firstOrNull;
        }
      }
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
      await _loadSwapRoute(emit);
      await _resumePendingTransfer(emit);
    } catch (e) {
      emit(state.copyWith(startError: Exception(e.toString())));
    } finally {
      emit(state.copyWith(isStarting: false));
    }
  }

  Future<void> _loadSwapRoute(Emitter<TransferState> emit) async {
    final route = await _getSwapRouteUsecase.execute();
    emit(state.copyWith(swapRoute: route));
    if (!route.startsWithBoltz) return;
    final (btcToLbtc, lbtcToBtc) = await (
      _getSwapLimitsAndFeesUsecase.execute(SwapType.bitcoinToLiquid),
      _getSwapLimitsAndFeesUsecase.execute(SwapType.liquidToBitcoin),
    ).wait;
    emit(
      state.copyWith(
        btcToLbtcSwapLimitsAndFees: switch (btcToLbtc) {
          Ok(:final value) => value,
          Err() => null,
        },
        lbtcToBtcSwapLimitsAndFees: switch (lbtcToBtc) {
          Ok(:final value) => value,
          Err() => null,
        },
      ),
    );
  }

  Future<void> _resumePendingTransfer(Emitter<TransferState> emit) async {
    final fromWallet = state.fromWallet;
    if (fromWallet == null) return;
    final pendingResult = await _getPendingOrderSwapsUsecase.execute();
    if (pendingResult case Err()) return;
    final pending =
        (pendingResult as Ok<List<OrderSwapRecord>, SwapFailure>).value;
    final record = pending.where((candidate) {
      final expectedEnvironment = fromWallet.network.requireHistoricalTestnet()
          ? OrderSwapEnvironment.testnet
          : OrderSwapEnvironment.mainnet;
      final expectedInNetwork = fromWallet.isLiquid
          ? OrderSwapNetwork.liquid
          : OrderSwapNetwork.bitcoin;
      final expectedOutNetwork = state.toWallet?.isLiquid == true
          ? OrderSwapNetwork.liquid
          : OrderSwapNetwork.bitcoin;
      final amountMatches =
          state.amount.isEmpty ||
          candidate.requestedAmountSat == BigInt.from(state.inputAmountSat);
      return candidate.purpose == OrderSwapPurpose.transfer &&
          candidate.environment == expectedEnvironment &&
          candidate.inNetwork == expectedInNetwork &&
          candidate.outNetwork == expectedOutNetwork &&
          amountMatches &&
          candidate.sourceWalletId == fromWallet.id &&
          candidate.destinationWalletId == state.toWallet?.id;
    }).firstOrNull;
    if (record == null || record.order == null) return;

    final order = record.order!;
    final isExpired =
        record.localStatus == OrderSwapLocalStatus.expired ||
        !order.confirmationDeadline.isAfter(DateTime.now());
    final displaySwap =
        Swap.chain(
              id: record.localId,
              keyIndex: 0,
              type: fromWallet.isLiquid
                  ? SwapType.liquidToBitcoin
                  : SwapType.bitcoinToLiquid,
              status: isExpired
                  ? SwapStatus.expired
                  : transferSwapStatusForOrderSwap(record.localStatus),
              environment: record.environment == OrderSwapEnvironment.testnet
                  ? SwapEnvironment.testnet
                  : SwapEnvironment.mainnet,
              creationTime: record.createdAt,
              sendWalletId: fromWallet.id,
              paymentAddress: order.payinAddress,
              paymentAmount: order.payinAmountSat.toInt(),
              receiveWalletId: state.toWallet?.id,
              receiveAddress: record.destination,
              refundAddress: record.fallback,
              fees: SwapFees(
                boltzFee: (order.payinAmountSat - order.payoutAmountSat)
                    .toInt(),
              ),
            )
            as ChainSwap;

    if (isExpired) {
      emit(
        state.copyWith(orderSwap: record, swap: displaySwap, signedPsbt: ''),
      );
      return;
    }
    final resumable =
        record.localStatus == OrderSwapLocalStatus.readyToBroadcast ||
        record.localStatus == OrderSwapLocalStatus.broadcastUnknown;
    if (!resumable || !record.hasPreparedPayin) return;
    emit(
      state.copyWith(
        orderSwap: record,
        swap: displaySwap,
        signedPsbt: record.signedPayinTransaction!,
        amount: state.bitcoinUnit == BitcoinUnit.sats
            ? record.requestedAmountSat.toString()
            : ConvertAmount.satsToBtc(
                record.requestedAmountSat.toInt(),
              ).toString(),
        receiveAddress: record.destination,
      ),
    );
    _watchExchangeOrderSwap(record.localId);
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
    final wasToWalletChanged = newToWallet != state.toWallet;
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
    if (wasFromWalletChanged || wasToWalletChanged) {
      _invalidateTransactionContract(emit);
    }

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
    _invalidateTransactionContract(emit);
  }

  Future<void> _onSwapCreated(
    TransferSwapCreated event,
    Emitter<TransferState> emit,
  ) async {
    final generation = ++_transactionGeneration;
    await _stopWatchingSwaps();
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
      final balanceSat = state.fromWallet?.balanceSat?.toInt();
      if (balanceSat == null || inputAmountSat > balanceSat) {
        return;
      }

      // A max transfer drains the selected wallet instead of fixing the payin.
      final isMaxSend =
          state.maxAmountSat != null && inputAmountSat == state.maxAmountSat;

      if (!state.isSameChainTransfer) {
        final route = await _getSwapRouteUsecase.execute();
        if (generation != _transactionGeneration) return;
        emit(state.copyWith(swapRoute: route));
        if (route.startsWithBoltz) {
          final boltzFailure = await _createBoltzChainTransfer(
            emit,
            inputAmountSat: inputAmountSat,
            isMaxSend: isMaxSend,
            generation: generation,
          );
          if (boltzFailure == null) return;
          if (!route.fallsBackToExchangeAfter(boltzFailure)) {
            emit(
              state.copyWith(
                swapFailure: boltzFailure.toSwapFailure(
                  amountSat: inputAmountSat,
                ),
              ),
            );
            return;
          }
          log.fine(
            '[Transfer] Boltz unavailable, falling back to the exchange '
            '(${boltzFailure.runtimeType})',
          );
        }
        await _createExchangeChainTransfer(
          emit,
          inputAmountSat: inputAmountSat,
          isMaxSend: isMaxSend,
          generation: generation,
        );
        return;
      }

      final bitcoinWalletId = state.fromWallet!.id;
      final toWallet = state.toWallet;
      if (toWallet == null) {
        emit(
          state.copyWith(
            swapCreationException: SwapCreationException(
              'receive_address_unavailable',
            ),
          ),
        );
        return;
      }
      final String receiveAddress;
      try {
        final address = await _getReceiveAddressUsecase.execute(
          walletId: toWallet.id,
        );
        if (generation != _transactionGeneration) return;
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
      final preparation = await _prepareBitcoinSendUsecase.execute(
        walletId: bitcoinWalletId,
        recipients: [
          if (isMaxSend)
            BitcoinTransactionRecipient.remainder(address: receiveAddress)
          else
            BitcoinTransactionRecipient.fixed(
              address: receiveAddress,
              amountSat: Sats.fromInt(inputAmountSat),
            ),
        ],
        networkFee: selectedFee,

        selectedInputs: state.selectedUtxos.isNotEmpty
            ? state.selectedUtxos
            : null,
        replaceByFee: state.replaceByFee,
      );
      if (generation != _transactionGeneration) return;
      final PreparedBitcoinSend unsignedPsbtAndTxSize;
      switch (preparation) {
        case Ok(:final value):
          unsignedPsbtAndTxSize = value;
        case Err(:final failure):
          emit(
            state.copyWith(
              swapCreationException:
                  failure is WalletInsufficientFundsFailure ||
                      failure is WalletNoSpendableInputsFailure ||
                      failure is WalletSelectedInputsUnavailableFailure
                  ? InsufficientFundsSwapException()
                  : SwapCreationException('bitcoin_transaction_build_failed'),
            ),
          );
          return;
      }

      final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
        walletId: bitcoinWalletId,
        psbt: unsignedPsbtAndTxSize.unsignedPsbt,
      );
      if (generation != _transactionGeneration) return;

      final signedPsbt = signedPsbtAndTxSize.signedPsbt;
      final bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase
          .execute(psbt: signedPsbt);
      if (generation != _transactionGeneration) return;

      emit(
        state.copyWith(
          signedPsbt: signedPsbt,
          bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
          bitcoinTxSize: signedPsbtAndTxSize.txSize,
          receiveAddress: receiveAddress,
          amount: event.amount,
        ),
      );
    } on WalletSpendBlockedException catch (e) {
      if (generation != _transactionGeneration) return;
      emit(
        state.copyWith(
          signedPsbt: '',
          swapCreationException: null,
          swapFailure: SwapSpendBlockedFailure(e.status),
        ),
      );
    } on ConsolidationRequiredException {
      if (generation != _transactionGeneration) return;
      emit(state.copyWith(consolidationRequired: true));
    } catch (e) {
      if (generation != _transactionGeneration) return;
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
      if (generation == _transactionGeneration) {
        emit(state.copyWith(isCreatingSwap: false, continueClicked: false));
      }
    }
  }

  /// Creates a Boltz chain swap and signs the lockup that funds it. Returns
  /// the failure when Boltz could not create the swap, so the caller can
  /// decide on the exchange fallback; nothing is created or signed then.
  /// Once the swap exists every later failure throws, never falls back.
  Future<SwapsFailure?> _createBoltzChainTransfer(
    Emitter<TransferState> emit, {
    required int inputAmountSat,
    required bool isMaxSend,
    required int generation,
  }) async {
    final fromWallet = state.fromWallet;
    if (fromWallet == null) {
      throw SwapCreationException('source_wallet_required');
    }
    if (fromWallet.isHardwareWallet) {
      throw SwapCreationException('hardware_wallet_swap_unavailable');
    }
    if (fromWallet.isLiquid && state.consolidationRequired) {
      throw ConsolidationRequiredException('liquid_consolidation_required');
    }
    final destinationWallet = state.sendToExternal ? null : state.toWallet;
    if (!state.sendToExternal && destinationWallet == null) {
      throw SwapCreationException('destination_wallet_required');
    }
    final externalRecipient = state.sendToExternal
        ? state.externalAddress
        : null;
    if (externalRecipient != null && externalRecipient.isEmpty) {
      throw SwapCreationException('destination_address_required');
    }
    if (externalRecipient != null &&
        (state.externalAddressError != null ||
            !await _receivesOnDestinationChain(
              fromWallet,
              externalRecipient,
            ))) {
      throw SwapCreationException('destination_address_invalid');
    }
    if (generation != _transactionGeneration) return null;
    final swapType = fromWallet.isLiquid
        ? SwapType.liquidToBitcoin
        : SwapType.bitcoinToLiquid;

    var paymentAmountSat = inputAmountSat;
    if (isMaxSend) {
      final networkFee =
          state.selectedFee ??
          (fromWallet.isLiquid
              ? state.liquidNetworkFees?.fastest
              : state.bitcoinNetworkFees?.fastest);
      if (networkFee == null) {
        throw BuildTransactionException('network_fees_unavailable');
      }
      final maxAmountSat = await _boltzMaxAmountSat(
        fromWallet,
        networkFee: networkFee,
      );
      if (generation != _transactionGeneration) return null;
      if (maxAmountSat == null) throw InsufficientFundsSwapException();
      paymentAmountSat = maxAmountSat;
    } else if (state.receiveExactAmount) {
      final limitsAndFees = await _getSwapLimitsAndFeesUsecase.execute(
        swapType,
      );
      if (generation != _transactionGeneration) return null;
      switch (limitsAndFees) {
        case Err(:final failure):
          return failure;
        case Ok(value: (_, final fees)):
          paymentAmountSat = fees.calculateSwapAmountFromReceivableAmount(
            inputAmountSat,
          );
      }
      final knownBalance = fromWallet.balanceSat;
      if (knownBalance == null) throw InsufficientFundsSwapException();
      final availableAmountSat = state.selectedUtxos.isEmpty
          ? knownBalance.toInt()
          : state.selectedUtxoTotalSat;
      if (paymentAmountSat > availableAmountSat) {
        throw InsufficientFundsSwapException();
      }
    }

    final ChainSwapDestination destination;
    if (externalRecipient != null) {
      destination = ToAddress(externalRecipient);
    } else if (destinationWallet != null) {
      destination = ToWallet(destinationWallet.id);
    } else {
      throw SwapCreationException('destination_wallet_required');
    }
    final created = fromWallet.isLiquid
        ? await _createLiquidToBitcoinSwapUsecase.execute(
            sendWalletId: fromWallet.id,
            amountSat: paymentAmountSat,
            destination: destination,
          )
        : await _createBitcoinToLiquidSwapUsecase.execute(
            sendWalletId: fromWallet.id,
            amountSat: paymentAmountSat,
            destination: destination,
          );
    if (generation != _transactionGeneration) return null;
    final ChainSwap swap;
    switch (created) {
      case Err(:final failure):
        return failure;
      case Ok(:final value):
        swap = value;
    }
    _watchBoltzSwap(swap.id);

    final String signedLockup;
    int? bitcoinAbsoluteFeesSat;
    int? liquidAbsoluteFeesSat;
    int? bitcoinTxSize;
    if (fromWallet.isLiquid) {
      final selectedFee = state.selectedFee ?? state.liquidNetworkFees?.fastest;
      if (selectedFee is! RelativeFee) {
        throw BuildTransactionException('network_fees_unavailable');
      }
      final preparation = await _prepareLiquidSendUsecase.execute(
        walletId: fromWallet.id,
        address: swap.paymentAddress,
        amountSat: isMaxSend ? null : swap.paymentAmount,
        feeRate: selectedFee,
        drain: isMaxSend,
      );
      if (generation != _transactionGeneration) return null;
      final String unsignedPset;
      switch (preparation) {
        case Ok(:final value):
          unsignedPset = value;
        case Err(:final failure):
          throw switch (failure) {
            SendConsolidationRequiredFailure() =>
              ConsolidationRequiredException('liquid_consolidation_required'),
            SendInsufficientBalanceFailure() ||
            SendInsufficientFundsForFeesFailure() =>
              InsufficientFundsSwapException(),
            _ => BuildTransactionException('liquid_transaction_build_failed'),
          };
      }
      await _verifyChainSwapAmountSendUsecase.execute(
        psbtOrPset: unsignedPset,
        swap: swap,
        walletId: fromWallet.id,
      );
      if (generation != _transactionGeneration) return null;
      signedLockup = await _signLiquidTxUsecase.execute(
        walletId: fromWallet.id,
        pset: unsignedPset,
      );
      if (generation != _transactionGeneration) return null;
      liquidAbsoluteFeesSat = await _calculateLiquidAbsoluteFeesUsecase.execute(
        pset: signedLockup,
      );
      if (generation != _transactionGeneration) return null;
    } else {
      final selectedFee =
          state.selectedFee ?? state.bitcoinNetworkFees?.fastest;
      if (selectedFee == null) {
        throw BuildTransactionException('network_fees_unavailable');
      }
      final preparation = await _prepareBitcoinSendUsecase.execute(
        walletId: fromWallet.id,
        recipients: [
          if (isMaxSend)
            BitcoinTransactionRecipient.remainder(address: swap.paymentAddress)
          else
            BitcoinTransactionRecipient.fixed(
              address: swap.paymentAddress,
              amountSat: Sats.fromInt(swap.paymentAmount),
            ),
        ],
        networkFee: selectedFee,
        selectedInputs: state.selectedUtxos.isEmpty
            ? null
            : state.selectedUtxos,
        replaceByFee: state.replaceByFee,
      );
      if (generation != _transactionGeneration) return null;
      final PreparedBitcoinSend unsigned;
      switch (preparation) {
        case Ok(:final value):
          unsigned = value;
        case Err(:final failure):
          throw failure is WalletInsufficientFundsFailure ||
                  failure is WalletNoSpendableInputsFailure ||
                  failure is WalletSelectedInputsUnavailableFailure
              ? InsufficientFundsSwapException()
              : BuildTransactionException('bitcoin_transaction_build_failed');
      }
      await _verifyChainSwapAmountSendUsecase.execute(
        psbtOrPset: unsigned.unsignedPsbt,
        swap: swap,
        walletId: fromWallet.id,
      );
      if (generation != _transactionGeneration) return null;
      final signed = await _signBitcoinTxUsecase.execute(
        walletId: fromWallet.id,
        psbt: unsigned.unsignedPsbt,
      );
      if (generation != _transactionGeneration) return null;
      signedLockup = signed.signedPsbt;
      bitcoinTxSize = signed.txSize;
      bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase
          .execute(psbt: signedLockup);
      if (generation != _transactionGeneration) return null;
      if (!_builtFeeClearsRelay(
        stateToUse: state,
        builtFeeSat: bitcoinAbsoluteFeesSat,
        txSize: bitcoinTxSize,
      )) {
        throw BuildTransactionException('built_fee_below_relay_floor');
      }
    }

    emit(
      state.copyWith(
        swap: swap.copyWith(
          fees: swap.fees?.copyWith(
            lockupFee: bitcoinAbsoluteFeesSat ?? liquidAbsoluteFeesSat,
          ),
        ),
        orderSwap: null,
        signedPsbt: signedLockup,
        bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
        liquidAbsoluteFeesSat: liquidAbsoluteFeesSat,
        bitcoinTxSize: bitcoinTxSize,
        receiveAddress: swap.receiveAddress ?? externalRecipient ?? '',
      ),
    );
    return null;
  }

  Future<void> _createExchangeChainTransfer(
    Emitter<TransferState> emit, {
    required int inputAmountSat,
    required bool isMaxSend,
    required int generation,
  }) async {
    final fromWallet = state.fromWallet;
    if (fromWallet == null) {
      throw SwapCreationException('source_wallet_required');
    }
    if (fromWallet.isHardwareWallet) {
      throw SwapCreationException('hardware_wallet_swap_unavailable');
    }
    final orderEnvironment = fromWallet.network.requireHistoricalTestnet()
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
    if (generation != _transactionGeneration) return;
    if (destinationAddress.isEmpty) {
      throw SwapCreationException('destination_address_required');
    }
    final fallbackAddress = (await _getReceiveAddressUsecase.execute(
      walletId: fromWallet.id,
    )).address;
    if (generation != _transactionGeneration) return;
    final isInAmountFixed = isMaxSend || !state.receiveExactAmount;

    final quoteResult = await _getOrderSwapQuoteUsecase.execute(
      environment: orderEnvironment,
      amountSat: BigInt.from(inputAmountSat),
      isInAmountFixed: isInAmountFixed,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
    );
    if (generation != _transactionGeneration) return;
    if (quoteResult case Err(:final failure)) {
      log.warning('[Transfer] quote failed (${failure.runtimeType})');
      emit(state.copyWith(swapFailure: failure));
      return;
    }
    final quote = (quoteResult as Ok<OrderSwapQuote, SwapFailure>).value;
    final availableAmountSat = state.selectedUtxos.isEmpty
        ? fromWallet.balanceSat
        : BigInt.from(state.selectedUtxoTotalSat);
    if (availableAmountSat == null) {
      emit(state.copyWith(swapFailure: const SwapUnexpectedFailure()));
      return;
    }
    if (quote.inAmountSat > availableAmountSat) {
      throw InsufficientFundsSwapException();
    }

    if (!fromWallet.isLiquid) {
      final admission = await _checkSwapSpendAdmissionUsecase.execute(
        fromWallet.id,
      );
      if (generation != _transactionGeneration) return;
      if (admission case Err(:final failure)) {
        emit(state.copyWith(swapFailure: failure));
        return;
      }
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
      quotedCounterpartAmountSat: isInAmountFixed
          ? quote.outAmountSat
          : quote.inAmountSat,
    );
    if (generation != _transactionGeneration) return;
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
              environment: fromWallet.network.requireHistoricalTestnet()
                  ? SwapEnvironment.testnet
                  : SwapEnvironment.mainnet,
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
      final preparation = await _prepareLiquidSendUsecase.execute(
        walletId: fromWallet.id,
        address: order.payinAddress,
        amountSat: isMaxSend ? null : order.payinAmountSat.toInt(),
        feeRate: selectedFee as RelativeFee,
        drain: isMaxSend,
      );
      if (generation != _transactionGeneration) return;
      final String unsignedPset;
      switch (preparation) {
        case Ok(:final value):
          unsignedPset = value;
        case Err(:final failure):
          emit(
            state.copyWith(
              signedPsbt: '',
              consolidationRequired:
                  failure is SendConsolidationRequiredFailure,
              swapCreationException:
                  failure is SendInsufficientBalanceFailure ||
                      failure is SendInsufficientFundsForFeesFailure
                  ? InsufficientFundsSwapException()
                  : SwapCreationException('liquid_transaction_build_failed'),
            ),
          );
          return;
      }
      await _verifyChainSwapAmountSendUsecase.execute(
        psbtOrPset: unsignedPset,
        swap: displaySwap,
        walletId: fromWallet.id,
      );
      if (generation != _transactionGeneration) return;
      signedPayin = await _signLiquidTxUsecase.execute(
        walletId: fromWallet.id,
        pset: unsignedPset,
      );
      if (generation != _transactionGeneration) return;
      liquidAbsoluteFeesSat = await _calculateLiquidAbsoluteFeesUsecase.execute(
        pset: signedPayin,
      );
      if (generation != _transactionGeneration) return;
      isPsbt = false;
    } else {
      final selectedFee =
          state.selectedFee ?? state.bitcoinNetworkFees!.fastest;
      final preparation = await _prepareBitcoinSendUsecase.execute(
        walletId: fromWallet.id,
        recipients: [
          if (isMaxSend)
            BitcoinTransactionRecipient.remainder(address: order.payinAddress)
          else
            BitcoinTransactionRecipient.fixed(
              address: order.payinAddress,
              amountSat: Sats.fromInt(order.payinAmountSat.toInt()),
            ),
        ],
        networkFee: selectedFee,

        selectedInputs: state.selectedUtxos.isEmpty
            ? null
            : state.selectedUtxos,
        replaceByFee: state.replaceByFee,
      );
      if (generation != _transactionGeneration) return;
      final PreparedBitcoinSend unsigned;
      switch (preparation) {
        case Ok(:final value):
          unsigned = value;
        case Err(:final failure):
          emit(
            state.copyWith(
              swapCreationException:
                  failure is WalletInsufficientFundsFailure ||
                      failure is WalletNoSpendableInputsFailure ||
                      failure is WalletSelectedInputsUnavailableFailure
                  ? InsufficientFundsSwapException()
                  : SwapCreationException('bitcoin_transaction_build_failed'),
            ),
          );
          return;
      }
      await _verifyChainSwapAmountSendUsecase.execute(
        psbtOrPset: unsigned.unsignedPsbt,
        swap: displaySwap,
        walletId: fromWallet.id,
      );
      if (generation != _transactionGeneration) return;
      final signed = await _signBitcoinTxUsecase.execute(
        walletId: fromWallet.id,
        psbt: unsigned.unsignedPsbt,
      );
      if (generation != _transactionGeneration) return;
      signedPayin = signed.signedPsbt;
      bitcoinTxSize = signed.txSize;
      bitcoinAbsoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase
          .execute(psbt: signedPayin);
      if (generation != _transactionGeneration) return;
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
    if (generation != _transactionGeneration) return;
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
    final receiveExactAmountChanged = state.receiveExactAmount != event.enabled;
    if (state.sendToExternal == event.enabled && !receiveExactAmountChanged) {
      return;
    }
    emit(
      state.copyWith(
        sendToExternal: event.enabled,
        externalAddress: event.enabled ? state.externalAddress : '',
        externalAddressError: event.enabled ? null : null,
        receiveExactAmount: event.enabled,
      ),
    );
    _invalidateTransactionContract(emit);
  }

  Future<void> _onExternalAddressChanged(
    TransferExternalAddressChanged event,
    Emitter<TransferState> emit,
  ) async {
    if (state.externalAddress == event.address) return;
    // Recipient is part of the cache fingerprint — drop every cached
    // preview when the new value differs from what we had cached against.
    _invalidateTransactionContract(emit);
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
    if (state.receiveExactAmount == event.enabled) return;
    emit(state.copyWith(receiveExactAmount: event.enabled));
    _invalidateTransactionContract(emit);
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
    final wasMaxSelected = state.isMaxSelected;
    // The UTXO set is an unordered selection — compare as sets so a
    // re-emit of the same set (different list order) doesn't invalidate.
    final previousOutpoints = state.selectedUtxos
        .map((utxo) => utxo.outpoint)
        .toSet();
    final nextOutpoints = event.utxos.map((utxo) => utxo.outpoint).toSet();
    final utxosChanged = !setEquals(previousOutpoints, nextOutpoints);
    emit(
      state.copyWith(
        selectedUtxos: event.utxos,
        signedPsbt: utxosChanged ? '' : state.signedPsbt,
        buildTransactionException: utxosChanged
            ? null
            : state.buildTransactionException,
      ),
    );
    if (!utxosChanged) return;

    var generation = ++_transactionGeneration;
    if (wasMaxSelected) {
      _invalidateTransactionContract(emit);
    } else {
      _clearBitcoinFeePreviews(emit);
    }
    generation = _transactionGeneration;
    final fromWallet = state.fromWallet;
    if (fromWallet != null) {
      final maxAmountSat = await getMaxAmountSat(fromWallet);
      if (generation != _transactionGeneration) return;
      emit(
        state.copyWith(
          maxAmountSat: maxAmountSat,
          amount: wasMaxSelected && maxAmountSat != null
              ? state.bitcoinUnit == BitcoinUnit.sats
                    ? maxAmountSat.toString()
                    : ConvertAmount.satsToBtc(maxAmountSat).toString()
              : state.amount,
        ),
      );
    }
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
      final spendableOutpoints = utxos
          .where((utxo) => !utxo.isFrozen)
          .map((utxo) => utxo.outpoint)
          .toSet();
      final selectionInvalid =
          state.selectedUtxos.isNotEmpty &&
          state.selectedUtxos.any(
            (utxo) => !spendableOutpoints.contains(utxo.outpoint),
          );
      if (selectionInvalid) _transactionGeneration++;
      emit(
        state.copyWith(
          utxos: utxos,
          signedPsbt: selectionInvalid ? '' : state.signedPsbt,
          buildTransactionException: selectionInvalid
              ? BuildTransactionException(selectedCoinsUnavailableCode)
              : state.buildTransactionException,
        ),
      );
      if (utxosChanged) _clearBitcoinFeePreviews(emit);
    } catch (e) {
      log.severe(
        message: 'Error loading UTXOs',
        error: e.runtimeType,
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
      recipients: [
        if (state.isMaxSelected)
          BitcoinTransactionRecipient.remainder(address: shape.address)
        else
          BitcoinTransactionRecipient.fixed(
            address: shape.address,
            amountSat: Sats.fromInt(shape.amountSat),
          ),
      ],
      networkFee: event.fee,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
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
      recipients: [
        if (state.isMaxSelected)
          BitcoinTransactionRecipient.remainder(address: shape.address)
        else
          BitcoinTransactionRecipient.fixed(
            address: shape.address,
            amountSat: Sats.fromInt(shape.amountSat),
          ),
      ],
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
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
  /// - same-chain transfer: use the destination wallet's receive address
  ///   resolved by the last build and the input amount, mirroring what
  ///   _rebuildTransactionWithState builds.
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
    _transactionGeneration++;
    emit(
      state.copyWith(
        feePreviewCache: BitcoinFeePreviewCache.empty,
        signedPsbt: '',
        isCreatingSwap: false,
        continueClicked: false,
      ),
    );
  }

  /// A contract-shape change makes a prepared remote swap belong to an old
  /// transfer, not merely an old fee/PSBT preview.
  void _invalidateTransactionContract(Emitter<TransferState> emit) {
    _clearBitcoinFeePreviews(emit);
    emit(state.copyWith(swap: null, orderSwap: null, receiveAddress: null));
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
    // A lockup whose broadcast is still being confirmed may already be on
    // chain: rebuilding against the same swap could fund it twice.
    if (stateToUse.swap?.hasPendingLockup ?? false) {
      emit(state.copyWith(swapFailure: const SwapLockupPendingFailure()));
      return;
    }
    if (stateToUse.signedPsbt.isEmpty &&
        stateToUse.swap == null &&
        !stateToUse.isSameChainTransfer) {
      return;
    }

    final generation = ++_transactionGeneration;
    emit(
      stateToUse.copyWith(
        signedPsbt: '',
        buildTransactionException: null,
        swapFailure: null,
      ),
    );

    try {
      final fromWallet = stateToUse.fromWallet!;
      if (fromWallet.isLiquid) return;

      // Reuse the modal-preview PSBT for the user's selected fee tile.
      // BDK's coin selection is randomized — rebuilding here would
      // broadcast a different fee than the modal displayed.
      final cachedSlot = stateToUse.feePreviewCache.slotFor(
        stateToUse.selectedFeeOption,
      );
      final cachedPsbt = cachedSlot.unsignedPsbt;
      final cachedTxSize = cachedSlot.txSize;
      final canUseCache = cachedSlot.isCacheReady;
      if (canUseCache && stateToUse.selectedUtxos.isNotEmpty) {
        try {
          await _validateBitcoinSelectionUsecase.execute(
            walletId: fromWallet.id,
            selectedInputs: stateToUse.selectedUtxos,
          );
        } on NoSpendableUtxoException {
          throw BuildTransactionException(selectedCoinsUnavailableCode);
        } on InsufficientFundsException {
          throw BuildTransactionException(selectedCoinsUnavailableCode);
        }
        if (generation != _transactionGeneration) return;
      }
      if (stateToUse.isSameChainTransfer) {
        final receiveAddress = stateToUse.receiveAddress;
        if (receiveAddress == null || receiveAddress.isEmpty) return;

        final inputAmountSat = stateToUse.inputAmountSat;
        final isMaxSend =
            stateToUse.maxAmountSat != null &&
            inputAmountSat == stateToUse.maxAmountSat;
        final selectedFee =
            stateToUse.selectedFee ?? stateToUse.bitcoinNetworkFees!.fastest;

        final preparation =
            canUseCache && cachedPsbt != null && cachedTxSize != null
            ? Ok<PreparedBitcoinSend, WalletFailure>((
                unsignedPsbt: cachedPsbt,
                txSize: cachedTxSize,
                isToSelf: true,
                recipientAmountsSat: cachedSlot.recipientAmountsSat
                    .map(Sats.fromInt)
                    .toList(),
              ))
            : await _prepareBitcoinSendUsecase.execute(
                walletId: fromWallet.id,
                recipients: [
                  if (isMaxSend)
                    BitcoinTransactionRecipient.remainder(
                      address: receiveAddress,
                    )
                  else
                    BitcoinTransactionRecipient.fixed(
                      address: receiveAddress,
                      amountSat: Sats.fromInt(inputAmountSat),
                    ),
                ],
                networkFee: selectedFee,

                selectedInputs: stateToUse.selectedUtxos.isNotEmpty
                    ? stateToUse.selectedUtxos
                    : null,
                replaceByFee: stateToUse.replaceByFee,
              );
        if (generation != _transactionGeneration) return;
        final PreparedBitcoinSend unsignedPsbtAndTxSize;
        switch (preparation) {
          case Ok(:final value):
            unsignedPsbtAndTxSize = value;
          case Err(:final failure):
            emit(
              stateToUse.copyWith(
                signedPsbt: '',
                buildTransactionException: BuildTransactionException(
                  failure is WalletSelectedInputsUnavailableFailure ||
                          (failure is WalletNoSpendableInputsFailure &&
                              stateToUse.selectedUtxos.isNotEmpty)
                      ? selectedCoinsUnavailableCode
                      : failure is WalletInsufficientFundsFailure &&
                            stateToUse.selectedUtxos.isNotEmpty
                      ? selectedCoinsInsufficientCode
                      : transactionRebuildFailedCode,
                ),
              ),
            );
            return;
        }

        final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
          walletId: fromWallet.id,
          psbt: unsignedPsbtAndTxSize.unsignedPsbt,
        );
        if (generation != _transactionGeneration) return;

        final bitcoinAbsoluteFeesSat =
            await _calculateBitcoinAbsoluteFeesUsecase.execute(
              psbt: signedPsbtAndTxSize.signedPsbt,
            );
        if (generation != _transactionGeneration) return;

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
      } else if (stateToUse.swap case final ChainSwap swap) {
        final orderSwap = stateToUse.orderSwap;
        final inputAmountSat = stateToUse.inputAmountSat;
        final isMaxSend =
            stateToUse.maxAmountSat != null &&
            inputAmountSat == stateToUse.maxAmountSat;
        final selectedFee =
            stateToUse.selectedFee ?? stateToUse.bitcoinNetworkFees!.fastest;

        final preparation =
            canUseCache && cachedPsbt != null && cachedTxSize != null
            ? Ok<PreparedBitcoinSend, WalletFailure>((
                unsignedPsbt: cachedPsbt,
                txSize: cachedTxSize,
                isToSelf: false,
                recipientAmountsSat: cachedSlot.recipientAmountsSat
                    .map(Sats.fromInt)
                    .toList(),
              ))
            : await _prepareBitcoinSendUsecase.execute(
                walletId: fromWallet.id,
                recipients: [
                  if (isMaxSend)
                    BitcoinTransactionRecipient.remainder(
                      address: swap.paymentAddress,
                    )
                  else
                    BitcoinTransactionRecipient.fixed(
                      address: swap.paymentAddress,
                      amountSat: Sats.fromInt(swap.paymentAmount),
                    ),
                ],
                networkFee: selectedFee,

                selectedInputs: stateToUse.selectedUtxos.isNotEmpty
                    ? stateToUse.selectedUtxos
                    : null,
                replaceByFee: stateToUse.replaceByFee,
              );
        if (generation != _transactionGeneration) return;
        final PreparedBitcoinSend unsignedPsbtAndTxSize;
        switch (preparation) {
          case Ok(:final value):
            unsignedPsbtAndTxSize = value;
          case Err(:final failure):
            emit(
              stateToUse.copyWith(
                signedPsbt: '',
                buildTransactionException: BuildTransactionException(
                  failure is WalletSelectedInputsUnavailableFailure ||
                          (failure is WalletNoSpendableInputsFailure &&
                              stateToUse.selectedUtxos.isNotEmpty)
                      ? selectedCoinsUnavailableCode
                      : failure is WalletInsufficientFundsFailure &&
                            stateToUse.selectedUtxos.isNotEmpty
                      ? selectedCoinsInsufficientCode
                      : transactionRebuildFailedCode,
                ),
              ),
            );
            return;
        }

        await _verifyChainSwapAmountSendUsecase.execute(
          psbtOrPset: unsignedPsbtAndTxSize.unsignedPsbt,
          swap: swap,
          walletId: fromWallet.id,
        );
        if (generation != _transactionGeneration) return;

        final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
          walletId: fromWallet.id,
          psbt: unsignedPsbtAndTxSize.unsignedPsbt,
        );
        if (generation != _transactionGeneration) return;

        final bitcoinAbsoluteFeesSat =
            await _calculateBitcoinAbsoluteFeesUsecase.execute(
              psbt: signedPsbtAndTxSize.signedPsbt,
            );
        if (generation != _transactionGeneration) return;

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

        OrderSwapRecord? prepared;
        if (orderSwap != null) {
          final replaceResult = await _replacePreparedOrderSwapPayinUsecase
              .execute(
                localId: orderSwap.localId,
                signedTransaction: signedPsbtAndTxSize.signedPsbt,
                isPsbt: true,
              );
          if (generation != _transactionGeneration) return;
          prepared = switch (replaceResult) {
            Ok(:final value) => value,
            Err(:final failure) => throw BuildTransactionException(
              failure.logMessage ?? failure.runtimeType.toString(),
            ),
          };
        }

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
    } on WalletSpendBlockedException catch (e) {
      if (generation != _transactionGeneration) return;
      emit(
        state.copyWith(
          signedPsbt: '',
          buildTransactionException: null,
          swapFailure: SwapSpendBlockedFailure(e.status),
        ),
      );
    } catch (e) {
      if (generation != _transactionGeneration) return;
      log.severe(
        message: 'Error rebuilding transaction',
        error: e.runtimeType,
        trace: StackTrace.current,
      );
      emit(
        stateToUse.copyWith(
          signedPsbt: '',
          buildTransactionException: BuildTransactionException(
            e is BuildTransactionException
                ? e.message
                : e is NoSpendableUtxoException &&
                      stateToUse.selectedUtxos.isNotEmpty
                ? selectedCoinsUnavailableCode
                : e is InsufficientFundsException &&
                      stateToUse.selectedUtxos.isNotEmpty
                ? selectedCoinsInsufficientCode
                : transactionRebuildFailedCode,
          ),
        ),
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

      final fromWallet = state.fromWallet;
      if (fromWallet == null) {
        emit(state.copyWith(swapFailure: const SwapInvalidStateFailure()));
        return;
      }
      final toWallet = state.toWallet;
      if (!fromWallet.isLiquid && state.selectedUtxos.isNotEmpty) {
        await _validateBitcoinSelectionUsecase.execute(
          walletId: fromWallet.id,
          selectedInputs: state.selectedUtxos,
        );
      }

      String txId;
      final orderSwap = state.orderSwap;
      if (orderSwap != null) {
        if (orderSwap.localStatus == OrderSwapLocalStatus.broadcastUnknown) {
          final refreshResult = await _refreshOrderSwapUsecase.execute(
            orderSwap.localId,
          );
          if (refreshResult case Err(:final failure)) {
            emit(state.copyWith(swapFailure: failure));
            return;
          }
          final refreshed =
              (refreshResult as Ok<OrderSwapRecord, SwapFailure>).value;
          final payinStatus = refreshed.order?.payinStatus.trim().toLowerCase();
          if (payinStatus == 'completed') {
            emit(state.copyWith(orderSwap: refreshed));
            return;
          }
        }
        if (!fromWallet.isLiquid) {
          final admission = await _checkSwapSpendAdmissionUsecase.execute(
            fromWallet.id,
          );
          if (admission case Err(:final failure)) {
            emit(state.copyWith(swapFailure: failure));
            return;
          }
        }
        // Admission can change after this pre-check. The gated broadcast is
        // authoritative; a refusal there must preserve broadcast uncertainty.
        final broadcastStartResult = await _markOrderSwapBroadcastUnknownUsecase
            .execute(orderSwap.localId);
        if (broadcastStartResult case Err(:final failure)) {
          emit(state.copyWith(swapFailure: failure));
          return;
        }
        final broadcasting =
            (broadcastStartResult as Ok<OrderSwapRecord, SwapFailure>).value;
        // Persisted uncertainty remains conservative even if admission refuses:
        // an earlier submission may still be awaiting observation.
        emit(state.copyWith(orderSwap: broadcasting));
        final signedPayin = broadcasting.signedPayinTransaction;
        final payinIsPsbt = broadcasting.payinIsPsbt;
        if (signedPayin == null || payinIsPsbt == null) {
          emit(state.copyWith(swapFailure: const SwapInvalidStateFailure()));
          return;
        }
        if (fromWallet.isLiquid) {
          txId = await _broadcastLiquidTxUsecase.execute(signedPayin);
        } else {
          txId = await _broadcastBitcoinTxUsecase.execute(
            signedPayin,
            isPsbt: payinIsPsbt,
            network: fromWallet.network,
            walletId: fromWallet.id,
          );
        }
        final broadcastResult = await _markOrderSwapPayinBroadcastUsecase
            .execute(localId: orderSwap.localId, transactionId: txId);
        if (broadcastResult case Err(:final failure)) {
          emit(state.copyWith(swapFailure: failure, txId: txId));
          return;
        }
        final broadcast =
            (broadcastResult as Ok<OrderSwapRecord, SwapFailure>).value;
        final displaySwap = state.swap as ChainSwap;
        emit(
          state.copyWith(
            orderSwap: broadcast,
            swap: displaySwap.copyWith(status: SwapStatus.paid, sendTxid: txId),
            txId: txId,
          ),
        );
        unawaited(_syncWalletAfterBroadcast(fromWallet.id));
        return;
      } else if (state.swap case final ChainSwap swap
          when !state.isSameChainTransfer) {
        if (!fromWallet.isLiquid) {
          final admission = await _checkSwapSpendAdmissionUsecase.execute(
            fromWallet.id,
          );
          if (admission case Err(:final failure)) {
            emit(state.copyWith(swapFailure: failure));
            return;
          }
        }
        // Stored before the broadcast so an unclear outcome is settled from
        // this exact transaction and the swap can never be funded twice.
        switch (await _recordPendingSwapLockupUsecase.execute(
          swapId: swap.id,
          signedTx: signedPsbt,
        )) {
          case Ok(value: final ChainSwap pending):
            emit(state.copyWith(swap: pending));
          case Ok():
            break;
          case Err():
            emit(
              state.copyWith(
                swapFailure: const SwapInvalidStateFailure(
                  'lockup not stored before broadcast',
                ),
              ),
            );
            return;
        }
        try {
          txId = fromWallet.isLiquid
              ? await _broadcastLiquidTxUsecase.execute(signedPsbt)
              : await _broadcastBitcoinTxUsecase.execute(
                  signedPsbt,
                  isPsbt: true,
                  network: fromWallet.network,
                  walletId: fromWallet.id,
                );
        } on WalletSpendBlockedException {
          final _ = await _dropPendingSwapLockupUsecase.execute(swap.id);
          rethrow;
        } on BroadcastTransactionException catch (e) {
          final category = BroadcastFailureCategory.of(e);
          if (category == BroadcastFailureCategory.rejected ||
              category == BroadcastFailureCategory.authorization) {
            final _ = await _dropPendingSwapLockupUsecase.execute(swap.id);
          }
          rethrow;
        }
        final recorded = await _recordSwapLockupUsecase.execute(
          swapId: swap.id,
          txid: txId,
          lockupFeeSat: state.absoluteFees,
        );
        emit(
          state.copyWith(
            swap: switch (recorded) {
              Ok(value: final ChainSwap funded) => funded,
              _ => swap.copyWith(status: SwapStatus.paid, sendTxid: txId),
            },
            txId: txId,
          ),
        );
        unawaited(_syncWalletAfterBroadcast(fromWallet.id));
        return;
      } else if (state.isSameChainTransfer) {
        txId = await _broadcastBitcoinTxUsecase.execute(
          signedPsbt,
          isPsbt: true,
          network: fromWallet.network,
          walletId: fromWallet.id,
        );
        unawaited(
          _syncWalletsAfterBroadcast([
            fromWallet.id,
            if (toWallet != null) toWallet.id,
          ]),
        );
      } else {
        return;
      }
      emit(state.copyWith(txId: txId));
    } on WalletSpendBlockedException catch (e) {
      emit(
        state.copyWith(
          confirmTransactionException: null,
          swapFailure: SwapSpendBlockedFailure(e.status),
        ),
      );
    } on NoSpendableUtxoException {
      _emitSelectionUnavailable(emit);
    } on InsufficientFundsException {
      _emitSelectionUnavailable(emit);
    } on ValidateBitcoinSelectionException {
      _emitSelectionUnavailable(emit);
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

  // Pre-broadcast confirmation validation failed: the staged selection can no
  // longer be spent as previewed, so drop the fee previews and surface the
  // unavailable-selection error for the user to re-review.
  void _emitSelectionUnavailable(Emitter<TransferState> emit) {
    _clearBitcoinFeePreviews(emit);
    emit(
      state.copyWith(
        buildTransactionException: BuildTransactionException(
          selectedCoinsUnavailableCode,
        ),
      ),
    );
  }

  Future<void> _syncWalletAfterBroadcast(String walletId) async {
    try {
      await _getWalletUsecase.execute(walletId, sync: true);
    } catch (_) {
      log.warning('Failed to sync wallet after transfer broadcast');
    }
  }

  Future<void> _syncWalletsAfterBroadcast(List<String> walletIds) async {
    for (final walletId in walletIds) {
      await _syncWalletAfterBroadcast(walletId);
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
      final knownBalance = fromWallet.balanceSat;
      if (knownBalance == null) return null;
      if (knownBalance <= BigInt.zero) return 0;
      final networkFee = fromWallet.isLiquid
          ? state.liquidNetworkFees!.fastest
          : state.bitcoinNetworkFees!.fastest;
      final receiveAddress = await _getReceiveAddressUsecase.execute(
        walletId: fromWallet.id,
      );
      return await _drainableAmountSat(
        fromWallet,
        address: receiveAddress.address,
        networkFee: networkFee,
      );
    } catch (e) {
      log.severe(
        message: 'Error getting max amount sat in transfer bloc',
        error: e.runtimeType,
        trace: StackTrace.current,
      );
      return null;
    }
  }

  /// A Boltz lockup is a Taproot output, larger than the wallet's own
  /// receive output, so a max transfer to Boltz is priced against a Taproot
  /// address of the same network at the fee the lockup is built with.
  /// Otherwise the drained lockup falls a few sats short of the swap amount
  /// and [VerifyChainSwapAmountSendUsecase] rejects it.
  /// Whether [address] can receive the claim of a chain swap from
  /// [fromWallet]: the other chain, on the same network.
  Future<bool> _receivesOnDestinationChain(
    Wallet fromWallet,
    String address,
  ) async {
    try {
      final request = await _detectBitcoinStringUsecase.execute(data: address);
      final onDestinationChain = switch (request) {
        Bip21PaymentRequest(:final network) =>
          fromWallet.isLiquid ? network.isBitcoin : network.isLiquid,
        _ =>
          fromWallet.isLiquid
              ? request.isBitcoinAddress
              : request.isLiquidAddress,
      };
      return onDestinationChain &&
          request.isTestnet != fromWallet.network.isMainnet;
    } on Exception {
      return false;
    }
  }

  Future<int?> _boltzMaxAmountSat(
    Wallet fromWallet, {
    required NetworkFee networkFee,
  }) async {
    final lockupAddress = switch (fromWallet.network) {
      Network.bitcoinMainnet =>
        'bc1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskq9pj5n4',
      Network.bitcoinTestnet =>
        'tb1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskqjfymf6',
      Network.liquidMainnet =>
        'lq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0we046p4uqlt24',
      Network.liquidTestnet =>
        'tlq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0w78z5h5l8mzyz',
      Network.bitcoinRegtest || Network.liquidRegtest => null,
    };
    if (lockupAddress == null) return null;
    return _drainableAmountSat(
      fromWallet,
      address: lockupAddress,
      networkFee: networkFee,
    );
  }

  Future<int?> _drainableAmountSat(
    Wallet fromWallet, {
    required String address,
    required NetworkFee networkFee,
  }) async {
    final knownBalance = fromWallet.balanceSat;
    if (knownBalance == null) return null;
    int absoluteFees;
    if (!fromWallet.isLiquid) {
      final preparation = await _prepareBitcoinSendUsecase.execute(
        walletId: fromWallet.id,
        recipients: [BitcoinTransactionRecipient.remainder(address: address)],
        networkFee: networkFee,
        selectedInputs: state.selectedUtxos,
      );

      final PreparedBitcoinSend dummyDrainTxInfo;
      switch (preparation) {
        case Ok(:final value):
          dummyDrainTxInfo = value;
        case Err():
          return null;
      }
      absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
        psbt: dummyDrainTxInfo.unsignedPsbt,
      );

      log.info("Absolute fees: $absoluteFees");
    } else {
      if (networkFee is! RelativeFee) {
        throw BuildTransactionException('network_fees_unavailable');
      }
      final dummyResult = await _prepareLiquidSendUsecase.execute(
        walletId: fromWallet.id,
        address: address,
        feeRate: networkFee,
        drain: true,
      );

      final String dummyPset;
      switch (dummyResult) {
        case Ok(:final value):
          dummyPset = value;
        case Err():
          return null;
      }
      absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
        pset: dummyPset,
      );
      log.info("Absolute fees: $absoluteFees");
    }

    final selectedBalanceSat = state.selectedUtxos.fold(
      0,
      (sum, utxo) => sum + utxo.amountSat.toInt(),
    );
    final balanceSat = state.selectedUtxos.isEmpty
        ? knownBalance.toInt()
        : selectedBalanceSat;
    final maxAmountSat = balanceSat - absoluteFees;
    return maxAmountSat < 0 ? 0 : maxAmountSat;
  }

  bool _isInsufficientFundsException(Object e) {
    return e is InsufficientFundsSwapException ||
        e is InsufficientFundsException;
  }

  Future<void> _onOrderSwapUpdated(
    TransferOrderSwapUpdated event,
    Emitter<TransferState> emit,
  ) async {
    if (event.result case Err(:final failure)) {
      emit(state.copyWith(swapFailure: failure));
      return;
    }
    final orderSwap = (event.result as Ok<OrderSwapRecord, SwapFailure>).value;
    final currentSwap = state.swap;
    if (currentSwap is! ChainSwap ||
        state.orderSwap?.localId != orderSwap.localId) {
      return;
    }
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
      unawaited(_syncWalletAfterBroadcast(state.fromWallet!.id));
      final destinationWalletId = orderSwap.destinationWalletId;
      if (destinationWalletId != null) {
        unawaited(_syncWalletAfterBroadcast(destinationWalletId));
      }
    }
  }

  Future<void> _onBoltzSwapUpdated(
    TransferBoltzSwapUpdated event,
    Emitter<TransferState> emit,
  ) async {
    final updated = event.swap;
    final current = state.swap;
    if (updated is! ChainSwap || current == null || current.id != updated.id) {
      return;
    }
    emit(
      state.copyWith(
        swap: state.txId.isEmpty
            ? current.copyWith(status: updated.status)
            : updated,
      ),
    );
    if (updated.status == SwapStatus.completed ||
        updated.status == SwapStatus.refunded) {
      unawaited(_syncWalletAfterBroadcast(updated.sendWalletId));
      final receiveWalletId = updated.receiveWalletId;
      if (updated.status == SwapStatus.completed && receiveWalletId != null) {
        unawaited(_syncWalletAfterBroadcast(receiveWalletId));
      }
      await _boltzSwapSubscription?.cancel();
      _boltzSwapSubscription = null;
    }
  }

  Future<void> _stopWatchingSwaps() async {
    await _orderSwapSubscription?.cancel();
    _orderSwapSubscription = null;
    await _boltzSwapSubscription?.cancel();
    _boltzSwapSubscription = null;
  }

  void _watchBoltzSwap(String swapId) {
    _boltzSwapSubscription?.cancel();
    _boltzSwapSubscription = _watchSwapUsecase
        .execute(swapId)
        .listen((swap) => add(TransferEvent.boltzSwapUpdated(swap)));
  }

  void _watchExchangeOrderSwap(String localId) {
    _orderSwapSubscription?.cancel();
    _orderSwapSubscription = _watchOrderSwapUsecase
        .execute(localId)
        .listen((result) => add(TransferEvent.orderSwapUpdated(result)));
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
        exchangeRate: s.exchangeRate,
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
