import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Network;
import 'package:swaps/order_swaps.dart';
import 'package:spend/fee_preview.dart';
import 'package:spend/spend.dart';
import 'package:send/src/payment/domain/usecases/load_send_display_preferences_usecase.dart';

import '../../domain/send_amount_conversion.dart';

import 'package:send/src/payment/domain/fixed_amount_wallet_choice_policy.dart';
import 'package:send/src/payment/domain/usecases/prepare_internal_recipient_usecase.dart';
import 'package:send/src/payment/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:send/src/payment/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart'
    show
        BitcoinTransactionRecipient,
        BitcoinUnit,
        ConvertAmount,
        Err,
        Ok,
        Outpoint,
        Result,
        Sats;

import 'dart:async';

import 'package:fees/fees.dart';
import 'package:send/src/payment/domain/usecases/load_send_network_fees_usecase.dart';
import 'package:send/send.dart';
import 'package:send/src/payment/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:primitives/primitives.dart' show ConversionConstants;
import 'package:satoshifier/payment_request.dart';
import 'package:coins/coins.dart' show WalletUtxo;
import 'package:sync/sync.dart' show WalletKey;

import '../../domain/send_source.dart';
import '../../domain/usecases/load_send_coins_usecase.dart';
import '../../domain/usecases/load_send_sources_usecase.dart';

import 'package:transactions/transactions.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:send/src/payment/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:send/src/payment/domain/usecases/create_send_swap_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:address_view/payment_destination.dart';
import 'package:send/src/payment/domain/usecases/broadcast_payjoin_original_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_visible_payjoin_transaction_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_adoptable_payjoin_sender_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:send/src/payment/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:send/src/payment/domain/usecases/prepare_sp_payment_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/refresh_sp_wallet_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:send/src/payment/domain/usecases/load_lnurl_pay_limits_usecase.dart';
import 'package:send/src/payment/domain/usecases/resolve_selected_inputs_usecase.dart';
import 'package:send/src/payment/domain/usecases/select_best_wallet_usecase.dart';
import 'package:send/src/payment/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:send/src/payment/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:send/src/payment/domain/usecases/send_sp_payment_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_sp_network_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/validate_sp_amount_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/validate_sp_recipient_for_send_usecase.dart';
import 'package:silent/silent.dart';
import 'package:send/src/payment/domain/usecases/watch_payjoin_usecase.dart';
import 'package:send/src/payment/presentation/send_mode.dart';
import 'package:send/src/payment/presentation/send_wallet_view.dart';
import 'package:send/src/payment/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:send/src/payment/domain/usecases/validate_coin_control_payment_request_usecase.dart';
import 'package:send/src/payment/domain/usecases/watch_send_swap_usecase.dart';
import 'package:send/src/payment/domain/bitcoin_recipient_list_policy.dart';
import 'package:send/src/payment/domain/boltz_swap_failure_to_send_failure.dart';
import 'package:send/src/payment/domain/usecases/create_boltz_send_swap_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_send_swap_route_usecase.dart';
import 'package:swaps/swaps.dart'
    show
        ChainSwap,
        CreateBitcoinToLiquidSwapUsecase,
        CreateLiquidToBitcoinSwapUsecase,
        ToAddress,
        DropPendingSwapLockupUsecase,
        GetSwapLimitsAndFeesUsecase,
        LnReceiveSwap,
        LnSendSwap,
        RecordPendingSwapLockupUsecase,
        RecordSwapLockupUsecase,
        Swap,
        SwapStatus,
        SwapType,
        SwapsFailure,
        WatchSwapUsecase;

import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:send/src/payment/domain/usecases/load_send_label_suggestions_usecase.dart';
import 'package:send/src/payment/domain/usecases/store_send_transaction_label_usecase.dart';

part 'send_mono_actions.dart';

class SendCubit extends Cubit<SendState>
    implements FeeModalActionsPort, FeeModalStatePort {
  SendCubit({
    this._prepareInternalRecipientUsecase,
    this._readAmountQuotes,
    WatchWalletRevisionsUsecase? watchWalletRevisionsUsecase,
    this._walletKey,
    this.mode = const SendModeBitcoin(),
    Set<Outpoint> initialSweepOutpoints = const {},
    Set<Outpoint> initialSelectedOutpoints = const {},
    required this._loadSendLabelSuggestions,
    required this._storeSendTransactionLabel,
    required this._bestWalletUsecase,
    required this._detectBitcoinStringUsecase,
    required this._loadPreferencesUsecase,
    required this._readExchangeRate,
    required this._loadNetworkFeesUsecase,
    required this._loadCoins,
    required this._validateBitcoinSelectionUsecase,
    required this._sendWithPayjoinUsecase,
    required this._spend,
    required this._watchPayjoinUsecase,
    required this._getAdoptablePayjoinSenderUsecase,
    required this._broadcastPayjoinOriginalUsecase,
    required this._getVisiblePayjoinTransactionUsecase,
    required this._retryPayjoinProposalUsecase,
    required this._loadSources,
    required this._createSendSwapUsecase,
    required this._getSendSwapQuoteUsecase,
    required this._createSendCrossChainSwapUsecase,
    required this._getSendCrossChainQuoteUsecase,
    required this._resolveLightningAddressUsecase,
    required this._loadLnurlPayLimitsUsecase,
    required this._updateSendSwapPayinUsecase,
    required this._watchSendSwapUsecase,
    required this._getSwapLimitsAndFeesUsecase,
    required this._createBitcoinToLiquidSwapUsecase,
    required this._createLiquidToBitcoinSwapUsecase,
    required this._transactions,
    required this._verifyChainSwapAmountSendUsecase,
    required this._verifyExchangePayinUsecase,
    required this._consolidation,
    required this._getSendPayjoinEnabledUsecase,
    required this._validateSpRecipientForSendUsecase,
    required this._validateSpAmountForSendUsecase,
    required this._getSpNetworkForSendUsecase,
    required this._prepareSpPaymentForSendUsecase,
    required this._sendSpPaymentForSendUsecase,
    required this._refreshSpWalletForSendUsecase,
    required this._resolveSelectedInputsUsecase,
    required this._validateCoinControlPaymentRequestUsecase,
    required this._getSendSwapRouteUsecase,
    required this._createBoltzSendSwapUsecase,
    required this._recordSwapLockupUsecase,
    required this._recordPendingSwapLockupUsecase,
    required this._dropPendingSwapLockupUsecase,
    required this._watchSwapUsecase,
    Future<PaymentRequest> Function(String)? parsePaymentRequest,
  }) : _parsePaymentRequest = parsePaymentRequest ?? PaymentRequest.parse,
       super(
         SendState(
           sweepOutpoints: Set.unmodifiable(initialSweepOutpoints),
           selectedInputOutpoints: Set.unmodifiable(initialSelectedOutpoints),
           sendType:
               initialSweepOutpoints.isEmpty && initialSelectedOutpoints.isEmpty
               ? SendType.lightning
               : _walletKey?.network is LiquidNetwork
               ? SendType.liquid
               : SendType.bitcoin,
           sendMax: initialSweepOutpoints.isNotEmpty,
           loadingBestWallet:
               initialSweepOutpoints.isNotEmpty ||
               initialSelectedOutpoints.isNotEmpty,
         ),
       ) {
    _revisionsSubscription = watchWalletRevisionsUsecase?.execute().listen(
      _onWalletRevision,
    );
  }

  void _applyMonoState(SendState next) => emit(next);

  /// Distinct user-defined labels for the suggestion chips in the label
  /// bottom sheet. Wraps the label suggestions use case so widgets
  /// don't need to reach into the locator.
  Future<Set<String>> fetchDistinctLabels() =>
      _loadSendLabelSuggestions.execute();

  final WalletKey? _walletKey;
  SendSource? _wallet;
  final PrepareInternalRecipientUsecase? _prepareInternalRecipientUsecase;
  int _internalRecipientGeneration = 0;
  final SendMode mode;
  bool get isSpMode => mode is SendModeSp;
  int? get preparedMaxAmountSat {
    if (!state.isMaxSend ||
        state.buildingTransaction ||
        state.failure != null) {
      return null;
    }
    if (isSpMode) return _spDraft == null ? null : state.confirmedAmountSat;
    if (state.usesRecipientList) {
      return state.recipientAmountsSat.length == 1
          ? state.recipientAmountsSat.single
          : null;
    }
    return state.unsignedPsbt == null ? null : state.maxSpendableBalanceSat;
  }

  final LoadSendLabelSuggestionsUsecase _loadSendLabelSuggestions;
  final StoreSendTransactionLabelUsecase _storeSendTransactionLabel;
  final SelectBestWalletUsecase _bestWalletUsecase;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final LoadSendDisplayPreferencesUsecase _loadPreferencesUsecase;
  final GetSendPayjoinEnabledUsecase _getSendPayjoinEnabledUsecase;
  final Future<Result<double, SendFailure>> Function({String? currencyCode})
  _readExchangeRate;
  final Future<Result<Map<SupportedCurrency, BitcoinPrice>, SendFailure>>
  Function()?
  _readAmountQuotes;
  final LoadSendNetworkFeesUsecase _loadNetworkFeesUsecase;
  final LoadSendCoinsUsecase _loadCoins;
  final LoadSendSourcesUsecase _loadSources;
  final ValidateBitcoinSelectionUsecase _validateBitcoinSelectionUsecase;
  final CreateSendSwapUsecase _createSendSwapUsecase;
  final GetSendSwapQuoteUsecase _getSendSwapQuoteUsecase;
  final CreateSendCrossChainSwapUsecase _createSendCrossChainSwapUsecase;
  final GetSendCrossChainQuoteUsecase _getSendCrossChainQuoteUsecase;
  final ResolveLightningAddressUsecase _resolveLightningAddressUsecase;
  final LoadLnurlPayLimitsUsecase _loadLnurlPayLimitsUsecase;
  final UpdateSendSwapPayinUsecase _updateSendSwapPayinUsecase;
  final WatchSendSwapUsecase _watchSendSwapUsecase;
  final SendWithPayjoinUsecase _sendWithPayjoinUsecase;
  final Spend _spend;
  final _spendPreviews = SpendFeePreview();
  PreparedBitcoinSpend? get preparedBitcoin => state.bitcoinPreparation;

  Future<BitcoinFeePreviewSlot> _previewBitcoin({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    required bool replaceByFee,
    required List<WalletUtxo> selectedInputs,
    required bool selectedOnly,
  }) async => _spendPreviews.project(
    (await _spend.previewBitcoinFee(
      walletId: walletId,
      recipients: recipients,
      networkFee: networkFee,
      replaceByFee: replaceByFee,
      selectedInputs: selectedInputs.map((coin) => coin.outpoint).toSet(),
      selectedOnly: selectedOnly,
    )).fold((value) => value, (_) => null),
  );

  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final GetAdoptablePayjoinSenderUsecase _getAdoptablePayjoinSenderUsecase;
  final BroadcastPayjoinOriginalUsecase _broadcastPayjoinOriginalUsecase;
  final GetVisiblePayjoinTransactionUsecase
  _getVisiblePayjoinTransactionUsecase;
  final RetryPayjoinProposalUsecase _retryPayjoinProposalUsecase;
  final GetSwapLimitsAndFeesUsecase _getSwapLimitsAndFeesUsecase;
  final CreateBitcoinToLiquidSwapUsecase _createBitcoinToLiquidSwapUsecase;
  final CreateLiquidToBitcoinSwapUsecase _createLiquidToBitcoinSwapUsecase;

  final Transactions _transactions;

  final VerifyChainSwapAmountSendUsecase _verifyChainSwapAmountSendUsecase;
  final VerifyExchangePayinUsecase _verifyExchangePayinUsecase;
  final Consolidation _consolidation;
  final ValidateSpRecipientForSendUsecase _validateSpRecipientForSendUsecase;
  final ValidateSpAmountForSendUsecase _validateSpAmountForSendUsecase;
  final GetSpNetworkForSendUsecase _getSpNetworkForSendUsecase;
  final PrepareSpPaymentForSendUsecase _prepareSpPaymentForSendUsecase;
  final SendSpPaymentForSendUsecase _sendSpPaymentForSendUsecase;
  final RefreshSpWalletForSendUsecase _refreshSpWalletForSendUsecase;
  final GetSendSwapRouteUsecase _getSendSwapRouteUsecase;
  final CreateBoltzSendSwapUsecase _createBoltzSendSwapUsecase;
  final RecordSwapLockupUsecase _recordSwapLockupUsecase;
  final RecordPendingSwapLockupUsecase _recordPendingSwapLockupUsecase;
  final DropPendingSwapLockupUsecase _dropPendingSwapLockupUsecase;
  final WatchSwapUsecase _watchSwapUsecase;

  SilentTxDraft? _spDraft;
  final ResolveSelectedInputsUsecase _resolveSelectedInputsUsecase;
  final ValidateCoinControlPaymentRequestUsecase
  _validateCoinControlPaymentRequestUsecase;
  final Future<PaymentRequest> Function(String) _parsePaymentRequest;

  StreamSubscription<Result<OrderSwapRecord, SendFailure>>?
  _orderSwapSubscription;
  StreamSubscription<Swap>? _boltzSwapSubscription;
  StreamSubscription<Result<SendSource?, SendFailure>>?
  _selectedWalletSyncingSubscription;
  StreamSubscription<String>? _revisionsSubscription;
  int _revisionRead = 0;
  StreamSubscription<WalletTransaction>? _txSubscription;
  StreamSubscription<PayjoinSession>? _payjoinSubscription;
  ({int generation, Future<PaymentRequest> future})?
  _pendingPaymentRequestInput;

  /// Monotonic token bumped by [clearBitcoinFeePreviews]. A preview build
  /// captures it before its `await` and re-checks before writing results
  /// back; if any input-shape change cleared the cache mid-flight the
  /// token moved on and the stale build is discarded instead of
  /// re-populating an emptied cache (which could otherwise stage a PSBT
  /// built for the previous tx shape for broadcast).
  int _bitcoinPreviewEpoch = 0;
  int _selectedWalletGeneration = 0;
  int _utxoLoadGeneration = 0;
  int _paymentRequestInputGeneration = 0;
  int _lightningInvoiceAttempt = 0;
  int _transactionGeneration = 0;
  int _nextRecipientId = 1;
  final Map<int, int> _recipientInputGenerations = {};
  Timer? _recipientPreviewTimer;
  Timer? _amountQuoteTimer;
  bool _loadingAmountQuotes = false;

  @override
  Future<void> close() async {
    _internalRecipientGeneration++;
    _recipientPreviewTimer?.cancel();
    _amountQuoteTimer?.cancel();
    await (
      _orderSwapSubscription?.cancel() ?? Future.value(),
      _boltzSwapSubscription?.cancel() ?? Future.value(),
      _selectedWalletSyncingSubscription?.cancel() ?? Future.value(),
      _revisionsSubscription?.cancel() ?? Future.value(),
      _txSubscription?.cancel() ?? Future.value(),
      _payjoinSubscription?.cancel() ?? Future.value(),
    ).wait;
    return super.close();
  }

  Future<void> _onWalletRevision(String walletId) async {
    final selected = state.selectedWallet;
    if (isClosed || selected is! SendWalletBitcoin || selected.id != walletId) {
      return;
    }
    final version = ++_revisionRead;
    try {
      final loaded = await _loadSources.read(walletId);
      final SendSource? wallet;
      switch (loaded) {
        case Ok(value: final source?) when source.key == selected.wallet.key:
          wallet = source;
        case Ok():
          wallet = null;
        case Err(:final failure):
          log.warning(
            'Send source revision read unavailable category=${failure.runtimeType}',
          );
          return;
      }
      if (isClosed ||
          version != _revisionRead ||
          state.selectedWallet?.id != walletId) {
        return;
      }
      clearBitcoinFeePreviews();
      emit(
        state.copyWith(
          selectedWallet: wallet == null ? null : SendWalletBitcoin(wallet),
          utxos: const [],
          selectedUtxos: wallet == null ? const [] : state.selectedUtxos,
        ),
      );
      if (wallet != null) await loadUtxos();
    } on Exception catch (error) {
      log.warning(
        'Send wallet revision read unavailable category=${error.runtimeType}',
      );
    }
  }

  /// LWK and the RBF builder are rate-only at the SDK boundary. When the user
  /// picked an absolute custom fee, we need a tx vsize to convert the absolute
  /// amount back to a rate. We get vsize by building a placeholder PSET at
  /// Liquid's minrelayfee — vsize is essentially independent of the fee rate,
  /// so the placeholder is accurate to within a single vbyte.
  Future<Result<RelativeFee, SendFailure>> _resolveLiquidFeeRate({
    required NetworkFee fee,
    required String walletId,
    required String address,
    required int? amountSat,
    required bool drain,
    Set<Outpoint>? selectedInputs,
  }) async {
    if (fee is RelativeFee) return Ok(fee);
    if (fee is! AbsoluteFee) {
      // A NetworkFee that is neither relative nor absolute is a programming
      // error, so it stays a thrown Error rather than becoming a Failure.
      throw StateError('Unexpected NetworkFee variant: $fee');
    }
    final placeholderResult = await _spend.prepareLiquid(
      walletId: walletId,
      address: address,
      amountSat: drain ? null : amountSat,
      feeRate: const RelativeFee(25),
      drain: drain,
      selectedInputs: selectedInputs,
    );
    return switch (placeholderResult) {
      Ok(:final value) => Ok(
        NetworkFee.relativeFromAbsoluteAndVsize(
          absoluteSats: fee.sats,
          vsize: value.discountedVsize,
        ),
      ),
      Err(:final failure) => Err(
        _liquidBuildFailure(failure, selectedInputs: selectedInputs),
      ),
    };
  }

  void clearFailure() => emit(state.copyWith(failure: null));

  int _startNewPaymentRequestInput() {
    cancelPendingInternalRecipient();
    final generation = ++_paymentRequestInputGeneration;
    _invalidateSignedTransaction();
    _dropBoltzSwap();
    if (state.loadingBestWallet || state.creatingSwap) {
      emit(state.copyWith(loadingBestWallet: false, creatingSwap: false));
    }
    return generation;
  }

  /// A Boltz swap belongs to the recipient, wallet and amount it was created
  /// for: once any of them changes, its lockup must never be paid. Going
  /// forward again reuses the pending swap of the same invoice, or creates a
  /// new one.
  void _dropBoltzSwap() {
    if (state.lightningSwap == null && state.chainSwap == null) return;
    unawaited(_stopWatchingBoltzSwap());
    emit(state.copyWith(lightningSwap: null, chainSwap: null));
  }

  void backClicked() {
    _lightningInvoiceAttempt++;
    cancelPendingInternalRecipient();
    _invalidateSignedTransaction();
    if (state.step != SendStep.address) _dropBoltzSwap();
    if (state.step == SendStep.address) {
      emit(
        state.copyWith(step: SendStep.address, amountConfirmedClicked: false),
      );
    } else if (state.step == SendStep.amount) {
      emit(
        state.copyWith(step: SendStep.address, amountConfirmedClicked: false),
      );
    } else if (state.step == SendStep.confirm) {
      emit(
        state.copyWith(
          step: state.isSweep && !state.hasMultipleRecipients
              ? SendStep.address
              : SendStep.amount,
          failure: null,
          amountConfirmedClicked: false,
        ),
      );
      // Quotes are not refreshed on the confirm step; editing resumes with a
      // current rate rather than the one from before the confirmation.
      unawaited(refreshAmountQuotes());
    }
  }

  Future<void> loadWalletWithRatesAndFees() async {
    try {
      // Silent Payments sends from the SP wallet, not the regular list, so it
      // returns before the wallets are loaded and cannot be blocked by them.
      if (mode case SendModeSp(:final walletLabel)) {
        final walletResult = await _refreshSpWalletForSendUsecase.execute();
        switch (walletResult) {
          case Ok(value: final spWallet):
            if (spWallet == null) return;
            emit(
              state.copyWith(
                selectedWallet: SendWalletSp(
                  label: walletLabel,
                  network: spWallet.network,
                  balanceSat: spWallet.balanceSat,
                ),
              ),
            );
            if (!await _loadLocalSendSettings()) return;
            await _loadCurrencyData();
            await getExchangeRate();
            await loadFees();
          case Err(failure: final failure):
            emit(state.copyWith(failure: failure));
        }
        return;
      }

      final List<SendSource> wallets;
      switch (await _loadSources.execute()) {
        case Ok(:final value):
          wallets = value;
        case Err(:final failure):
          log.warning('Failed to load the wallets: ${failure.logMessage}');
          emit(
            state.copyWith(
              failure: SendUnexpectedFailure('wallets: ${failure.runtimeType}'),
            ),
          );
          return;
      }
      if (isClosed) return;
      final walletKey = _walletKey;
      _wallet = walletKey == null
          ? null
          : wallets.where((source) => source.key == walletKey).firstOrNull;
      final explicitWalletIds = {walletKey?.id, state.selectedWallet?.id};
      emit(
        state.copyWith(
          wallets: wallets
              .where(
                (wallet) =>
                    !wallet.isWatchOnly ||
                    explicitWalletIds.contains(wallet.id),
              )
              .toList(),
        ),
      );
      if (!await _loadLocalSendSettings()) return;
      if (state.isSweep) {
        await _initializeSweep(state.sweepOutpoints);
      } else if (state.selectedInputOutpoints.isNotEmpty) {
        await _initializeSelectedInputs();
      }
      await _loadCurrencyData();
      await getExchangeRate();
      await loadFees();
    } catch (e) {
      log.warning('Failed to load wallet rates and fees', error: e);
      emit(
        state.copyWith(
          loadingBestWallet: false,
          failure: SendUnexpectedFailure(e.toString()),
        ),
      );
    }
  }

  Future<void> _initializeSweep(Set<Outpoint> outpoints) async {
    final wallet = _wallet;
    if (wallet == null) {
      emit(
        state.copyWith(
          sweepOutpoints: outpoints,
          sendType: SendType.bitcoin,
          loadingBestWallet: false,
          failure: const SendSelectedCoinsUnavailableFailure(),
        ),
      );
      return;
    }

    await _setSelectedWallet(wallet, manual: true);
    final amount = state.spendableBalanceSat.toString();
    emit(
      state.copyWith(
        amount: state.failure == null ? amount : '',
        inputAmountCurrencyCode: BitcoinUnit.sats.code,
        loadingBestWallet: false,
      ),
    );
  }

  Future<void> _initializeSelectedInputs() async {
    final wallet = _wallet;
    if (wallet == null) {
      emit(
        state.copyWith(
          sendType: SendType.bitcoin,
          loadingBestWallet: false,
          failure: const SendSelectedCoinsUnavailableFailure(),
        ),
      );
      return;
    }

    await _setSelectedWallet(
      wallet,
      manual: true,
      preserveSelectedInputs: true,
    );
    if (!isClosed) emit(state.copyWith(loadingBestWallet: false));
  }

  /// Called when a payment request is detected directly from the scanner
  Future<void> onScannedPaymentRequest(
    String scannedRawPaymentRequest, {
    bool autoContinue = true,
  }) async {
    if (state.selectedInputsUnavailable) return;
    if (isSpMode) {
      final input = onChangedText(scannedRawPaymentRequest);
      final generation = _paymentRequestInputGeneration;
      await input;
      if (!isClosed &&
          generation == _paymentRequestInputGeneration &&
          state.copiedRawPaymentRequest == scannedRawPaymentRequest.trim() &&
          state.hasValidPaymentRequest &&
          state.failure == null &&
          autoContinue) {
        await continueOnAddressConfirmed();
      }
      return;
    }
    final sanitizedText = scannedRawPaymentRequest.trim().replaceAll(
      RegExp(r'^["\"]+|["\"]+$'),
      '',
    );
    // The text input path invalidates the old request and fee plans, and shares
    // its parsing future with Continue before yielding to the detector.
    final input = onChangedText(scannedRawPaymentRequest);
    final generation = _paymentRequestInputGeneration;
    emit(
      state.copyWith(
        scannedRawPaymentRequest: scannedRawPaymentRequest,
        recipientDrafts: _primaryRecipientDrafts(
          paymentRequest: null,
          address: sanitizedText,
          isValid: false,
        ),
      ),
    );
    await input;
    if (isClosed ||
        generation != _paymentRequestInputGeneration ||
        state.copiedRawPaymentRequest != sanitizedText) {
      return;
    }
    if (state.hasValidPaymentRequest && state.failure == null && autoContinue) {
      await continueOnAddressConfirmed();
    }
  }

  /// Called when text is pasted or entered manually
  Future<void> onChangedText(String text) async {
    if (state.selectedInputsUnavailable) return;
    final inputGeneration = _startNewPaymentRequestInput();
    clearFailure();
    final sanitizedText = text.trim().replaceAll(
      RegExp(r'^["\"]+|["\"]+$'),
      '',
    );
    final recipientChanged =
        state.paymentRequest != null ||
        state.copiedRawPaymentRequest != sanitizedText;
    final recipients = state.recipientDrafts.isEmpty
        ? <SendRecipientDraft>[
            (
              id: 0,
              address: sanitizedText,
              amount: state.isSweep ? '' : state.amount,
              receivesRemainder: state.isSweep,
              isValid: false,
            ),
          ]
        : <SendRecipientDraft>[
            (
              id: state.recipientDrafts.first.id,
              address: sanitizedText,
              amount: state.recipientDrafts.first.amount,
              receivesRemainder: state.recipientDrafts.first.receivesRemainder,
              isValid: false,
            ),
            ...state.recipientDrafts.skip(1),
          ];
    emit(
      state.copyWith(
        copiedRawPaymentRequest: sanitizedText,
        paymentRequest: null,
        lnurlPay: null,
        recipientDrafts: recipients,
        recipientAmountsSat: recipientChanged
            ? const []
            : state.recipientAmountsSat,
        sendMax: state.isSweep,
      ),
    );
    if (recipientChanged) clearBitcoinFeePreviews();
    if (sanitizedText.isEmpty) {
      _pendingPaymentRequestInput = null;
      return;
    }
    if (isSpMode) {
      _pendingPaymentRequestInput = null;
      await _confirmSpRecipient(
        sanitizedText,
        advance: false,
        inputGeneration: inputGeneration,
      );
      return;
    }
    final parsing = Future<PaymentRequest>.sync(
      () => _detectBitcoinStringUsecase.execute(data: sanitizedText),
    );
    _pendingPaymentRequestInput = (
      generation: inputGeneration,
      future: parsing,
    );
    try {
      final paymentRequest = await parsing;
      if (isClosed ||
          inputGeneration != _paymentRequestInputGeneration ||
          state.copiedRawPaymentRequest != sanitizedText) {
        return;
      }
      final address = _bitcoinAddressOf(paymentRequest);
      final drafts = _primaryRecipientDrafts(
        paymentRequest: paymentRequest,
        address: address ?? sanitizedText,
        isValid: address != null,
      );
      emit(
        state.copyWith(
          paymentRequest: paymentRequest,
          amountConversion: (paymentRequest.amountSat ?? 0) > 0
              ? null
              : state.amountConversion,
          confirmedConversion: null,
          recipientConversions: (paymentRequest.amountSat ?? 0) > 0
              ? const {}
              : state.recipientConversions,
          recipientDrafts: drafts,
          internalRecipientWallets: _internalWalletsFor(drafts),
          qrAmountRecipientIds: _qrAmountsFor(drafts),
        ),
      );
    } on Error {
      rethrow;
    } catch (e) {
      if (isClosed ||
          inputGeneration != _paymentRequestInputGeneration ||
          state.copiedRawPaymentRequest != sanitizedText) {
        return;
      }
      emit(state.copyWith(failure: const SendInvalidPaymentRequestFailure()));
      // Type only, never the reason: this is user-pasted text and could be a
      // mistyped seed phrase or private key, which must never reach the logs.
      log.warning(
        'Could not parse the pasted payment request',
        error: e.runtimeType.toString(),
      );
    }
  }

  Set<int> _qrAmountsFor(Iterable<SendRecipientDraft> recipients) => {
    for (final recipient in recipients)
      if (state.qrAmountRecipientIds.contains(recipient.id)) recipient.id,
  };

  Map<int, SendSource> _internalWalletsFor(
    Iterable<SendRecipientDraft> recipients,
  ) => {
    for (final recipient in recipients)
      recipient.id: ?state.internalRecipientWallets[recipient.id],
  };

  List<SendRecipientDraft> _primaryRecipientDrafts({
    required PaymentRequest? paymentRequest,
    required String address,
    required bool isValid,
  }) {
    final existing = state.recipientDrafts;
    final policy = const BitcoinRecipientListPolicy();
    final selectedIsMainnet = state.selectedWallet?.network.isMainnet;
    final existingNetworkIsTestnet =
        policy.networkIsTestnet(state.paymentRequest) ??
        (selectedIsMainnet == null ? null : !selectedIsMainnet);
    final canKeepAdditional = policy.shouldRetainAdditionalRecipients(
      recipientCount: existing.length,
      nextRequest: paymentRequest,
      currentNetworkIsTestnet: existingNetworkIsTestnet,
    );
    final primary = existing.isEmpty
        ? (
            id: 0,
            address: address,
            amount: state.isSweep ? '' : state.amount,
            receivesRemainder: state.isSweep,
            isValid: isValid,
          )
        : (
            id: existing.first.id,
            address: address,
            amount: existing.first.amount,
            receivesRemainder: canKeepAdditional
                ? existing.first.receivesRemainder
                : state.isSweep,
            isValid: isValid,
          );
    return [primary, if (canKeepAdditional) ...existing.skip(1)];
  }

  String? _bitcoinAddressOf(PaymentRequest? request) => switch (request) {
    BitcoinPaymentRequest(:final address) => address,
    Bip21PaymentRequest(:final network, :final address)
        when network is BitcoinNetwork =>
      address,
    _ => null,
  };

  Future<PaymentRequest?> _resolvePrimaryPaymentRequest(
    int inputGeneration,
  ) async {
    final rawPaymentRequest = state.copiedRawPaymentRequest;
    final cachedPaymentRequest = state.paymentRequest;
    if (rawPaymentRequest.isEmpty && cachedPaymentRequest == null) {
      emit(
        state.copyWith(
          paymentRequest: null,
          loadingBestWallet: false,
          failure: const SendInvalidPaymentRequestFailure(),
        ),
      );
      return null;
    }

    final PaymentRequest paymentRequest;
    if (cachedPaymentRequest != null) {
      paymentRequest = cachedPaymentRequest;
    } else {
      try {
        final pendingInput = _pendingPaymentRequestInput;
        paymentRequest =
            await (pendingInput != null &&
                    pendingInput.generation == inputGeneration
                ? pendingInput.future
                : Future<PaymentRequest>.sync(
                    () => _detectBitcoinStringUsecase.execute(
                      data: rawPaymentRequest,
                    ),
                  ));
      } on Exception {
        if (isClosed ||
            inputGeneration != _paymentRequestInputGeneration ||
            state.copiedRawPaymentRequest != rawPaymentRequest) {
          return null;
        }
        emit(
          state.copyWith(
            loadingBestWallet: false,
            failure: const SendInvalidPaymentRequestFailure(),
          ),
        );
        return null;
      }
    }
    if (isClosed ||
        inputGeneration != _paymentRequestInputGeneration ||
        state.copiedRawPaymentRequest != rawPaymentRequest) {
      return null;
    }

    final address = _bitcoinAddressOf(paymentRequest);
    final recipientDrafts = _primaryRecipientDrafts(
      paymentRequest: paymentRequest,
      address: address ?? rawPaymentRequest,
      isValid: address != null,
    );
    emit(
      state.copyWith(
        paymentRequest: paymentRequest,
        recipientDrafts: recipientDrafts,
      ),
    );
    return paymentRequest;
  }

  void cancelPendingInternalRecipient() {
    _internalRecipientGeneration++;
    if (!isClosed && state.addingInternalRecipient) {
      emit(
        state.copyWith(
          addingInternalRecipient: false,
          loadingBestWallet: false,
        ),
      );
    }
  }

  Future<void> addInternalRecipient(String walletId) async {
    final prepare = _prepareInternalRecipientUsecase;
    if (prepare == null ||
        state.step != SendStep.address ||
        isSpMode ||
        !state.canAddRecipient ||
        state.addingInternalRecipient ||
        state.recipientDrafts.any((recipient) => !recipient.isValid)) {
      return;
    }
    final generation = ++_internalRecipientGeneration;
    emit(state.copyWith(addingInternalRecipient: true, failure: null));
    final result = await prepare.execute(
      walletId: walletId,
      wallets: state.wallets,
      request: state.paymentRequest,
      excludedAddresses: state.recipientDrafts
          .map((recipient) => recipient.address)
          .toSet(),
      fixedSourceWalletId: state.isSweep || state.usesSelectedInputsOnly
          ? (_wallet?.id ?? state.selectedWallet?.id)
          : null,
    );
    if (isClosed || generation != _internalRecipientGeneration) return;
    if (state.step != SendStep.address) {
      cancelPendingInternalRecipient();
      return;
    }
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(addingInternalRecipient: false, failure: failure));
      case Ok(:final value):
        await _addRecipient(internal: value, internalGeneration: generation);
        if (!isClosed && generation == _internalRecipientGeneration) {
          emit(state.copyWith(addingInternalRecipient: false));
        }
    }
  }

  Future<bool> addRecipient() {
    cancelPendingInternalRecipient();
    return _addRecipient();
  }

  Future<bool> _addRecipient({
    PreparedInternalRecipient? internal,
    int? internalGeneration,
  }) async {
    bool cancelled() =>
        internalGeneration != null &&
        (internalGeneration != _internalRecipientGeneration ||
            state.step != SendStep.address);
    final inputGeneration = _paymentRequestInputGeneration;
    if (cancelled() ||
        state.selectedInputsUnavailable ||
        (state.usesSelectedInputsOnly &&
            state.selectedWallet?.isLiquid == true)) {
      return false;
    }
    emit(state.copyWith(loadingBestWallet: true, failure: null));
    final paymentRequest = await _resolvePrimaryPaymentRequest(inputGeneration);
    if (paymentRequest == null || cancelled()) return false;
    if (!state.supportsRecipientList) {
      emit(state.copyWith(loadingBestWallet: false));
      return false;
    }
    final wallets = state.bitcoinRecipientWallets;
    if (wallets.isEmpty) {
      emit(
        state.copyWith(
          loadingBestWallet: false,
          failure: const SendInsufficientBalanceFailure(
            'A matching Bitcoin wallet is required',
          ),
        ),
      );
      return false;
    }
    final selectedWallet = state.selectedWallet;
    if (selectedWallet == null ||
        !wallets.any((wallet) => wallet.id == selectedWallet.id)) {
      final selection = _bestWalletUsecase.execute(
        wallets: wallets,
        request: paymentRequest,
        amountSat: state.totalFixedRecipientAmountSat,
      );
      final wallet = switch (selection) {
        Ok(:final value) => value,
        Err() => wallets.first,
      };
      await _setSelectedWallet(wallet, manual: false);
    }
    if (isClosed ||
        cancelled() ||
        inputGeneration != _paymentRequestInputGeneration ||
        state.paymentRequest != paymentRequest ||
        !state.supportsRecipientList) {
      return false;
    }
    final previousOrderSwapSubscription = _orderSwapSubscription;
    _orderSwapSubscription = null;
    await previousOrderSwapSubscription?.cancel();
    if (isClosed ||
        cancelled() ||
        inputGeneration != _paymentRequestInputGeneration ||
        state.paymentRequest != paymentRequest ||
        !state.supportsRecipientList) {
      return false;
    }
    final recipients = state.recipientDrafts.isEmpty
        ? _primaryRecipientDrafts(
            paymentRequest: state.paymentRequest,
            address: state.paymentRequestAddress,
            isValid: state.hasValidPaymentRequest,
          )
        : List<SendRecipientDraft>.of(state.recipientDrafts);
    final recipientId = _nextRecipientId++;
    recipients.add((
      id: recipientId,
      address: internal?.address ?? '',
      amount: '',
      receivesRemainder: false,
      isValid: internal != null,
    ));
    emit(
      state.copyWith(
        recipientDrafts: recipients,
        internalRecipientWallets: {
          ...state.internalRecipientWallets,
          if (internal != null) recipientId: internal.wallet,
        },
        recipientAmountsSat: const [],
        lightningInvoice: null,
        lightningOrder: null,
        lightningQuote: null,
        loadingBestWallet: false,
        creatingSwap: false,
        failure: null,
      ),
    );
    _dropBoltzSwap();
    _invalidateSignedTransaction();
    clearBitcoinFeePreviews();
    _scheduleRecipientPreview();
    return true;
  }

  void removeRecipient(int id) {
    cancelPendingInternalRecipient();
    if (state.recipientDrafts.length <= 1) return;
    final removed = state.recipientDrafts.firstWhere(
      (recipient) => recipient.id == id,
    );
    final recipients = state.recipientDrafts
        .where((recipient) => recipient.id != id)
        .toList();
    if (state.isSweep && removed.receivesRemainder) {
      final first = recipients.first;
      recipients[0] = (
        id: first.id,
        address: first.address,
        amount: first.amount,
        receivesRemainder: true,
        isValid: first.isValid,
      );
    }
    emit(
      state.copyWith(
        recipientDrafts: recipients,
        invalidAmountRecipientIds: {...state.invalidAmountRecipientIds}
          ..remove(id),
        recipientConversions: {...state.recipientConversions}..remove(id),
        qrAmountRecipientIds: {...state.qrAmountRecipientIds}..remove(id),
        internalRecipientWallets: {...state.internalRecipientWallets}
          ..remove(id),
        recipientAmountsSat: const [],
        failure: null,
      ),
    );
    _recipientInputGenerations.remove(id);
    _invalidateSignedTransaction();
    clearBitcoinFeePreviews();
    _scheduleRecipientPreview();
  }

  Future<void> recipientAddressChanged(int id, String text) async {
    cancelPendingInternalRecipient();
    if (state.internalRecipientWallets.containsKey(id)) {
      emit(
        state.copyWith(
          internalRecipientWallets: {...state.internalRecipientWallets}
            ..remove(id),
        ),
      );
    }
    final generation = (_recipientInputGenerations[id] ?? 0) + 1;
    _recipientInputGenerations[id] = generation;
    final sanitized = text.trim().replaceAll(RegExp(r'^["\"]+|["\"]+$'), '');
    _replaceRecipient(
      id,
      address: sanitized,
      isValid: false,
      clearPreparedTransaction: true,
    );
    if (sanitized.isEmpty) return;
    try {
      final request = await _detectBitcoinStringUsecase.execute(
        data: sanitized,
      );
      if (isClosed || _recipientInputGenerations[id] != generation) return;
      final address = const BitcoinRecipientListPolicy()
          .compatibleAdditionalAddress(
            request: request,
            primaryNetworkIsTestnet: const BitcoinRecipientListPolicy()
                .networkIsTestnet(state.paymentRequest),
            isSweep: state.isSweep,
          );
      final isCompatible = address != null;
      final embeddedAmountSat = switch (request) {
        Bip21PaymentRequest(:final amountSat) => amountSat,
        _ => null,
      };
      if (isCompatible && embeddedAmountSat != null) {
        _replaceRecipientWithEmbeddedAmount(
          id,
          address: address,
          amountSat: embeddedAmountSat,
        );
      } else {
        _replaceRecipient(
          id,
          address: isCompatible ? address : sanitized,
          isValid: isCompatible,
          clearPreparedTransaction: true,
        );
      }
      _scheduleRecipientPreview();
    } on Exception {
      if (isClosed || _recipientInputGenerations[id] != generation) return;
      _replaceRecipient(
        id,
        address: sanitized,
        isValid: false,
        clearPreparedTransaction: true,
      );
    }
  }

  void recipientEntryChanged(
    int id,
    BigInt? sats, {
    required bool isValid,
    required bool isEdit,
    required String currencyCode,
    required String text,
    required double? rate,
    required DateTime? quotedAt,
  }) {
    if (state.amountConfirmedClicked) return;
    final amountFailure = SendAmountConversion.validateQuantity(sats);
    if (amountFailure != null) {
      emit(
        state.copyWith(
          invalidAmountRecipientIds: {...state.invalidAmountRecipientIds, id},
          recipientConversions: {...state.recipientConversions}..remove(id),
          failure: amountFailure,
        ),
      );
      return;
    }
    final invalid = {...state.invalidAmountRecipientIds};
    if (isValid) {
      invalid.remove(id);
    } else {
      invalid.add(id);
    }
    final conversions = {...state.recipientConversions};
    if (isEdit) {
      conversions.remove(id);
      final conversion = SendAmountConversion.fromEdit(
        sats: sats,
        currencyCode: currencyCode,
        text: text,
        rate: rate,
        quotedAt: quotedAt,
      );
      if (conversion != null) conversions[id] = conversion;
    }
    emit(
      state.copyWith(
        invalidAmountRecipientIds: invalid,
        recipientConversions: conversions,
      ),
    );
    if (!isEdit) return;
    final unit = BitcoinUnit.fromCode(state.inputAmountCurrencyCode);
    unawaited(
      recipientAmountChanged(
        id,
        sats == null ? '' : Sats(sats).toBitcoinText(unit),
      ),
    );
  }

  Future<void> recipientAmountChanged(int id, String amount) async {
    final recipient = state.recipientDrafts.firstWhere((r) => r.id == id);
    if (recipient.receivesRemainder) return;
    final validatedAmount = _validateAmount(amount, recipient.amount);
    if (validatedAmount == recipient.amount) return;
    _replaceRecipient(
      id,
      amount: validatedAmount,
      clearPreparedTransaction: true,
    );
    if (id == 0) {
      emit(state.copyWith(amount: validatedAmount));
    }
    _scheduleRecipientPreview();
    await updateBestWallet();
  }

  void setRemainderRecipient(int id, bool receivesRemainder) {
    if (!receivesRemainder && state.isSweep) return;
    final recipients = [
      for (final recipient in state.recipientDrafts)
        (
          id: recipient.id,
          address: recipient.address,
          amount: recipient.amount,
          receivesRemainder: receivesRemainder && recipient.id == id,
          isValid: recipient.isValid,
        ),
    ];
    emit(
      state.copyWith(
        recipientDrafts: recipients,
        invalidAmountRecipientIds: receivesRemainder
            ? ({...state.invalidAmountRecipientIds}..remove(id))
            : state.invalidAmountRecipientIds,
        recipientConversions: receivesRemainder
            ? ({...state.recipientConversions}..remove(id))
            : state.recipientConversions,
        recipientAmountsSat: const [],
        failure: null,
      ),
    );
    _invalidateSignedTransaction();
    clearBitcoinFeePreviews();
    _scheduleRecipientPreview();
  }

  void _scheduleRecipientPreview() {
    _recipientPreviewTimer?.cancel();
    if (!state.usesRecipientList ||
        (!state.hasRemainderRecipient && !state.hasMultipleRecipients)) {
      return;
    }
    final wallet = state.selectedWallet;
    if (wallet == null || wallet.isLiquid) return;
    if (state.selectedFee == null || _previewBitcoinRecipients() == null) {
      return;
    }
    _recipientPreviewTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_previewRecipientAmounts()),
    );
  }

  Future<void> _previewRecipientAmounts() async {
    final wallet = state.selectedWallet;
    final fee = state.selectedFee;
    final recipients = _previewBitcoinRecipients();
    if (wallet == null || fee == null || recipients == null) return;

    final epoch = _bitcoinPreviewEpoch;
    final selection = state.selectedFeeOption;
    final slot = await _previewBitcoin(
      walletId: wallet.id,
      recipients: recipients,
      networkFee: fee,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
      selectedOnly: state.usesSelectedInputsOnly,
    );
    if (isClosed ||
        epoch != _bitcoinPreviewEpoch ||
        selection != state.selectedFeeOption ||
        !slot.isCacheReady) {
      return;
    }
    emit(
      state.copyWith(
        recipientAmountsSat: slot.recipientAmountsSat,
        bitcoinAbsoluteFeesSat: slot.feeSat,
        bitcoinTxSize: slot.txSize,
        isToSelf: slot.isToSelf,
        feePreviewCache: state.feePreviewCache.withSlot(selection, slot),
      ),
    );
  }

  void _replaceRecipient(
    int id, {
    String? address,
    String? amount,
    bool? isValid,
    bool clearPreparedTransaction = false,
  }) {
    final recipients = [
      for (final recipient in state.recipientDrafts)
        if (recipient.id == id)
          (
            id: recipient.id,
            address: address ?? recipient.address,
            amount: amount ?? recipient.amount,
            receivesRemainder: recipient.receivesRemainder,
            isValid: isValid ?? recipient.isValid,
          )
        else
          recipient,
    ];
    emit(
      state.copyWith(
        recipientDrafts: recipients,
        qrAmountRecipientIds: address == null
            ? state.qrAmountRecipientIds
            : ({...state.qrAmountRecipientIds}..remove(id)),
        recipientAmountsSat: clearPreparedTransaction
            ? const []
            : state.recipientAmountsSat,
        failure: null,
      ),
    );
    if (clearPreparedTransaction) {
      _invalidateSignedTransaction();
      clearBitcoinFeePreviews();
    }
  }

  void _replaceRecipientWithEmbeddedAmount(
    int id, {
    required String address,
    required int amountSat,
  }) {
    final inputCurrencyCode = state.isInputAmountFiat
        ? (state.bitcoinUnit ?? BitcoinUnit.sats).code
        : state.inputAmountCurrencyCode;
    String formatAmount(int sats) => inputCurrencyCode == BitcoinUnit.sats.code
        ? sats.toString()
        : ConvertAmount.satsToBtc(sats).toStringAsFixed(8);
    final convertsFromFiat = inputCurrencyCode != state.inputAmountCurrencyCode;
    final recipients = [
      for (final recipient in state.recipientDrafts)
        if (recipient.id == id)
          (
            id: recipient.id,
            address: address,
            amount: formatAmount(amountSat),
            receivesRemainder: false,
            isValid: true,
          )
        else if (convertsFromFiat &&
            !recipient.receivesRemainder &&
            recipient.amount.isNotEmpty)
          (
            id: recipient.id,
            address: recipient.address,
            amount: formatAmount(state.recipientAmountSat(recipient)),
            receivesRemainder: false,
            isValid: recipient.isValid,
          )
        else
          recipient,
    ];
    emit(
      state.copyWith(
        amount: recipients.first.amount,
        amountConversion: id == 0 ? null : state.amountConversion,
        recipientConversions: {...state.recipientConversions}..remove(id),
        invalidAmountRecipientIds: {...state.invalidAmountRecipientIds}
          ..remove(id),
        inputAmountCurrencyCode: inputCurrencyCode,
        recipientDrafts: recipients,
        qrAmountRecipientIds: {
          ...state.qrAmountRecipientIds,
          if (id != 0 && amountSat > 0) id,
        },
        recipientAmountsSat: const [],
        failure: null,
      ),
    );
    _invalidateSignedTransaction();
    clearBitcoinFeePreviews();
  }

  Future<void> continueOnAddressConfirmed() async {
    if (state.selectedInputsUnavailable || state.addingInternalRecipient) {
      return;
    }
    final inputGeneration = _paymentRequestInputGeneration;
    PaymentRequest? confirmedRequest;
    bool isStale() =>
        isClosed ||
        inputGeneration != _paymentRequestInputGeneration ||
        (confirmedRequest != null && state.paymentRequest != confirmedRequest);
    try {
      emit(state.copyWith(loadingBestWallet: true, failure: null));
      if (isSpMode) {
        final pendingInput = _pendingPaymentRequestInput;
        if (pendingInput != null &&
            pendingInput.generation == inputGeneration) {
          try {
            await pendingInput.future;
          } on Exception {
            // Silent Payments validates the input through its own use case below.
          }
        }
        if (inputGeneration != _paymentRequestInputGeneration) return;
        emit(state.copyWith(failure: null));
        await _confirmSpRecipient(state.copiedRawPaymentRequest);
        return;
      }

      var paymentRequest = await _resolvePrimaryPaymentRequest(inputGeneration);
      if (paymentRequest == null) return;
      final walletKey = _walletKey;
      if (walletKey != null && _wallet == null) {
        // Navigation can reach confirmation while the inventory is loading.
        // Keep the account chosen by the caller through that race.
        final result = await _loadSources.read(walletKey.id);
        if (isClosed || isStale()) return;
        switch (result) {
          case Ok(value: final source?) when source.key == walletKey:
            _wallet = source;
          case _:
            emit(
              state.copyWith(
                loadingBestWallet: false,
                failure: const SendUnexpectedFailure(
                  'Selected wallet unavailable',
                ),
              ),
            );
            return;
        }
      }
      if (!state.usesSelectedInputsOnly && !state.hasMultipleRecipients) {
        await unifiedBip21Prioritization(inputGeneration: inputGeneration);
        paymentRequest = state.paymentRequest ?? paymentRequest;
      }
      if (inputGeneration != _paymentRequestInputGeneration) return;

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
      confirmedRequest = paymentRequest;
      final coinControlWallet = state.selectedBitcoinWallet;
      if (state.usesSelectedInputsOnly &&
          !state.isSweep &&
          coinControlWallet != null &&
          coinControlWallet.isLiquid) {
        final validation = _validateCoinControlPaymentRequestUsecase.execute(
          wallet: coinControlWallet,
          paymentRequest: paymentRequest,
          isSweep: state.isSweep,
        );
        if (validation case Err(:final failure)) {
          emit(state.copyWith(loadingBestWallet: false, failure: failure));
          return;
        }
      }
      if (state.supportsRecipientList &&
          state.recipientDrafts.any((recipient) => !recipient.isValid)) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            failure: const SendInvalidPaymentRequestFailure(),
          ),
        );
        return;
      }

      if (state.isSweep) {
        final wallet = _wallet ?? state.selectedBitcoinWallet;
        if (wallet == null) {
          emit(
            state.copyWith(
              loadingBestWallet: false,
              failure: const SendInvalidPaymentRequestFailure(),
            ),
          );
          return;
        }
        switch (_validateCoinControlPaymentRequestUsecase.execute(
          wallet: wallet,
          paymentRequest: paymentRequest,
        )) {
          case Err(:final failure):
            emit(state.copyWith(loadingBestWallet: false, failure: failure));
            return;
          case Ok():
        }
        _applyEmbeddedPaymentLabel(paymentRequest);
        await _setSelectedWallet(wallet, manual: true);
        if (isStale()) return;
        emit(
          state.copyWith(
            sendType: wallet.isLiquid ? SendType.liquid : SendType.bitcoin,
            loadingBestWallet: false,
          ),
        );
        await loadFees(inputGeneration: inputGeneration);
        if (isStale()) return;
        if (state.hasMultipleRecipients) {
          emit(state.copyWith(step: SendStep.amount));
          return;
        }
        await onAmountConfirmed();
        return;
      }

      if (paymentRequest is Bolt11PaymentRequest) {
        final invoice = paymentRequest;
        if (invoice.expiresAt <=
            DateTime.now().millisecondsSinceEpoch ~/ 1000) {
          emit(
            state.copyWith(
              loadingBestWallet: false,
              failure: const SendInvoiceExpiredFailure(),
            ),
          );
          return;
        }
        emit(state.copyWith(lightningInvoice: invoice));
      }

      if (paymentRequest is LnAddressPaymentRequest) {
        final hasExistingLimits = state.lnurlPayLimits != null;
        final result = await _loadLnurlPayLimitsUsecase.execute(
          paymentRequest.address,
        );
        if (isStale()) return;
        switch (result) {
          case Err(:final failure):
            emit(
              state.copyWith(
                lnurlPay: null,
                loadingBestWallet: false,
                failure: failure,
              ),
            );
            return;
          case Ok(:final value):
            emit(
              state.copyWith(
                lnurlPay: (recipient: paymentRequest.address, limits: value),
                amount: hasExistingLimits ? state.amount : '',
                amountEntryValid: hasExistingLimits && state.amountEntryValid,
                amountConversion: hasExistingLimits
                    ? state.amountConversion
                    : null,
                confirmedAmountSat: null,
                confirmedConversion: null,
                sendMax: false,
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
      final SendSource wallet;
      final manuallySelectedWallet = state.isWalletManuallySelected
          ? state.selectedBitcoinWallet
          : null;
      final canUseManualWalletForRecipients =
          manuallySelectedWallet != null &&
          state.bitcoinRecipientWallets.any(
            (wallet) => wallet.id == manuallySelectedWallet.id,
          );
      final presetWallet = _wallet;
      final canUsePresetForRecipients =
          presetWallet != null &&
          state.bitcoinRecipientWallets.any(
            (wallet) => wallet.id == presetWallet.id,
          );
      if (state.hasMultipleRecipients && canUseManualWalletForRecipients) {
        wallet = manuallySelectedWallet;
      } else if (state.hasMultipleRecipients && canUsePresetForRecipients) {
        wallet = presetWallet;
      } else if (presetWallet != null && !state.hasMultipleRecipients) {
        wallet = presetWallet;
      } else {
        final selection = _bestWalletUsecase.execute(
          wallets: state.hasMultipleRecipients
              ? state.bitcoinRecipientWallets
              : state.wallets,
          request: paymentRequest,
          amountSat: state.hasMultipleRecipients
              ? state.totalFixedRecipientAmountSat
              : state.lnurlPayLimits?.fixedAmountSat ??
                    paymentRequest.amountSat,
        );
        switch (selection) {
          case Ok(:final value):
            wallet = value;
          case Err(:final failure):
            final directWallets = const FixedAmountWalletChoicePolicy()
                .eligibleWallets(paymentRequest, state.wallets);
            if (!state.usesSelectedInputsOnly && directWallets.length >= 2) {
              // Hardware wallets can fund a direct request even though the
              // automatic selector normally prefers a local signer.
              wallet = directWallets.first;
            } else {
              emit(
                state.copyWith(
                  loadingBestWallet: false,
                  creatingSwap: false,
                  failure: failure,
                ),
              );
              return;
            }
        }
      }

      final sendType = SendType.from(paymentRequest);

      // Pre-populate label from the embedded invoice description or BIP21 label
      // if the user hasn't manually set one already.
      _applyEmbeddedPaymentLabel(paymentRequest);

      await _setSelectedWallet(
        wallet,
        manual: state.hasMultipleRecipients && canUseManualWalletForRecipients,
      );
      if (isStale()) return;
      emit(state.copyWith(sendType: sendType));
      await loadFees(inputGeneration: inputGeneration);
      if (isStale()) return;
      if (state.blocksSwapDueToHardwareWallet) {
        emit(
          state.copyWith(
            loadingBestWallet: false,
            failure: const SendHardwareWalletFailure(),
          ),
        );
        return;
      }

      if (paymentRequest is Bolt11PaymentRequest) {
        final invoice = paymentRequest;
        if (invoice.amountSat == 0) {
          emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
          return;
        }
        emit(state.copyWith(creatingSwap: true));
        if (await _sendLightningViaBoltz(wallet: wallet, invoice: invoice)) {
          return;
        }
        if (isStale()) return;
        final quoteLoaded = await loadSendSwapQuote(
          wallet: wallet,
          amountSat: BigInt.from(invoice.amountSat),
          inputGeneration: inputGeneration,
        );
        if (isStale()) return;
        if (!quoteLoaded) {
          emit(state.copyWith(creatingSwap: false, loadingBestWallet: false));
          return;
        }
        final hasEnoughBalance = await hasBalance();
        if (isStale()) return;
        if (!hasEnoughBalance) {
          emit(
            state.copyWith(
              failure: const SendInsufficientBalanceFailure(),
              creatingSwap: false,
              loadingBestWallet: false,
            ),
          );
          return;
        }
        final swapResult = await _createSendSwapUsecase.execute(
          walletId: wallet.id,
          invoice: invoice,
          amountSat: invoice.amountSat,
          quote: state.lightningQuote,
          note: state.label,
        );
        if (isStale()) return;
        switch (swapResult) {
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
      if (paymentRequest.isBip21) {
        final needsWalletChoice = const FixedAmountWalletChoicePolicy()
            .requiresChoice(
              request: paymentRequest,
              wallets: state.wallets,
              hasFixedSource: state.usesSelectedInputsOnly,
            );
        if (paymentRequest.amountSat == null || needsWalletChoice) {
          emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        } else {
          if (!await handleChainSwap(inputGeneration: inputGeneration) ||
              state.failure != null) {
            return;
          }
          if (isStale()) return;
          await createTransaction();
        }
        return;
      }
      if (paymentRequest.isLnAddress) {
        emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
      } else {
        emit(state.copyWith(step: SendStep.amount, loadingBestWallet: false));
        return;
      }
    } on Exception catch (e, st) {
      if (isStale()) return;
      log.severe(
        message: 'Unexpected error while confirming the send address',
        error: e,
        trace: st,
      );
      emit(
        state.copyWith(
          failure: SendUnexpectedFailure(e.toString()),
          loadingBestWallet: false,
          creatingSwap: false,
        ),
      );
    }
  }

  void _applyEmbeddedPaymentLabel(PaymentRequest paymentRequest) {
    final embeddedLabel = switch (paymentRequest) {
      Bolt11PaymentRequest(description: final description)
          when description.isNotEmpty =>
        description,
      Bip21PaymentRequest(label: final label) when label.isNotEmpty => label,
      _ => null,
    };
    if (embeddedLabel != null && state.label.isEmpty) {
      emit(state.copyWith(label: embeddedLabel));
    }
  }

  // Creates an exact-output Exchange order before building its funding tx.
  /// Returns whether the caller should go on to build the funding
  /// transaction.
  Future<bool> handleChainSwap({int? inputGeneration}) async {
    bool isStale() =>
        inputGeneration != null &&
        inputGeneration != _paymentRequestInputGeneration;
    final isChainSwap =
        (state.sendType == SendType.liquid &&
            !state.selectedWallet!.isLiquid) ||
        state.sendType == SendType.bitcoin && state.selectedWallet!.isLiquid ||
        state.isChainSwap;
    if (isChainSwap) {
      if (state.isMaxSend) {
        emit(
          state.copyWith(
            amountConfirmedClicked: false,
            loadingBestWallet: false,
            failure: const SendSwapCreationFailure(
              'Send max is unavailable for Exchange cross-chain swaps',
            ),
          ),
        );
        return false;
      }
      final wallet = state.selectedBitcoinWallet!;
      final amountSat = state.paymentRequest!.amountSat ?? state.inputAmountSat;
      final destinationAddress = state.paymentRequest!.isBip21
          ? (state.paymentRequest! as Bip21PaymentRequest).address
          : state.paymentRequestAddress;
      switch (await _sendChainViaBoltz(
        wallet: wallet,
        destinationAddress: destinationAddress,
        receivableSat: amountSat,
      )) {
        case _BoltzChainSendOutcome.created:
          _confirmChainSwapAmount();
          return true;
        case _BoltzChainSendOutcome.stopped:
          return false;
        case _BoltzChainSendOutcome.useExchange:
          _dropBoltzSwap();
      }
      final quoteResult = await _getSendCrossChainQuoteUsecase.execute(
        wallet: wallet,
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: false,
      );
      if (isStale()) return false;
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
          return false;
      }
      if (quote.inAmountSat > BigInt.from(state.spendableBalanceSat)) {
        emit(
          state.copyWith(
            amountConfirmedClicked: false,
            loadingBestWallet: false,
            failure: const SendInsufficientBalanceFailure(),
          ),
        );
        return false;
      }
      emit(state.copyWith(creatingSwap: true, lightningQuote: quote));
      final swapResult = await _createSendCrossChainSwapUsecase.execute(
        walletId: wallet.id,
        destinationAddress: destinationAddress,
        destinationIsTestnet: state.paymentRequest!.isTestnet,
        amountSat: amountSat,
        isInAmountFixed: false,
        quotedCounterpartAmountSat: quote.inAmountSat,
        note: state.label.isEmpty ? null : state.label,
      );
      if (isStale()) return false;
      switch (swapResult) {
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
          return false;
      }
    }
    if (isStale()) return false;
    _confirmChainSwapAmount();
    return true;
  }

  void _confirmChainSwapAmount() {
    emit(
      state.copyWith(
        // Amountless external addresses carry no request amount; fall back to
        // the entered amount so the confirm headline never flashes 0 sats
        // before createTransaction settles it.
        confirmedAmountSat:
            state.paymentRequest?.amountSat ?? state.inputAmountSat,
        step: SendStep.confirm,
        loadingBestWallet: false,
      ),
    );
  }

  /// Pays [receivableSat] to [destinationAddress] on the other chain through a
  /// Boltz chain swap when the swap route starts with Boltz. The swap amount
  /// carries Boltz's current fees on top so the recipient gets exactly
  /// [receivableSat], as the exchange path's exact-output order does.
  Future<_BoltzChainSendOutcome> _sendChainViaBoltz({
    required SendSource wallet,
    required String destinationAddress,
    required int receivableSat,
  }) async {
    final inputGeneration = _paymentRequestInputGeneration;
    final route = await _getSendSwapRouteUsecase.execute();
    if (isClosed || inputGeneration != _paymentRequestInputGeneration) {
      return _BoltzChainSendOutcome.stopped;
    }
    if (!route.startsWithBoltz) return _BoltzChainSendOutcome.useExchange;
    final paymentRequest = state.paymentRequest;
    if (paymentRequest == null ||
        destinationAddress.isEmpty ||
        (paymentRequest is Bip21PaymentRequest
            ? paymentRequest.network.env != wallet.network.env
            : paymentRequest.isTestnet == wallet.network.isMainnet)) {
      emit(
        state.copyWith(
          amountConfirmedClicked: false,
          loadingBestWallet: false,
          failure: const SendInvalidPaymentRequestFailure(
            logMessage: 'Destination network does not match wallet network',
          ),
        ),
      );
      return _BoltzChainSendOutcome.stopped;
    }
    if (!await _spendPreconditionsReadable(wallet)) {
      return _BoltzChainSendOutcome.stopped;
    }
    emit(state.copyWith(creatingSwap: true));
    final fromLiquid = wallet.isLiquid;
    final limitsAndFees = await _getSwapLimitsAndFeesUsecase.execute(
      fromLiquid ? SwapType.liquidToBitcoin : SwapType.bitcoinToLiquid,
    );
    if (isClosed || inputGeneration != _paymentRequestInputGeneration) {
      return _BoltzChainSendOutcome.stopped;
    }
    final Result<ChainSwap, SwapsFailure> created;
    switch (limitsAndFees) {
      case Err(:final failure):
        created = Err(failure);
      case Ok(value: (_, final fees)):
        final amountSat = fees.calculateSwapAmountFromReceivableAmount(
          receivableSat,
        );
        final destination = ToAddress(destinationAddress);
        created = fromLiquid
            ? await _createLiquidToBitcoinSwapUsecase.execute(
                sendWalletId: wallet.id,
                amountSat: amountSat,
                destination: destination,
              )
            : await _createBitcoinToLiquidSwapUsecase.execute(
                sendWalletId: wallet.id,
                amountSat: amountSat,
                destination: destination,
              );
        if (isClosed || inputGeneration != _paymentRequestInputGeneration) {
          return _BoltzChainSendOutcome.stopped;
        }
    }
    switch (created) {
      case Err(:final failure):
        if (route.fallsBackToExchangeAfter(failure)) {
          log.fine(
            '[Send] Boltz unavailable, falling back to the exchange '
            '(${failure.runtimeType})',
          );
          emit(state.copyWith(creatingSwap: false));
          return _BoltzChainSendOutcome.useExchange;
        }
        emit(
          state.copyWith(
            creatingSwap: false,
            loadingBestWallet: false,
            amountConfirmedClicked: false,
            failure: failure.toSendFailure(amountSat: receivableSat),
          ),
        );
        return _BoltzChainSendOutcome.stopped;
      case Ok(value: final swap):
        await _orderSwapSubscription?.cancel();
        if (isClosed) return _BoltzChainSendOutcome.stopped;
        _orderSwapSubscription = null;
        _watchBoltzSwap(swap.id);
        emit(
          state.copyWith(
            chainSwap: swap,
            lightningSwap: null,
            lightningOrder: null,
            lightningQuote: null,
            creatingSwap: false,
          ),
        );
        if (state.spendableBalanceSat < swap.paymentAmount) {
          emit(
            state.copyWith(
              loadingBestWallet: false,
              amountConfirmedClicked: false,
              failure: const SendInsufficientBalanceFailure(
                'Not enough funds to cover amount and fees',
              ),
            ),
          );
          return _BoltzChainSendOutcome.stopped;
        }
        return _BoltzChainSendOutcome.created;
    }
  }

  Future<bool> loadSendSwapQuote({
    required SendSource wallet,
    required BigInt amountSat,
    int? inputGeneration,
  }) async {
    final result = await _getSendSwapQuoteUsecase.execute(
      wallet: wallet,
      amountSat: amountSat,
    );
    if (inputGeneration != null &&
        inputGeneration != _paymentRequestInputGeneration) {
      return false;
    }
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(lightningQuote: value, failure: null));
        return true;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return false;
    }
  }

  Future<bool> hasBalance() async {
    if ((state.selectedWallet == null && state.paymentRequest == null) ||
        state.paymentRequest == null) {
      return false;
    }
    final paymentRequest = state.paymentRequest!;
    // Balance checks exclude frozen coins once UTXOs have loaded.
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
        if (state.usesRecipientList) {
          final outputTotal = state.recipientAmountsSat.isNotEmpty
              ? state.recipientAmountsSat.fold(0, (sum, amount) => sum + amount)
              : state.totalFixedRecipientAmountSat;
          return spendableSat >= outputTotal + (state.absoluteFees ?? 0);
        }
        return spendableSat >=
            (state.effectiveAmountSat + (state.absoluteFees ?? 0));
    }
  }

  Future<bool> _loadLocalSendSettings() async {
    switch (await _loadPreferencesUsecase.execute()) {
      case Ok(:final value):
        final payjoinEnabled = await _getSendPayjoinEnabledUsecase.execute();
        emit(
          state.copyWith(
            fiatCurrencyCode: value.currencyCode,
            bitcoinUnit: value.bitcoinUnit,
            inputAmountCurrencyCode: BitcoinUnit.sats.code,
            payjoinGloballyEnabled: payjoinEnabled,
          ),
        );
        return true;
      case Err(:final failure):
        emit(state.copyWith(loadingBestWallet: false, failure: failure));
        return false;
    }
  }

  Future<void> _loadCurrencyData() async {
    await refreshAmountQuotes();
    if (isClosed) return;
    if (_readAmountQuotes != null) {
      _amountQuoteTimer ??= Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(refreshAmountQuotes()),
      );
    }
    final exchangeRate = await _exchangeRate();
    emit(
      state.copyWith(
        fiatCurrencyCodes: SupportedCurrency.codes,
        exchangeRate: exchangeRate,
      ),
    );
  }

  Future<void> refreshAmountQuotes() async {
    final quotes = _readAmountQuotes;
    if (quotes == null ||
        _loadingAmountQuotes ||
        state.amountConfirmedClicked ||
        state.step == SendStep.confirm) {
      return;
    }
    _loadingAmountQuotes = true;
    try {
      final result = await quotes();
      if (isClosed) return;
      switch (result) {
        case Ok(:final value):
          emit(state.copyWith(amountQuotes: value));
        case Err():
          emit(state.copyWith(amountQuotes: const {}));
      }
    } finally {
      _loadingAmountQuotes = false;
    }
  }

  void amountEntryChanged({
    required BigInt? sats,
    required String currencyCode,
    required String text,
    required double? rate,
    required DateTime? quotedAt,
    required bool isValid,
    required bool isEdit,
  }) {
    if (state.hasFixedRequestAmount || state.amountConfirmedClicked) return;
    final amountFailure = SendAmountConversion.validateQuantity(sats);
    if (amountFailure != null) {
      emit(
        state.copyWith(
          amountEntryValid: false,
          amountConversion: null,
          failure: amountFailure,
        ),
      );
      return;
    }
    final conversion = isEdit
        ? SendAmountConversion.fromEdit(
            sats: sats,
            currencyCode: currencyCode,
            text: text,
            rate: rate,
            quotedAt: quotedAt,
          )
        : state.amountConversion;
    emit(
      state.copyWith(
        amountEntryValid: isValid,
        amountConversion: conversion,
        confirmedConversion: null,
      ),
    );
    if (!isEdit) return;
    final unit = BitcoinUnit.values
        .where((unit) => unit.code == state.inputAmountCurrencyCode)
        .firstOrNull;
    if (unit == null) return;
    unawaited(
      amountChanged(amount: sats == null ? '' : Sats(sats).toBitcoinText(unit)),
    );
  }

  Future<void> amountChanged({String? amount, bool isMax = false}) async {
    if (state.hasFixedRequestAmount) return;
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
        final spendableSat = state.maxAvailableBalanceSat;
        if (state.inputAmountCurrencyCode == BitcoinUnit.sats.code) {
          validatedAmount = spendableSat.toString();
        } else {
          final spendableBtc = ConvertAmount.satsToBtc(spendableSat);
          validatedAmount = spendableBtc.toStringAsFixed(8);
        }
      } else {
        validatedAmount = _validateAmount(amount, state.amount);
      }

      final recipientDrafts = [
        for (var index = 0; index < state.recipientDrafts.length; index++)
          if (index == 0)
            (
              id: state.recipientDrafts[index].id,
              address: state.recipientDrafts[index].address,
              amount: validatedAmount,
              receivesRemainder: isMax,
              isValid: state.recipientDrafts[index].isValid,
            )
          else
            (
              id: state.recipientDrafts[index].id,
              address: state.recipientDrafts[index].address,
              amount: state.recipientDrafts[index].amount,
              receivesRemainder: isMax
                  ? false
                  : state.recipientDrafts[index].receivesRemainder,
              isValid: state.recipientDrafts[index].isValid,
            ),
      ];
      final hasRemainder = recipientDrafts.any(
        (recipient) => recipient.receivesRemainder,
      );
      final amountChanged =
          state.amount != validatedAmount ||
          state.hasRemainderRecipient != hasRemainder ||
          (!state.usesRecipientList && state.sendMax != isMax);
      emit(
        state.copyWith(
          amount: validatedAmount,
          amountConversion: isMax ? null : state.amountConversion,
          amountEntryValid: isMax ? true : state.amountEntryValid,
          recipientDrafts: recipientDrafts,
          recipientAmountsSat: amountChanged
              ? const []
              : state.recipientAmountsSat,
          sendMax: state.usesRecipientList ? false : isMax,
        ),
      );
      if (amountChanged) _invalidateSignedTransaction();
      // Amount is part of the cache fingerprint — any change invalidates
      // every previously-built preview PSBT. Without this clear, the user
      // can open the fee modal at amount A, change the amount to B
      // without re-opening the modal, and `createTransaction` reads back
      // a stale cached PSBT for A. Skip the clear when the validator
      // bounced the input (validatedAmount == state.amount).
      if (amountChanged) clearBitcoinFeePreviews();
      _scheduleRecipientPreview();
      if (isMax && !state.usesRecipientList) await createTransaction();
      if (isSpMode) return;
      // Don't update wallet when MAX is clicked to avoid changing network and triggering chain swaps
      if (!isMax) {
        await updateBestWallet();
      }
    } catch (e, st) {
      log.severe(
        message: 'Failed to apply the amount change',
        error: e,
        trace: st,
      );
      emit(state.copyWith(failure: SendUnexpectedFailure(e.toString())));
    }
  }

  String _validateAmount(String amount, String currentAmount) {
    if (amount.isEmpty) return amount;
    if (state.isInputAmountFiat) {
      final amountFiat = double.tryParse(amount);
      return amountFiat == null && amount != '.' ? currentAmount : amount;
    }
    if (state.inputAmountCurrencyCode == BitcoinUnit.sats.code) {
      final amountSats = BigInt.tryParse(amount);
      if (amountSats == null ||
          amount.contains('.') ||
          amountSats > ConversionConstants.maxSatsAmount) {
        return currentAmount;
      }
      return amountSats.toString();
    }
    final amountBtc = double.tryParse(amount);
    final decimals = amount.split('.').last.length;
    if ((amountBtc == null && amount != '.') ||
        decimals > BitcoinUnit.btc.decimals ||
        (amountBtc != null &&
            amountBtc > ConversionConstants.maxBitcoinAmount.toDouble())) {
      return currentAmount;
    }
    return amount;
  }

  Future<void> onCurrencyChanged(String currencyCode) async {
    double? exchangeRate = state.exchangeRate;
    String fiatCurrencyCode = state.fiatCurrencyCode;
    bool payjoinGloballyEnabled = state.payjoinGloballyEnabled;
    final preserveRemainder = state.hasMultipleRecipients;

    if (![BitcoinUnit.btc.code, BitcoinUnit.sats.code].contains(currencyCode)) {
      // If the currency is a fiat currency, retrieve the exchange rate and replace
      //  the current exchange rate and fiat currency code.
      final rate = await _exchangeRate(currencyCode: currencyCode);
      // No price for that currency: stay on the current one rather than take
      // a fiat input that cannot be converted.
      if (rate == null) return;
      fiatCurrencyCode = currencyCode;
      exchangeRate = rate;
    } else {
      // If the currency is a bitcoin unit, set the fiat currency and exchange
      //  rate back to the currency from the settings.
      final (result, rate, payjoinEnabled) = await (
        _loadPreferencesUsecase.execute(),
        _exchangeRate(),
        _getSendPayjoinEnabledUsecase.execute(),
      ).wait;

      switch (result) {
        case Ok(:final value):
          fiatCurrencyCode = value.currencyCode;
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
          return;
      }
      exchangeRate = rate;
      payjoinGloballyEnabled = payjoinEnabled;
    }

    emit(
      state.copyWith(
        inputAmountCurrencyCode: currencyCode,
        fiatCurrencyCode: fiatCurrencyCode,
        exchangeRate: exchangeRate,
        payjoinGloballyEnabled: payjoinGloballyEnabled,
        amount: '', // Clear the amount when changing the currency
        recipientDrafts: [
          for (final recipient in state.recipientDrafts)
            (
              id: recipient.id,
              address: recipient.address,
              amount: '',
              receivesRemainder:
                  preserveRemainder && recipient.receivesRemainder,
              isValid: recipient.isValid,
            ),
        ],
        recipientAmountsSat: const [],
        sendMax: false,
      ),
    );
  }

  Future<void> updateBestWallet() async {
    if (isSpMode) return;
    if (state.paymentRequest == null || state.selectedWallet == null) return;
    // Respect the user's manual wallet pick — auto-switching it silently
    // can route funds from the wrong wallet (e.g. cold → hot). See #1918.
    if (state.isWalletManuallySelected) return;

    emit(state.copyWith(loadingBestWallet: true));
    try {
      final preSelected = _wallet;
      if (preSelected != null &&
          (!state.hasMultipleRecipients ||
              state.bitcoinRecipientWallets.any(
                (wallet) => wallet.id == preSelected.id,
              ))) {
        await _setSelectedWallet(preSelected, manual: false);
      } else {
        final selection = _bestWalletUsecase.execute(
          wallets: state.hasMultipleRecipients
              ? state.bitcoinRecipientWallets
              : state.wallets,
          request: state.paymentRequest!,
          amountSat: state.usesRecipientList
              ? state.totalFixedRecipientAmountSat
              : state.inputAmountSat,
        );
        if (selection case Ok(:final value)) {
          await _setSelectedWallet(value, manual: false);
        }
      }
    } catch (e, st) {
      log.warning(
        'Failed to auto-pick the best wallet; keeping the current selection',
        error: e,
        trace: st,
      );
    } finally {
      emit(state.copyWith(loadingBestWallet: false));
    }
  }

  void noteChanged(String note) => emit(state.copyWith(label: note));

  SendAmountConversion? _conversionMatching(
    SendAmountConversion? conversion,
    int amountSat,
  ) => conversion != null && conversion.producedAmount(amountSat)
      ? conversion
      : null;

  /// The MAX amount in the unit the user is typing in: fiat when the input is fiat, otherwise BTC or sats.
  String _maxAmountText(int amountSat) {
    final rate = state.exchangeRate;
    if (state.isInputAmountFiat && rate != null) {
      return ConvertAmount.satsToFiat(amountSat, rate).toString();
    }
    final unit = state.inputAmountCurrencyCode == BitcoinUnit.btc.code
        ? BitcoinUnit.btc
        : BitcoinUnit.sats;
    return Sats.fromInt(amountSat).toBitcoinText(unit);
  }

  Future<void> onAmountConfirmed() async {
    if (!state.hasValidAmountEntry) return;
    _recipientPreviewTimer?.cancel();
    _bitcoinPreviewEpoch++;
    clearFailure();

    // SP has no bitcoin wallet to run hasBalance() against, so the amount is
    // checked here instead: before the build, so an obviously bad amount is
    // reported as such rather than as a generic prepare() failure.
    if (isSpMode && !await _confirmSpAmount()) return;
    if (isClosed) return;
    if (state.paymentRequest is LnAddressPaymentRequest) {
      final limits = state.lnurlPayLimits;
      if (limits == null) {
        emit(
          state.copyWith(failure: const SendLnurlLimitsUnavailableFailure()),
        );
        return;
      }
      if (!limits.includes(state.effectiveAmountSat)) {
        emit(
          state.copyWith(
            failure: SendLnurlAmountOutOfBoundsFailure(
              limits.minimumSat,
              limits.maximumSat,
            ),
          ),
        );
        return;
      }
      if (state.effectiveAmountSat > state.maxAvailableBalanceSat) {
        emit(state.copyWith(failure: const SendInsufficientBalanceFailure()));
        return;
      }
    }
    if (state.usesRecipientList) {
      if (!state.hasValidRecipientDrafts) {
        emit(state.copyWith(failure: const SendInvalidPaymentRequestFailure()));
        return;
      }
      final wallet = state.selectedWallet;
      if (wallet == null) {
        emit(
          state.copyWith(
            failure: const SendTransactionBuildFailure('No wallet selected'),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }
      if (state.hasMultipleRecipients && wallet.isLiquid) {
        emit(
          state.copyWith(
            failure: const SendInvalidPaymentRequestFailure(),
            amountConfirmedClicked: false,
          ),
        );
        return;
      }
    }

    if (state.blocksSwapDueToHardwareWallet) {
      emit(state.copyWith(failure: const SendHardwareWalletFailure()));
      return;
    }

    // A plain Bitcoin send still uses the recipient list for its one output.
    final paymentRequest = state.paymentRequest;
    final singleBitcoinConversion =
        paymentRequest is BitcoinPaymentRequest &&
            state.usesRecipientList &&
            state.recipientDrafts.length == 1 &&
            !state.isMaxSend
        ? _conversionMatching(
            state.amountConversion,
            state.totalFixedRecipientAmountSat,
          )
        : null;
    emit(
      state.copyWith(
        amountConfirmedClicked: true,
        confirmedConversion: _conversionMatching(
          state.hasFixedRequestAmount || state.usesRecipientList
              ? null
              : state.amountConversion,
          state.effectiveAmountSat,
        ),
        confirmedRecipientConversions: Map.unmodifiable({
          for (final recipient in state.recipientDrafts)
            recipient.id: ?_conversionMatching(
              state.recipientConversions[recipient.id],
              state.recipientAmountSat(recipient),
            ),
        }),
        confirmedAmountSat: state.usesRecipientList
            ? state.totalFixedRecipientAmountSat
            : state.effectiveAmountSat,
      ),
    );

    if (state.sendType == SendType.lightning) {
      final Bolt11PaymentRequest invoice;
      final paymentRequest = state.paymentRequest;
      if (paymentRequest is Bolt11PaymentRequest) {
        invoice = paymentRequest;
      } else {
        final inputGeneration = _paymentRequestInputGeneration;
        final attempt = ++_lightningInvoiceAttempt;
        final amountSat = state.effectiveAmountSat;
        final invoiceResult = await _resolveLightningAddressUsecase.execute(
          lightningAddress: state.paymentRequestAddress,
          amountSat: amountSat,
        );
        if (isClosed ||
            inputGeneration != _paymentRequestInputGeneration ||
            attempt != _lightningInvoiceAttempt ||
            !state.amountConfirmedClicked ||
            state.paymentRequest != paymentRequest ||
            state.effectiveAmountSat != amountSat) {
          return;
        }
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
      final boltzWallet = state.selectedBitcoinWallet;
      if (boltzWallet != null) {
        emit(state.copyWith(creatingSwap: true));
        if (await _sendLightningViaBoltz(
          wallet: boltzWallet,
          invoice: invoice,
        )) {
          return;
        }
        emit(state.copyWith(creatingSwap: false));
      }
      if (!await loadSendSwapQuote(
        wallet: state.selectedBitcoinWallet!,
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
        amountSat: state.effectiveAmountSat,
        quote: state.lightningQuote,
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
      if (!await handleChainSwap() || state.failure != null) return;
    }
    // updateSwapLockupFees();

    var transactionCreated = true;
    if (state.sendType == SendType.liquid ||
        state.sendType == SendType.bitcoin) {
      transactionCreated = await createTransaction();
    }
    // A regtest node without fee estimates still reaches the confirmation
    // screen below, where the user picks a custom fee.
    final regtestFeesUnavailable =
        state.failure is SendFeesUnavailableFailure &&
        state.selectedWallet?.network == BitcoinNetwork.regtest &&
        state.sendType == SendType.bitcoin;
    if (!transactionCreated && !regtestFeesUnavailable) {
      if (state.amountConfirmedClicked) {
        emit(state.copyWith(amountConfirmedClicked: false));
      }
      return;
    }
    if (isSpMode) {
      // The SP build already knows the fee and the spendable balance, so the
      // bitcoin balance check below would only re-answer it against a wallet
      // that does not exist.
      emit(
        state.copyWith(
          step: state.failure == null ? SendStep.confirm : state.step,
          amountConfirmedClicked: false,
        ),
      );
      return;
    }
    // Skipped when the build above already failed: it knows whether the fee or
    // the coins fell short, and this check would flatten that away.
    if (state.failure == null && !await hasBalance()) {
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
    // Regtest nodes may have no fee estimate yet. Keep the explicit failure
    // and unsigned state, but expose the existing custom-fee control on the
    // confirmation screen. A build still needs a user-selected valid fee.
    if (state.failure is SendFeesUnavailableFailure &&
        state.selectedWallet?.network == BitcoinNetwork.regtest &&
        state.sendType == SendType.bitcoin &&
        state.effectiveAmountSat > 0 &&
        await hasBalance()) {
      emit(
        state.copyWith(step: SendStep.confirm, amountConfirmedClicked: false),
      );
      return;
    }
    // Any other failure keeps the user here.
    if (state.failure == null) {
      final recipientConversion =
          state.paymentRequest == paymentRequest &&
              state.recipientAmountsSat.length == 1
          ? _conversionMatching(
              singleBitcoinConversion,
              state.recipientAmountsSat.single,
            )
          : null;
      emit(
        state.copyWith(
          confirmedConversion: recipientConversion ?? state.confirmedConversion,
          step: SendStep.confirm,
          confirmedAmountSat: state.usesRecipientList && !state.isChainSwap
              ? state.recipientAmountsSat.fold<int>(
                  0,
                  (sum, amount) => sum + amount,
                )
              : state.effectiveAmountSat,
          amountConfirmedClicked: false,
        ),
      );
    } else {
      emit(state.copyWith(amountConfirmedClicked: false));
    }
  }

  Future<void> _continueWithLightningOrder(OrderSwapRecord order) async {
    await _stopWatchingBoltzSwap();
    final txId = order.localPayinTransactionId;
    emit(
      state.copyWith(
        lightningSwap: null,
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

  /// Bitcoin funding reads the Payjoin reservations; when they cannot be read
  /// (the runtime still serves the network the app launched on) funding would
  /// fail after the swap was created. Surfaces the relaunch failure and
  /// returns false in that case, before any swap exists.
  Future<bool> _spendPreconditionsReadable(SendSource wallet) async {
    if (wallet.isLiquid) return true;
    final result = await _validateBitcoinSelectionUsecase.execute(
      walletId: wallet.id,
    );
    if (result is Ok) return true;
    if (!isClosed) {
      emit(
        state.copyWith(
          creatingSwap: false,
          loadingBestWallet: false,
          amountConfirmedClicked: false,
          failure: const SendRelaunchRequiredFailure(
            'spend preconditions unreadable',
          ),
        ),
      );
    }
    return false;
  }

  /// Tries to pay [invoice] through a Boltz submarine swap when the swap route
  /// starts with Boltz. Returns true when Boltz handled the send — the swap
  /// exists and its lockup is being built, or its failure was surfaced — and
  /// false when the exchange path should run instead: the route is
  /// exchange-only, or Boltz failed before creating anything and the user
  /// opted into the exchange fallback.
  Future<bool> _sendLightningViaBoltz({
    required SendSource wallet,
    required Bolt11PaymentRequest invoice,
  }) async {
    // A submarine swap pays the amount written in the invoice; an amountless
    // invoice can only be paid by the exchange, with the amount typed here.
    if (invoice.amountSat <= 0) return false;
    final inputGeneration = _paymentRequestInputGeneration;
    final route = await _getSendSwapRouteUsecase.execute();
    if (isClosed) return true;
    if (!route.startsWithBoltz) return false;
    if (!await _spendPreconditionsReadable(wallet)) return true;
    final created = await _createBoltzSendSwapUsecase.execute(
      wallet: wallet,
      invoice: invoice,
    );
    if (isClosed || inputGeneration != _paymentRequestInputGeneration) {
      return true;
    }
    switch (created) {
      case Ok(:final value):
        await _continueWithLightningSwap(value, invoice: invoice);
        return true;
      case Err(:final failure):
        if (route.fallsBackToExchangeAfter(failure)) {
          log.fine(
            '[Send] Boltz unavailable, falling back to the exchange '
            '(${failure.runtimeType})',
          );
          return false;
        }
        emit(
          state.copyWith(
            creatingSwap: false,
            loadingBestWallet: false,
            amountConfirmedClicked: false,
            failure: failure.toSendFailure(amountSat: invoice.amountSat),
          ),
        );
        return true;
    }
  }

  Future<void> _continueWithLightningSwap(
    LnSendSwap swap, {
    required Bolt11PaymentRequest invoice,
  }) async {
    await _orderSwapSubscription?.cancel();
    if (isClosed) return;
    _orderSwapSubscription = null;
    _watchBoltzSwap(swap.id);
    if (state.spendableBalanceSat < swap.paymentAmount) {
      emit(
        state.copyWith(
          lightningSwap: swap,
          lightningOrder: null,
          lightningQuote: null,
          creatingSwap: false,
          loadingBestWallet: false,
          amountConfirmedClicked: false,
          failure: const SendInsufficientBalanceFailure(
            'Not enough funds to cover amount and fees',
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        lightningSwap: swap,
        lightningOrder: null,
        lightningQuote: null,
        confirmedAmountSat: invoice.amountSat,
        creatingSwap: false,
        loadingBestWallet: false,
        amountConfirmedClicked: false,
        step: SendStep.confirm,
        failure: null,
      ),
    );
    await createTransaction();
  }

  void _watchBoltzSwap(String swapId) {
    _boltzSwapSubscription?.cancel();
    _boltzSwapSubscription = _watchSwapUsecase
        .execute(swapId)
        .listen(_onBoltzSwapUpdated);
  }

  Future<void> _stopWatchingBoltzSwap() async {
    await _boltzSwapSubscription?.cancel();
    _boltzSwapSubscription = null;
  }

  void _onBoltzSwapUpdated(Swap updated) {
    if (isClosed) return;
    switch (updated) {
      case LnSendSwap() when state.lightningSwap?.id == updated.id:
        emit(
          state.copyWith(
            lightningSwap: updated,
            step:
                updated.status == SwapStatus.paid ||
                    updated.status == SwapStatus.canCoop ||
                    updated.status == SwapStatus.completed
                ? SendStep.success
                : state.step,
          ),
        );
      case ChainSwap() when state.chainSwap?.id == updated.id:
        emit(state.copyWith(chainSwap: updated));
      default:
        return;
    }
    final sendWalletId = switch (updated) {
      LnSendSwap(:final sendWalletId) ||
      ChainSwap(:final sendWalletId) => sendWalletId,
      LnReceiveSwap() => null,
    };
    if (sendWalletId != null &&
        (updated.status == SwapStatus.completed ||
            updated.status == SwapStatus.refunded)) {
      unawaited(_refreshSource(sendWalletId));
    }
  }

  Future<void> _refreshSource(
    String walletId, {
    String diagnostic = 'send_post_transfer_refresh_failed',
  }) async {
    try {
      final result = await _loadSources.read(walletId, sync: true);
      if (result is Ok) return;
    } on Exception {
      // The payment already settled. Report refresh failure without payloads.
    }
    log.warning('$diagnostic category=unexpected');
  }

  Future<void> loadUtxos({
    int? transactionGeneration,
    bool invalidatePreparedTransaction = true,
  }) async {
    if (isSpMode) return;
    final wallet = state.selectedWallet;
    if (wallet == null) return;
    final loadGeneration = ++_utxoLoadGeneration;
    bool isStale() =>
        isClosed ||
        loadGeneration != _utxoLoadGeneration ||
        state.selectedWallet?.id != wallet.id ||
        (transactionGeneration != null &&
            transactionGeneration != _transactionGeneration);

    try {
      final loaded = await _loadCoins.execute(wallet.id);
      if (isStale()) return;
      final List<WalletUtxo> utxos;
      switch (loaded) {
        case Ok(:final value):
          utxos = value;
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
          return;
      }
      // A wallet sync can change the available coins. Any cached preview
      // PSBT was built against the prior UTXO set, so drop it — otherwise
      // a sync landing mid-flow could leave a stale PSBT staged for
      // broadcast. Guarded so a no-op refresh doesn't needlessly
      // re-shimmer an open modal.
      final utxosChanged = !setEquals(
        _coinSetFingerprint(state.utxos),
        _coinSetFingerprint(utxos),
      );
      // Proactively flag consolidation for Liquid wallets whose UTXO count is
      // over the threshold, so the card shows before a build is attempted. The
      // Preparation still enforces the consolidation requirement.
      // Routed through Consolidation (the same check the
      // consolidation banner uses) rather than re-deriving the comparison
      // here from a possibly-differently-filtered UTXO list, so this and the
      // banner can never disagree about whether the wallet needs
      // consolidating.
      final consolidationRequired =
          wallet.isLiquid &&
          !state.usesSelectedInputsOnly &&
          (await _consolidation.isRequired(wallet.id))
              .fold((value) => value, (_) => false);
      if (isStale()) return;
      // Resolve the persisted intent against fresh wallet data. On failure the
      // resolved list is emptied but the requested outpoints remain in state,
      // so clearing an error cannot silently fall back to automatic selection
      // or a partial subset.
      final requiredOutpoints = state.requiredInputOutpoints;
      final selectionResolution = requiredOutpoints.isEmpty
          ? null
          : await _resolveSelectedInputsUsecase.execute(
              outpoints: requiredOutpoints,
              availableUtxos: utxos,
            );
      if (isStale()) return;
      final selectedUtxos = switch (selectionResolution) {
        Ok(:final value) => value,
        Err() => const <WalletUtxo>[],
        null => const <WalletUtxo>[],
      };
      final selectionWasLost = switch (selectionResolution) {
        Err() => true,
        _ => false,
      };
      emit(
        state.copyWith(
          utxos: utxos,
          selectedUtxos: selectedUtxos,
          selectedInputOutpoints: state.isSweep
              ? state.selectedInputOutpoints
              : requiredOutpoints,
          recipientAmountsSat: utxosChanged
              ? const []
              : state.recipientAmountsSat,
          consolidationRequired: consolidationRequired,
          failure: switch (selectionResolution) {
            Err(:final failure) => failure,
            Ok() when state.failure is SendSelectedCoinsUnavailableFailure =>
              null,
            _ => state.failure,
          },
        ),
      );
      if (selectionWasLost) {
        _invalidateSignedTransaction(
          cancelInFlightBuild: transactionGeneration == null,
        );
        clearBitcoinFeePreviews();
      } else if (utxosChanged) {
        clearBitcoinFeePreviews();
        if (invalidatePreparedTransaction) {
          _invalidateSignedTransaction();
          if (state.step == SendStep.confirm) {
            await createTransaction();
          } else {
            _scheduleRecipientPreview();
          }
        }
      }
    } catch (e, st) {
      // A superseded load is not a failure, so it returns before logging.
      if (isStale()) return;
      log.severe(
        message: 'Failed to load the wallet utxos for coin control',
        error: e,
        trace: st,
      );
      emit(state.copyWith(failure: SendUnexpectedFailure(e.toString())));
    }
  }

  /// What can invalidate a cached preview PSBT: which coins exist and whether
  /// each is spendable. Renaming a coin can't, and counting it re-shimmered
  /// the open modal on every sync.
  static Set<({Outpoint outpoint, bool isFrozen})> _coinSetFingerprint(
    List<WalletUtxo> utxos,
  ) => utxos.map((u) => (outpoint: u.outpoint, isFrozen: u.isFrozen)).toSet();

  Future<void> utxoSelected(WalletUtxo utxo) async {
    final selectedUtxos = List.of(state.selectedUtxos);
    final selectedIndex = selectedUtxos.indexWhere(
      (u) => u.outpoint == utxo.outpoint,
    );
    if (selectedIndex >= 0) {
      selectedUtxos.removeAt(selectedIndex);
    } else {
      selectedUtxos.add(utxo);
    }
    emit(
      state.copyWith(
        selectedUtxos: selectedUtxos,
        selectedInputOutpoints: state.isSweep
            ? state.selectedInputOutpoints
            : {for (final selected in selectedUtxos) selected.outpoint},
      ),
    );
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

  Future<void> loadFees({int? inputGeneration}) async {
    final wallet = state.selectedWallet;
    if (wallet == null) return;
    bool isStale() =>
        (inputGeneration != null &&
            inputGeneration != _paymentRequestInputGeneration) ||
        state.selectedWallet?.network != wallet.network;
    try {
      final bitcoinResult = await _loadNetworkFeesUsecase.execute(
        walletNetwork: wallet.network,
        isLiquid: false,
      );
      if (isStale()) return;
      final FeeOptions bitcoinFees;
      switch (bitcoinResult) {
        case Ok(:final value):
          bitcoinFees = value;
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
          return;
      }
      FeeOptions? liquidFees;
      if (wallet.network != BitcoinNetwork.regtest) {
        final liquidResult = await _loadNetworkFeesUsecase.execute(
          walletNetwork: wallet.network,
          isLiquid: true,
        );
        if (isStale()) return;
        switch (liquidResult) {
          case Ok(:final value):
            liquidFees = value;
          case Err(:final failure):
            emit(state.copyWith(failure: failure));
            return;
        }
      }
      final ratesChanged =
          state.bitcoinFeesList != bitcoinFees ||
          state.liquidFeesList != liquidFees;
      emit(
        state.copyWith(
          bitcoinFeesList: bitcoinFees,
          liquidFeesList: liquidFees,
        ),
      );
      // Mempool rates changed — preset PSBTs were built at the old
      // rates and are now stale. Custom slot is keyed by the typed rate
      // so it's unaffected, but `clearBitcoinFeePreviews` is whole-batch
      // by design and the next modal open will rebuild it. Skip the
      // clear when the API returned identical rates (which freezed
      // equality on FeeOptions makes cheap to check).
      if (ratesChanged) {
        clearBitcoinFeePreviews();
        _scheduleRecipientPreview();
      }
    } catch (e) {
      if (isStale()) return;
      log.warning('Network fee rates unavailable', error: e.runtimeType);
      emit(
        state.copyWith(
          failure: SendFeesUnavailableFailure(e.runtimeType.toString()),
        ),
      );
    }
  }

  Future<void> feeOptionSelected(FeeSelection feeSelection) async {
    _recipientPreviewTimer?.cancel();
    _bitcoinPreviewEpoch++;
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
    _recipientPreviewTimer?.cancel();
    _bitcoinPreviewEpoch++;
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

    // The settings sheet can commit a fee before Send has selected a wallet.
    if (state.selectedWallet == null) return;
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
    if (isSpMode) return;
    if (state.selectedWallet == null) return;
    if (state.selectedWallet!.isLiquid) return; // Liquid path handled elsewhere
    final recipients = _previewBitcoinRecipients();
    if (recipients == null) {
      log.info(
        '[fee-preview] skip — recipients unavailable '
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
      'recipients=${recipients.length} '
      'selectedInputs=${state.selectedUtxos.length} rbf=${state.replaceByFee}',
    );
    final slot = await _previewBitcoin(
      walletId: state.selectedWallet!.id,
      recipients: recipients,
      networkFee: fee,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
      selectedOnly: state.usesSelectedInputsOnly,
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
  /// Slow) through Spend, which deduplicates by rate
  /// — same-rate presets share one PSBT so a quiet mempool can't make
  /// Slow look more expensive than Economic at the same 1 sat/vB.
  Future<void> loadBitcoinFeePresetPreviews() async {
    if (isSpMode) return;
    if (state.selectedWallet == null) return;
    if (state.selectedWallet!.isLiquid) return;
    final presets = state.bitcoinFeesList;
    if (presets == null) return;
    final recipients = _previewBitcoinRecipients();
    if (recipients == null) return;
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache.copyWith(presetsLoading: true),
      ),
    );
    final epoch = _bitcoinPreviewEpoch;
    log.info(
      '[fee-presets] start recipients=${recipients.length} '
      'selectedInputs=${state.selectedUtxos.length} rbf=${state.replaceByFee}',
    );
    final result = await _spend.previewBitcoinFeePresets(
      presets: presets,
      walletId: state.selectedWallet!.id,
      recipients: recipients,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos.map((coin) => coin.outpoint).toSet(),
      selectedOnly: state.usesSelectedInputsOnly,
    );
    final slots = result.fold(
      (value) => value.map(
        (key, preview) => MapEntry(key, _spendPreviews.project(preview)),
      ),
      (_) => <FeeSelection, BitcoinFeePreviewSlot>{},
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
    emit(
      state.copyWith(
        feePreviewCache: BitcoinFeePreviewCache.empty,
        recipientAmountsSat: state.step == SendStep.amount && state.isMaxSend
            ? const []
            : state.recipientAmountsSat,
      ),
    );
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
    if (state.boltzLockupAddress case final lockupAddress?) {
      return lockupAddress;
    }
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
    if (state.boltzLockupAmountSat case final lockupAmountSat?) {
      return lockupAmountSat;
    }
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

  List<BitcoinTransactionRecipient>? _previewBitcoinRecipients() {
    if (state.usesRecipientList) {
      if (!state.hasValidRecipientDrafts) return null;
      return state.bitcoinTransactionRecipients;
    }
    final address = _previewBitcoinAddress();
    final amount = _previewBitcoinAmountSat();
    if (address == null || amount == null) return null;
    return [
      if (state.isMaxSend)
        BitcoinTransactionRecipient.remainder(address: address)
      else
        BitcoinTransactionRecipient.fixed(
          address: address,
          amountSat: Sats.fromInt(amount),
        ),
    ];
  }

  // [CHAIN SWAP LIFECYCLE — Step 3: build the funding tx]
  // When state.chainSwap is set, this builds the tx that funds the Boltz
  // lockup. For sendMax chain swaps, the payment address receives the
  // remainder so the prepare usecase drains the wallet — this is the SECOND
  // drain (the first was Step 2a). The dummy in Step 2a is P2TR by design,
  // matching Boltz's P2TR lockup, so dummyFees == realFees and the drained
  // output equals swap.paymentAmount. If Boltz ever switches lockup script
  // type the dummies in Step 2a must be updated to match, otherwise Step 3b
  // will fire.
  Future<bool> createTransaction() async {
    // A lockup whose broadcast is still being confirmed may already be on
    // chain: building another payment to the same swap could fund it twice.
    if (state.boltzSendSwap?.hasPendingLockup ?? false) {
      emit(
        state.copyWith(
          failure: const SendTransactionConfirmationFailure(
            isBroadcastFailure: true,
            logMessage: 'swap lockup still being confirmed',
          ),
        ),
      );
      return false;
    }
    _invalidateSignedTransaction();
    final generation = _transactionGeneration;
    bool isStale() => generation != _transactionGeneration;
    try {
      bool hasSelectedFee() {
        if (state.selectedFeeOption == FeeSelection.custom) {
          return state.customFee != null;
        }
        return (state.selectedWallet?.isLiquid ?? false)
            ? state.liquidFeesList != null
            : state.bitcoinFeesList != null;
      }

      if (!hasSelectedFee()) {
        await loadFees();
        if (isStale()) return false;
        if (!hasSelectedFee()) return false;
      }
      if (isStale()) return false;
      final wallet = state.selectedWallet;
      if (wallet == null) {
        emit(
          state.copyWith(
            failure: const SendTransactionBuildFailure('No wallet selected'),
            buildingTransaction: false,
          ),
        );
        return false;
      }
      clearFailure();
      // Clear the previous build's derived confirmation values before
      // loadUtxos so the UI never pairs stale outputs or an absolute fee with
      // newly-changed inputs (rate / amount / UTXO selection).
      emit(
        state.copyWith(
          buildingTransaction: true,
          bitcoinAbsoluteFeesSat: null,
          liquidAbsoluteFees: null,
          recipientAmountsSat: state.usesRecipientList
              ? const []
              : state.recipientAmountsSat,
          confirmedAmountSat: state.usesRecipientList && !state.isChainSwap
              ? null
              : state.confirmedAmountSat,
        ),
      );
      await loadUtxos(
        transactionGeneration: generation,
        invalidatePreparedTransaction: false,
      );
      if (generation != _transactionGeneration || isClosed) return false;
      if (isSpMode) {
        await _buildSpTransaction();
        return state.failure == null && _spDraft != null;
      }
      if (state.failure != null || generation != _transactionGeneration) {
        if (generation == _transactionGeneration) {
          emit(state.copyWith(buildingTransaction: false));
        }
        return false;
      }
      final selectedFee = state.selectedFee;
      if (selectedFee == null) {
        emit(
          state.copyWith(
            failure: const SendFeesUnavailableFailure(),
            buildingTransaction: false,
          ),
        );
        return false;
      }
      final paymentRequest = state.paymentRequest;
      final address =
          state.lightningOrder?.order?.payinAddress ??
          state.boltzLockupAddress ??
          (paymentRequest is Bip21PaymentRequest
              ? paymentRequest.address
              : state.paymentRequestAddress);
      final amount =
          state.lightningOrder?.order?.payinAmountSat.toInt() ??
          state.boltzLockupAmountSat ??
          state.confirmedAmountSat;
      // A Lightning payment pays a fixed lockup: never drain into it.
      final paysFixedLightningAmount =
          state.lightningOrder != null || state.lightningSwap != null;
      // Fees can be selectedFee as it defaults to Fastest
      if (wallet.isLiquid) {
        final drain = !paysFixedLightningAmount && state.isMaxSend;
        final feeRateResult = await _resolveLiquidFeeRate(
          fee: selectedFee,
          walletId: wallet.id,
          address: address,
          amountSat: amount,
          drain: drain,
          selectedInputs: state.usesSelectedInputsOnly
              ? state.requiredInputOutpoints
              : null,
        );
        if (isStale()) return false;
        final RelativeFee liquidFeeRate;
        switch (feeRateResult) {
          case Ok(:final value):
            liquidFeeRate = value;
          case Err(:final failure):
            _invalidateSignedTransaction();
            emit(
              state.copyWith(
                failure: failure,
                buildingTransaction: false,
                consolidationRequired:
                    failure is SendConsolidationRequiredFailure,
              ),
            );
            return false;
        }
        final preparation = await _spend.prepareLiquid(
          walletId: wallet.id,
          address: address,
          feeRate: liquidFeeRate,
          amountSat: drain ? null : amount,
          drain: drain,
          selectedInputs: state.usesSelectedInputsOnly
              ? state.requiredInputOutpoints
              : null,
        );
        if (isStale()) return false;
        final PreparedLiquidSpend prepared;
        switch (preparation) {
          case Ok(:final value):
            prepared = value;
          case Err(:final failure):
            _invalidateSignedTransaction();
            final mapped = _liquidBuildFailure(
              failure,
              selectedInputs: state.usesSelectedInputsOnly
                  ? state.requiredInputOutpoints
                  : null,
            );
            emit(
              state.copyWith(
                failure: mapped,
                consolidationRequired:
                    mapped is SendConsolidationRequiredFailure,
                buildingTransaction: false,
              ),
            );
            return false;
        }
        final pset = prepared.unsignedPset;
        if (state.lightningOrder case final order?) {
          // Fail closed: never sign a pset that doesn't pay the pinned order.
          final payin = await _verifyExchangePayinUsecase.execute(
            psbtOrPset: pset,
            record: order,
            walletId: wallet.id,
          );
          if (isStale()) return false;
          if (payin case Err(:final failure)) {
            emit(state.copyWith(failure: failure, buildingTransaction: false));
            return false;
          }
        }
        if (state.boltzSendSwap case final boltzSwap?) {
          // [CHAIN SWAP LIFECYCLE — Step 3b: fail-safe verification]
          // Confirms the built pset pays swap.paymentAmount to
          // swap.paymentAddress. Guards against any future flow that
          // desyncs the funding tx from the swap's locked-in
          // amount/address, and against a Boltz lockup script-type
          // change that would invalidate the P2TR dummy assumption in
          // Step 2a.
          await _verifyChainSwapAmountSendUsecase.execute(
            psbtOrPset: pset,
            swap: boltzSwap,
            walletId: wallet.id,
          );
          if (isStale()) return false;
        }
        emit(
          state.copyWith(
            unsignedPsbt: pset,
            liquidPreparation: prepared,
            liquidAbsoluteFees: prepared.fee.value.toInt(),
            buildingTransaction: false,
          ),
        );
        if (state.isMaxSend && !state.usesRecipientList) {
          final maxAmountSat = state.maxSpendableBalanceSat;
          emit(
            state.copyWith(
              amount: _maxAmountText(maxAmountSat),
              confirmedAmountSat: maxAmountSat,
            ),
          );
        }
      } else {
        final drain = !paysFixedLightningAmount && state.isMaxSend;
        final List<BitcoinTransactionRecipient> recipients;
        if (state.usesRecipientList &&
            !paysFixedLightningAmount &&
            state.chainSwap == null) {
          recipients = state.bitcoinTransactionRecipients;
        } else if (drain) {
          recipients = [
            BitcoinTransactionRecipient.remainder(address: address),
          ];
        } else if (amount != null) {
          recipients = [
            BitcoinTransactionRecipient.fixed(
              address: address,
              amountSat: Sats.fromInt(amount),
            ),
          ];
        } else {
          emit(
            state.copyWith(
              failure: const SendTransactionBuildFailure('Amount required'),
              buildingTransaction: false,
            ),
          );
          return false;
        }
        // Retain the reviewed wallet generation, not just the PSBT bytes.
        final cached = state.isSweep
            ? null
            : _spendPreviews.prepared(
                state.feePreviewCache.slotFor(state.selectedFeeOption),
              );
        final preparationResult = cached != null
            ? Ok<PreparedBitcoinSpend, SpendFailure>(cached)
            : await _spend.prepareBitcoin(
                walletId: wallet.id,
                recipients: recipients,
                networkFee: selectedFee,
                replaceByFee: state.replaceByFee,
                selectedInputs: state.selectedUtxos
                    .map((coin) => coin.outpoint)
                    .toSet(),
                selectedOnly: state.usesSelectedInputsOnly,
              );
        if (isStale()) return false;
        final PreparedBitcoinSpend txPreparation;
        switch (preparationResult) {
          case Ok(:final value):
            txPreparation = value;
          case Err(:final failure):
            final hasSelection = state.selectedUtxos.isNotEmpty;
            final mapped = switch (failure) {
              SpendSelectedInputsUnavailableFailure() =>
                const SendSelectedCoinsUnavailableFailure(),
              SpendNoSpendableInputsFailure() =>
                hasSelection
                    ? const SendSelectedCoinsUnavailableFailure()
                    : const SendInsufficientBalanceFailure(),
              SpendInsufficientFundsFailure() ||
              SpendInsufficientFundsForFeesFailure() =>
                hasSelection
                    ? const SendSelectedCoinsInsufficientFailure()
                    : state.frozenBalanceSat > 0
                    ? const SendInsufficientBalanceFailure()
                    : const SendInsufficientFundsForFeesFailure(),
              SpendUnavailableFailure(:final busy) => SendSpendBlockedFailure(
                busy: busy,
              ),
              SpendNetworkMismatchFailure() =>
                const SendAddressNetworkMismatchFailure(),
              _ => const SendTransactionBuildFailure(),
            };
            emit(state.copyWith(failure: mapped, buildingTransaction: false));
            return false;
        }
        final recipientAmountsSat = [
          for (final amount in txPreparation.recipientAmountsSat)
            amount.value.toInt(),
        ];
        final builtFee = txPreparation.fee.value.toInt();
        if (isStale()) return false;
        if (state.lightningOrder case final order?) {
          // Fail closed: never sign a psbt that doesn't pay the pinned order.
          final payin = await _verifyExchangePayinUsecase.execute(
            psbtOrPset: txPreparation.unsignedPsbt,
            record: order,
            walletId: wallet.id,
          );
          // Supersession first, as in the Liquid branch above: verification
          // awaits a repository call, so a newer build can start during it.
          // Emitting a superseded build's failure would clear
          // buildingTransaction under the live build and leave an error on
          // screen that the fresh build never produced.
          if (isStale()) return false;
          if (payin case Err(:final failure)) {
            emit(state.copyWith(failure: failure, buildingTransaction: false));
            return false;
          }
        }
        if (isStale()) return false;
        log.fine('[create-tx] transaction prepared');

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
          if (isStale()) return false;
          log.warning('[create-tx] built fee below relay floor');
          emit(
            state.copyWith(
              failure: SendFeeBelowRelayFloorFailure(
                'Built fee $builtFee sats at ${txPreparation.txSize} vbytes '
                'is below the relay floor of '
                '${state.bitcoinFeesList?.minRelay.satPerVbyte ?? NetworkFeeRelayPolicy.minRelaySatPerVbyte} sat/vB',
              ),
              buildingTransaction: false,
            ),
          );
          return false;
        }

        if (isStale()) return false;

        if (state.boltzSendSwap case final boltzSwap?) {
          // [CHAIN SWAP LIFECYCLE — Step 3b: fail-safe verification]
          // See note on the liquid branch above. Do not remove.
          await _verifyChainSwapAmountSendUsecase.execute(
            psbtOrPset: txPreparation.unsignedPsbt,
            swap: boltzSwap,
            walletId: wallet.id,
          );
          if (isStale()) return false;
        }

        // Software and hardware paths both keep the original opaque
        // preparation through verification and broadcast.
        SignedBitcoinSpend? signed;
        if (wallet.signsLocally && !state.willAttemptPayjoin) {
          final result = await _spend.signBitcoin(prepared: txPreparation);
          if (isStale()) return false;
          switch (result) {
            case Ok(:final value):
              signed = value;
            case Err(:final failure):
              emit(
                state.copyWith(
                  failure: _spendConfirmationFailure(failure),
                  buildingTransaction: false,
                ),
              );
              return false;
          }
        }
        emit(
          state.copyWith(
            bitcoinPreparation: txPreparation,
            bitcoinSignature: signed,
            unsignedPsbt: txPreparation.unsignedPsbt,
            signedBitcoinPsbt: signed?.signedTransaction,
            bitcoinTxSize: signed?.txSize ?? txPreparation.txSize,
            bitcoinAbsoluteFeesSat: builtFee,
            recipientAmountsSat: recipientAmountsSat,
            confirmedAmountSat: state.usesRecipientList
                ? recipientAmountsSat.fold<int>(
                    0,
                    (sum, amount) => sum + amount,
                  )
                : state.confirmedAmountSat,
            isToSelf: txPreparation.isToSelf,
            buildingTransaction: false,
          ),
        );
        if (state.isMaxSend && !state.hasMultipleRecipients) {
          // Keep the displayed MAX amount aligned with the built PSBT inputs.
          final maxAmountSat = state.maxSpendableBalanceSat;
          final rate = state.exchangeRate;
          final maxAmount =
              state.inputAmountCurrencyCode == BitcoinUnit.btc.code
              ? ConvertAmount.satsToBtc(maxAmountSat)
              : state.isInputAmountFiat && rate != null
              ? ConvertAmount.satsToFiat(maxAmountSat, rate)
              : maxAmountSat;
          emit(
            state.copyWith(
              amount: maxAmount.toString(),
              confirmedAmountSat: maxAmountSat,
            ),
          );
        }
      }
    } catch (e) {
      if (isStale()) return false;
      _invalidateSignedTransaction();
      log.severe(error: e, trace: StackTrace.current);
      emit(
        state.copyWith(
          failure: SendUnexpectedFailure(e.toString()),
          buildingTransaction: false,
        ),
      );
      return false;
    }
    return true;
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
    final generation = _transactionGeneration;
    final result = await _updateSendSwapPayinUsecase.execute(
      localId: order.localId,
      update: order.localStatus == OrderSwapLocalStatus.readyToBroadcast
          ? SendSwapPayinUpdate.replaced
          : SendSwapPayinUpdate.prepared,
      signedTransaction: signedTransaction,
      isPsbt: isPsbt,
    );
    if (isClosed || generation != _transactionGeneration) return false;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(lightningOrder: value));
        return true;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return false;
    }
  }

  Future<void> signTransaction() async {
    final generation = _transactionGeneration;
    bool isStale() => isClosed || generation != _transactionGeneration;
    final wallet = state.selectedWallet;
    final unsignedPsbt = state.unsignedPsbt;
    if (wallet == null || unsignedPsbt == null) {
      emit(
        state.copyWith(
          failure: SendTransactionConfirmationFailure(
            logMessage: wallet == null ? 'No wallet selected' : null,
          ),
          signingTransaction: false,
        ),
      );
      return;
    }
    try {
      emit(state.copyWith(signingTransaction: true));

      if (wallet.isLiquid) {
        final prepared = state.liquidPreparation;
        if (prepared == null || prepared.unsignedPset != unsignedPsbt) {
          emit(
            state.copyWith(
              failure: const SendTransactionConfirmationFailure(),
              signingTransaction: false,
            ),
          );
          return;
        }
        final signedResult = await _spend.signLiquid(prepared: prepared);
        if (isStale()) return;
        final SignedLiquidSpend signed;
        switch (signedResult) {
          case Ok(:final value):
            signed = value;
          case Err(:final failure):
            emit(
              state.copyWith(
                failure: _spendConfirmationFailure(failure),
                signingTransaction: false,
              ),
            );
            return;
        }
        final persisted = await _persistPreparedOrderPayin(
          signedTransaction: signed.signedPset,
          isPsbt: false,
        );
        if (isStale()) return;
        if (!persisted) {
          emit(state.copyWith(signingTransaction: false));
          return;
        }
        emit(
          state.copyWith(
            liquidSignature: signed,
            signedLiquidTx: signed.signedPset,
            signingTransaction: false,
          ),
        );
      } else {
        final prepared = state.bitcoinPreparation;
        if (prepared == null || prepared.unsignedPsbt != unsignedPsbt) {
          emit(
            state.copyWith(
              failure: const SendTransactionConfirmationFailure(),
              signingTransaction: false,
            ),
          );
          return;
        }
        final network = wallet.network;
        if (state.willAttemptPayjoin && network is BitcoinNetwork) {
          final paymentRequest = state.paymentRequest! as Bip21PaymentRequest;
          final payjoinResult = await _sendWithPayjoinUsecase.execute(
            walletId: wallet.id,
            network: network,
            bip21: paymentRequest.uri,
            prepared: prepared,
            amountSat: state.confirmedAmountSat!,
            networkFeesSatPerVb: state.selectedFee!.isRelative
                ? state.selectedFee!.value as double
                : 1,
          );
          final PayjoinSenderSession payjoinSender;
          var settleAdoptedNow = false;
          switch (payjoinResult) {
            case Ok(:final value):
              payjoinSender = value;
            case Err(:final failure):
              // A failed start is not a failed payment: when this payment's
              // session was persisted (GetAdoptablePayjoinSenderUsecase says
              // which rows count), adopt it exactly as a successful start.
              // Re-arming Confirm over it would pay the payee a second time.
              // A kept post names the original the stored row must carry.
              final keptOriginal = failure is SendTransactionConfirmationFailure
                  ? failure.keptPayjoinOriginalTxId
                  : null;
              final persisted = await _getAdoptablePayjoinSenderUsecase.execute(
                sessionId: paymentRequest.uri,
                walletId: wallet.id,
                amountSat: state.confirmedAmountSat,
                expectedOriginalTxId: keptOriginal,
              );
              if (persisted == null) {
                emit(
                  state.copyWith(failure: failure, signingTransaction: false),
                );
                return;
              }
              log.warning(
                'Send Payjoin start failed but session ${persisted.logRef} is '
                'persisted (status=${persisted.status.name}); adopting it '
                'instead of re-arming Confirm',
              );
              payjoinSender = persisted;
              // Only a session this attempt persisted and whose post failed
              // is settled at once. Any other rejection (an earlier healthy
              // session for the same payment, for instance) is adopted and
              // watched, never downgraded to the plain original.
              settleAdoptedNow =
                  keptOriginal != null &&
                  failure is SendTransactionConfirmationFailure &&
                  !failure.payjoinPublicationUnknown;
          }
          // Show originalTxId provisionally; the payjoin runs asynchronously
          //  in the repository (poll → sign → broadcast, or fallback to the
          //  original on expiry). Watch its stream so the send flow resolves
          //  to success with the final txid instead of hanging on the
          //  "coordinating" screen (#2246).
          emit(
            state.copyWith(
              txId: payjoinSender.originalTxId,
              payjoinSender: payjoinSender,
              failure: payjoinSender.spendFailure == null
                  ? null
                  : const SendPayjoinPausedFailure(),
              signingTransaction: false,
            ),
          );
          _watchPayjoin(payjoinSender.id);
          // The directory did not take the original and the stored row cannot
          // pick up a proposal: settle now rather than at the session
          // deadline. A refusal leaves the armed session as is.
          if (settleAdoptedNow) {
            final userLabel = state.label;
            unawaited(
              _broadcastPayjoinOriginalUsecase.execute(payjoinSender.id).then((
                settled,
              ) {
                // The engine also publishes this on the session stream; this
                // covers a settlement that ran before the watch was attached.
                if (settled == null) return;
                _settlePayjoin(
                  settled,
                  settled.txId ?? settled.originalTxId,
                  walletId: wallet.id,
                  userLabel: userLabel,
                );
              }),
            );
          }
        } else {
          final existing = state.bitcoinSignature;
          final result = existing == null
              ? await _spend.signBitcoin(prepared: prepared)
              : Ok<SignedBitcoinSpend, SpendFailure>(existing);
          if (isStale()) return;
          final SignedBitcoinSpend signed;
          switch (result) {
            case Ok(:final value):
              signed = value;
            case Err(:final failure):
              emit(
                state.copyWith(
                  failure: _spendConfirmationFailure(failure),
                  signingTransaction: false,
                ),
              );
              return;
          }
          final bitcoinAbsoluteFeesSat = prepared.fee.value.toInt();
          final persisted = await _persistPreparedOrderPayin(
            signedTransaction: signed.signedTransaction,
            isPsbt: true,
          );
          if (isStale()) return;
          if (!persisted) {
            emit(state.copyWith(signingTransaction: false));
            return;
          }
          {
            emit(
              state.copyWith(
                bitcoinSignature: signed,
                signedBitcoinPsbt: signed.signedTransaction,
                bitcoinAbsoluteFeesSat: bitcoinAbsoluteFeesSat,
                signingTransaction: false,
              ),
            );
          }
        }
      }
    } catch (e, st) {
      if (isStale()) return;
      log.severe(
        message: 'Failed to sign the transaction',
        error: e,
        trace: st,
      );
      emit(
        state.copyWith(
          failure: SendTransactionConfirmationFailure(logMessage: e.toString()),
          signingTransaction: false,
        ),
      );
    }
  }

  /// Stores the signed lockup on its Boltz swap before broadcasting. Without
  /// it a broadcast whose outcome is unknown could not be settled safely, so
  /// nothing is broadcast when it cannot be stored.
  Future<bool> _storePendingLockup(
    Swap swap, {
    required bool fromLiquid,
    required bool isPsbt,
  }) async {
    final signedLockup = fromLiquid
        ? state.signedLiquidTx
        : (isPsbt ? state.signedBitcoinPsbt : null);
    final stored = signedLockup == null
        ? null
        : await _recordPendingSwapLockupUsecase.execute(
            swapId: swap.id,
            signedTx: signedLockup,
          );
    if (isClosed) return false;
    switch (stored) {
      case Ok(value: final LnSendSwap pending):
        emit(state.copyWith(lightningSwap: pending));
        return true;
      case Ok(value: final ChainSwap pending):
        emit(state.copyWith(chainSwap: pending));
        return true;
      case Ok(value: LnReceiveSwap()) || Err() || null:
        emit(
          state.copyWith(
            failure: const SendTransactionConfirmationFailure(
              logMessage: 'swap lockup not stored before broadcast',
            ),
            broadcastingTransaction: false,
          ),
        );
        return false;
    }
  }

  /// The lockup was never relayed: forget it so the swap reads as unfunded.
  Future<void> _forgetUnsentLockup() async {
    final swap = state.boltzSendSwap;
    if (swap == null) return;
    final _ = await _dropPendingSwapLockupUsecase.execute(swap.id);
  }

  Future<void> broadcastTransaction({bool isPsbt = true}) async {
    try {
      if (state.txId != null || state.broadcastingTransaction) {
        log.warning('Transaction already being broadcast or broadcasted');
        return;
      }
      // Everything the post-broadcast bookkeeping needs is captured up front.
      // Once the transaction is on the network the send MUST still be
      // recorded even if the user left the screen: after `close()` the emits
      // are skipped, but reading `state.txId` back would be null and the
      // label, swap update and wallet sync would be lost to a null-check
      // crash instead.
      // SP diverts in onConfirmTransactionClicked; this path uses a
      // Bitcoin or Liquid wallet.
      final wallet = state.selectedBitcoinWallet;
      if (wallet == null) {
        emit(
          state.copyWith(
            failure: const SendTransactionConfirmationFailure(),
            step: SendStep.confirm,
          ),
        );
        return;
      }
      final generation = _transactionGeneration;
      final selectionValid = await _validateSelectedInputsForBroadcast(wallet);
      if (!selectionValid || isClosed || generation != _transactionGeneration) {
        return;
      }
      final label = state.label;
      final boltzSwap = state.boltzSendSwap;
      final lockupFeeSat = state.absoluteFees;
      final bitcoinSignature = state.bitcoinSignature;

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
              state.copyWith(
                failure: failure,
                broadcastingTransaction: false,
                step: sendStepAfterBroadcastPersistenceFailure(
                  current: state.step,
                  transactionId: state.txId,
                ),
              ),
            );
            return;
        }
      }

      if (boltzSwap != null &&
          !await _storePendingLockup(
            boltzSwap,
            fromLiquid: wallet.isLiquid,
            isPsbt: isPsbt,
          )) {
        return;
      }

      final String txId;
      {
        final order = lightningOrder?.order;
        final Result<SpendBroadcastReceipt, SpendFailure> result;
        switch (wallet.network) {
          case LiquidNetwork network:
            final signature = state.liquidSignature;
            result = switch ((
              signature,
              persistedPayin,
              persistedPayinIsPsbt,
            )) {
              (final signature?, null, _) => await _spend.broadcastLiquid(
                signature,
              ),
              (final signature?, final saved?, false)
                  when signature.signedPset == saved =>
                await _spend.broadcastLiquid(signature),
              (null, final saved?, false)
                  when order != null &&
                      lightningOrder?.sourceWalletId == wallet.id &&
                      lightningOrder?.environment ==
                          (wallet.network.isMainnet
                              ? OrderSwapEnvironment.mainnet
                              : OrderSwapEnvironment.testnet) =>
                await _spend.resumeLiquidPayin(
                  signedPset: saved,
                  walletId: wallet.id,
                  network: network,
                  address: order.payinAddress,
                  amount: Sats(order.payinAmountSat),
                ),
              _ => const Err<SpendBroadcastReceipt, SpendFailure>(
                SpendInvalidRequestFailure(),
              ),
            };
          case BitcoinNetwork network:
            result = switch ((
              bitcoinSignature,
              persistedPayin,
              persistedPayinIsPsbt,
            )) {
              (final signature?, null, _) => await _spend.broadcastBitcoin(
                signature,
              ),
              (final signature?, final saved?, _)
                  when signature.signedTransaction == saved =>
                await _spend.broadcastBitcoin(signature),
              (null, final saved?, final isPsbt?)
                  when order != null &&
                      lightningOrder?.sourceWalletId == wallet.id &&
                      lightningOrder?.environment ==
                          (wallet.network.isMainnet
                              ? OrderSwapEnvironment.mainnet
                              : OrderSwapEnvironment.testnet) =>
                await _spend.resumeBitcoinPayin(
                  signedPsbt: saved,
                  walletId: wallet.id,
                  network: network,
                  address: order.payinAddress,
                  amount: Sats(order.payinAmountSat),
                  isPsbt: isPsbt,
                ),
              _ => const Err<SpendBroadcastReceipt, SpendFailure>(
                SpendInvalidRequestFailure(),
              ),
            };
        }
        switch (result) {
          case Ok(value: final receipt):
            txId = receipt.txid;
          case Err(:final failure):
            final category = switch (failure) {
              SpendBroadcastRejectedFailure() => 'rejected',
              SpendBroadcastConnectionFailure() => 'connection',
              SpendAlreadyInChainFailure() => 'alreadyInChain',
              SpendDeveloperAuthorizationFailure() => 'authorization',
              SpendBroadcastOutcomeUnknownFailure() => 'outcomeUnknown',
              SpendUnavailableFailure() => 'blocked',
              _ => 'unexpected',
            };
            log.warning('send_broadcast_failed category=$category');
            if (failure is! SpendBroadcastOutcomeUnknownFailure &&
                failure is! SpendBroadcastConnectionFailure &&
                failure is! SpendAlreadyInChainFailure) {
              await _forgetUnsentLockup();
            }
            if (!isClosed) {
              emit(
                state.copyWith(
                  failure: _spendConfirmationFailure(failure),
                  broadcastingTransaction: false,
                ),
              );
            }
            return;
        }
      }
      if (!isClosed) emit(state.copyWith(txId: txId));

      if (lightningOrder != null) {
        switch (await _updateSendSwapPayinUsecase.execute(
          localId: lightningOrder.localId,
          update: SendSwapPayinUpdate.broadcastSucceeded,
          transactionId: txId,
        )) {
          case Ok(:final value):
            if (!isClosed) emit(state.copyWith(lightningOrder: value));
          case Err(:final failure):
            if (!isClosed) {
              emit(
                state.copyWith(
                  failure: failure,
                  broadcastingTransaction: false,
                  step: sendStepAfterBroadcastPersistenceFailure(
                    current: state.step,
                    transactionId: txId,
                  ),
                ),
              );
            }
            return;
        }
      }

      if (boltzSwap != null) {
        final recorded = await _recordSwapLockupUsecase.execute(
          swapId: boltzSwap.id,
          txid: txId,
          lockupFeeSat: lockupFeeSat,
        );
        if (!isClosed) {
          switch (recorded) {
            case Ok(value: final LnSendSwap funded):
              emit(state.copyWith(lightningSwap: funded));
            case Ok(value: final ChainSwap funded):
              emit(state.copyWith(chainSwap: funded));
            case _:
              break;
          }
        }
      }

      if (lightningOrder == null && label.isNotEmpty) {
        await _storeSendTransactionLabel.execute(
          transactionId: txId,
          label: label,
          origin: wallet.id,
        );
      }

      if (!isClosed) {
        emit(
          state.copyWith(
            broadcastingTransaction: false,
            step: SendStep.success,
          ),
        );
      }

      unawaited(
        _refreshSource(
          wallet.id,
          diagnostic: 'send_post_broadcast_refresh_failed',
        ),
      );
    } catch (_) {
      log.warning('send_broadcast_failed category=unexpected');
      if (!isClosed) {
        emit(
          state.copyWith(
            failure: const SendTransactionConfirmationFailure(
              logMessage: 'send_broadcast_failed',
            ),
            broadcastingTransaction: false,
          ),
        );
      }
    }
  }

  Future<bool> _validateSelectedInputsForBroadcast(SendSource wallet) async {
    if (!state.usesSelectedInputsOnly) return true;
    final generation = _transactionGeneration;
    bool isStale() => isClosed || generation != _transactionGeneration;
    final requiredOutpoints = state.requiredInputOutpoints;
    if (state.selectedInputsUnavailable) {
      emit(
        state.copyWith(
          failure: const SendSelectedCoinsUnavailableFailure(
            'selected_coins_unavailable',
          ),
          broadcastingTransaction: false,
          step: SendStep.confirm,
        ),
      );
      return false;
    }
    final Result<void, SendFailure> result;
    if (wallet.isLiquid) {
      final available = await _loadCoins.execute(wallet.id);
      if (isStale()) return false;
      result = switch (available) {
        Ok(:final value) => (await _resolveSelectedInputsUsecase.execute(
          outpoints: requiredOutpoints,
          availableUtxos: value,
        )).map((_) {}),
        Err(:final failure) => Err(failure),
      };
    } else {
      result = await _validateBitcoinSelectionUsecase.execute(
        walletId: wallet.id,
        selectedInputs: requiredOutpoints,
      );
    }
    if (isStale()) return false;
    if (result is Ok) return true;
    _invalidateSignedTransaction();
    emit(
      state.copyWith(
        failure: const SendSelectedCoinsUnavailableFailure(
          'selected_coins_unavailable',
        ),
        broadcastingTransaction: false,
        step: SendStep.confirm,
      ),
    );
    return false;
  }

  /// True when the amount may go on to the SP build. Rust `prepare()` stays the
  /// authority on fee-inclusive feasibility.
  Future<bool> _confirmSpAmount() async {
    final amount = state.inputAmountSat;
    final previewEpoch = _bitcoinPreviewEpoch;
    final recipientGeneration = _paymentRequestInputGeneration;
    final result = await _validateSpAmountForSendUsecase.execute(
      Sats.fromInt(amount),
    );
    if (isClosed ||
        state.inputAmountSat != amount ||
        _bitcoinPreviewEpoch != previewEpoch ||
        _paymentRequestInputGeneration != recipientGeneration) {
      return false;
    }
    if (result case Err(:final failure)) {
      emit(state.copyWith(failure: failure, amountConfirmedClicked: false));
      return false;
    }
    return true;
  }

  /// Resolves the typed or scanned recipient in SP mode and moves to the
  /// amount step. The bitcoin path resolves a [PaymentRequest] instead; SP
  /// addresses are not a payment-request format the detector knows.
  Future<void> _confirmSpRecipient(
    String rawPaymentRequest, {
    bool advance = true,
    int? inputGeneration,
  }) async {
    final generation = inputGeneration ?? _paymentRequestInputGeneration;
    bool isStale() => isClosed || generation != _paymentRequestInputGeneration;
    if (isStale()) return;
    // The network decides how the shared screens render the request, so read it
    // first and stop on a failure. Guessing mainnet here would show a testnet
    // wallet a mainnet request.
    final Network network;
    final networkResult = await _getSpNetworkForSendUsecase.execute();
    if (isStale()) return;
    switch (networkResult) {
      case Ok(value: final value):
        network = value;
      case Err(failure: final failure):
        _clearSpRecipient(failure);
        return;
    }
    final result = await _validateSpRecipientForSendUsecase.execute(
      input: rawPaymentRequest,
      amountSat: Sats.fromInt(state.inputAmountSat),
      isMax: state.sendMax,
    );
    if (isStale()) return;
    switch (result) {
      case Ok():
        final recipientChanged =
            state.paymentRequestAddress != rawPaymentRequest;
        emit(
          state.copyWith(
            paymentRequest: PaymentRequest.bitcoin(
              address: rawPaymentRequest,
              isTestnet: network == BitcoinNetwork.testnet,
            ),
            sendType: SendType.bitcoin,
            step: advance ? SendStep.amount : state.step,
            loadingBestWallet: false,
          ),
        );
        if (recipientChanged) clearBitcoinFeePreviews();
        if (advance) await loadFees(inputGeneration: generation);
      case Err(failure: final failure):
        _clearSpRecipient(failure);
    }
  }

  void _clearSpRecipient(SendFailure failure) {
    final recipientCleared = state.paymentRequest != null;
    emit(
      state.copyWith(
        paymentRequest: null,
        loadingBestWallet: false,
        failure: failure,
      ),
    );
    if (recipientCleared) clearBitcoinFeePreviews();
  }

  /// Simulates the SP spend so the confirm step can show a real fee and, for
  /// MAX, the amount left after it.
  Future<void> _buildSpTransaction() async {
    final generation = _transactionGeneration;
    final amountSat = Sats.fromInt(state.inputAmountSat);
    final validated = await _validateSpRecipientForSendUsecase.execute(
      input: state.paymentRequestAddress,
      amountSat: amountSat,
      isMax: state.sendMax,
    );
    if (isClosed || generation != _transactionGeneration) return;
    final SilentRecipient recipient;
    switch (validated) {
      case Ok(value: final value):
        recipient = value;
      case Err(failure: final failure):
        emit(state.copyWith(failure: failure, buildingTransaction: false));
        return;
    }
    final prepared = await _prepareSpPaymentForSendUsecase.execute(
      recipients: [recipient],
      fee: state.selectedFee ?? state.bitcoinFeesList?.fastest,
    );
    if (isClosed || generation != _transactionGeneration) return;
    switch (prepared) {
      case Ok(value: final draft):
        _spDraft = draft;
        final outputAmount = draft.outputs.isNotEmpty
            ? draft.outputs.first.amountSat.value.toInt()
            : state.inputAmountSat;
        final amount = state.sendMax
            ? _maxAmountText(outputAmount)
            : state.amount;
        emit(
          state.copyWith(
            amount: amount,
            bitcoinAbsoluteFeesSat: draft.feeSat.value.toInt(),
            confirmedAmountSat: outputAmount,
            buildingTransaction: false,
          ),
        );
      case Err(failure: final failure):
        emit(state.copyWith(failure: failure, buildingTransaction: false));
    }
  }

  Future<void> _sendSpTransaction() async {
    if (state.txId != null || state.broadcastingTransaction) {
      log.warning('SP transaction already being broadcast or broadcasted');
      return;
    }
    final draft = _spDraft;
    if (draft == null) {
      emit(
        state.copyWith(
          step: SendStep.confirm,
          failure: const SendTransactionBuildFailure(
            'SP transaction draft missing',
          ),
        ),
      );
      return;
    }
    emit(state.copyWith(step: SendStep.sending, broadcastingTransaction: true));
    final result = await _sendSpPaymentForSendUsecase.execute(draft: draft);
    switch (result) {
      case Ok(value: final txId):
        _spDraft = null;
        emit(
          state.copyWith(
            txId: txId,
            broadcastingTransaction: false,
            step: SendStep.success,
          ),
        );
      case Err(failure: final failure):
        emit(
          state.copyWith(
            failure: failure,
            broadcastingTransaction: false,
            step: SendStep.confirm,
          ),
        );
    }
  }

  Future<void> onConfirmTransactionClicked() async {
    var generation = _transactionGeneration;
    bool isStale() => isClosed || generation != _transactionGeneration;
    // Needed even though createTransaction() also clears: the payjoin-only
    // path below skips it, and a leftover failure blocks every retry.
    clearFailure();
    if (state.isSweep) {
      await loadUtxos(transactionGeneration: generation);
      if (isStale()) return;
      if (state.failure != null) {
        emit(state.copyWith(step: SendStep.confirm));
        return;
      }
    }
    try {
      if (isSpMode) {
        await _sendSpTransaction();
        return;
      }
      final wallet = state.selectedWallet;
      if (wallet == null) {
        emit(
          state.copyWith(
            failure: const SendTransactionConfirmationFailure(),
            step: SendStep.confirm,
          ),
        );
        return;
      }
      final orderNeedsPayin =
          state.lightningOrder != null &&
          state.lightningOrder?.hasPreparedPayin != true;
      final sendNeedsSignature = wallet.isLiquid
          ? state.signedLiquidTx == null
          : state.signedBitcoinTx == null && state.signedBitcoinPsbt == null;
      final sendNeedsPayjoinStart =
          state.willAttemptPayjoin && state.payjoinSender == null;
      if (orderNeedsPayin || sendNeedsSignature || sendNeedsPayjoinStart) {
        // Review and confirmation share the same preparation. Rebuild only
        // when no current preparation survives; selecting coins again here
        // could silently change the reviewed transaction.
        if (state.unsignedPsbt == null ||
            (!wallet.isLiquid && state.bitcoinPreparation == null) ||
            (wallet.isLiquid && state.liquidPreparation == null)) {
          final building = createTransaction();
          generation = _transactionGeneration;
          final created = await building;
          if (isStale()) return;
          if (!created) {
            emit(state.copyWith(step: SendStep.confirm));
            return;
          }
        }
        // Stop on any failure, not just a build one — otherwise an
        // insufficient-balance failure would sign whatever PSBT is left over.
        if (state.failure != null || state.unsignedPsbt == null) {
          emit(state.copyWith(step: SendStep.confirm));
          return;
        }
        await signTransaction();
        if (isStale()) return;
        if ((state.failure == null ||
                state.failure is SendPayjoinPausedFailure) &&
            (!orderNeedsPayin ||
                state.lightningOrder?.hasPreparedPayin == true)) {
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
      await broadcastTransaction(isPsbt: state.signedBitcoinTx == null);
      if (isStale()) return;
      if (state.failure is SendTransactionConfirmationFailure) {
        final nextStep = sendStepAfterBroadcastPersistenceFailure(
          current: state.step,
          transactionId: state.txId,
        );
        emit(state.copyWith(step: nextStep));
        if (state.txId == null) return;
      }
      // For a payjoin, _watchPayjoin (started in signTransaction) owns
      // resolving the flow to success — it watches the payjoin session and
      // sets the final txid. Starting the tx watcher here too would race it
      // (both emit) and briefly surface the original txid. For all other
      // sends, watch the broadcast tx for its latest status.
      if (state.payjoinSender == null) {
        final txId = state.txId;
        if (txId == null) {
          emit(state.copyWith(step: SendStep.confirm));
          return;
        }
        _watchWalletTransactionByTxId(walletId: wallet.id, txId: txId);
      }
    } catch (_) {
      if (isStale()) return;
      emit(state.copyWith(step: SendStep.confirm));
      log.severe(
        message: 'send_confirmation_failed category=unexpected',
        error: Exception('send_confirmation_failed'),
        trace: StackTrace.current,
      );
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
    final exchangeRate = await _exchangeRate(
      currencyCode: currencyCode ?? state.fiatCurrencyCode,
    );

    emit(state.copyWith(exchangeRate: exchangeRate));
  }

  /// The price of one bitcoin, or null without one. Sending works on
  /// without a price, with no fiat value, so that failure is not shown; any
  /// other is.
  Future<double?> _exchangeRate({String? currencyCode}) async {
    switch (await _readExchangeRate(currencyCode: currencyCode)) {
      case Ok(:final value):
        return value;
      case Err(failure: SendPriceUnavailableFailure()):
        return null;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return null;
    }
  }

  void _watchOrderSwap(String localId) {
    _orderSwapSubscription?.cancel();
    _orderSwapSubscription = _watchSendSwapUsecase.execute(localId).listen((
      result,
    ) {
      switch (result) {
        case Ok(:final value):
          if (isClosed) return;
          if (state.lightningOrder?.localId != value.localId) return;
          emit(
            state.copyWith(
              lightningOrder: value,
              step: sendStepForWatchedOrderSwap(state.step, value.localStatus),
            ),
          );
          final walletId = state.selectedWallet?.id;
          if (value.localStatus.isTerminal && walletId != null) {
            unawaited(_refreshSource(walletId));
          }
        case Err(:final failure):
          if (isClosed) return;
          emit(state.copyWith(failure: failure));
      }
    });
  }

  Future<void> retryPayjoinProposal() async {
    final sender = state.payjoinSender;
    // Cubit calls have no event transformer: admit synchronously and drop
    // duplicate taps until the pending retry settles.
    if (isClosed ||
        state.isRetryingPayjoinProposal ||
        sender == null ||
        !sender.canRetryProposal) {
      return;
    }
    emit(state.copyWith(isRetryingPayjoinProposal: true));
    try {
      final result = await _retryPayjoinProposalUsecase.execute(sender.id);
      final latest = state.payjoinSender;
      if (isClosed ||
          latest == null ||
          latest.id != sender.id ||
          !latest.isOngoing) {
        return;
      }
      switch (result) {
        case Err(:final failure):
          // The subscription owns session transitions. A late retry failure
          // must not replace a newer observation, even for the same session.
          if (identical(latest, sender)) emit(state.copyWith(failure: failure));
        case Ok():
          break;
      }
    } finally {
      if (!isClosed) emit(state.copyWith(isRetryingPayjoinProposal: false));
    }
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
        // A failed update is logged at the boundary and skipped here: losing one
        // poll must not tear down the subscription, and there is nothing to show
        // the user while the payjoin is still in flight.
        .expand(
          (result) => switch (result) {
            Ok(:final value) => [value],
            Err() => const <PayjoinSession>[],
          },
        )
        .where((payjoin) => payjoin is PayjoinSenderSession)
        .cast<PayjoinSenderSession>()
        .listen((payjoin) async {
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
          void settle(String finalTxId) => _settlePayjoin(
            payjoin,
            finalTxId,
            walletId: walletId,
            userLabel: userLabel,
          );

          if (payjoin.isCompleted || payjoin.isAborted) {
            // Prefer the payjoin txid; fall back to the original tx that
            //  was broadcast when the negotiation didn't complete.
            //  originalTxId is always set for a sender, so this is never null.
            settle(payjoin.txId ?? payjoin.originalTxId);
          } else if (payjoin.isExpired) {
            // Terminal without a recorded broadcast: the session expired and
            // the engine's own fallback sent nothing, or a received proposal
            // failed to sign or broadcast and the fallback did too. The engine
            // released the inputs. The receiver still holds a signed original
            // it may broadcast on its own, and a lagging sync can hide a
            // fallback that did reach the network; either pays the payee, so
            // look once before offering Confirm again on other coins.
            _payjoinSubscription?.cancel();
            final visibleTxId = await _getVisiblePayjoinTransactionUsecase
                .execute(payjoin.id);
            if (isClosed) return;
            if (visibleTxId != null) {
              log.warning(
                '[SendCubit] Payjoin ${payjoin.logRef} expired but its '
                'transaction is visible; settling on it',
              );
              settle(visibleTxId);
              return;
            }
            log.warning(
              '[SendCubit] Payjoin ${payjoin.logRef} expired without broadcast',
            );
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
                  logMessage: 'Payjoin expired and the transaction could not be broadcast',
                  isBroadcastFailure: true,
                ),
              ),
            );
          } else {
            emit(
              state.copyWith(
                payjoinSender: payjoin,
                failure: payjoin.spendFailure == null
                    ? null
                    : const SendPayjoinPausedFailure(),
              ),
            );
          }
        });
  }

  /// Resolves the send flow on a settled payjoin session. Idempotent: the
  /// settlement can arrive from the session stream and from the immediate
  /// fallback's return value.
  void _settlePayjoin(
    PayjoinSenderSession payjoin,
    String finalTxId, {
    required String? walletId,
    required String userLabel,
  }) {
    if (isClosed || state.step == SendStep.success) return;
    emit(
      state.copyWith(
        payjoinSender: payjoin,
        failure: null,
        txId: finalTxId,
        step: SendStep.success,
      ),
    );
    _payjoinSubscription?.cancel();
    if (walletId != null) {
      unawaited(
        _refreshSource(
          walletId,
          diagnostic: 'send_post_payjoin_refresh_failed',
        ),
      );
    }
    // broadcastTransaction never reaches its own label-store call for a
    // payjoin (it early-returns because txId is already set), so the user's
    // typed label has to be stored here instead, once the final txid is
    // known.
    if (userLabel.isNotEmpty && walletId != null) {
      unawaited(
        _storeSendTransactionLabel.execute(
          transactionId: finalTxId,
          label: userLabel,
          origin: walletId,
        ),
      );
    }
  }

  void _watchWalletTransactionByTxId({
    required String walletId,
    required String txId,
  }) {
    // Cancel the previous subscription if it exists
    _txSubscription?.cancel();
    _txSubscription = _transactions
        .watchWalletTransactionByTxId(walletId: walletId, txId: txId)
        .listen((tx) {
          // log.info(
          //   '[SendBloc] Watched transaction ${tx.txId} updated: ${tx.status}',
          // );
          emit(state.copyWith(walletTransaction: tx));
        });
  }

  Future<void> unifiedBip21Prioritization({
    required int inputGeneration,
  }) async {
    final request = state.paymentRequest;
    if (request == null) return;
    if (request is! Bip21PaymentRequest) return;
    if (request.lightning.isEmpty) return;

    try {
      final lightning = await _parsePaymentRequest(request.lightning);
      if (inputGeneration != _paymentRequestInputGeneration) return;
      final overLightning = _bestWalletUsecase.execute(
        wallets: state.wallets,
        request: lightning,
        amountSat: lightning.amountSat,
      );
      if (overLightning case Ok(:final value)) {
        emit(
          state.copyWith(
            selectedWallet: SendWalletBitcoin(value),
            paymentRequest: lightning,
          ),
        );
        return;
      }
      // No wallet can fund the lightning leg — fall through to the on-chain
      // part of the unified BIP21.
    } catch (e, st) {
      log.info(
        'Unified BIP21 lightning part did not parse; using the on-chain part',
        error: e,
        trace: st,
      );
      if (inputGeneration != _paymentRequestInputGeneration) return;
    }

    final onChain = _bestWalletUsecase.execute(
      wallets: state.wallets,
      request: request,
      amountSat: request.amountSat,
    );
    if (onChain case Ok(:final value)) {
      emit(
        state.copyWith(
          selectedWallet: SendWalletBitcoin(value),
          paymentRequest: request,
        ),
      );
    }
  }

  SendFailure _liquidBuildFailure(
    SpendFailure failure, {
    Set<Outpoint>? selectedInputs,
  }) => switch (failure) {
    SpendSelectedInputsUnavailableFailure() =>
      const SendSelectedCoinsUnavailableFailure(),
    SpendNoSpendableInputsFailure() =>
      selectedInputs != null
          ? const SendSelectedCoinsUnavailableFailure()
          : const SendInsufficientBalanceFailure(),
    SpendInsufficientFundsFailure() || SpendInsufficientFundsForFeesFailure() =>
      selectedInputs != null
          ? const SendSelectedCoinsInsufficientFailure()
          : state.frozenBalanceSat > 0
          ? const SendInsufficientBalanceFailure()
          : const SendInsufficientFundsForFeesFailure(),
    SpendConsolidationRequiredFailure() =>
      const SendConsolidationRequiredFailure(),
    SpendNetworkMismatchFailure() => const SendAddressNetworkMismatchFailure(),
    SpendUnavailableFailure(:final busy) => SendSpendBlockedFailure(busy: busy),
    _ => const SendTransactionBuildFailure(),
  };

  SendFailure _spendConfirmationFailure(SpendFailure failure) =>
      switch (failure) {
        SpendUnavailableFailure(:final busy) => SendSpendBlockedFailure(
          busy: busy,
        ),
        SpendBroadcastRejectedFailure() ||
        SpendBroadcastConnectionFailure() ||
        SpendBroadcastOutcomeUnknownFailure() ||
        SpendAlreadyInChainFailure() ||
        SpendDeveloperAuthorizationFailure() =>
          const SendTransactionConfirmationFailure(isBroadcastFailure: true),
        _ => const SendTransactionConfirmationFailure(),
      };

  Future<bool> updateSignedBitcoinTx(
    String signedTx, {
    required PreparedBitcoinSpend prepared,
  }) async {
    if (!identical(state.bitcoinPreparation, prepared)) return false;
    final generation = _transactionGeneration;
    bool isStale() =>
        isClosed ||
        generation != _transactionGeneration ||
        !identical(state.bitcoinPreparation, prepared);
    emit(
      state.copyWith(
        bitcoinSignature: null,
        signedBitcoinTx: null,
        failure: null,
      ),
    );
    final verification = await _spend.verifySignedBitcoin(
      prepared: prepared,
      signedTransaction: signedTx,
      isPsbt: false,
    );
    if (isStale()) return false;
    switch (verification) {
      case Err(:final failure):
        emit(state.copyWith(failure: _spendConfirmationFailure(failure)));
        return false;
      case Ok(:final value):
        if (!await _persistPreparedOrderPayin(
              signedTransaction: signedTx,
              isPsbt: false,
            ) ||
            isStale()) {
          return false;
        }
        emit(
          state.copyWith(
            bitcoinSignature: value,
            signedBitcoinTx: signedTx,
            failure: null,
          ),
        );
        return true;
    }
  }

  /// Drops every payload that was built or signed for the *previous* shape of
  /// this payment. The BDK path stores its signed transaction in
  /// [SendState.signedBitcoinPsbt] and the hardware path in
  /// [SendState.signedBitcoinTx]; `onConfirmTransactionClicked` broadcasts
  /// whichever is present, so clearing only one leaves an editable payment
  /// with a broadcastable signature attached to the old recipient/amount.
  /// The unsigned PSBT goes too: it is the reference
  /// [updateSignedBitcoinTx] verifies a hardware signature against.
  void _invalidateSignedTransaction({bool cancelInFlightBuild = true}) {
    _spDraft = null;
    if (cancelInFlightBuild) _transactionGeneration++;
    if (state.signedBitcoinTx == null &&
        state.signedBitcoinPsbt == null &&
        state.signedLiquidTx == null &&
        state.unsignedPsbt == null &&
        !state.buildingTransaction &&
        !state.signingTransaction) {
      return;
    }
    emit(
      state.copyWith(
        // Validation can be cancelled; a broadcast already in flight must finish.
        step:
            state.step == SendStep.sending &&
                !state.broadcastingTransaction &&
                state.txId == null
            ? SendStep.confirm
            : state.step,
        signedBitcoinTx: null,
        signedBitcoinPsbt: null,
        signedLiquidTx: null,
        bitcoinPreparation: null,
        bitcoinSignature: null,
        liquidPreparation: null,
        liquidSignature: null,
        unsignedPsbt: null,
        signingTransaction: false,
        buildingTransaction: cancelInFlightBuild
            ? false
            : state.buildingTransaction,
      ),
    );
  }

  Future<void> updateSelectedWallet(SendSource newWallet) async {
    if (state.usesSelectedInputsOnly) return;
    if (state.hasMultipleRecipients && newWallet.isLiquid) return;
    await _setSelectedWallet(newWallet, manual: true);
  }

  /// Central path for every wallet change in the send flow.
  /// `manual: true` locks the pick so [updateBestWallet]'s auto-switching
  /// (used as the user types an amount) doesn't override the user's choice —
  /// the silent override regressed cold-wallet sends. See #1918.
  Future<void> _setSelectedWallet(
    SendSource wallet, {
    required bool manual,
    bool preserveSelectedInputs = false,
  }) async {
    final walletChanged = state.selectedWallet?.id != wallet.id;
    final walletGeneration = ++_selectedWalletGeneration;
    final previousSubscription = _selectedWalletSyncingSubscription;
    _selectedWalletSyncingSubscription = null;
    if (walletChanged) {
      _invalidateSignedTransaction();
      _dropBoltzSwap();
    }
    emit(
      state.copyWith(
        selectedWallet: SendWalletBitcoin(wallet),
        isWalletManuallySelected: manual,
        failure: null,
        // Drop resolved UTXOs on a wallet change so balance math never mixes
        // wallets. A user-selected wallet clears the old input intent below;
        // route initialization preserves it and stays blocked until resolved.
        utxos: walletChanged ? const [] : state.utxos,
        selectedUtxos: walletChanged ? const [] : state.selectedUtxos,
        selectedInputOutpoints: walletChanged && !preserveSelectedInputs
            ? const {}
            : state.selectedInputOutpoints,
        recipientAmountsSat: walletChanged
            ? const []
            : state.recipientAmountsSat,
      ),
    );
    // Wallet swap invalidates every cached preview: the PSBT was built
    // from a different wallet's UTXOs and descriptor. Clear after the
    // emit so the loading flags don't race with the wallet swap. Skip
    // when the "swap" picks the same wallet — common via updateBestWallet.
    if (walletChanged) clearBitcoinFeePreviews();
    await previousSubscription?.cancel();
    if (isClosed || walletGeneration != _selectedWalletGeneration) return;
    // Load utxos up front so the spendable balance (which excludes frozen
    // coins, D7) is known during amount entry — not only after the first sync.
    // Guarded on an actual wallet change so the per-keystroke auto-pick
    // (updateBestWallet) doesn't re-read utxos on every keypress.
    if (walletChanged) await loadUtxos();
    if (isClosed ||
        walletGeneration != _selectedWalletGeneration ||
        state.selectedWallet?.id != wallet.id) {
      return;
    }
    _scheduleRecipientPreview();
    _selectedWalletSyncingSubscription = _loadSources
        .watchFinished(wallet.key)
        .listen((result) async {
          if (isClosed ||
              walletGeneration != _selectedWalletGeneration ||
              state.selectedWallet?.id != wallet.id) {
            return;
          }
          switch (result) {
            case Ok(value: final synced?):
              emit(state.copyWith(selectedWallet: SendWalletBitcoin(synced)));
              await loadUtxos();
            case Ok():
              emit(state.copyWith(selectedWallet: null, utxos: const []));
            case Err(:final failure):
              log.warning(
                'Send source sync read unavailable category=${failure.runtimeType}',
              );
          }
        });
  }

  // ────── FeeModalStatePort + FeeModalActionsPort adoption ──────
  // SendCubit is the driving adapter for the Bitcoin-send path; the
  // shared modal in lib/features/fees/public/ depends on these ports.
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

enum _BoltzChainSendOutcome { created, stopped, useExchange }
