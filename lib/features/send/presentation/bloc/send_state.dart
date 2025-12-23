import 'package:bb_mobile/core/errors/bull_exception.dart';
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

@freezed
abstract class SendState with _$SendState {
  const factory SendState({
    @Default(SendStep.address) SendStep step,
    @Default(SendType.lightning) SendType sendType,
    @Default('') String scannedRawPaymentRequest,
    @Default('') String copiedRawPaymentRequest,
    PaymentRequest? paymentRequest,
    @Default([]) List<Wallet> wallets,
    Wallet? selectedWallet,
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
    @Default(false) bool invoiceHasMrh,
    FeeOptions? bitcoinFeesList,
    FeeOptions? liquidFeesList,
    NetworkFee? customFee,
    @Default(FeeSelection.fastest) FeeSelection selectedFeeOption,
    int? bitcoinTxSize,
    int? liquidAbsoluteFees,
    // prepare
    String? unsignedPsbt,
    String? signedBitcoinPsbt,
    String? signedBitcoinTx,
    String? signedLiquidTx,
    LnSendSwap? lightningSwap,
    ChainSwap? chainSwap,
    // confirm
    String? txId,
    PayjoinSender? payjoinSender,
    WalletTransaction? walletTransaction,
    Object? error,
    @Default(false) bool sendMax,
    @Default(false) bool amountConfirmedClicked,
    @Default(false) bool loadingBestWallet,
    @Default(false) bool creatingSwap,
    @Default(false) bool buildingTransaction,
    @Default(false) bool signingTransaction,
    @Default(false) bool broadcastingTransaction,
    @Default('') String balanceApproximatedAmount,
    SwapCreationException? swapCreationException,
    InsufficientBalanceException? insufficientBalanceException,
    InvalidBitcoinStringException? invalidBitcoinStringException,
    SwapLimitsException? swapLimitsException,
    BuildTransactionException? buildTransactionException,
    ConfirmTransactionException? confirmTransactionException,

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
      if (invoiceHasMrh) {
        // Return the raw string instead of the payment request
        return copiedRawPaymentRequest.isNotEmpty
            ? copiedRawPaymentRequest
            : scannedRawPaymentRequest;
      }
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

  double get confirmedSwapAmountBtc => lightningSwap != null
      ? ConvertAmount.satsToBtc(lightningSwap!.paymentAmount)
      : 0;

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
    if (bitcoinUnit == null || lightningSwap == null) return '';

    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(lightningSwap!.paymentAmount);
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
    if (absoluteFees == null) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(absoluteFees!);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(absoluteFees!));
    }
  }

  bool get walletHasBalance =>
      // ignore: avoid_bool_literals_in_conditional_expressions
      selectedWallet == null
      ? false
      : (inputAmountSat > 0 &&
            inputAmountSat <= selectedWallet!.balanceSat.toInt());

  String sendTypeName() {
    switch (sendType) {
      case SendType.bitcoin:
        return 'Send';
      case SendType.lightning:
        return 'Swap';
      case SendType.liquid:
        return 'Send';
    }
  }

  bool get isLightning => sendType == SendType.lightning;
  bool get isLightningBitcoinSwap =>
      isLightning && selectedWallet!.network.isBitcoin;

  bool get swapAmountBelowLimit {
    if (isLightning && inputAmountSat != 0) {
      if (selectedSwapLimits == null) return false;
      // Allow 100 sats minimum for Liquid to Lightning swaps
      final isLiquidToLightning =
          selectedWallet != null && selectedWallet!.isLiquid;
      final minLimit = isLiquidToLightning ? 100 : selectedSwapLimits!.min;
      return inputAmountSat < minLimit;
    }
    if (requireChainSwap && inputAmountSat != 0) {
      return selectedSwapLimits != null &&
          inputAmountSat < selectedSwapLimits!.min;
    }
    return false;
  }

  bool get swapAmountAboveLimit {
    if (isLightning) {
      return selectedSwapLimits != null &&
          inputAmountSat > selectedSwapLimits!.max;
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
    return lightningSwap != null && lightningSwap!.status == SwapStatus.canCoop;
  }

  bool get isSwapCompleted {
    return lightningSwap != null &&
        lightningSwap!.status == SwapStatus.completed;
  }

  bool get disableConfirmSend =>
      buildingTransaction || signingTransaction || broadcastingTransaction;

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

  int? get absoluteFees => selectedWallet == null
      ? null
      : selectedWallet!.isLiquid
      ? liquidAbsoluteFees
      : selectedFee?.toAbsolute(bitcoinTxSize ?? 0).value.toInt();

  int? get totalSwapFees {
    if (lightningSwap == null) return null;
    return lightningSwap!.fees?.totalFees(lightningSwap!.paymentAmount) ?? 0;
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
    if (lightningSwap != null) {
      return lightningSwap!.getFeeAsPercentOfAmount();
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

class SwapCreationException extends BullException {
  SwapCreationException(super.message);
  String get displayMessage => 'Failed to create swap.';
}

class InsufficientBalanceException extends BullException {
  InsufficientBalanceException([
    super.message = 'Not enough balance to cover this payment',
  ]);
}

class InvalidBitcoinStringException extends BullException {
  InvalidBitcoinStringException([
    super.message = 'Invalid Bitcoin Payment Address or Invoice',
  ]);
}

/// Exception for swap limit violations.
/// Stored in SendState with min/max limit values for localized error messages.
/// UI displays context-specific messages using sendErrorAmountBelowMinimum,
/// sendErrorAmountAboveMaximum, sendErrorBalanceTooLowForMinimum, etc.
class SwapLimitsException extends BullException {
  SwapLimitsException(super.message, {this.minLimit, this.maxLimit});

  final int? minLimit;
  final int? maxLimit;

  bool get isBelowMinimum => minLimit != null;
  bool get isAboveMaximum => maxLimit != null;
}

/// Exception for transaction build failures.
/// Stored in SendState and displayed by UI using sendErrorBuildFailed.
/// The message parameter is for debugging/logging only.
class BuildTransactionException extends BullException {
  BuildTransactionException(super.message);
}

/// Exception for transaction confirmation failures.
/// Stored in SendState and displayed by UI using sendErrorConfirmationFailed.
/// The message parameter is for debugging/logging only.
class ConfirmTransactionException extends BullException {
  ConfirmTransactionException(super.message);
}
