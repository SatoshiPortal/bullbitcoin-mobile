import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart'
    show BroadcastTransactionException;
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/core/widgets/fees/fee_modal_controller.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState>
    implements FeeModalActions, FeeModalViewState {
  SendCubit({
    this._wallet,
    required this._labelsFacade,
    required this._bestWalletUsecase,
    required this._detectBitcoinStringUsecase,
    required this._getSettingsUsecase,
    required this._convertSatsToCurrencyAmountUsecase,
    required this._getNetworkFeesUsecase,
    required this._getWalletUtxosUsecase,
    required this._getAvailableCurrenciesUsecase,
    required this._prepareBitcoinSendUsecase,
    required this._prepareLiquidSendUsecase,
    required this._sendWithPayjoinUsecase,
    required this._watchPayjoinUsecase,
    required this._getWalletsUsecase,
    required this._getWalletUsecase,
    required this._createSendSwapUsecase,
    required this._getSendSwapQuoteUsecase,
    required this._createSendCrossChainSwapUsecase,
    required this._getSendCrossChainQuoteUsecase,
    required this._resolveLightningAddressUsecase,
    required this._updateSendSwapPayinUsecase,
    required this._watchSendSwapUsecase,
    required this._updatePaidSendSwapUsecase,
    required this._getSwapLimitsUsecase,
    required this._watchFinishedWalletSyncsUsecase,
    required this._signBitcoinTxUsecase,
    required this._signLiquidTxUsecase,
    required this._broadcastBitcoinTxUsecase,
    required this._broadcastLiquidTxUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
    required this._calculateLiquidPsetSizeUsecase,
    required this._watchWalletTransactionByTxIdUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._updateSendSwapLockupFeesUsecase,
    required this._verifyChainSwapAmountSendUsecase,
    required this._previewBitcoinFeeUsecase,
    required this._previewBitcoinFeePresetsUsecase,
    required this._checkLiquidConsolidationUsecase,
    required this._getSendPayjoinEnabledUsecase,
  }) : super(const SendState());

  /// Distinct user-defined labels for the suggestion chips in the label
  /// bottom sheet. Wraps [LabelsFacade.fetchDistinctLabels] so widgets
  /// don't need to reach into the locator.
  Future<Set<String>> fetchDistinctLabels() =>
      _labelsFacade.fetchDistinctLabels();

  // ignore: unused_field
  final Wallet? _wallet;
  final LabelsFacade _labelsFacade;
  final SelectBestWalletUsecase _bestWalletUsecase;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final GetSendPayjoinEnabledUsecase _getSendPayjoinEnabledUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetWalletUsecase _getWalletUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CalculateLiquidPsetSizeUsecase _calculateLiquidPsetSizeUsecase;
  final CreateSendSwapUsecase _createSendSwapUsecase;
  final GetSendSwapQuoteUsecase _getSendSwapQuoteUsecase;
  final CreateSendCrossChainSwapUsecase _createSendCrossChainSwapUsecase;
  final GetSendCrossChainQuoteUsecase _getSendCrossChainQuoteUsecase;
  final ResolveLightningAddressUsecase _resolveLightningAddressUsecase;
  final UpdateSendSwapPayinUsecase _updateSendSwapPayinUsecase;
  final WatchSendSwapUsecase _watchSendSwapUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTxUsecase;
  final SendWithPayjoinUsecase _sendWithPayjoinUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final UpdatePaidSendSwapUsecase _updatePaidSendSwapUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;

  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final UpdateSendSwapLockupFeesUsecase _updateSendSwapLockupFeesUsecase;
  final VerifyChainSwapAmountSendUsecase _verifyChainSwapAmountSendUsecase;
  final PreviewBitcoinFeeUsecase _previewBitcoinFeeUsecase;
  final PreviewBitcoinFeePresetsUsecase _previewBitcoinFeePresetsUsecase;
  final CheckLiquidConsolidationUsecase _checkLiquidConsolidationUsecase;

  StreamSubscription<OrderSwapRecord>? _orderSwapSubscription;
  StreamSubscription<Wallet>? _selectedWalletSyncingSubscription;
  StreamSubscription<WalletTransaction>? _txSubscription;
  StreamSubscription<PayjoinSession>? _payjoinSubscription;

  /// Monotonic token bumped by [clearBitcoinFeePreviews]. A preview build
  /// captures it before its `await` and re-checks before writing results
  /// back; if any input-shape change cleared the cache mid-flight the
  /// token moved on and the stale build is discarded instead of
  /// re-populating an emptied cache (which could otherwise stage a PSBT
  /// built for the previous tx shape for broadcast).
  int _bitcoinPreviewEpoch = 0;

  @override
  Future<void> close() async {
    await (
      _orderSwapSubscription?.cancel() ?? Future.value(),
      _selectedWalletSyncingSubscription?.cancel() ?? Future.value(),
      _txSubscription?.cancel() ?? Future.value(),
      _payjoinSubscription?.cancel() ?? Future.value(),
    ).wait;
    return super.close();
  }

  /// LWK and the RBF builder are rate-only at the SDK boundary. When the user
  /// picked an absolute custom fee, we need a tx vsize to convert the absolute
  /// amount back to a rate. We get vsize by building a placeholder PSET at
  /// Liquid's minrelayfee — vsize is essentially independent of the fee rate,
  /// so the placeholder is accurate to within a single vbyte.
  Future<RelativeFee> _resolveLiquidFeeRate({
    required NetworkFee fee,
    required String walletId,
    required String address,
    required int? amountSat,
    required bool drain,
  }) async {
    if (fee is RelativeFee) return fee;
    if (fee is! AbsoluteFee) {
      throw StateError('Unexpected NetworkFee variant: $fee');
    }
    final placeholderPset = await _prepareLiquidSendUsecase.execute(
      walletId: walletId,
      address: address,
      amountSat: amountSat,
      feeRate: const RelativeFee(25),
      drain: drain,
    );
    final vsize = await _calculateLiquidPsetSizeUsecase.execute(
      pset: placeholderPset,
    );
    return NetworkFee.relativeFromAbsoluteAndVsize(
      absoluteSats: fee.sats,
      vsize: vsize,
    );
  }

  void clearFailure() => emit(state.copyWith(failure: null));

  void backClicked() {
    if (state.step == SendStep.address) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.amount) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.confirm) {
      emit(state.copyWith(step: SendStep.amount, failure: null));
    }
  }

  Future<void> loadWalletWithRatesAndFees() async {
    try {
      final wallets = await _getWalletsUsecase.execute();
      emit(
        state.copyWith(wallets: wallets.where((w) => !w.isWatchOnly).toList()),
      );
      await getCurrencies();
      await getExchangeRate();
      await loadFees();
    } catch (e) {
      emit(state.copyWith(failure: SendUnexpectedFailure(e.toString())));
    }
  }

  /// Called when a payment request is detected directly from the scanner
  Future<void> onScannedPaymentRequest(
    String scannedRawPaymentRequest,
    PaymentRequest? paymentRequest,
  ) async {
    clearFailure();
    final sanitizedText = scannedRawPaymentRequest.trim().replaceAll(
      RegExp(r'^["\"]+|["\"]+$'),
      '',
    );
    final recipientChanged =
        state.paymentRequest != paymentRequest ||
        state.scannedRawPaymentRequest != scannedRawPaymentRequest;
    emit(
      state.copyWith(
        scannedRawPaymentRequest: scannedRawPaymentRequest,
        copiedRawPaymentRequest: sanitizedText,
        paymentRequest: paymentRequest,
      ),
    );
    // Recipient is part of the cache fingerprint — a different address
    // means a different output script in the PSBT. Skip the clear when
    // nothing actually changed so the modal doesn't re-shimmer on a
    // no-op scan.
    if (recipientChanged) clearBitcoinFeePreviews();
    await continueOnAddressConfirmed();
  }

  /// Called when text is pasted or entered manually
  Future<void> onChangedText(String text) async {
    try {
      clearFailure();
      final sanitizedText = text.trim().replaceAll(
        RegExp(r'^["\"]+|["\"]+$'),
        '',
      );
      final paymentRequest = await _detectBitcoinStringUsecase.execute(
        data: sanitizedText,
      );
      final recipientChanged = state.paymentRequest != paymentRequest;
      emit(
        state.copyWith(
          copiedRawPaymentRequest: sanitizedText,
          paymentRequest: paymentRequest,
        ),
      );
      // Same invalidation reason as onScannedPaymentRequest — recipient
      // changed. Skip when paste/typing resolves to the same paymentRequest.
      if (recipientChanged) clearBitcoinFeePreviews();
    } catch (e) {
      final recipientCleared = state.paymentRequest != null;
      emit(
        state.copyWith(
          copiedRawPaymentRequest: text,
          paymentRequest: null,
          // Don't show exception if text field is clear
          failure: text.isNotEmpty
              ? const SendInvalidPaymentRequestFailure()
              : null,
        ),
      );
      if (recipientCleared) clearBitcoinFeePreviews();
    }
  }

  Future<void> continueOnAddressConfirmed() async {
    try {
      emit(state.copyWith(loadingBestWallet: true));
      await unifiedBip21Prioritization();

      if (!state.hasValidPaymentRequest) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            failure: state.scannedRawPaymentRequest.isNotEmpty
                ? const SendInvalidPaymentRequestFailure(isUnsupportedQr: true)
                : const SendInvalidPaymentRequestFailure(),
          ),
        );
        return;
      }

      if (state.paymentRequest!.isBolt11) {
        final paymentRequest = state.paymentRequest! as Bolt11PaymentRequest;
        if (paymentRequest.expiresAt <=
            DateTime.now().millisecondsSinceEpoch ~/ 1000) {
          emit(
            state.copyWith(
              loadingBestWallet: false,
              failure: const SendInvoiceExpiredFailure(),
            ),
          );
          return;
        }
        emit(state.copyWith(lightningInvoice: paymentRequest));
      }

      // [CHAIN SWAP LIFECYCLE — Step 1: trigger]
      // SelectBestWalletUsecase picks a same-network wallet with sufficient
      // funds first. A chain swap is only triggered when:
      //   (a) no same-network wallet has enough balance, so a wallet from the
      //       OTHER network is chosen (BTC <-> L-BTC), OR
      //   (b) the user explicitly pre-selected a different-network wallet via
      //       `_wallet`.
      // The `state.isChainSwap` getter (see send_state.dart) flips true when
      // selectedWallet.network does not match the payment request's network.
      final wallet =
          _wallet ??
          _bestWalletUsecase.execute(
            wallets: state.wallets,
            request: state.paymentRequest!,
            amountSat: state.paymentRequest!.amountSat,
          );

      final sendType = SendType.from(state.paymentRequest!);

      // Pre-populate label from the embedded invoice description or BIP21 label
      // if the user hasn't manually set one already.
      final embeddedLabel = switch (state.paymentRequest!) {
        Bolt11PaymentRequest(description: final d) when d.isNotEmpty => d,
        Bip21PaymentRequest(label: final l) when l.isNotEmpty => l,
        _ => null,
      };
      if (embeddedLabel != null && state.label.isEmpty) {
        emit(state.copyWith(label: embeddedLabel));
      }

      await _setSelectedWallet(wallet, manual: false);
      emit(state.copyWith(sendType: sendType));
      await loadFees();
      if (state.blocksSwapDueToHardwareWallet) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            failure: const SendHardwareWalletFailure(),
          ),
        );
        return;
      }

      if (state.paymentRequest!.isBolt11) {
        final paymentRequest = state.paymentRequest! as Bolt11PaymentRequest;
        if (paymentRequest.amountSat == 0) {
          emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
          return;
        }
        emit(state.copyWith(creatingSwap: true));
        if (!await loadSendSwapQuote(
          wallet: wallet,
          amountSat: BigInt.from(paymentRequest.amountSat),
        )) {
          emit(state.copyWith(creatingSwap: false, loadingBestWallet: false));
          return;
        }
        if (!await hasBalance()) {
          emit(
            state.copyWith(
              failure: const SendInsufficientBalanceFailure(),
              creatingSwap: false,
              loadingBestWallet: false,
            ),
          );
          return;
        }
        switch (await _createSendSwapUsecase.execute(
          walletId: wallet.id,
          invoice: paymentRequest,
          amountSat: paymentRequest.amountSat,
          note: state.label,
        )) {
          case Ok(:final value):
            await _continueWithLightningOrder(value);
          case Err(:final failure):
            emit(
              state.copyWith(
                creatingSwap: false,
                failure: failure,
                loadingBestWallet: false,
              ),
            );
        }
        return;
      }
      if (state.paymentRequest!.isBip21) {
        if (state.paymentRequest!.amountSat == null) {
          emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        } else {
          await handleChainSwap();
          if (state.swapAmountAboveLimit ||
              state.swapAmountBelowLimit ||
              state.failure != null) {
            return;
          }
          await createTransaction();
        }
        return;
      }
      if (state.paymentRequest!.isLnAddress) {
        emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
      } else {
        emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        return;
      }
    } catch (e) {
      if (e is NotEnoughFundsException) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            failure: const SendInsufficientBalanceFailure(),
            creatingSwap: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            failure: SendInvalidPaymentRequestFailure(logMessage: e.toString()),
            loadingBestWallet: false,
            creatingSwap: false,
          ),
        );
      }
    }
  }

  // Creates an exact-output Exchange order before building its funding tx.
  Future<void> handleChainSwap() async {
    final isChainSwap =
        (state.sendType == SendType.liquid &&
            !state.selectedWallet!.isLiquid) ||
        state.sendType == SendType.bitcoin && state.selectedWallet!.isLiquid ||
        state.isChainSwap;
    if (isChainSwap) {
      if (state.sendMax) {
        emit(
          state.copyWith(
            amountConfirmedClicked: false,
            loadingBestWallet: false,
            failure: const SendSwapCreationFailure(
              'Send max is unavailable for Exchange cross-chain swaps',
            ),
          ),
        );
        return;
      }
      final wallet = state.selectedWallet!;
      final amountSat = state.paymentRequest!.amountSat ?? state.inputAmountSat;
      final quoteResult = await _getSendCrossChainQuoteUsecase.execute(
        wallet: wallet,
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: false,
      );
      final OrderSwapQuote quote;
      switch (quoteResult) {
        case Ok(:final value):
          quote = value;
        case Err(:final failure):
          emit(
            state.copyWith(
              amountConfirmedClicked: false,
              loadingBestWallet: false,
              failure: failure,
            ),
          );
          return;
      }
      if (quote.inAmountSat > BigInt.from(state.spendableBalanceSat)) {
        emit(
          state.copyWith(
            amountConfirmedClicked: false,
            loadingBestWallet: false,
            failure: const SendInsufficientBalanceFailure(),
          ),
        );
        return;
      }
      emit(state.copyWith(creatingSwap: true, lightningQuote: quote));
      final destinationAddress = state.paymentRequest!.isBip21
          ? (state.paymentRequest! as Bip21PaymentRequest).address
          : state.paymentRequestAddress;
      switch (await _createSendCrossChainSwapUsecase.execute(
        walletId: wallet.id,
        destinationAddress: destinationAddress,
        destinationIsTestnet: state.paymentRequest!.isTestnet,
        amountSat: amountSat,
        isInAmountFixed: false,
        note: state.label.isEmpty ? null : state.label,
      )) {
        case Ok(:final value):
          _watchOrderSwap(value.localId);
          emit(
            state.copyWith(
              lightningOrder: value,
              confirmedAmountSat: value.order!.payoutAmountSat.toInt(),
              creatingSwap: false,
            ),
          );
        case Err(:final failure):
          emit(
            state.copyWith(
              amountConfirmedClicked: false,
              creatingSwap: false,
              loadingBestWallet: false,
              failure: failure,
            ),
          );
          return;
      }
    }
    emit(
      state.copyWith(
        // Amountless external addresses carry no request amount; fall back to
        // the entered amount so the confirm headline never flashes 0 sats
        // before createTransaction settles it.
        confirmedAmountSat:
            state.paymentRequest!.amountSat ?? state.inputAmountSat,
        step: SendStep.confirm,
        loadingBestWallet: false,
      ),
    );
  }

  Future<bool> loadSendSwapQuote({
    required Wallet wallet,
    required BigInt amountSat,
  }) async {
    switch (await _getSendSwapQuoteUsecase.execute(
      wallet: wallet,
      amountSat: amountSat,
    )) {
      case Ok(:final value):
        emit(state.copyWith(lightningQuote: value, failure: null));
        return true;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return false;
    }
  }

  Future<void> loadSwapLimits() async {
    final paymentRequest = state.paymentRequest;
    final loadLnSwapLimits =
        paymentRequest?.isBolt11 == true || paymentRequest?.isLnAddress == true;
    if (loadLnSwapLimits) {
      final (
        (liquidSwapLimits, liquidSwapFees),
        (bitcoinSwapLimits, bitcoinSwapFees),
      ) = await (
        _getSwapLimitsUsecase.execute(type: SwapType.liquidToLightning),
        _getSwapLimitsUsecase.execute(type: SwapType.bitcoinToLightning),
      ).wait;
      emit(
        state.copyWith(
          liquidLnSwapLimits: liquidSwapLimits,
          liquidLnSwapFees: liquidSwapFees,
          bitcoinLnSwapLimits: bitcoinSwapLimits,
          bitcoinLnSwapFees: bitcoinSwapFees,
        ),
      );
    }
    if (state.requireChainSwap) {
      final (
        (lbtcToBtcSwapLimits, lbtcToBtcSwapFees),
        (btcToLbtcSwapLimits, btcToLbtcSwapFees),
      ) = await (
        _getSwapLimitsUsecase.execute(type: SwapType.liquidToBitcoin),
        _getSwapLimitsUsecase.execute(type: SwapType.bitcoinToLiquid),
      ).wait;
      emit(
        state.copyWith(
          btcToLbtcChainSwapLimits: btcToLbtcSwapLimits,
          btcToLbtcChainSwapFees: btcToLbtcSwapFees,
          lbtcToBtcChainSwapLimits: lbtcToBtcSwapLimits,
          lbtcToBtcChainSwapFees: lbtcToBtcSwapFees,
        ),
      );
    }
  }

  void setSelectedSwapLimits() {
    if (state.selectedWallet == null) return;

    final walletNetwork = state.selectedWallet!.network;
    switch (walletNetwork) {
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        if (state.paymentRequest?.isBolt11 == true ||
            state.paymentRequest?.isLnAddress == true) {
          emit(
            state.copyWith(
              selectedSwapFees: state.bitcoinLnSwapFees,
              selectedSwapLimits: state.bitcoinLnSwapLimits,
            ),
          );
        } else {
          emit(
            state.copyWith(
              selectedSwapFees: state.btcToLbtcChainSwapFees,
              selectedSwapLimits: state.btcToLbtcChainSwapLimits,
            ),
          );
        }
      case Network.liquidMainnet:
      case Network.liquidTestnet:
        if (state.paymentRequest?.isBolt11 == true ||
            state.paymentRequest?.isLnAddress == true) {
          emit(
            state.copyWith(
              selectedSwapFees: state.liquidLnSwapFees,
              selectedSwapLimits: state.liquidLnSwapLimits,
            ),
          );
        } else {
          emit(
            state.copyWith(
              selectedSwapFees: state.lbtcToBtcChainSwapFees,
              selectedSwapLimits: state.lbtcToBtcChainSwapLimits,
            ),
          );
        }
    }
  }

  Future<bool> hasBalance() async {
    if ((state.selectedWallet == null && state.paymentRequest == null) ||
        state.paymentRequest == null) {
      return false;
    }
    final paymentRequest = state.paymentRequest!;
    // D7: frozen coins are never spendable, so every balance check compares
    // against the spendable balance (wallet balance − frozen total), not the
    // raw wallet balance. Degrades to the full balance on Liquid / before
    // utxos load (nothing frozen there).
    final spendableSat = state.spendableBalanceSat;
    switch (paymentRequest) {
      case Bolt11PaymentRequest _:
        final totalPayable =
            state.lightningQuote?.inAmountSat.toInt() ??
            paymentRequest.amountSat;
        return spendableSat > totalPayable;

      case LnAddressPaymentRequest _:
        final totalPayable =
            state.lightningQuote?.inAmountSat.toInt() ?? state.inputAmountSat;
        return spendableSat > totalPayable;

      default:
        return spendableSat >=
            (state.inputAmountSat + (state.absoluteFees ?? 0));
    }
  }

  Future<void> getCurrencies() async {
    final settings = await _getSettingsUsecase.execute();
    final payjoinEnabled = await _getSendPayjoinEnabledUsecase.execute();

    final (exchangeRate, fiatCurrencies) = await (
      _convertSatsToCurrencyAmountUsecase.execute(),
      _getAvailableCurrenciesUsecase.execute(),
    ).wait;

    final bitcoinUnit = settings.bitcoinUnit;
    final fiatCurrency = settings.currencyCode;

    emit(
      state.copyWith(
        fiatCurrencyCodes: fiatCurrencies,
        fiatCurrencyCode: fiatCurrency,
        exchangeRate: exchangeRate,
        bitcoinUnit: bitcoinUnit,
        inputAmountCurrencyCode: bitcoinUnit.code,
        payjoinGloballyEnabled: payjoinEnabled,
      ),
    );
  }

  Future<void> amountChanged({String? amount, bool isMax = false}) async {
    try {
      clearFailure();
      String validatedAmount;

      if (amount == null) {
        if (!isMax) {
          throw Exception('Amount should be provided if max is not selected');
        }

        // To avoid converting rounding errors when max is set, set the
        //  input currency to bitcoin unit if it was fiat
        if (state.isInputAmountFiat) {
          final bitcoinUnit = state.bitcoinUnit ?? BitcoinUnit.btc;
          emit(state.copyWith(inputAmountCurrencyCode: bitcoinUnit.code));
        }

        // D7: Max drains only spendable coins (frozen are excluded at build),
        // so the Max amount must reflect spendable balance, not the raw
        // wallet balance — otherwise Max overshoots by the frozen total.
        final spendableSat = state.spendableBalanceSat;
        if (state.inputAmountCurrencyCode == BitcoinUnit.sats.code) {
          validatedAmount = spendableSat.toString();
        } else {
          final spendableBtc = ConvertAmount.satsToBtc(spendableSat);
          validatedAmount = spendableBtc.toStringAsFixed(8);
        }
      } else {
        if (amount.isEmpty) {
          validatedAmount = amount;
        } else if (state.isInputAmountFiat) {
          final amountFiat = double.tryParse(amount);
          final isDecimalPoint = amount == '.';

          validatedAmount = amountFiat == null && !isDecimalPoint
              ? state.amount
              : amount;
        } else if (state.inputAmountCurrencyCode == BitcoinUnit.sats.code) {
          // If the amount is in sats, make sure it is a valid BigInt and do not
          //  allow a decimal point.
          final amountSats = BigInt.tryParse(amount);
          final hasDecimals = amount.contains('.');

          validatedAmount =
              amountSats == null ||
                  hasDecimals ||
                  amountSats > ConversionConstants.maxSatsAmount
              ? state.amount
              : amountSats.toString();
        } else {
          // If the amount is in BTC, make sure it is a valid double and
          //  do not allow more than 8 decimal places.
          final amountBtc = double.tryParse(amount);
          final decimals = amount.split('.').last.length;
          final isDecimalPoint = amount == '.';

          validatedAmount =
              (amountBtc == null && !isDecimalPoint) ||
                  decimals > BitcoinUnit.btc.decimals ||
                  (amountBtc != null &&
                      amountBtc >
                          ConversionConstants.maxBitcoinAmount.toDouble())
              ? state.amount
              : amount;
        }
      }

      final amountChanged =
          state.amount != validatedAmount || state.sendMax != isMax;
      emit(state.copyWith(amount: validatedAmount, sendMax: isMax));
      // Amount is part of the cache fingerprint — any change invalidates
      // every previously-built preview PSBT. Without this clear, the user
      // can open the fee modal at amount A, change the amount to B
      // without re-opening the modal, and `createTransaction` reads back
      // a stale cached PSBT for A. Skip the clear when the validator
      // bounced the input (validatedAmount == state.amount).
      if (amountChanged) clearBitcoinFeePreviews();
      // Don't update wallet when MAX is clicked to avoid changing network and triggering chain swaps
      if (!isMax) {
        await updateBestWallet();
      }
    } catch (e) {
      emit(state.copyWith(failure: SendUnexpectedFailure(e.toString())));
    }
  }

  Future<void> onCurrencyChanged(String currencyCode) async {
    double exchangeRate = state.exchangeRate;
    String fiatCurrencyCode = state.fiatCurrencyCode;
    bool payjoinGloballyEnabled = state.payjoinGloballyEnabled;

    if (![BitcoinUnit.btc.code, BitcoinUnit.sats.code].contains(currencyCode)) {
      // If the currency is a fiat currency, retrieve the exchange rate and replace
      //  the current exchange rate and fiat currency code.
      fiatCurrencyCode = currencyCode;
      exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: currencyCode,
      );
    } else {
      // If the currency is a bitcoin unit, set the fiat currency and exchange
      //  rate back to the currency from the settings.
      final currencyValues = await Future.wait([
        _getSettingsUsecase.execute(),
        _convertSatsToCurrencyAmountUsecase.execute(),
        _getSendPayjoinEnabledUsecase.execute(),
      ]);

      final settings = currencyValues[0] as SettingsEntity;
      fiatCurrencyCode = settings.currencyCode;
      exchangeRate = currencyValues[1] as double;
      payjoinGloballyEnabled = currencyValues[2] as bool;
    }

    emit(
      state.copyWith(
        inputAmountCurrencyCode: currencyCode,
        fiatCurrencyCode: fiatCurrencyCode,
        exchangeRate: exchangeRate,
        payjoinGloballyEnabled: payjoinGloballyEnabled,
        amount: '', // Clear the amount when changing the currency
      ),
    );
  }

  Future<void> updateBestWallet() async {
    if (state.paymentRequest == null || state.selectedWallet == null) return;
    // Respect the user's manual wallet pick — auto-switching it silently
    // can route funds from the wrong wallet (e.g. cold → hot). See #1918.
    if (state.isWalletManuallySelected) return;

    emit(state.copyWith(loadingBestWallet: true));
    try {
      final wallet =
          _wallet ??
          _bestWalletUsecase.execute(
            wallets: state.wallets,
            request: state.paymentRequest!,
            amountSat: state.inputAmountSat,
          );
      await _setSelectedWallet(wallet, manual: false);
    } catch (_) {
      // swallow — auto-pick is best-effort; the user's current selection stays.
    } finally {
      emit(state.copyWith(loadingBestWallet: false));
    }
  }

  void noteChanged(String note) => emit(state.copyWith(label: note));

  Future<void> onAmountConfirmed() async {
    clearFailure();

    if (state.blocksSwapDueToHardwareWallet) {
      emit(state.copyWith(failure: const SendHardwareWalletFailure()));
      return;
    }

    emit(
      state.copyWith(
        amountConfirmedClicked: true,
        confirmedAmountSat: state.inputAmountSat,
      ),
    );

    if (state.sendType == SendType.lightning) {
      final Bolt11PaymentRequest invoice;
      final paymentRequest = state.paymentRequest;
      if (paymentRequest is Bolt11PaymentRequest) {
        invoice = paymentRequest;
      } else {
        final invoiceResult = await _resolveLightningAddressUsecase.execute(
          lightningAddress: state.paymentRequestAddress,
          amountSat: state.inputAmountSat,
        );
        switch (invoiceResult) {
          case Ok(:final value):
            invoice = value;
          case Err(:final failure):
            emit(
              state.copyWith(failure: failure, amountConfirmedClicked: false),
            );
            return;
        }
      }
      emit(
        state.copyWith(
          lightningInvoice: invoice,
          label: state.label.isEmpty && invoice.description.isNotEmpty
              ? invoice.description
              : state.label,
        ),
      );
      if (!await loadSendSwapQuote(
        wallet: state.selectedWallet!,
        amountSat: BigInt.from(state.inputAmountSat),
      )) {
        emit(state.copyWith(amountConfirmedClicked: false));
        return;
      }
      if (!await hasBalance()) {
        emit(
          state.copyWith(
            failure: const SendInsufficientBalanceFailure(
              'Not enough funds to cover amount and fees',
            ),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }
      emit(state.copyWith(creatingSwap: true));
      switch (await _createSendSwapUsecase.execute(
        walletId: state.selectedWallet!.id,
        invoice: invoice,
        amountSat: state.inputAmountSat,
        note: state.label,
      )) {
        case Ok(:final value):
          await _continueWithLightningOrder(value);
        case Err(:final failure):
          emit(
            state.copyWith(
              creatingSwap: false,
              failure: failure,
              amountConfirmedClicked: false,
              step: SendStep.amount,
            ),
          );
      }
      return;
    }

    if (state.isChainSwap) {
      await handleChainSwap();
      if (state.swapAmountAboveLimit ||
          state.swapAmountBelowLimit ||
          state.failure != null) {
        return;
      }
      await createTransaction();
    }
    // updateSwapLockupFees();

    if (state.sendType == SendType.liquid ||
        state.sendType == SendType.bitcoin) {
      await createTransaction();
    }
    if (!await hasBalance()) {
      emit(
        state.copyWith(
          failure: const SendInsufficientBalanceFailure(
            'Not enough funds to cover amount and fees',
          ),
          amountConfirmedClicked: false,
        ),
      );
      return;
    }
    if (state.failure is! SendTransactionBuildFailure) {
      emit(
        state.copyWith(
          step: SendStep.confirm,
          confirmedAmountSat: state.inputAmountSat,
          amountConfirmedClicked: false,
        ),
      );
    } else {
      emit(state.copyWith(amountConfirmedClicked: false));
    }
  }

  Future<void> _continueWithLightningOrder(OrderSwapRecord order) async {
    final txId = order.localPayinTransactionId;
    emit(
      state.copyWith(
        lightningOrder: order,
        confirmedAmountSat: order.order?.payoutAmountSat.toInt(),
        txId: txId,
        creatingSwap: false,
        amountConfirmedClicked: false,
        loadingBestWallet: false,
        step: sendStepForOrderSwapStatus(order.localStatus),
        failure:
            order.localStatus == OrderSwapLocalStatus.creating ||
                order.localStatus == OrderSwapLocalStatus.creationUnknown
            ? const SendSwapCreationFailure('Swap creation outcome is unknown')
            : null,
      ),
    );
    _watchOrderSwap(order.localId);
    if (txId != null) {
      _watchWalletTransactionByTxId(
        walletId: state.selectedWallet!.id,
        txId: txId,
      );
    }
    if (order.localStatus == OrderSwapLocalStatus.awaitingUserConfirmation ||
        order.localStatus == OrderSwapLocalStatus.preparingPayin) {
      await createTransaction();
    }
  }

  Future<void> loadUtxos() async {
    if (state.selectedWallet == null) return;

    try {
      final utxos = await _getWalletUtxosUsecase.execute(
        walletId: state.selectedWallet!.id,
      );
      // A wallet sync can change the available coins. Any cached preview
      // PSBT was built against the prior UTXO set, so drop it — otherwise
      // a sync landing mid-flow could leave a stale PSBT staged for
      // broadcast. Guarded so a no-op refresh doesn't needlessly
      // re-shimmer an open modal.
      final utxosChanged = !setEquals(state.utxos.toSet(), utxos.toSet());
      // Proactively flag consolidation for Liquid wallets whose UTXO count is
      // over the threshold, so the card shows before a build is attempted. The
      // ConsolidationRequiredException remains the backstop on the build path.
      // Routed through CheckLiquidConsolidationUsecase (the same check the
      // consolidation banner uses) rather than re-deriving the comparison
      // here from a possibly-differently-filtered UTXO list, so this and the
      // banner can never disagree about whether the wallet needs
      // consolidating.
      final consolidationRequired =
          (state.selectedWallet?.isLiquid ?? false) &&
          await _checkLiquidConsolidationUsecase.execute(
            walletId: state.selectedWallet!.id,
          );
      emit(
        state.copyWith(
          utxos: utxos,
          consolidationRequired: consolidationRequired,
        ),
      );
      if (utxosChanged) clearBitcoinFeePreviews();
    } catch (e) {
      emit(state.copyWith(failure: SendUnexpectedFailure(e.toString())));
    }
  }

  Future<void> utxoSelected(WalletUtxo utxo) async {
    final selectedUtxos = List.of(state.selectedUtxos);
    if (selectedUtxos.contains(utxo)) {
      selectedUtxos.remove(utxo);
    } else {
      selectedUtxos.add(utxo);
    }
    emit(state.copyWith(selectedUtxos: selectedUtxos));
    // UTXO set is part of the cache fingerprint — different inputs
    // produce a different PSBT, even at the same rate.
    clearBitcoinFeePreviews();
    await createTransaction();
    // updateSwapLockupFees();
  }

  Future<void> replaceByFeeChanged(bool replaceByFee) async {
    if (state.replaceByFee == replaceByFee) return;
    emit(state.copyWith(replaceByFee: replaceByFee));
    // RBF flag changes the sequence numbers in the PSBT — flipping it
    // makes the cached PSBT semantically wrong even if vsize matches.
    clearBitcoinFeePreviews();
    await createTransaction();
  }

  Future<void> loadFees() async {
    if (state.selectedWallet == null) return;
    try {
      final bitcoinFees = await _getNetworkFeesUsecase.execute(isLiquid: false);
      final liquidFees = await _getNetworkFeesUsecase.execute(isLiquid: true);
      final ratesChanged =
          state.bitcoinFeesList != bitcoinFees ||
          state.liquidFeesList != liquidFees;
      // Default to Fastest only on the first successful load. Once a
      // selection exists, a fee refresh must preserve it — silently
      // resetting to Fastest would clobber a committed tier (or custom).
      final isFirstLoad = state.bitcoinFeesList == null;
      emit(
        state.copyWith(
          bitcoinFeesList: bitcoinFees,
          liquidFeesList: liquidFees,
          selectedFeeOption: isFirstLoad
              ? FeeSelection.fastest
              : state.selectedFeeOption,
        ),
      );
      // Mempool rates changed — preset PSBTs were built at the old
      // rates and are now stale. Custom slot is keyed by the typed rate
      // so it's unaffected, but `clearBitcoinFeePreviews` is whole-batch
      // by design and the next modal open will rebuild it. Skip the
      // clear when the API returned identical rates (which freezed
      // equality on FeeOptions makes cheap to check).
      if (ratesChanged) clearBitcoinFeePreviews();
    } catch (e) {
      emit(state.copyWith(failure: SendUnexpectedFailure(e.toString())));
    }
  }

  Future<void> feeOptionSelected(FeeSelection feeSelection) async {
    // Clears any in-flight custom-fee arm — picking a preset is itself a
    // commit, no rollback needed.
    emit(
      state.copyWith(
        selectedFeeOption: feeSelection,
        armPriorSelection: null,
        armPriorCustomFee: null,
      ),
    );
    await createTransaction();
    // updateSwapLockupFees();
  }

  Future<void> customFeesChanged(NetworkFee fee) async {
    // Real commit — discard the arm snapshot (no rollback path needed
    // anymore) and trigger the PSBT rebuild.
    emit(
      state.copyWith(
        customFee: fee,
        selectedFeeOption: FeeSelection.custom,
        armPriorSelection: null,
        armPriorCustomFee: null,
      ),
    );

    await createTransaction();
    // updateSwapLockupFees();
  }

  /// Called when the user enters a value in the custom-fee modal. Eagerly
  /// commits `selectedFeeOption: custom` + the typed [fee] so the preset
  /// tiles visually deselect, without triggering a `createTransaction`
  /// rebuild (the rebuild happens once on submit via [customFeesChanged]).
  ///
  /// On the first call, snapshots the prior selection so [disarmCustomFee]
  /// can roll back if the user closes the modal without submitting. Later
  /// calls only update `customFee` — the snapshot stays pinned to the
  /// pre-arm state.
  @override
  void armCustomFee(NetworkFee fee) {
    // The typed rate just changed — the cached custom-slot PSBT is for
    // the old rate and would broadcast the wrong fee. Clear it; the
    // next debounced previewBitcoinCustomFee will rebuild.
    //
    // Bump the epoch too: a previewBitcoinCustomFee for the PRIOR rate may
    // still be in flight (it captured the old epoch before its await). If
    // it lands after this clear it must be discarded — otherwise a slower
    // stale build could overwrite the slot for the new rate and stage the
    // wrong (or below-floor) PSBT for broadcast.
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
          customFee: fee,
          bitcoinAbsoluteFeesSat: null,
          feePreviewCache: cleared,
        ),
      );
    } else {
      emit(
        state.copyWith(
          customFee: fee,
          bitcoinAbsoluteFeesSat: null,
          feePreviewCache: cleared,
        ),
      );
    }
  }

  /// Rolls back `selectedFeeOption` and `customFee` to the values snapshotted
  /// by [armCustomFee], if the arm is still active. No-op once cleared
  /// (the user picked a preset, which fires [feeOptionSelected]).
  @override
  void disarmCustomFee() {
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

  /// Called by the fee modal's parent when the user dismisses the modal
  /// without picking a preset. Replaces the old explicit "Confirm Custom
  /// Fee" button — typing IS the selection, dismissing IS the apply.
  ///
  /// If the cubit is armed AND the typed value is at or above the 0.1
  /// sat/vB floor → commit via [customFeesChanged] (which also triggers
  /// `createTransaction`). If below the floor → roll back via
  /// [disarmCustomFee]. If not armed (user never typed) → no-op.
  @override
  Future<void> finalizeArmedCustomFee() async {
    if (state.armPriorSelection == null) return;
    final fee = state.customFee;
    final txSize = state.bitcoinTxSize ?? 140;
    if (fee != null &&
        fee.aboveMinRelay(
          txSize: txSize,
          floorSatPerKwu: state.bitcoinFeesList?.minRelay.satPerKwu,
        )) {
      await customFeesChanged(fee);
    } else {
      disarmCustomFee();
    }
  }

  /// Builds an unsigned PSBT at the typed custom fee rate and reads its
  /// real `psbt.fee()`. No signing, no swap-state updates — pure "what
  /// would BDK pay for this rate against the current wallet/recipient/
  /// amount/UTXOs". Result lands in `state.feePreviewCache.custom`; the
  /// UI shimmers while `feePreviewCache.customLoading` is true.
  ///
  /// Debounced from the widget (~350 ms after the user pauses typing).
  /// If the user keeps typing or dismisses the modal, the result is
  /// silently discarded — `mounted`-style state checks aren't needed
  /// because every subsequent armCustomFee/preview kicks the loading
  /// flag and the latest emit wins.
  Future<void> previewBitcoinCustomFee(NetworkFee fee) async {
    if (state.selectedWallet == null) return;
    if (state.selectedWallet!.isLiquid) return; // Liquid path handled elsewhere
    final address = _previewBitcoinAddress();
    final amount = _previewBitcoinAmountSat();
    if (address == null || amount == null) {
      log.info(
        '[fee-preview] skip — address=$address amount=$amount '
        'wallet=${state.selectedWallet?.id}',
      );
      return;
    }
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache.copyWith(customLoading: true),
      ),
    );
    final epoch = _bitcoinPreviewEpoch;
    log.info(
      '[fee-preview] start customRate=${fee is RelativeFee ? fee.satPerVbyte : fee.value} '
      'amount=$amount drain=${state.sendMax} '
      'selectedInputs=${state.selectedUtxos.length} rbf=${state.replaceByFee}',
    );
    final slot = await _previewBitcoinFeeUsecase.execute(
      walletId: state.selectedWallet!.id,
      address: address,
      networkFee: fee,
      amountSat: amount,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
      drain: state.sendMax,
    );
    // An input-shape change cleared the cache while we were building —
    // discard this now-stale result instead of repopulating an emptied
    // slot (which could stage a PSBT for the prior shape at commit).
    if (epoch != _bitcoinPreviewEpoch) {
      log.info('[fee-preview] discarded — inputs changed mid-build');
      return;
    }
    if (slot.isCacheReady) {
      log.info(
        '[fee-preview] done rate=${fee is RelativeFee ? fee.satPerVbyte : fee.value} '
        '→ vsize=${slot.txSize} realFee=${slot.feeSat} sats — cached for commit',
      );
    } else {
      // Use case already logged the underlying error; emit shows shimmer
      // gone + no preview value so the UI doesn't pretend a fee exists.
      log.info(
        '[fee-preview] done rate=${fee is RelativeFee ? fee.satPerVbyte : fee.value} '
        '→ no PSBT (build failed)',
      );
    }
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache
            .withSlot(FeeSelection.custom, slot)
            .copyWith(customLoading: false),
      ),
    );
  }

  /// Fires three prepare-only builds in parallel (Fastest / Economic /
  /// Slow) via [PreviewBitcoinFeePresetsUsecase], which dedupes by rate
  /// — same-rate presets share one PSBT so a quiet mempool can't make
  /// Slow look more expensive than Economic at the same 1 sat/vB.
  Future<void> loadBitcoinFeePresetPreviews() async {
    if (state.selectedWallet == null) return;
    if (state.selectedWallet!.isLiquid) return;
    final presets = state.bitcoinFeesList;
    if (presets == null) return;
    final address = _previewBitcoinAddress();
    final amount = _previewBitcoinAmountSat();
    if (address == null || amount == null) return;
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache.copyWith(presetsLoading: true),
      ),
    );
    final epoch = _bitcoinPreviewEpoch;
    log.info(
      '[fee-presets] start amount=$amount drain=${state.sendMax} '
      'selectedInputs=${state.selectedUtxos.length} rbf=${state.replaceByFee}',
    );
    final slots = await _previewBitcoinFeePresetsUsecase.execute(
      presets: presets,
      walletId: state.selectedWallet!.id,
      address: address,
      amountSat: amount,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
      drain: state.sendMax,
    );
    // Discard if an input-shape change emptied the cache mid-build (see
    // previewBitcoinCustomFee).
    if (epoch != _bitcoinPreviewEpoch) {
      log.info('[fee-presets] discarded — inputs changed mid-build');
      return;
    }
    log.info(
      '[fee-presets] done '
      'fastest=${slots[FeeSelection.fastest]?.feeSat} '
      'economic=${slots[FeeSelection.economic]?.feeSat} '
      'slow=${slots[FeeSelection.slow]?.feeSat}',
    );
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

  /// Clear all preview state — call when underlying inputs change
  /// (wallet, recipient, amount, UTXO selection) so we don't display
  /// stale fees for a different tx shape.
  void clearBitcoinFeePreviews() {
    _bitcoinPreviewEpoch++;
    emit(state.copyWith(feePreviewCache: BitcoinFeePreviewCache.empty));
  }

  /// Recipient address for preview builds. Mirrors what
  /// createTransaction picks but skips swap-creation logic — previews
  /// can use any plausible address for the wallet's network since
  /// vsize doesn't depend on the address bytes once the script type
  /// matches.
  String? _previewBitcoinAddress() {
    if (state.lightningOrder?.order != null) {
      return state.lightningOrder!.order!.payinAddress;
    }
    if (state.chainSwap != null) return state.chainSwap!.paymentAddress;
    final pr = state.paymentRequest;
    if (pr is Bip21PaymentRequest) return pr.address;
    if (state.paymentRequestAddress.isNotEmpty) {
      return state.paymentRequestAddress;
    }
    return null;
  }

  int? _previewBitcoinAmountSat() {
    if (state.lightningOrder?.order != null) {
      return state.lightningOrder!.order!.payinAmountSat.toInt();
    }
    if (state.chainSwap != null) return state.chainSwap!.paymentAmount;
    final input = state.inputAmountSat;
    if (input > 0) return input;
    // A BIP21 URI with an embedded amount sets confirmedAmountSat but leaves
    // state.amount (→ inputAmountSat) empty. createTransaction builds from
    // confirmedAmountSat, so the preview must use the same source — otherwise
    // previews are skipped (modal shimmers forever) and the cache stays empty
    // for that payment class.
    final confirmed = state.confirmedAmountSat;
    if (confirmed != null && confirmed > 0) return confirmed;
    return null;
  }

  // [CHAIN SWAP LIFECYCLE — Step 3: build the funding tx]
  // When state.chainSwap is set, this builds the tx that funds the Boltz
  // lockup. For sendMax chain swaps, drain=true is passed down so the prepare
  // usecase drains the wallet to swap.paymentAddress — this is the SECOND
  // drain (the first was Step 2a). The dummy in Step 2a is P2TR by design,
  // matching Boltz's P2TR lockup, so dummyFees == realFees and the drained
  // output equals swap.paymentAmount. If Boltz ever switches lockup script
  // type the dummies in Step 2a must be updated to match, otherwise Step 3b
  // will fire.
  Future<void> createTransaction() async {
    try {
      if (state.bitcoinFeesList == null || state.liquidFeesList == null) {
        await loadFees();
        if (state.bitcoinFeesList == null || state.liquidFeesList == null) {
          return;
        }
      }
      clearFailure();
      // Clear the previous build's absolute fee before loadUtxos so the UI
      // doesn't briefly pair a stale Bitcoin fee with newly-changed inputs
      // (rate / amount / utxo selection). The getter falls back to the
      // rate × txSize prediction until the rebuild emits a fresh value.
      emit(
        state.copyWith(buildingTransaction: true, bitcoinAbsoluteFeesSat: null),
      );
      await loadUtxos();
      final address = state.lightningOrder?.order != null
          ? state.lightningOrder!.order!.payinAddress
          : (state.chainSwap != null)
          ? state.chainSwap!.paymentAddress
          : state.paymentRequest != null &&
                state.paymentRequest is Bip21PaymentRequest
          ? (state.paymentRequest! as Bip21PaymentRequest).address
          : state.paymentRequestAddress;
      final amount = state.lightningOrder?.order != null
          ? state.lightningOrder!.order!.payinAmountSat.toInt()
          : (state.chainSwap != null)
          ? state.chainSwap!.paymentAmount
          : state.confirmedAmountSat;
      // Fees can be selectedFee as it defaults to Fastest
      if (state.selectedWallet!.network.isLiquid) {
        // ignore: avoid_bool_literals_in_conditional_expressions
        final drain = state.lightningOrder != null ? false : state.sendMax;
        final liquidFeeRate = await _resolveLiquidFeeRate(
          fee: state.selectedFee!,
          walletId: state.selectedWallet!.id,
          address: address,
          amountSat: amount,
          drain: drain,
        );
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: address,
          feeRate: liquidFeeRate,
          amountSat: amount,
          drain: drain,
        );
        if (state.chainSwap != null) {
          // [CHAIN SWAP LIFECYCLE — Step 3b: fail-safe verification]
          // Confirms the built pset pays swap.paymentAmount to
          // swap.paymentAddress. Guards against any future flow that
          // desyncs the funding tx from the swap's locked-in
          // amount/address, and against a Boltz lockup script-type
          // change that would invalidate the P2TR dummy assumption in
          // Step 2a.
          await _verifyChainSwapAmountSendUsecase.execute(
            psbtOrPset: pset,
            swap: state.chainSwap!,
            walletId: state.selectedWallet!.id,
          );
        }
        // final signedPset = await _signLiquidTxUsecase.execute(
        //   walletId: state.selectedWallet!.id,
        //   pset: pset,
        // );
        final absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
        if (state.chainSwap != null) {
          final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
            swapId: state.chainSwap!.id,
            lockupFees: absoluteFees,
          );
          emit(
            state.copyWith(
              unsignedPsbt: pset,
              liquidAbsoluteFees: absoluteFees,
              chainSwap: updatedSwap as ChainSwap,
              buildingTransaction: false,
            ),
          );
        } else if (state.lightningOrder != null) {
          emit(
            state.copyWith(
              unsignedPsbt: pset,
              liquidAbsoluteFees: absoluteFees,
              buildingTransaction: false,
            ),
          );
        } else {
          emit(
            state.copyWith(
              unsignedPsbt: pset,
              liquidAbsoluteFees: absoluteFees,
              buildingTransaction: false,
            ),
          );
        }
        if (state.sendMax) {
          final maxAmountSat =
              state.selectedWallet!.balanceSat.toInt() -
              (state.absoluteFees ?? 0);
          // convert to btc or fiat based on selected currency
          final maxAmount = state.bitcoinUnit == BitcoinUnit.btc
              ? ConvertAmount.satsToBtc(maxAmountSat)
              : state.isInputAmountFiat
              ? ConvertAmount.satsToFiat(maxAmountSat, state.exchangeRate)
              : maxAmountSat;
          emit(
            state.copyWith(
              amount: maxAmount.toString(),
              confirmedAmountSat: state.inputAmountSat,
            ),
          );
        }
      } else {
        // ignore: avoid_bool_literals_in_conditional_expressions
        final drain = state.lightningOrder != null ? false : state.sendMax;
        final selectedFee = state.selectedFee!;
        // CRITICAL: if a preview PSBT exists for the current selection,
        // REUSE it instead of calling _prepareBitcoinSendUsecase again.
        // BDK's TxBuilder.finish() picks UTXOs non-deterministically
        // (logs show 113/154/195 vbyte variance for identical inputs),
        // so rebuilding here would broadcast a different fee than the
        // preview displayed. Caches are cleared on any input-shape
        // change (armCustomFee, clearBitcoinFeePreviews).
        //
        // Chain swap is fine to cache: the preview was built with
        // state.chainSwap!.paymentAddress / paymentAmount (see
        // _previewBitcoinAddress / _previewBitcoinAmountSat), which is
        // exactly what `address` and `amount` resolve to above. The
        // verification step below runs on `txPreparation.unsignedPsbt`
        // whether it came from cache or a fresh build.
        final cachedSlot = state.feePreviewCache.slotFor(
          state.selectedFeeOption,
        );
        final canUseCache = cachedSlot.isCacheReady;
        log.info(
          '[create-tx] build address=$address amount=$amount '
          'rate=${selectedFee is RelativeFee ? selectedFee.satPerVbyte : selectedFee.value} '
          'drain=$drain selectedInputs=${state.selectedUtxos.length} '
          'rbf=${state.replaceByFee} '
          'lightningOrder=${state.lightningOrder != null} '
          'chainSwap=${state.chainSwap != null} '
          'cacheHit=$canUseCache',
        );
        final txPreparation = canUseCache
            ? (
                unsignedPsbt: cachedSlot.unsignedPsbt!,
                txSize: cachedSlot.txSize!,
                // The cached PSBT was built for the same address, so the
                // to-self determination is invariant — preserve it rather
                // than dropping it to false (which would flip the "to self"
                // badge and mis-gate payjoin on a self-send).
                isToSelf: state.isToSelf ?? false,
              )
            : await _prepareBitcoinSendUsecase.execute(
                walletId: state.selectedWallet!.id,
                address: address,
                networkFee: selectedFee,
                amountSat: amount,
                replaceByFee: state.replaceByFee,
                selectedInputs: state.selectedUtxos,
                drain: drain,
              );
        final builtFee = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: txPreparation.unsignedPsbt,
        );
        log.info(
          '[create-tx] built vsize=${txPreparation.txSize} '
          'realFee=$builtFee sats '
          '(impliedRate=${txPreparation.txSize > 0 ? (builtFee / txPreparation.txSize).toStringAsFixed(4) : "n/a"} sat/vB)',
        );

        // Belt-and-suspenders relay-floor re-assert. The commit gate in
        // finalizeArmedCustomFee checks an ABSOLUTE custom fee against the
        // *previous* build's bitcoinTxSize (or the 140 fallback); if the real
        // tx is larger, an absolute fee that cleared the gate can land below
        // the relay floor at the actual vsize. Re-check the freshly built fee
        // against the freshly built vsize so no below-relay tx ever reaches
        // broadcast, regardless of selection type or BDK's coin-selection
        // vsize variance. Don't rely on BDK rejecting sub-minrelay itself.
        final clearsRelay = NetworkFee.absolute(builtFee).aboveMinRelay(
          txSize: txPreparation.txSize,
          floorSatPerKwu: state.bitcoinFeesList?.minRelay.satPerKwu,
        );
        if (!clearsRelay) {
          log.warning(
            '[create-tx] ABORT — built fee $builtFee sats at '
            '${txPreparation.txSize} vbytes is below the relay floor '
            '(${state.bitcoinFeesList?.minRelay.satPerVbyte ?? NetworkFeeRelayPolicy.minRelaySatPerVbyte} sat/vB)',
          );
          emit(
            state.copyWith(
              failure: SendTransactionBuildFailure(
                'Built fee $builtFee sats at ${txPreparation.txSize} vbytes '
                'is below the relay floor',
              ),
              buildingTransaction: false,
            ),
          );
          return;
        }

        if (state.chainSwap != null) {
          // [CHAIN SWAP LIFECYCLE — Step 3b: fail-safe verification]
          // See note on the liquid branch above. Do not remove.
          await _verifyChainSwapAmountSendUsecase.execute(
            psbtOrPset: txPreparation.unsignedPsbt,
            swap: state.chainSwap!,
            walletId: state.selectedWallet!.id,
          );
        }

        if (state.selectedWallet!.signsRemotely) {
          // psbt.fee() reads input/output deltas — works on unsigned PSBTs
          // since BDK finalizes coin selection at build time.
          final bitcoinAbsoluteFeesSat =
              await _calculateBitcoinAbsoluteFeesUsecase.execute(
                psbt: txPreparation.unsignedPsbt,
              );
          emit(
            state.copyWith(
              unsignedPsbt: txPreparation.unsignedPsbt,
              bitcoinTxSize: txPreparation.txSize,
              bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
              isToSelf: txPreparation.isToSelf,
              buildingTransaction: false,
            ),
          );
        } else {
          final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
            psbt: txPreparation.unsignedPsbt,
            walletId: state.selectedWallet!.id,
          );
          final bitcoinAbsoluteFeesSat =
              await _calculateBitcoinAbsoluteFeesUsecase.execute(
                psbt: signedPsbtAndTxSize.signedPsbt,
              );
          if (state.chainSwap != null) {
            final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
              swapId: state.chainSwap!.id,
              lockupFees: bitcoinAbsoluteFeesSat,
            );
            emit(
              state.copyWith(
                unsignedPsbt: txPreparation.unsignedPsbt,
                signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
                bitcoinTxSize: signedPsbtAndTxSize.txSize,
                bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
                isToSelf: txPreparation.isToSelf,
                chainSwap: updatedSwap as ChainSwap,
                buildingTransaction: false,
              ),
            );
          } else if (state.lightningOrder != null) {
            emit(
              state.copyWith(
                unsignedPsbt: txPreparation.unsignedPsbt,
                signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
                bitcoinTxSize: signedPsbtAndTxSize.txSize,
                bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
                isToSelf: txPreparation.isToSelf,
                buildingTransaction: false,
              ),
            );
          } else {
            emit(
              state.copyWith(
                unsignedPsbt: txPreparation.unsignedPsbt,
                signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
                bitcoinTxSize: signedPsbtAndTxSize.txSize,
                bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
                isToSelf: txPreparation.isToSelf,
                buildingTransaction: false,
              ),
            );
          }
        }
        if (state.sendMax) {
          final maxAmountSat =
              state.selectedWallet!.balanceSat.toInt() -
              (state.absoluteFees ?? 0);
          final maxAmount =
              state.inputAmountCurrencyCode == BitcoinUnit.btc.code
              ? ConvertAmount.satsToBtc(maxAmountSat)
              : state.isInputAmountFiat
              ? ConvertAmount.satsToFiat(maxAmountSat, state.exchangeRate)
              : maxAmountSat;
          emit(
            state.copyWith(
              amount: maxAmount.toString(),
              confirmedAmountSat: state.inputAmountSat,
            ),
          );
        }
      }
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      if (e is ConsolidationRequiredException) {
        emit(
          state.copyWith(
            consolidationRequired: true,
            buildingTransaction: false,
          ),
        );
        return;
      }
      if (e is PrepareBitcoinSendException) {
        emit(
          state.copyWith(
            failure: SendTransactionBuildFailure(e.message),
            buildingTransaction: false,
          ),
        );
        return;
      }
      if (e is PrepareLiquidSendException) {
        emit(
          state.copyWith(
            failure: SendTransactionBuildFailure(e.message),
            buildingTransaction: false,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          failure: SendTransactionBuildFailure(e.toString()),
          buildingTransaction: false,
        ),
      );
      return;
    }
  }

  /// The sender's choice on the confirm screen: attempt the payjoin or send
  /// a plain transaction. Ignored once signing has started — the decision is
  /// consumed by [signTransaction]'s payjoin branch.
  void togglePayjoin(bool attempt) {
    if (state.signingTransaction || state.txId != null) return;
    emit(state.copyWith(payjoinOptedOut: !attempt));
  }

  Future<bool> _persistPreparedOrderPayin({
    required String signedTransaction,
    required bool isPsbt,
  }) async {
    final order = state.lightningOrder;
    if (order == null) return true;
    switch (await _updateSendSwapPayinUsecase.execute(
      localId: order.localId,
      update: SendSwapPayinUpdate.prepared,
      signedTransaction: signedTransaction,
      isPsbt: isPsbt,
    )) {
      case Ok(:final value):
        emit(state.copyWith(lightningOrder: value));
        return true;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return false;
    }
  }

  Future<void> signTransaction() async {
    try {
      emit(state.copyWith(signingTransaction: true));

      if (state.selectedWallet!.network.isLiquid) {
        final signedPset = await _signLiquidTxUsecase.execute(
          pset: state.unsignedPsbt!,
          walletId: state.selectedWallet!.id,
        );
        if (!await _persistPreparedOrderPayin(
          signedTransaction: signedPset,
          isPsbt: false,
        )) {
          emit(state.copyWith(signingTransaction: false));
          return;
        }

        emit(
          state.copyWith(signedLiquidTx: signedPset, signingTransaction: false),
        );
      } else {
        if (state.willAttemptPayjoin) {
          final paymentRequest = state.paymentRequest! as Bip21PaymentRequest;
          final payjoinSender = await _sendWithPayjoinUsecase.execute(
            walletId: state.selectedWallet!.id,
            isTestnet: state.selectedWallet!.network.isTestnet,
            bip21: paymentRequest.uri,
            unsignedOriginalPsbt: state.unsignedPsbt!,
            amountSat: state.confirmedAmountSat!,
            networkFeesSatPerVb: state.selectedFee!.isRelative
                ? state.selectedFee!.value as double
                : 1,
          );
          // Show originalTxId provisionally; the payjoin runs asynchronously
          //  in the repository (poll → sign → broadcast, or fallback to the
          //  original on expiry). Watch its stream so the send flow resolves
          //  to success with the final txid instead of hanging on the
          //  "coordinating" screen (#2246).
          emit(
            state.copyWith(
              txId: payjoinSender.originalTxId,
              payjoinSender: payjoinSender,
              signingTransaction: false,
            ),
          );
          _watchPayjoin(payjoinSender.id);
        } else {
          final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
            psbt: state.unsignedPsbt!,
            walletId: state.selectedWallet!.id,
          );
          final bitcoinAbsoluteFeesSat =
              await _calculateBitcoinAbsoluteFeesUsecase.execute(
                psbt: signedPsbtAndTxSize.signedPsbt,
              );
          if (!await _persistPreparedOrderPayin(
            signedTransaction: signedPsbtAndTxSize.signedPsbt,
            isPsbt: true,
          )) {
            emit(state.copyWith(signingTransaction: false));
            return;
          }
          if (state.chainSwap != null) {
            final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
              swapId: state.chainSwap!.id,
              lockupFees: bitcoinAbsoluteFeesSat,
            );
            emit(
              state.copyWith(
                signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
                bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
                chainSwap: updatedSwap as ChainSwap,
                signingTransaction: false,
              ),
            );
          } else {
            emit(
              state.copyWith(
                signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
                bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
                signingTransaction: false,
              ),
            );
          }
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          failure: SendTransactionConfirmationFailure(logMessage: e.toString()),
          signingTransaction: false,
        ),
      );
    }
  }

  Future<void> broadcastTransaction({bool isPsbt = true}) async {
    try {
      if (state.txId != null || state.broadcastingTransaction) {
        log.warning('Transaction already being broadcast or broadcasted');
        return;
      }
      emit(state.copyWith(broadcastingTransaction: true));
      final lightningOrder = state.lightningOrder;
      final persistedPayin = lightningOrder?.signedPayinTransaction;
      final persistedPayinIsPsbt = lightningOrder?.payinIsPsbt;
      if (lightningOrder != null &&
          (persistedPayin == null || persistedPayinIsPsbt == null)) {
        emit(
          state.copyWith(
            failure: const SendTransactionConfirmationFailure(
              logMessage: 'Signed swap payin is not persisted',
            ),
            broadcastingTransaction: false,
          ),
        );
        return;
      }
      if (lightningOrder != null) {
        switch (await _updateSendSwapPayinUsecase.execute(
          localId: lightningOrder.localId,
          update: SendSwapPayinUpdate.broadcastStarted,
        )) {
          case Ok(:final value):
            emit(state.copyWith(lightningOrder: value));
          case Err(:final failure):
            emit(
              state.copyWith(failure: failure, broadcastingTransaction: false),
            );
            return;
        }
      }

      if (state.selectedWallet!.network.isLiquid) {
        final txId = await _broadcastLiquidTxUsecase.execute(
          persistedPayin ?? state.signedLiquidTx!,
        );
        emit(state.copyWith(txId: txId));
      } else {
        // Payjoin sends are already broadcast asynchronously by the repository
        // and their state.txId is set in signTransaction, so only plain
        // Bitcoin sends and Exchange payins broadcast here.
        final paymentRequest = state.paymentRequest;
        if (state.isToSelf != true &&
            paymentRequest != null &&
            paymentRequest is Bip21PaymentRequest &&
            paymentRequest.pj.isNotEmpty) {
          emit(state.copyWith(broadcastingTransaction: false));
        } else {
          final txId = await _broadcastBitcoinTxUsecase.execute(
            persistedPayin ??
                (isPsbt ? state.signedBitcoinPsbt! : state.signedBitcoinTx!),
            isPsbt: persistedPayinIsPsbt ?? isPsbt,
          );
          emit(state.copyWith(txId: txId));
        }
      }

      if (lightningOrder != null) {
        switch (await _updateSendSwapPayinUsecase.execute(
          localId: lightningOrder.localId,
          update: SendSwapPayinUpdate.broadcastSucceeded,
          transactionId: state.txId!,
        )) {
          case Ok(:final value):
            emit(state.copyWith(lightningOrder: value));
          case Err(:final failure):
            emit(
              state.copyWith(failure: failure, broadcastingTransaction: false),
            );
            return;
        }
      }

      if (state.chainSwap != null) {
        // Don't pass absoluteFees: createTransaction already persisted the
        // real lockup fee. Passing a value here overwrites it (0 clobbered it).
        await _updatePaidSendSwapUsecase.execute(
          txid: state.txId!,
          swapId: state.chainSwap!.id,
        );
      }

      if (lightningOrder == null && state.label.isNotEmpty) {
        await _labelsFacade.store(
          NewLabel.tx(
            transactionId: state.txId!,
            label: state.label,
            origin: state.selectedWallet!.id,
          ),
        );
      }

      emit(
        state.copyWith(broadcastingTransaction: false, step: SendStep.success),
      );

      unawaited(
        _getWalletUsecase
            .execute(state.selectedWallet!.id, sync: true)
            .catchError((e) {
              log.warning('Failed to sync wallet after broadcast: $e');
              return null;
            }),
      );
    } on GetWalletException catch (e) {
      emit(
        state.copyWith(
          failure: SendTransactionConfirmationFailure(logMessage: e.message),
          broadcastingTransaction: false,
        ),
      );
    } on BroadcastTransactionException catch (e) {
      log.warning('Failed to broadcast transaction: ${e.message}');
      emit(
        state.copyWith(
          failure: const SendTransactionConfirmationFailure(
            isBroadcastFailure: true,
            logMessage: 'BroadcastTransactionException',
          ),
          broadcastingTransaction: false,
        ),
      );
    } catch (e, st) {
      log.warning(
        'Unexpected broadcast transaction error',
        error: e,
        trace: st,
      );
      emit(
        state.copyWith(
          failure: SendTransactionConfirmationFailure(logMessage: e.toString()),
          broadcastingTransaction: false,
        ),
      );
    }
  }

  Future<void> onConfirmTransactionClicked() async {
    try {
      if (state.signedBitcoinTx == null &&
          state.lightningOrder?.hasPreparedPayin != true) {
        await createTransaction();
        await signTransaction();
        // if (!state.isLightning) {
        if (state.failure is! SendTransactionConfirmationFailure) {
          // _watchPayjoin (armed inside signTransaction's payjoin branch)
          //  can resolve the flow to success before this line, if a
          //  terminal payjoin event arrives in the gap between arming and
          //  here. Don't clobber an already-resolved success with
          //  "sending" — that would strand the flow on the sending screen
          //  despite having actually completed (the exact symptom #2246
          //  fixes, just a narrower window of it).
          if (state.step != SendStep.success) {
            emit(state.copyWith(step: SendStep.sending));
          }
        } else {
          emit(state.copyWith(step: SendStep.confirm));
          return;
        }
      }
      // }
      await broadcastTransaction(isPsbt: state.signedBitcoinTx == null);
      if (state.failure is SendTransactionConfirmationFailure) {
        emit(state.copyWith(step: SendStep.confirm));
        return;
      }
      // For a payjoin, _watchPayjoin (started in signTransaction) owns
      // resolving the flow to success — it watches the payjoin session and
      // sets the final txid. Starting the tx watcher here too would race it
      // (both emit) and briefly surface the original txid. For all other
      // sends, watch the broadcast tx for its latest status.
      if (state.payjoinSender == null) {
        _watchWalletTransactionByTxId(
          walletId: state.selectedWallet!.id,
          txId: state.txId!,
        );
      }
    } catch (e) {
      emit(state.copyWith(step: SendStep.confirm));
      log.severe(error: e, trace: StackTrace.current);
    }
  }

  Future<void> currencyCodeChanged(String currencyCode) async {
    if (currencyCode == BitcoinUnit.btc.code ||
        currencyCode == BitcoinUnit.sats.code) {
      emit(
        state.copyWith(
          bitcoinUnit: BitcoinUnit.fromCode(currencyCode),
          inputAmountCurrencyCode: currencyCode,
          fiatCurrencyCode: 'CAD',
          amount: '0',
        ),
      );
      return;
    }
    await getExchangeRate(currencyCode: currencyCode);
    emit(
      state.copyWith(
        fiatCurrencyCode: currencyCode,
        inputAmountCurrencyCode: currencyCode,
        amount: '0',
      ),
    );
    // await updateFiatApproximatedAmount();
  }

  Future<void> getExchangeRate({String? currencyCode}) async {
    final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
      currencyCode: currencyCode ?? state.fiatCurrencyCode,
    );

    emit(state.copyWith(exchangeRate: exchangeRate));
  }

  void _watchOrderSwap(String localId) {
    _orderSwapSubscription?.cancel();
    _orderSwapSubscription = _watchSendSwapUsecase
        .execute(localId)
        .listen(
          (order) {
            emit(
              state.copyWith(
                lightningOrder: order,
                step: sendStepForOrderSwapStatus(order.localStatus),
              ),
            );
            if (order.localStatus.isTerminal) {
              unawaited(
                _getWalletUsecase.execute(state.selectedWallet!.id, sync: true),
              );
            }
          },
          onError: (Object error) {
            emit(
              state.copyWith(failure: SendUnexpectedFailure(error.toString())),
            );
          },
        );
  }

  /// Watches the sender side of an in-flight payjoin and resolves the send
  /// flow once it terminates. The payjoin negotiation runs asynchronously in
  /// the repository; without this the UI would sit on the "coordinating"
  /// screen forever (#2246).
  ///
  /// - completed: the receiver responded and the payjoin transaction was
  ///   broadcast — move to success with the payjoin txid.
  /// - aborted: the repository fell back to broadcasting the original
  ///   transaction (below-minimum decline, failed negotiation, or the
  ///   counterparty's own fallback observed on-chain) — move to success
  ///   with the original txid.
  /// - expired: terminal with nothing broadcast — the original-transaction
  ///   fallback itself also failed — return to confirm with a
  ///   broadcast-failure exception so the user can retry.
  void _watchPayjoin(String payjoinId) {
    _payjoinSubscription?.cancel();
    // Captured up front: the completion event fires arbitrarily later on a
    // background poll, so read these off state now rather than closing over
    // state (which may have moved on) inside the async callback.
    final walletId = state.selectedWallet?.id;
    final userLabel = state.label;
    _payjoinSubscription = _watchPayjoinUsecase
        .execute(ids: [payjoinId])
        .where((payjoin) => payjoin is PayjoinSenderSession)
        .cast<PayjoinSenderSession>()
        .listen((payjoin) {
          // The payjoin poll lives in the repository and outlives this cubit;
          // an event can arrive after the send flow is torn down. Never emit
          // on a closed cubit (it throws).
          if (isClosed) return;
          // logRef, never id: a sender payjoin id is the full BIP21 URI
          // (address + amount), which must not reach logs.
          log.info(
            '[SendCubit] Watched payjoin ${payjoin.logRef} updated: '
            '${payjoin.status}',
          );
          if (payjoin.isCompleted || payjoin.isAborted) {
            emit(
              state.copyWith(
                payjoinSender: payjoin,
                // Prefer the payjoin txid; fall back to the original tx that
                //  was broadcast when the negotiation didn't complete.
                txId: payjoin.txId ?? payjoin.originalTxId,
                step: SendStep.success,
              ),
            );
            _payjoinSubscription?.cancel();
            if (walletId != null) {
              unawaited(
                _getWalletUsecase.execute(walletId, sync: true).catchError((e) {
                  log.warning('Failed to sync wallet after payjoin: $e');
                  return null;
                }),
              );
            }
            // broadcastTransaction never reaches its own label-store call for
            //  a payjoin (it early-returns because txId is already set), so
            //  the user's typed label has to be stored here instead, once the
            //  final txid is known.
            // originalTxId is always set for a sender, so this is never null.
            final finalTxId = payjoin.txId ?? payjoin.originalTxId;
            if (userLabel.isNotEmpty && walletId != null) {
              unawaited(
                _labelsFacade.store(
                  NewLabel.tx(
                    transactionId: finalTxId,
                    label: userLabel,
                    origin: walletId,
                  ),
                ),
              );
            }
          } else if (payjoin.isExpired) {
            // Terminal without a broadcast: either the session expired and the
            // original-transaction fallback failed too, or a received proposal
            // failed to sign/broadcast and the original fallback also failed
            // (the repository only emits the raw expired-marked entity on one
            // of these unrecoverable paths). Nothing hit the chain, so surface
            // a broadcast failure and return to confirm so the user can retry,
            // instead of hanging on "coordinating".
            log.warning(
              '[SendCubit] Payjoin ${payjoin.logRef} expired without broadcast',
            );
            _payjoinSubscription?.cancel();
            // Clear the provisional txId AND payjoinSender so a retry starts
            //  clean: signTransaction set state.txId = originalTxId up front,
            //  and broadcastTransaction early-returns while txId != null — so
            //  leaving them set would permanently short-circuit the retry's
            //  broadcast. Nulling both lets createTransaction/signTransaction
            //  re-run the payjoin branch from scratch.
            emit(
              state.copyWith(
                txId: null,
                payjoinSender: null,
                step: SendStep.confirm,
                failure: const SendTransactionConfirmationFailure(
                  logMessage:
                      'Payjoin expired and the transaction could not be broadcast',
                  isBroadcastFailure: true,
                ),
              ),
            );
          } else {
            emit(state.copyWith(payjoinSender: payjoin));
          }
        });
  }

  void _watchWalletTransactionByTxId({
    required String walletId,
    required String txId,
  }) {
    // Cancel the previous subscription if it exists
    _txSubscription?.cancel();
    _txSubscription = _watchWalletTransactionByTxIdUsecase
        .execute(walletId: walletId, txId: txId)
        .listen((tx) {
          // log.info(
          //   '[SendBloc] Watched transaction ${tx.txId} updated: ${tx.status}',
          // );
          emit(state.copyWith(walletTransaction: tx));
        });
  }

  Future<void> unifiedBip21Prioritization() async {
    final request = state.paymentRequest;
    if (request == null) return;
    if (request is! Bip21PaymentRequest) return;
    if (request.lightning.isEmpty) return;

    try {
      final lightning = await PaymentRequest.parse(request.lightning);
      final wallet = _bestWalletUsecase.execute(
        wallets: state.wallets,
        request: lightning,
        amountSat: lightning.amountSat,
      );
      emit(state.copyWith(selectedWallet: wallet, paymentRequest: lightning));
    } catch (_) {
      final wallet = _bestWalletUsecase.execute(
        wallets: state.wallets,
        request: request,
        amountSat: request.amountSat,
      );
      emit(state.copyWith(selectedWallet: wallet, paymentRequest: request));
    }
  }

  // [CHAIN SWAP LIFECYCLE — Step 2a: first drain, against a dummy address]
  // Used only when sendMax is selected for a chain swap. Drains the wallet
  // against a dummy P2TR address to discover the absolute fees, then
  // publishes state.amount = balance - fees so the caller can use it as
  // the swap paymentAmount.
  //
  // The dummies below are P2TR by design — Boltz returns P2TR lockup
  // addresses today, so dummyFees == realFees and Step 3's drain to the
  // real swap.paymentAddress produces an output equal to the committed
  // swap.paymentAmount. If Boltz ever switches lockup script type,
  // dummyFees != realFees and Step 3b (verify) will fire — replace the
  // dummies below with addresses matching the new lockup type.
  Future<void> buildDummyTxsForMaxSwapAmount() async {
    try {
      if (state.selectedWallet == null) return;
      clearFailure();
      await loadSwapLimits();
      setSelectedSwapLimits();
      final swapLimits = state.selectedWallet!.isLiquid
          ? state.lbtcToBtcChainSwapLimits
          : state.btcToLbtcChainSwapLimits;
      if (swapLimits == null) return;
      if (state.selectedFee == null) await loadFees();
      final networkFee = state.selectedFee!;
      int absoluteFees;
      if (state.selectedWallet!.isLiquid) {
        // P2TR dummy matching Boltz's L-BTC P2TR lockup script.
        const String dummySwapAddress =
            "lq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0we046p4uqlt24";
        final liquidFeeRate = await _resolveLiquidFeeRate(
          fee: networkFee,
          walletId: state.selectedWallet!.id,
          address: dummySwapAddress,
          amountSat: null,
          drain: true,
        );
        final dummyPset = await _prepareLiquidSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: dummySwapAddress,
          feeRate: liquidFeeRate,
          drain: true,
        );
        absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: dummyPset,
        );
        emit(state.copyWith(liquidAbsoluteFees: absoluteFees));
      } else {
        // P2TR dummy matching Boltz's BTC P2TR lockup script.
        const String dummySwapAddress =
            "bc1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskq9pj5n4";
        final dummyDrainTxInfo = await _prepareBitcoinSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: dummySwapAddress,
          networkFee: networkFee,
          drain: true,
        );
        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: dummyDrainTxInfo.unsignedPsbt,
        );
        // Surface the real drain fee, mirroring the Liquid branch above
        // (line 1759). The user is asking "what's my max" — the drain
        // dummy's fee is exactly what they'd pay.
        emit(
          state.copyWith(
            bitcoinTxSize: dummyDrainTxInfo.txSize,
            bitcoinAbsoluteFeesSat: absoluteFees,
          ),
        );
      }
      // D7: base MAX on the spendable balance — the funding drain excludes
      // frozen coins, so committing `fullBalance - fee` would overstate the
      // swap amount by the frozen total and trip the Step 3b verify. Equals the
      // full balance on Liquid (freeze isn't surfaced there).
      final balance = state.spendableBalanceSat;
      final maxAmount = balance - absoluteFees;
      if (state.bitcoinUnit == BitcoinUnit.sats) {
        emit(state.copyWith(amount: maxAmount.toString()));
      } else {
        final validatedAmount = ConvertAmount.satsToBtc(maxAmount);
        emit(state.copyWith(amount: validatedAmount.toString()));
      }
      if (swapLimits.min > maxAmount) {
        emit(
          state.copyWith(
            failure: SendAmountOutOfBoundsFailure(
              minimumSat: BigInt.from(swapLimits.min),
              logMessage: 'Balance too low for minimum swap amount',
            ),
          ),
        );
        return;
      }
      if (swapLimits.max < maxAmount) {
        emit(
          state.copyWith(
            failure: SendAmountOutOfBoundsFailure(
              maximumSat: BigInt.from(swapLimits.max),
              logMessage: 'Amount exceeds maximum swap amount',
            ),
          ),
        );
        return;
      }
    } catch (e) {
      emit(state.copyWith(failure: SendTransactionBuildFailure(e.toString())));
    }
  }

  Future<void> updateSignedBitcoinTx(String signedTx) async {
    if (!await _persistPreparedOrderPayin(
      signedTransaction: signedTx,
      isPsbt: false,
    )) {
      return;
    }
    emit(state.copyWith(signedBitcoinTx: signedTx));
  }

  Future<void> updateSelectedWallet(Wallet newWallet) =>
      _setSelectedWallet(newWallet, manual: true);

  /// Central path for every wallet change in the send flow.
  /// `manual: true` locks the pick so [updateBestWallet]'s auto-switching
  /// (used as the user types an amount) doesn't override the user's choice —
  /// the silent override regressed cold-wallet sends. See #1918.
  Future<void> _setSelectedWallet(Wallet wallet, {required bool manual}) async {
    final walletChanged = state.selectedWallet?.id != wallet.id;
    emit(
      state.copyWith(
        selectedWallet: wallet,
        isWalletManuallySelected: manual,
        failure: null,
        // Drop the previous wallet's utxos on a change so spendable-balance math
        // never mixes the new wallet's balance with the old wallet's frozen
        // coins in the window before loadUtxos() repopulates (it degrades to the
        // full balance meanwhile — the safe fallback). Also clear any manual
        // coin selection: those outpoints belong to the old wallet and would
        // otherwise be fed as required inputs into the new wallet's PSBT build,
        // which fails (outpoint not in wallet) or builds against wrong coins.
        utxos: walletChanged ? const [] : state.utxos,
        selectedUtxos: walletChanged ? const [] : state.selectedUtxos,
      ),
    );
    // Wallet swap invalidates every cached preview: the PSBT was built
    // from a different wallet's UTXOs and descriptor. Clear after the
    // emit so the loading flags don't race with the wallet swap. Skip
    // when the "swap" picks the same wallet — common via updateBestWallet.
    if (walletChanged) clearBitcoinFeePreviews();
    setSelectedSwapLimits();
    // Load utxos up front so the spendable balance (which excludes frozen
    // coins, D7) is known during amount entry — not only after the first sync.
    // Guarded on an actual wallet change so the per-keystroke auto-pick
    // (updateBestWallet) doesn't re-read utxos on every keypress.
    if (walletChanged) await loadUtxos();
    await _selectedWalletSyncingSubscription?.cancel();
    _selectedWalletSyncingSubscription = _watchFinishedWalletSyncsUsecase
        .execute(walletId: wallet.id)
        .listen((synced) async {
          emit(state.copyWith(selectedWallet: synced));
          await loadUtxos();
        });
  }

  // ────── FeeModalViewState + FeeModalActions adoption ──────
  // SendCubit is the driving adapter for the Bitcoin-send path; the
  // shared modal in lib/core/widgets/fees/ depends on these ports.
  // Method bodies just delegate to the existing internal API so the
  // port surface stays a stable contract while the cubit's own
  // naming can evolve.

  static FeeModalSnapshot _modalSnapshotFromState(SendState s) =>
      FeeModalSnapshot(
        feePresets: s.bitcoinFeesList,
        customFee: s.customFee,
        selectedFeeOption: s.selectedFeeOption,
        feePreviewCache: s.feePreviewCache,
        exchangeRate: s.exchangeRate,
        fiatCurrencyCode: s.fiatCurrencyCode,
        txSize: s.bitcoinTxSize ?? 140,
      );

  @override
  FeeModalSnapshot get snapshot => _modalSnapshotFromState(state);

  @override
  Stream<FeeModalSnapshot> get snapshots => stream.map(_modalSnapshotFromState);

  @override
  void requestPresetPreviews() => unawaited(loadBitcoinFeePresetPreviews());

  @override
  void requestCustomFeePreview(NetworkFee fee) =>
      unawaited(previewBitcoinCustomFee(fee));

  @override
  void selectFeeOption(FeeSelection selection) =>
      unawaited(feeOptionSelected(selection));
}
