import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/percentage.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'send_state.freezed.dart';

enum SendType {
  bitcoin,
  lightning,
  liquid;

  static SendType from(PaymentRequest paymentRequest) {
    switch (paymentRequest) {
      case ArkPaymentRequest():
        throw UnimplementedError(
          'ARK payment requests are available from experimental Ark feature only.',
        );
      case BitcoinPaymentRequest():
        return SendType.bitcoin;
      case LiquidPaymentRequest():
        return SendType.liquid;
      case Bolt11PaymentRequest():
      case LnAddressPaymentRequest():
        return SendType.lightning;
      case Bip21PaymentRequest():
        if (paymentRequest.network.isBitcoin) {
          return SendType.bitcoin;
        } else {
          return SendType.liquid;
        }
      case PsbtPaymentRequest():
        return SendType.bitcoin; //TODO(azad): nop
    }
  }

  String get displayName {
    switch (this) {
      case SendType.bitcoin:
        return 'Bitcoin';
      case SendType.lightning:
        return 'Lightning';
      case SendType.liquid:
        return 'Liquid';
    }
  }
}

enum SendStep { address, amount, confirm, sending, success }

SendStep sendStepForOrderSwapStatus(OrderSwapLocalStatus status) =>
    switch (status) {
      OrderSwapLocalStatus.awaitingUserConfirmation ||
      OrderSwapLocalStatus.preparingPayin ||
      OrderSwapLocalStatus.readyToBroadcast ||
      OrderSwapLocalStatus.broadcastUnknown => SendStep.confirm,
      OrderSwapLocalStatus.payinBroadcast ||
      OrderSwapLocalStatus.payoutInProgress ||
      OrderSwapLocalStatus.completed ||
      OrderSwapLocalStatus.refunded ||
      OrderSwapLocalStatus.expired ||
      OrderSwapLocalStatus.failed => SendStep.success,
      OrderSwapLocalStatus.creating ||
      OrderSwapLocalStatus.creationUnknown => SendStep.address,
    };

@freezed
abstract class SendState with _$SendState {
  const factory SendState({
    @Default(SendStep.address) SendStep step,
    @Default(SendType.lightning) SendType sendType,
    @Default('') String scannedRawPaymentRequest,
    @Default('') String copiedRawPaymentRequest,
    PaymentRequest? paymentRequest,
    Bolt11PaymentRequest? lightningInvoice,
    @Default([]) List<Wallet> wallets,
    Wallet? selectedWallet,
    @Default(false) bool isWalletManuallySelected,
    bool? isToSelf,
    @Default('') String amount,
    int? confirmedAmountSat,
    BitcoinUnit? bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('CAD') String fiatCurrencyCode,
    @Default('') String inputAmountCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String label,
    @Default([]) List<WalletUtxo> utxos,
    @Default([]) List<WalletUtxo> selectedUtxos,
    @Default(true) bool replaceByFee,
    FeeOptions? bitcoinFeesList,
    FeeOptions? liquidFeesList,
    NetworkFee? customFee,
    @Default(FeeSelection.fastest) FeeSelection selectedFeeOption,
    // Arm/disarm snapshot — internal to the custom-fee modal flow. When the
    // user enters a value in the custom-fee field we eagerly commit
    // `selectedFeeOption: custom` + typed `customFee` so the preset tiles
    // visually deselect, without triggering a `createTransaction` rebuild.
    // `armPriorSelection != null` iff the modal currently holds the arm;
    // `disarmCustomFee` rolls back if the user closes the modal without
    // `customFeesChanged` (which clears the arm). UI must not read these
    // directly — they exist only to gate the rollback.
    FeeSelection? armPriorSelection,
    NetworkFee? armPriorCustomFee,
    // Real-fee previews + cached unsigned PSBTs per FeeSelection slot.
    // Built on modal open (presets) and on debounced custom-rate typing.
    // Cached PSBTs are REUSED at commit so the broadcast tx has the
    // EXACT vsize/fee the modal showed — BDK's TxBuilder.finish() picks
    // UTXOs via a randomized BnB→SRD algorithm (113/154/195 vbyte
    // variance for identical inputs in our logs), so rebuilding at
    // commit would diverge from the preview.
    //
    // Cleared on any input-shape change (wallet, recipient, amount,
    // UTXO selection, replaceByFee, or a new armCustomFee/preview
    // request). The principle: NEVER display a fee derived from
    // rate × vsize math — only what BDK produces from a real PSBT.
    @Default(BitcoinFeePreviewCache.empty)
    BitcoinFeePreviewCache feePreviewCache,
    int? bitcoinTxSize,
    int? liquidAbsoluteFees,
    // Real Bitcoin absolute fee, read from the built PSBT (not a prediction).
    // BDK overshoots a rate-based fee by 1–3 sat at sub-1 sat/vByte rates due
    // to ceil rounding and sub-dust change absorption (documented BDK
    // behaviour, see bdk_wallet TxBuilder docs and rust-bitcoin
    // FeeRate::mul_by_weight which uses div_ceil). At normal rates the
    // overshoot is invisible; at the sub-1 sat/vByte rates allowed by #2133
    // it's significant (e.g. 14 → 16, 28 → 30). Set whenever a PSBT exists.
    int? bitcoinAbsoluteFeesSat,
    // prepare
    String? unsignedPsbt,
    String? signedBitcoinPsbt,
    String? signedBitcoinTx,
    String? signedLiquidTx,
    OrderSwapRecord? lightningOrder,
    OrderSwapQuote? lightningQuote,
    ChainSwap? chainSwap,
    // confirm
    String? txId,
    PayjoinSender? payjoinSender,
    WalletTransaction? walletTransaction,
    @Default(false) bool sendMax,
    @Default(false) bool amountConfirmedClicked,
    @Default(false) bool loadingBestWallet,
    @Default(false) bool creatingSwap,
    @Default(false) bool buildingTransaction,
    @Default(false) bool signingTransaction,
    @Default(false) bool broadcastingTransaction,
    @Default('') String balanceApproximatedAmount,
    SendFailure? failure,

    // swapLimits
    SwapLimits? bitcoinLnSwapLimits,
    SwapLimits? liquidLnSwapLimits,
    SwapLimits? btcToLbtcChainSwapLimits,
    SwapLimits? lbtcToBtcChainSwapLimits,
    SwapLimits? selectedSwapLimits,

    SwapFees? bitcoinLnSwapFees,
    SwapFees? liquidLnSwapFees,
    SwapFees? btcToLbtcChainSwapFees,
    SwapFees? lbtcToBtcChainSwapFees,
    SwapFees? selectedSwapFees,
  }) = _SendState;
  const SendState._();

  List<String> get inputAmountCurrencyCodes {
    return [BitcoinUnit.btc.code, BitcoinUnit.sats.code, ...fiatCurrencyCodes];
  }

  /// Whether we have a valid payment request
  bool get hasValidPaymentRequest => paymentRequest != null;

  String get paymentRequestAddress {
    if (paymentRequest == null) {
      return copiedRawPaymentRequest.isNotEmpty
          ? copiedRawPaymentRequest
          : scannedRawPaymentRequest;
    }

    if (paymentRequest!.isBip21) {
      final bip21PaymentRequest = paymentRequest! as Bip21PaymentRequest;
      return bip21PaymentRequest.address;
    }
    if (paymentRequest!.isBolt11) {
      final bolt11PaymentRequest = paymentRequest! as Bolt11PaymentRequest;
      return bolt11PaymentRequest.invoice;
    }
    if (paymentRequest!.isLnAddress) {
      final lnAddressPaymentRequest =
          paymentRequest! as LnAddressPaymentRequest;
      return lnAddressPaymentRequest.address;
    }
    if (paymentRequest!.isBitcoinAddress) {
      final bitcoinPaymentRequest = paymentRequest! as BitcoinPaymentRequest;
      return bitcoinPaymentRequest.address;
    }
    if (paymentRequest!.isLiquidAddress) {
      final liquidPaymentRequest = paymentRequest! as LiquidPaymentRequest;
      return liquidPaymentRequest.address;
    }
    return copiedRawPaymentRequest.isNotEmpty
        ? copiedRawPaymentRequest
        : scannedRawPaymentRequest;
  }

  bool get isInputAmountFiat => ![
    BitcoinUnit.btc.code,
    BitcoinUnit.sats.code,
  ].contains(inputAmountCurrencyCode);

  int get inputAmountSat {
    int amountSat = 0;
    if (amount.isNotEmpty) {
      if (isInputAmountFiat) {
        final amountFiat = double.tryParse(amount) ?? 0;
        amountSat = ConvertAmount.fiatToSats(amountFiat, exchangeRate);
      } else if (inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        amountSat = int.tryParse(amount) ?? 0;
      } else {
        final amountBtc = double.tryParse(amount) ?? 0;
        amountSat = ConvertAmount.btcToSats(amountBtc);
      }
    }

    return amountSat;
  }

  int get effectiveAmountSat {
    final embedded = paymentRequest?.amountSat ?? 0;
    return embedded > 0 ? embedded : inputAmountSat;
  }

  double get inputAmountBtc => ConvertAmount.satsToBtc(inputAmountSat);

  double get inputAmountFiat {
    return ConvertAmount.btcToFiat(inputAmountBtc, exchangeRate);
  }

  double get confirmedAmountBtc => confirmedAmountSat != null
      ? ConvertAmount.satsToBtc(confirmedAmountSat!)
      : 0;

  double get confirmedAmountFiat {
    return ConvertAmount.btcToFiat(confirmedAmountBtc, exchangeRate);
  }

  int? get lightningPayinAmountSat =>
      lightningOrder?.order?.payinAmountSat.toInt() ??
      lightningQuote?.inAmountSat.toInt();

  double get confirmedSwapAmountBtc =>
      ConvertAmount.satsToBtc(lightningPayinAmountSat ?? 0);

  String get formattedConfirmedAmountBitcoin {
    if (bitcoinUnit == null) {
      return '';
    } else if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(confirmedAmountSat ?? 0);
    } else {
      return FormatAmount.btc(confirmedAmountBtc);
    }
  }

  String get formattedSwapAmountBitcoin {
    final payinAmount = lightningPayinAmountSat;
    if (bitcoinUnit == null || payinAmount == null) return '';

    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(payinAmount);
    } else {
      return FormatAmount.btc(confirmedSwapAmountBtc);
    }
  }

  String get formattedConfirmedAmountFiat {
    return FormatAmount.fiat(confirmedAmountFiat, fiatCurrencyCode);
  }

  String get formattedAmountInputEquivalent {
    if (isInputAmountFiat) {
      // If the input is in fiat, the equivalent should be in bitcoin
      if (bitcoinUnit == null) {
        return '';
      } else if (bitcoinUnit == BitcoinUnit.sats) {
        return FormatAmount.sats(inputAmountSat);
      } else {
        return FormatAmount.btc(inputAmountBtc);
      }
    } else {
      return FormatAmount.fiat(inputAmountFiat, fiatCurrencyCode);
    }
  }

  String formattedWalletBalance() {
    if (selectedWallet == null) return '0';

    if (inputAmountCurrencyCode == BitcoinUnit.btc.code) {
      return FormatAmount.btc(
        ConvertAmount.satsToBtc(selectedWallet!.balanceSat.toInt()),
      );
    } else if (inputAmountCurrencyCode == BitcoinUnit.sats.code) {
      return FormatAmount.sats(selectedWallet!.balanceSat.toInt());
    } else {
      return FormatAmount.fiat(
        ConvertAmount.satsToFiat(
          selectedWallet!.balanceSat.toInt(),
          exchangeRate,
        ),
        inputAmountCurrencyCode,
      );
    }
  }

  String formattedApproximateBalance() {
    if (selectedWallet == null) return '0';

    final satsBalance = selectedWallet!.balanceSat.toInt();

    if (inputAmountCurrencyCode == BitcoinUnit.btc.code ||
        inputAmountCurrencyCode == BitcoinUnit.sats.code) {
      return FormatAmount.fiat(
        ConvertAmount.satsToFiat(satsBalance, exchangeRate),
        fiatCurrencyCode,
      );
    } else {
      if (bitcoinUnit == BitcoinUnit.sats) {
        return FormatAmount.sats(satsBalance);
      } else {
        return FormatAmount.btc(ConvertAmount.satsToBtc(satsBalance));
      }
    }
  }

  String get formattedAbsoluteFees {
    // `…` not `0` when no PSBT has been built yet — we never compute a
    // fee ourselves from `rate × vsize`. Send screen will render this
    // string verbatim; the brief `…` is honest about "not yet known".
    if (absoluteFees == null) return '…';
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(absoluteFees!);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(absoluteFees!));
    }
  }

  /// Amount (sats) locked in user-frozen coins ([WalletUtxo.isFrozen], which is
  /// scoped to `origin = 'user'`). Zero until [utxos] are loaded, and zero in
  /// practice for Liquid because freeze isn't surfaced there (the Coins entry is
  /// Bitcoin-only) — not because the network is intrinsically exempt.
  ///
  /// Note: this intentionally excludes payjoin-derived locks, which the spend
  /// path also treats as unspendable. So with an active payjoin the real drain
  /// may produce slightly less than [spendableBalanceSat] reports — it never
  /// over-spends (the build re-excludes both sets), only fails closed.
  int get frozenBalanceSat => utxos
      .where((u) => u.isFrozen)
      .fold(0, (sum, u) => sum + u.amountSat.toInt());

  /// Frozen balance ([frozenBalanceSat]) formatted in the active [bitcoinUnit],
  /// for the "you have frozen coins" hint shown when a payment can't be covered
  /// by the spendable balance alone (#2337).
  String get formattedFrozenBalance => bitcoinUnit == BitcoinUnit.sats
      ? FormatAmount.sats(frozenBalanceSat)
      : FormatAmount.btc(ConvertAmount.satsToBtc(frozenBalanceSat));

  /// Spendable balance (sats) — the wallet balance minus the amount locked in
  /// frozen coins (D7). Frozen coins are never spendable, so the amount screen
  /// must validate against this, not the raw wallet balance. Falls back to the
  /// full balance before [utxos] have loaded so it never under-reports.
  int get spendableBalanceSat =>
      (selectedWallet?.balanceSat.toInt() ?? 0) - frozenBalanceSat;

  bool get walletHasBalance =>
      // ignore: avoid_bool_literals_in_conditional_expressions
      selectedWallet == null
      ? false
      : (inputAmountSat > 0 && inputAmountSat <= spendableBalanceSat);

  String sendTypeName() {
    switch (sendType) {
      case SendType.bitcoin:
        return 'Send';
      case SendType.lightning:
        return 'Transfer';
      case SendType.liquid:
        return 'Send';
    }
  }

  bool get isLightning => sendType == SendType.lightning;
  bool get isLightningBitcoinSwap =>
      isLightning && selectedWallet!.network.isBitcoin;

  bool get swapAmountBelowLimit {
    final amount = effectiveAmountSat;
    if (isLightning && amount != 0) {
      if (selectedSwapLimits == null) return false;
      // Allow 100 sats minimum for Liquid to Lightning swaps
      final isLiquidToLightning =
          selectedWallet != null && selectedWallet!.isLiquid;
      final minLimit = isLiquidToLightning ? 100 : selectedSwapLimits!.min;
      return amount < minLimit;
    }
    if (requireChainSwap && amount != 0) {
      return selectedSwapLimits != null && amount < selectedSwapLimits!.min;
    }
    return false;
  }

  int get swapMinimum {
    final min = selectedSwapLimits?.min ?? 0;
    if (min != 0) return min;
    return selectedWallet?.isLiquid == true ? 100 : 25000;
  }

  bool get swapAmountAboveLimit {
    final amount = effectiveAmountSat;
    if (isLightning) {
      return selectedSwapLimits != null && amount > selectedSwapLimits!.max;
    }
    if (requireChainSwap && amount != 0) {
      return selectedSwapLimits != null && amount > selectedSwapLimits!.max;
    }
    return false;
  }

  bool get isSwapAmountValid =>
      isLightning ||
      requireChainSwap &&
          (selectedSwapLimits == null ||
              inputAmountSat == 0 ||
              swapAmountBelowLimit ||
              swapAmountAboveLimit);

  bool get isLnInvoicePaid {
    return lightningOrder?.localStatus == OrderSwapLocalStatus.completed;
  }

  bool get isSwapCompleted {
    return lightningOrder?.localStatus == OrderSwapLocalStatus.completed;
  }

  bool get disableConfirmSend =>
      buildingTransaction || signingTransaction || broadcastingTransaction;

  bool get blocksSwapDueToHardwareWallet {
    final wallet = selectedWallet;
    if (wallet == null) return false;
    final isSwap =
        sendType == SendType.lightning ||
        (sendType == SendType.liquid && !wallet.isLiquid) ||
        (sendType == SendType.bitcoin && wallet.isLiquid);
    return isSwap && wallet.isHardwareWallet;
  }

  bool get requireChainSwap {
    if (selectedWallet == null) return false;
    return (selectedWallet!.network.isBitcoin && sendType == SendType.liquid) ||
        (selectedWallet!.network.isLiquid && sendType == SendType.bitcoin);
  }

  NetworkFee? get selectedFee {
    switch (selectedFeeOption) {
      case FeeSelection.fastest:
        return selectedWallet!.isLiquid
            ? liquidFeesList?.fastest
            : bitcoinFeesList?.fastest;
      case FeeSelection.economic:
        return selectedWallet!.isLiquid
            ? liquidFeesList?.economic
            : bitcoinFeesList?.economic;

      case FeeSelection.slow:
        return selectedWallet!.isLiquid
            ? liquidFeesList?.slow
            : bitcoinFeesList?.slow;
      case FeeSelection.custom:
        return customFee;
    }
  }

  bool get isChainSwap =>
      (sendType == SendType.liquid && !selectedWallet!.isLiquid) ||
      sendType == SendType.bitcoin && selectedWallet!.isLiquid;

  FeeOptions? get feeOptions => selectedWallet == null
      ? null
      : selectedWallet!.isLiquid
      ? liquidFeesList
      : bitcoinFeesList;

  /// Absolute fee the user will (or did) pay, in sats. **Real PSBT fee
  /// only** when `bitcoinAbsoluteFeesSat` is populated (`psbt.fee()` =
  /// Σ inputs − Σ outputs). Returns null otherwise; UI must render a
  /// shimmer / loading placeholder, **never** fall back to local
  /// `rate × vsize` arithmetic.
  ///
  /// The Liquid branch uses `liquidAbsoluteFees` — same contract,
  /// populated by the LWK build.
  int? get absoluteFees => selectedWallet == null
      ? null
      : selectedWallet!.isLiquid
      ? liquidAbsoluteFees
      : bitcoinAbsoluteFeesSat;

  int? get totalSwapFees {
    final order = lightningOrder?.order;
    final payin = order?.payinAmountSat ?? lightningQuote?.inAmountSat;
    final payout = order?.payoutAmountSat ?? lightningQuote?.outAmountSat;
    if (payin == null || payout == null) return null;
    final serviceFee = payin - payout;
    return serviceFee > BigInt.zero ? serviceFee.toInt() : 0;
  }

  bool get isSlowPayment =>
      // ignore: avoid_bool_literals_in_conditional_expressions
      selectedWallet == null
      ? false
      // ignore: avoid_bool_literals_in_conditional_expressions
      : selectedWallet!.isLiquid
      ? false
      : true;
}

extension SendStateFeePercent on SendState {
  double getFeeAsPercentOfAmount() {
    if (lightningPayinAmountSat != null) {
      return calculatePercentage(
        lightningOrder?.order?.payoutAmountSat.toInt() ??
            lightningQuote!.outAmountSat.toInt(),
        totalSwapFees ?? 0,
      );
    }
    if (chainSwap != null) {
      return chainSwap!.getFeeAsPercentOfAmount();
    }
    final fee = absoluteFees ?? 0;
    final amount = confirmedAmountSat ?? 0;
    if (fee == 0 || amount == 0) return 0.0;
    return calculatePercentage(amount, fee);
  }

  bool get showFeeWarning => getFeeAsPercentOfAmount() > 5.0;
}
