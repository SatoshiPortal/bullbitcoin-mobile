import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart'
    show BroadcastTransactionException;
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
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
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
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
    required this._createChainSwapToExternalUsecase,
    required this._watchWalletTransactionByTxIdUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._updateSendSwapLockupFeesUsecase,
    required this._verifyChainSwapAmountSendUsecase,
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
  final CreateSendSwapUsecase _createSendSwapUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTxUsecase;
  final SendWithPayjoinUsecase _sendWithPayjoinUsecase;
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

  StreamSubscription<Swap>? _swapSubscription;
  StreamSubscription<Wallet>? _selectedWalletSyncingSubscription;
  StreamSubscription<WalletTransaction>? _txSubscription;

  @override
  Future<void> close() async {
    await (
      _swapSubscription?.cancel() ?? Future.value(),
      _selectedWalletSyncingSubscription?.cancel() ?? Future.value(),
      _txSubscription?.cancel() ?? Future.value(),
    ).wait;
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
    emit(
      state.copyWith(
        scannedRawPaymentRequest: scannedRawPaymentRequest,
        copiedRawPaymentRequest: sanitizedText,
        paymentRequest: paymentRequest,
      ),
    );
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
      emit(
        state.copyWith(
          copiedRawPaymentRequest: sanitizedText,
          paymentRequest: paymentRequest,
        ),
      );
    } catch (e) {
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

      emit(state.copyWith(amount: validatedAmount, sendMax: isMax));
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
      emit(state.copyWith(utxos: utxos));
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
    await createTransaction();
    // updateSwapLockupFees();
  }

  Future<void> replaceByFeeChanged(bool replaceByFee) async {
    emit(state.copyWith(replaceByFee: replaceByFee));
    await createTransaction();
  }

  Future<void> loadFees() async {
    if (state.selectedWallet == null) return;
    try {
      final bitcoinFees = await _getNetworkFeesUsecase.execute(isLiquid: false);
      final liquidFees = await _getNetworkFeesUsecase.execute(isLiquid: true);
      emit(
        state.copyWith(
          bitcoinFeesList: bitcoinFees,
          liquidFeesList: liquidFees,
          selectedFeeOption: FeeSelection.fastest,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> feeOptionSelected(FeeSelection feeSelection) async {
    emit(state.copyWith(selectedFeeOption: feeSelection));
    await createTransaction();
    // updateSwapLockupFees();
  }

  Future<void> customFeesChanged(NetworkFee fee) async {
    emit(
      state.copyWith(customFee: fee, selectedFeeOption: FeeSelection.custom),
    );

    await createTransaction();
    // updateSwapLockupFees();
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
      await loadUtxos();
      emit(state.copyWith(buildingTransaction: true));
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
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: address,
          networkFee: state.selectedFee!,
          amountSat: amount,
          // ignore: avoid_bool_literals_in_conditional_expressions
          drain: state.lightningSwap != null ? false : state.sendMax,
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
        final txPreparation = await _prepareBitcoinSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: address,
          networkFee: state.selectedFee!,
          amountSat: amount,
          replaceByFee: state.replaceByFee,
          selectedInputs: state.selectedUtxos,
          // ignore: avoid_bool_literals_in_conditional_expressions
          drain: state.lightningSwap != null ? false : state.sendMax,
        );

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
          emit(
            state.copyWith(
              unsignedPsbt: txPreparation.unsignedPsbt,
              bitcoinTxSize: txPreparation.txSize,
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
          // TODO: Watch the payjoin and transaction to update the txId with the
          //  payjoin txId if it is completed.
          final txId = payjoinSender.originalTxId;
          emit(
            state.copyWith(
              txId: txId,
              payjoinSender: payjoinSender,
              signingTransaction: false,
            ),
          );
        } else {
          final signedPsbtAndTxSize = await _signBitcoinTxUsecase.execute(
            psbt: state.unsignedPsbt!,
            walletId: state.selectedWallet!.id,
          );
          if (state.chainSwap != null) {
            final bitcoinAbsoluteFeesSat =
                await _calculateBitcoinAbsoluteFeesUsecase.execute(
                  psbt: signedPsbtAndTxSize.signedPsbt,
                );
            final updatedSwap = await _updateSendSwapLockupFeesUsecase.execute(
              swapId: state.chainSwap!.id,
              lockupFees: bitcoinAbsoluteFeesSat,
            );
            emit(
              state.copyWith(
                signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
                chainSwap: updatedSwap as ChainSwap,
                signingTransaction: false,
              ),
            );
          } else {
            emit(
              state.copyWith(
                signedBitcoinPsbt: signedPsbtAndTxSize.signedPsbt,
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
    } on BroadcastTransactionException catch (_) {
      emit(
        state.copyWith(
          confirmTransactionException: ConfirmTransactionException(
            'BroadcastTransactionException',
            isBroadcastFailure: true,
          ),
          broadcastingTransaction: false,
        ),
      );
    } catch (e) {
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
        final dummyPset = await _prepareLiquidSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: dummySwapAddress,
          networkFee: networkFee,
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
        emit(state.copyWith(bitcoinTxSize: dummyDrainTxInfo.txSize));
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
}
