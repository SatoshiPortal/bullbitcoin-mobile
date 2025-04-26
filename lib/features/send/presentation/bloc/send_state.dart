import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'send_state.freezed.dart';

enum SendType {
  bitcoin,
  lightning,
  liquid;

  static SendType from(PaymentRequest paymentRequest) {
    switch (paymentRequest) {
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

enum SendStep {
  address,
  amount,
  confirm,
  sending,
  success,
}

@freezed
class SendState with _$SendState {
  const factory SendState({
    @Default(SendStep.address) SendStep step,
    @Default(SendType.lightning) SendType sendType,
    // input
    PaymentRequest? paymentRequest,
    @Default('') String addressOrInvoice,
    @Default([]) List<Wallet> wallets,
    Wallet? selectedWallet,
    @Default('') String amount,
    int? confirmedAmountSat,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('CAD') String fiatCurrencyCode,
    @Default('') String inputAmountCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String label,
    @Default([]) List<TransactionOutput> utxos,
    @Default([]) List<TransactionOutput> selectedUtxos,
    @Default(false) bool replaceByFee,
    FeeOptions? feesList,
    NetworkFee? selectedFee,
    FeeSelection? selectedFeeOption,
    int? customFee,
    // prepare
    String? unsignedPsbt,
    LnSendSwap? lightningSwap,
    // confirm
    String? txId,
    PayjoinSender? payjoinSender,
    Object? error,
    @Default(false) bool sendMax,
    @Default(false) bool amountConfirmedClicked,
    @Default(false) bool loadingBestWallet,
    @Default(false) bool creatingSwap,
    @Default(false) bool finalizingTransaction,
    @Default('') String balanceApproximatedAmount,
    SwapCreationException? swapCreationException,
    InsufficientBalanceException? insufficientBalanceException,
    InvalidBitcoinStringException? invalidBitcoinStringException,
    SwapLimitsException? swapLimitsException,
    BuildTransactionException? buildTransactionException,
    ConfirmTransactionException? confirmTransactionException,

    // swapLimits
    SwapLimits? swapLimits,
    SwapFees? swapFees,
  }) = _SendState;
  const SendState._();

  bool get isInputAmountFiat => ![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
      .contains(inputAmountCurrencyCode);

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
    if (bitcoinUnit == BitcoinUnit.sats) {
      // For sats, use integer formatting without decimals
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: 0, // Use 0 decimals for sats
        customPattern: '#,##0 ¤',
      );
      return currencyFormatter.format(confirmedAmountSat ?? 0);
    } else {
      // For BTC, use the standard decimal formatting
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: bitcoinUnit.decimals,
        customPattern: '#,##0.00 ¤',
      );
      final formatted = currencyFormatter
          .format(confirmedAmountBtc)
          .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
      return formatted;
    }
  }

  String get formattedSwapAmountBitcoin {
    if (lightningSwap == null) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      // For sats, use integer formatting without decimals
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: 0, // Use 0 decimals for sats
        customPattern: '#,##0 ¤',
      );
      return currencyFormatter.format(lightningSwap!.paymentAmount);
    } else {
      // For BTC, use the standard decimal formatting
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: bitcoinUnit.decimals,
        customPattern: '#,##0.00 ¤',
      );
      final formatted = currencyFormatter
          .format(confirmedAmountBtc)
          .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
      return formatted;
    }
  }

  String get formattedConfirmedAmountFiat {
    return FormatAmount.fiat(confirmedAmountFiat, fiatCurrencyCode);
  }

  String get formattedAmountInputEquivalent {
    if (isInputAmountFiat) {
      // If the input is in fiat, the equivalent should be in bitcoin
      if (bitcoinUnit == BitcoinUnit.sats) {
        // For sats, use integer formatting without decimals
        return FormatAmount.sats(inputAmountSat);
      } else {
        // For BTC, use the standard decimal formatting
        return FormatAmount.btc(inputAmountBtc);
      }
    } else {
      // If the input is in bitcoin, the equivalent should be in fiat
      return FormatAmount.fiat(inputAmountFiat, fiatCurrencyCode);
    }
  }

  String formattedWalletBalance() {
    if (selectedWallet == null) return '0';

    if (inputAmountCurrencyCode == BitcoinUnit.btc.code) {
      return FormatAmount.btc(
        ConvertAmount.satsToBtc(
          selectedWallet!.balanceSat.toInt(),
        ),
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
        return FormatAmount.btc(
          ConvertAmount.satsToBtc(satsBalance),
        );
      }
    }
  }

  bool walletHasBalance() {
    if (selectedWallet == null) return false;
    return inputAmountSat <= selectedWallet!.balanceSat.toInt();
  }

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

  bool get swapAmountBelowLimit {
    if (isLightning && inputAmountSat != 0) {
      return swapLimits != null && inputAmountSat < swapLimits!.min;
    }
    return false;
  }

  bool get swapAmountAboveLimit {
    if (isLightning) {
      return swapLimits != null && inputAmountSat > swapLimits!.max;
    }
    return false;
  }

  bool get isSwapAmountValid =>
      isLightning &&
      (swapLimits == null ||
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
}

class SwapCreationException implements Exception {
  final String message;

  SwapCreationException(this.message);

  @override
  String toString() => message;
  String get displayMessage => 'Failed to create swap.';
}

class InsufficientBalanceException implements Exception {
  final String message;

  InsufficientBalanceException({
    this.message = 'Not enough balance to cover this payment',
  });

  @override
  String toString() => message;
}

class InvalidBitcoinStringException implements Exception {
  final String message;

  InvalidBitcoinStringException({
    this.message = 'Invalid Bitcoin Payment Address or Invoice',
  });

  @override
  String toString() => message;
}

class SwapLimitsException implements Exception {
  final String message;

  SwapLimitsException(this.message);

  @override
  String toString() => message;
}

class BuildTransactionException implements Exception {
  final String message;

  BuildTransactionException(this.message);

  @override
  String toString() => message;

  String get title => 'Build Failed';
}

class ConfirmTransactionException implements Exception {
  final String message;

  ConfirmTransactionException(this.message);

  @override
  String toString() => message;

  String get title => 'Confirmation Failed';
}
