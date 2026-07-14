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
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/lightning.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
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
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
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
    required this._updatePaidSendSwapUsecase,
    required this._getSwapLimitsUsecase,
    required this._watchSwapUsecase,
    required this._watchFinishedWalletSyncsUsecase,
    required this._decodeInvoiceUsecase,
    required this._signBitcoinTxUsecase,
    required this._signLiquidTxUsecase,
    required this._broadcastBitcoinTxUsecase,
    required this._broadcastLiquidTxUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
    required this._calculateLiquidPsetSizeUsecase,
    required this._createChainSwapToExternalUsecase,
    required this._watchWalletTransactionByTxIdUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._updateSendSwapLockupFeesUsecase,
    required this._verifyChainSwapAmountSendUsecase,
    required this._previewBitcoinFeeUsecase,
    required this._previewBitcoinFeePresetsUsecase,
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
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetWalletUsecase _getWalletUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CalculateLiquidPsetSizeUsecase _calculateLiquidPsetSizeUsecase;
  final CreateSendSwapUsecase _createSendSwapUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTxUsecase;
  final SendWithPayjoinUsecase _sendWithPayjoinUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final UpdatePaidSendSwapUsecase _updatePaidSendSwapUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  final DecodeInvoiceUsecase _decodeInvoiceUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  final WatchSwapUsecase _watchSwapUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;

  final CreateChainSwapToExternalUsecase _createChainSwapToExternalUsecase;

  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final UpdateSendSwapLockupFeesUsecase _updateSendSwapLockupFeesUsecase;
  final VerifyChainSwapAmountSendUsecase _verifyChainSwapAmountSendUsecase;
  final PreviewBitcoinFeeUsecase _previewBitcoinFeeUsecase;
  final PreviewBitcoinFeePresetsUsecase _previewBitcoinFeePresetsUsecase;

  StreamSubscription<Swap>? _swapSubscription;
  StreamSubscription<Wallet>? _selectedWalletSyncingSubscription;
  StreamSubscription<WalletTransaction>? _txSubscription;
  StreamSubscription<Payjoin>? _payjoinSubscription;

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
      _swapSubscription?.cancel() ?? Future.value(),
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

  void backClicked() {
    if (state.step == SendStep.address) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.amount) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.confirm) {
      emit(
        state.copyWith(step: SendStep.amount, buildTransactionException: null),
      );
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
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Called when a payment request is detected directly from the scanner
  Future<void> onScannedPaymentRequest(
    String scannedRawPaymentRequest,
    PaymentRequest? paymentRequest,
  ) async {
    clearAllExceptions();
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
      clearAllExceptions();
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
          invalidBitcoinStringException: text.isNotEmpty
              ? InvalidBitcoinStringException()
              : null,
        ),
      );
      if (recipientCleared) clearBitcoinFeePreviews();
    }
  }

  Future<void> continueOnAddressConfirmed() async {
    try {
      emit(state.copyWith(loadingBestWallet: true, invoiceHasMrh: false));
      await unifiedBip21Prioritization();

      if (!state.hasValidPaymentRequest) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            invalidBitcoinStringException:
                state.scannedRawPaymentRequest.isNotEmpty
                ? UnsupportedQrFormatException()
                : InvalidBitcoinStringException(),
          ),
        );
        return;
      }

      if (state.paymentRequest!.isBolt11) {
        final paymentRequest = state.paymentRequest! as Bolt11PaymentRequest;
        final invoice = await _decodeInvoiceUsecase.execute(
          invoice: paymentRequest.invoice,
        );
        if (invoice.isExpired) {
          emit(
            state.copyWith(
              loadingBestWallet: false,
              swapCreationException: ExpiredInvoiceException(),
            ),
          );
          return;
        }
        if (invoice.sats == 0) {
          emit(
            state.copyWith(
              loadingBestWallet: false,
              swapCreationException: AmountlessInvoiceException(
                'Invoice has no amount',
              ),
            ),
          );
          return;
        }
        if (invoice.magicBip21 != null) {
          final updatedRequest = await _detectBitcoinStringUsecase.execute(
            data: invoice.magicBip21!,
          );
          emit(
            state.copyWith(
              // copiedRawPaymentRequest: invoice.toString(),
              paymentRequest: updatedRequest,
              invoiceHasMrh: true,
            ),
          );
        }
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

      if (state.invoiceHasMrh) {
        if (!await hasBalance()) {
          emit(
            state.copyWith(
              insufficientBalanceException: InsufficientBalanceException(),
              creatingSwap: false,
              loadingBestWallet: false,
            ),
          );
          return;
        }
        //
        emit(
          state.copyWith(confirmedAmountSat: state.paymentRequest!.amountSat),
        );
        await handleChainSwap();
        if (state.swapAmountAboveLimit ||
            state.swapAmountBelowLimit ||
            state.swapCreationException != null) {
          return;
        }

        await createTransaction();
        emit(
          state.copyWith(
            step: SendStep.confirm,
            confirmedAmountSat: state.paymentRequest!.amountSat,
          ),
        );
        return;
      }
      if (state.paymentRequest!.isBolt11) {
        emit(state.copyWith(creatingSwap: true));
        if (!await hasBalance()) {
          emit(
            state.copyWith(
              insufficientBalanceException: InsufficientBalanceException(),
              creatingSwap: false,
              loadingBestWallet: false,
            ),
          );
          return;
        }
        final swapType = wallet.isLiquid
            ? SwapType.liquidToLightning
            : SwapType.bitcoinToLightning;
        await loadSwapLimits();
        setSelectedSwapLimits();

        if (state.swapAmountBelowLimit) {
          final swapMinimum = state.swapMinimum;
          if (!state.selectedWallet!.isLiquid) {
            emit(
              state.copyWith(
                creatingSwap: false,
                swapLimitsException: SwapLimitsException(
                  'Amount is below swap limits of $swapMinimum sats.',
                  minLimit: swapMinimum,
                  suggestInstantPayments: true,
                ),
                loadingBestWallet: false,
              ),
            );
            return;
          } else {
            emit(
              state.copyWith(
                creatingSwap: false,
                swapLimitsException: SwapLimitsException(
                  'Amount is below swap limit of $swapMinimum sats.',
                  minLimit: swapMinimum,
                ),
                loadingBestWallet: false,
              ),
            );
          }
          return;
        }
        if (state.swapAmountAboveLimit) {
          emit(
            state.copyWith(
              creatingSwap: false,
              swapLimitsException: SwapLimitsException(
                'Amount is above swap limits',
                maxLimit: state.selectedSwapLimits?.max,
              ),
              loadingBestWallet: false,
            ),
          );
          return;
        }

        try {
          final paymentRequest = state.paymentRequest! as Bolt11PaymentRequest;
          final swap = await _createSendSwapUsecase.execute(
            walletId: wallet.id,
            type: swapType,
            invoice: paymentRequest.invoice,
          );
          emit(
            state.copyWith(
              step: SendStep.confirm,
              lightningSwap: swap,
              confirmedAmountSat: state.paymentRequest!.amountSat,
              creatingSwap: false,
            ),
          );
          await createTransaction();
          // updateSwapLockupFees();
          return;
        } catch (e) {
          log.severe(
            message: 'Failed to create swap',
            error: e,
            trace: StackTrace.current,
          );
          emit(
            state.copyWith(
              creatingSwap: false,
              swapCreationException: SwapCreationException(
                'Something went wrong. Please try again.',
              ),
              loadingBestWallet: false,
            ),
          );
          return;
        }
      }
      if (state.paymentRequest!.isBip21) {
        if (state.paymentRequest!.amountSat == null) {
          emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        } else {
          await handleChainSwap();
          if (state.swapAmountAboveLimit ||
              state.swapAmountBelowLimit ||
              state.swapCreationException != null) {
            return;
          }
          await createTransaction();
        }
        return;
      }
      if (state.paymentRequest!.isLnAddress) {
        try {
          final lnAddressPaymentRequest =
              state.paymentRequest! as LnAddressPaymentRequest;

          // Validate the LNURL by trying to create an invoice with a dummy amount
          // This uses the same function that will be used when creating the actual swap
          const dummyAmount = 1000; // 1000 sats dummy amount
          await invoiceFromLnAddress(
            lnAddress: lnAddressPaymentRequest.address,
            amountSat: dummyAmount,
          );

          // If successful, proceed to amount step
          emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        } catch (e) {
          // If LNURL validation fails, set error and stay on address step
          emit(
            state.copyWith(
              loadingBestWallet: false,
              invalidBitcoinStringException: InvalidBitcoinStringException(),
            ),
          );
          return;
        }
      } else {
        emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        return;
      }
    } catch (e) {
      if (e is NotEnoughFundsException) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            insufficientBalanceException: InsufficientBalanceException(),
            creatingSwap: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            invalidBitcoinStringException: InvalidBitcoinStringException(
              e.toString(),
            ),
            loadingBestWallet: false,
            creatingSwap: false,
          ),
        );
      }
    }
  }

  // [CHAIN SWAP LIFECYCLE — Step 2: create the swap]
  // Single chain-swap orchestration point. Runs to completion BEFORE the
  // real funding tx is built. The sequence is:
  //   (a) If sendMax: drain to a dummy P2TR address (matching Boltz's
  //       P2TR lockup) to discover absolute fees and derive
  //       state.amount = balance - fees. See buildDummyTxsForMaxSwapAmount.
  //   (b) Load swap limits + fees, compute paymentAmount:
  //         - sendMax: paymentAmount = state.inputAmountSat
  //           (already balance - txFees from Step 2a; Boltz deducts its
  //           fees from this amount before paying the receiver).
  //         - otherwise: paymentAmount = receivable + boltz fees, so the
  //           receiver gets the exact requested amount.
  //   (c) Call createChainSwapToExternalUsecase → Boltz LOCKS IN
  //       swap.paymentAmount and swap.paymentAddress (P2TR lockup). From
  //       this point, the final funding tx MUST send exactly
  //       swap.paymentAmount to swap.paymentAddress.
  // After this returns, createTransaction is invoked to build the funding tx.
  Future<void> handleChainSwap() async {
    final isChainSwap =
        (state.sendType == SendType.liquid &&
            !state.selectedWallet!.isLiquid) ||
        state.sendType == SendType.bitcoin && state.selectedWallet!.isLiquid ||
        state.isChainSwap;
    if (isChainSwap) {
      try {
        if (state.sendMax) {
          // [CHAIN SWAP LIFECYCLE — Step 2a: first drain (dummy address)]
          // Computes fees against a dummy address. Result feeds state.amount,
          // which becomes the swap paymentAmount below.
          await buildDummyTxsForMaxSwapAmount();
        }
        final swapType = state.selectedWallet!.isLiquid
            ? SwapType.liquidToBitcoin
            : SwapType.bitcoinToLiquid;
        await loadSwapLimits();
        setSelectedSwapLimits();
        if (state.swapAmountBelowLimit) {
          emit(
            state.copyWith(
              swapLimitsException: SwapLimitsException(
                'Amount below minimum swap limit: ${state.selectedSwapLimits!.min} sats',
                minLimit: state.selectedSwapLimits!.min,
              ),
              amountConfirmedClicked: false,
            ),
          );
          return;
        }
        if (state.swapAmountAboveLimit) {
          emit(
            state.copyWith(
              swapLimitsException: SwapLimitsException(
                'Amount above maximum swap limit: ${state.selectedSwapLimits!.max} sats',
                maxLimit: state.selectedSwapLimits!.max,
              ),
              amountConfirmedClicked: false,
            ),
          );
          return;
        }
        emit(state.copyWith(creatingSwap: true));
        final receivableAmount =
            state.paymentRequest!.amountSat ?? state.inputAmountSat;
        final swapFees = state.selectedSwapFees;
        if (swapFees == null) {
          emit(
            state.copyWith(
              creatingSwap: false,
              swapCreationException: SwapCreationException(
                'Swap fees not loaded',
              ),
              loadingBestWallet: false,
            ),
          );
          return;
        }
        // For sendMax, state.inputAmountSat is already balance - txFees
        // (set by buildDummyTxsForMaxSwapAmount). It IS the funding
        // amount, not a receivable — Boltz deducts its fees from this
        // before paying the receiver. Running it through
        // calculateSwapAmountFromReceivableAmount would add boltz fees on
        // top, over-quoting paymentAmount and tripping Step 3b. #1735.
        final paymentAmount = state.sendMax
            ? state.inputAmountSat
            : swapFees.calculateSwapAmountFromReceivableAmount(
                receivableAmount,
              );
        // [CHAIN SWAP LIFECYCLE — Step 2c: commit paymentAmount]
        // Boltz locks in the exact amount that must be paid to its lockup
        // address. swap.paymentAmount and swap.paymentAddress are now fixed.
        // Any deviation in the final funding tx will be rejected by
        // VerifyChainSwapAmountSendUsecase (the fail-safe at Step 3b).
        final swap = await _createChainSwapToExternalUsecase.execute(
          sendWalletId: state.selectedWallet!.id,
          receiveAddress: state.paymentRequest!.isBip21
              ? (state.paymentRequest! as Bip21PaymentRequest).address
              : state.paymentRequestAddress,
          type: swapType,
          amountSat: paymentAmount,
        );
        _watchSendSwap(swap.id);
        emit(
          state.copyWith(
            chainSwap: swap,
            confirmedAmountSat: swap.paymentAmount,
            creatingSwap: false,
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(
            creatingSwap: false,
            swapCreationException: SwapCreationException(e.toString()),
            loadingBestWallet: false,
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
        // final swapLimits = state.swapLimits!.;
        final invoice = await _decodeInvoiceUsecase.execute(
          invoice: state.paymentRequestAddress,
        );
        final invoiceAmount = invoice.sats;
        final feeEstimate =
            state.selectedSwapFees?.totalFees(invoiceAmount) ?? 0;
        final totalPayable = invoiceAmount + feeEstimate;
        return spendableSat > totalPayable;

      case LnAddressPaymentRequest _:
        final invoiceAmount = state.inputAmountSat;
        final feeEstimate =
            state.selectedSwapFees?.totalFees(invoiceAmount) ?? 0;
        final totalPayable = invoiceAmount + feeEstimate;
        return spendableSat > totalPayable;

      default:
        return spendableSat >=
            (state.inputAmountSat + (state.absoluteFees ?? 0));
    }
  }

  Future<void> getCurrencies() async {
    final settings = await _getSettingsUsecase.execute();

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
      ),
    );
  }

  Future<void> amountChanged({String? amount, bool isMax = false}) async {
    try {
      clearAllExceptions();
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
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> onCurrencyChanged(String currencyCode) async {
    double exchangeRate = state.exchangeRate;
    String fiatCurrencyCode = state.fiatCurrencyCode;

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
      ]);

      fiatCurrencyCode = (currencyValues[0] as SettingsEntity).currencyCode;
      exchangeRate = currencyValues[1] as double;
    }

    emit(
      state.copyWith(
        inputAmountCurrencyCode: currencyCode,
        fiatCurrencyCode: fiatCurrencyCode,
        exchangeRate: exchangeRate,
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
    clearAllExceptions();

    if (state.blocksSwapDueToBitcoinHardwareWallet) {
      emit(
        state.copyWith(swapCreationException: HardwareWalletSwapException()),
      );
      return;
    }

    emit(
      state.copyWith(
        amountConfirmedClicked: true,
        confirmedAmountSat: state.inputAmountSat,
      ),
    );

    if (state.sendType == SendType.lightning) {
      if (state.selectedSwapLimits == null) {
        await loadSwapLimits();
        setSelectedSwapLimits();
      }
      final swapType = state.selectedWallet!.isLiquid
          ? SwapType.liquidToLightning
          : SwapType.bitcoinToLightning;

      if (state.swapAmountBelowLimit) {
        final isLiquidToLightning = state.selectedWallet!.isLiquid;
        final minLimit = isLiquidToLightning
            ? 100
            : state.selectedSwapLimits!.min;
        emit(
          state.copyWith(
            swapLimitsException: SwapLimitsException(
              'Amount below minimum swap limit: $minLimit sats',
              minLimit: minLimit,
              suggestInstantPayments: !isLiquidToLightning,
            ),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }
      if (state.swapAmountAboveLimit) {
        emit(
          state.copyWith(
            swapLimitsException: SwapLimitsException(
              'Amount above maximum swap limit: ${state.selectedSwapLimits!.max} sats',
              maxLimit: state.selectedSwapLimits!.max,
            ),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }
      if (!await hasBalance()) {
        emit(
          state.copyWith(
            insufficientBalanceException: InsufficientBalanceException(
              'Not enough funds to cover amount and fees',
            ),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }
      try {
        emit(state.copyWith(creatingSwap: true));

        final swap = await _createSendSwapUsecase.execute(
          walletId: state.selectedWallet!.id,
          type: swapType,
          lnAddress: state.paymentRequestAddress,
          amountSat: state.confirmedAmountSat,
        );
        try {
          final decodedInvoice = await _decodeInvoiceUsecase.execute(
            invoice: swap.invoice,
          );
          final memo = decodedInvoice.description?.trim() ?? '';
          if (memo.isNotEmpty && state.label.isEmpty) {
            emit(state.copyWith(label: memo));
          }
        } catch (_) {}
        emit(state.copyWith(creatingSwap: false));
        await Future.delayed(const Duration(seconds: 1));
        emit(
          state.copyWith(
            amountConfirmedClicked: false,
            step: SendStep.confirm,
            lightningSwap: swap,
          ),
        );
        _watchSendSwap(swap.id);
        await createTransaction();
        // updateSwapLockupFees();
      } catch (e) {
        emit(
          state.copyWith(
            creatingSwap: false,
            swapCreationException: SwapCreationException(e.toString()),
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
          state.swapCreationException != null) {
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
          insufficientBalanceException: InsufficientBalanceException(
            'Not enough funds to cover amount and fees',
          ),
          amountConfirmedClicked: false,
        ),
      );
      return;
    }
    if (state.buildTransactionException == null) {
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
      emit(state.copyWith(utxos: utxos));
      if (utxosChanged) clearBitcoinFeePreviews();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
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
      emit(state.copyWith(error: e.toString()));
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
    if (state.lightningSwap != null) return state.lightningSwap!.paymentAddress;
    if (state.chainSwap != null) return state.chainSwap!.paymentAddress;
    final pr = state.paymentRequest;
    if (pr is Bip21PaymentRequest) return pr.address;
    if (state.paymentRequestAddress.isNotEmpty) {
      return state.paymentRequestAddress;
    }
    return null;
  }

  int? _previewBitcoinAmountSat() {
    if (state.lightningSwap != null) return state.lightningSwap!.paymentAmount;
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
      clearAllExceptions();
      // Clear the previous build's absolute fee before loadUtxos so the UI
      // doesn't briefly pair a stale Bitcoin fee with newly-changed inputs
      // (rate / amount / utxo selection). The getter falls back to the
      // rate × txSize prediction until the rebuild emits a fresh value.
      emit(
        state.copyWith(buildingTransaction: true, bitcoinAbsoluteFeesSat: null),
      );
      await loadUtxos();
      final address = state.lightningSwap != null
          ? state.lightningSwap!.paymentAddress
          : (state.chainSwap != null)
          ? state.chainSwap!.paymentAddress
          : state.paymentRequest != null &&
                state.paymentRequest is Bip21PaymentRequest
          ? (state.paymentRequest! as Bip21PaymentRequest).address
          : state.paymentRequestAddress;
      final amount = state.lightningSwap != null
          ? state.lightningSwap!.paymentAmount
          : (state.chainSwap != null)
          ? state.chainSwap!.paymentAmount
          : state.confirmedAmountSat;
      // Fees can be selectedFee as it defaults to Fastest
      if (state.selectedWallet!.network.isLiquid) {
        // ignore: avoid_bool_literals_in_conditional_expressions
        final drain = state.lightningSwap != null ? false : state.sendMax;
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
        } else if (state.lightningSwap != null) {
          final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
            swapId: state.lightningSwap!.id,
            lockupFees: absoluteFees,
          );
          emit(
            state.copyWith(
              unsignedPsbt: pset,
              liquidAbsoluteFees: absoluteFees,
              lightningSwap: updatedSwap as LnSendSwap,
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
        final drain = state.lightningSwap != null ? false : state.sendMax;
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
          'lightningSwap=${state.lightningSwap != null} '
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
              buildTransactionException: BuildTransactionException(
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
          } else if (state.lightningSwap != null) {
            final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
              swapId: state.lightningSwap!.id,
              lockupFees: bitcoinAbsoluteFeesSat,
            );
            emit(
              state.copyWith(
                unsignedPsbt: txPreparation.unsignedPsbt,
                signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
                bitcoinTxSize: signedPsbtAndTxSize.txSize,
                bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
                isToSelf: txPreparation.isToSelf,
                lightningSwap: updatedSwap as LnSendSwap,
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
      if (e is PrepareBitcoinSendException) {
        emit(
          state.copyWith(
            buildTransactionException: BuildTransactionException(e.message),
            buildingTransaction: false,
          ),
        );
        return;
      }
      if (e is PrepareLiquidSendException) {
        emit(
          state.copyWith(
            buildTransactionException: BuildTransactionException(e.message),
            buildingTransaction: false,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          buildTransactionException: BuildTransactionException(e.toString()),
          buildingTransaction: false,
        ),
      );
      return;
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

        emit(
          state.copyWith(signedLiquidTx: signedPset, signingTransaction: false),
        );
      } else {
        final paymentRequest = state.paymentRequest;
        if (state.isToSelf != true &&
            paymentRequest != null &&
            paymentRequest is Bip21PaymentRequest &&
            paymentRequest.pj.isNotEmpty) {
          final payjoinSender = await _sendWithPayjoinUsecase.execute(
            walletId: state.selectedWallet!.id,
            isTestnet: state.selectedWallet!.network.isTestnet,
            bip21: paymentRequest.uri,
            unsignedOriginalPsbt: state.unsignedPsbt!,
            amountSat: state.confirmedAmountSat!,
            networkFeesSatPerVb: state.selectedFee!.isRelative
                ? state.selectedFee!.value as double
                : 1,
            expireAfterSec: PayjoinConstants.defaultExpireAfterSec,
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
          confirmTransactionException: ConfirmTransactionException(
            e.toString(),
          ),
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

      if (state.selectedWallet!.network.isLiquid) {
        final txId = await _broadcastLiquidTxUsecase.execute(
          state.signedLiquidTx!,
        );
        emit(state.copyWith(txId: txId));
      } else {
        final paymentRequest = state.paymentRequest;
        if (state.isToSelf != true &&
            paymentRequest != null &&
            paymentRequest is Bip21PaymentRequest &&
            paymentRequest.pj.isNotEmpty) {
          emit(state.copyWith(broadcastingTransaction: false));
        } else {
          final txId = await _broadcastBitcoinTxUsecase.execute(
            isPsbt ? state.signedBitcoinPsbt! : state.signedBitcoinTx!,
            isPsbt: isPsbt,
          );
          emit(state.copyWith(txId: txId));
        }
      }

      if (state.lightningSwap != null) {
        await _updatePaidSendSwapUsecase.execute(
          txid: state.txId!,
          swapId: state.lightningSwap!.id,
          absoluteFees: state.absoluteFees!,
        );
      }
      if (state.chainSwap != null) {
        // Don't pass absoluteFees: createTransaction already persisted the
        // real lockup fee. Passing a value here overwrites it (0 clobbered it).
        await _updatePaidSendSwapUsecase.execute(
          txid: state.txId!,
          swapId: state.chainSwap!.id,
        );
      }

      if (state.label.isNotEmpty) {
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
          confirmTransactionException: ConfirmTransactionException(e.message),
          broadcastingTransaction: false,
        ),
      );
    } on BroadcastTransactionException catch (e) {
      log.warning('Failed to broadcast transaction: ${e.message}');
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            'BroadcastTransactionException',
            isBroadcastFailure: true,
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
          confirmTransactionException: ConfirmTransactionException(
            e.toString(),
          ),
          broadcastingTransaction: false,
        ),
      );
    }
  }

  Future<void> onConfirmTransactionClicked() async {
    try {
      if (state.signedBitcoinTx == null) {
        await createTransaction();
        await signTransaction();
        // if (!state.isLightning) {
        if (state.confirmTransactionException == null) {
          emit(state.copyWith(step: SendStep.sending));
        } else {
          emit(state.copyWith(step: SendStep.confirm));
          return;
        }
      }
      // }
      await broadcastTransaction(isPsbt: state.signedBitcoinTx == null);
      if (state.confirmTransactionException != null) {
        emit(state.copyWith(step: SendStep.confirm));
        return;
      }
      // Start watching the transaction to have the latest status
      _watchWalletTransactionByTxId(
        walletId: state.selectedWallet!.id,
        txId: state.txId!,
      );
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

  void _watchSendSwap(String swapId) {
    _swapSubscription?.cancel();
    _swapSubscription = _watchSwapUsecase.execute(swapId).listen((updatedSwap) {
      log.info(
        '[SendCubit] Watched swap ${updatedSwap.id} updated: ${updatedSwap.status}',
      );
      if (updatedSwap is LnSendSwap) {
        emit(state.copyWith(lightningSwap: updatedSwap));
        // paid == the invoice has been paid: the recipient has the money,
        // regardless of when the coop close handshake happens (batched
        // sub-minimum swaps may never get one).
        if (updatedSwap.status == SwapStatus.paid ||
            updatedSwap.status == SwapStatus.canCoop ||
            updatedSwap.status == SwapStatus.completed) {
          emit(state.copyWith(step: SendStep.success));
          unawaited(
            _getWalletUsecase
                .execute(state.selectedWallet!.id, sync: true)
                .catchError((e) {
                  log.warning('Failed to sync wallet after swap completed: $e');
                  return null;
                }),
          );
        }
      }
      if (updatedSwap is ChainSwap) {
        emit(state.copyWith(chainSwap: updatedSwap));
        if (updatedSwap.status == SwapStatus.completed) {
          emit(state.copyWith(step: SendStep.success));
        }
        if (updatedSwap.status == SwapStatus.completed ||
            updatedSwap.status == SwapStatus.refunded) {
          // Sync on refund too so the returned funds show up.
          unawaited(
            _getWalletUsecase
                .execute(state.selectedWallet!.id, sync: true)
                .catchError((e) {
                  log.warning('Failed to sync wallet after swap completed: $e');
                  return null;
                }),
          );
        }
      }
    });
  }

  /// Watches the sender side of an in-flight payjoin and resolves the send
  /// flow once it terminates. The payjoin negotiation runs asynchronously in
  /// the repository; without this the UI would sit on the "coordinating"
  /// screen forever (#2246).
  ///
  /// - completed: the receiver responded and the payjoin transaction was
  ///   broadcast — move to success with the payjoin txid.
  /// - expired: the receiver never responded; the repository fell back to
  ///   broadcasting the original transaction — move to success with the
  ///   original txid so the payment still resolves.
  void _watchPayjoin(String payjoinId) {
    _payjoinSubscription?.cancel();
    _payjoinSubscription = _watchPayjoinUsecase
        .execute(ids: [payjoinId])
        .where((payjoin) => payjoin is PayjoinSender)
        .cast<PayjoinSender>()
        .listen((payjoin) {
          log.info(
            '[SendCubit] Watched payjoin ${payjoin.id} updated: '
            '${payjoin.status}',
          );
          if (payjoin.isCompleted) {
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
            unawaited(
              _getWalletUsecase
                  .execute(state.selectedWallet!.id, sync: true)
                  .catchError((e) {
                    log.warning('Failed to sync wallet after payjoin: $e');
                    return null;
                  }),
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
      clearAllExceptions();
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
            swapLimitsException: SwapLimitsException(
              'Balance too low for minimum swap amount',
              minLimit: swapLimits.min,
            ),
          ),
        );
        return;
      }
      if (swapLimits.max < maxAmount) {
        emit(
          state.copyWith(
            swapLimitsException: SwapLimitsException(
              'Amount exceeds maximum swap amount',
              maxLimit: swapLimits.max,
            ),
          ),
        );
        return;
      }
    } catch (e) {
      emit(
        state.copyWith(
          buildTransactionException: BuildTransactionException(e.toString()),
        ),
      );
    }
  }

  Future<void> updateSignedBitcoinTx(String signedTx) async {
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
        insufficientBalanceException: null,
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
