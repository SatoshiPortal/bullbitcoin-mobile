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

enum SendAddressType {
  bitcoin,
  lightning,
  liquid;

  static SendAddressType from(PaymentRequest paymentRequest) {
    switch (paymentRequest) {
      case BitcoinPaymentRequest():
        return SendAddressType.bitcoin;
      case LiquidPaymentRequest():
        return SendAddressType.liquid;
      case Bolt11PaymentRequest():
      case LnAddressPaymentRequest():
        return SendAddressType.lightning;
      case Bip21PaymentRequest():
        if (paymentRequest.network.isBitcoin) {
          return SendAddressType.bitcoin;
        } else {
          return SendAddressType.liquid;
        }
      case PsbtPaymentRequest():
        return SendAddressType.bitcoin; //TODO(azad): nop
    }
  }

  String get displayName {
    switch (this) {
      case SendAddressType.bitcoin:
        return 'Bitcoin';
      case SendAddressType.lightning:
        return 'Lightning';
      case SendAddressType.liquid:
        return 'Liquid';
    }
  }
}

enum SendStep { amount, confirm, sending, success }

enum SendProcess {
  bitcoinOnchain,
  bitcoinOnchainPayjoin,
  liquidOnchain,
  lbtcLn,
  btcLn,
  btcLbtcChain,
  lbtcBtcChain,
}

@freezed
abstract class SendState with _$SendState {
  const factory SendState({
    @Default(SendStep.amount) SendStep step,
    required PaymentRequest paymentRequest,
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
    // exceptions
    SwapCreationException? swapCreationException,
    InsufficientBalanceException? insufficientBalanceException,
    InvalidBitcoinStringException? invalidBitcoinStringException,
    SwapLimitsException? swapLimitsException,
    BuildTransactionException? buildTransactionException,
    ConfirmTransactionException? confirmTransactionException,
    ExchangeApiException? exchangeApiException,
    FeesException? feesException,
    LoadWalletException? loadWalletException,

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

  String get paymentRequestAddress {
    switch (paymentRequest) {
      case final Bip21PaymentRequest bip21Request:
        if (invoiceHasMrh) return 'MRH'; // TODO: MRH
        return bip21Request.address;
      case final Bolt11PaymentRequest bolt11Request:
        return bolt11Request.invoice;
      case final LnAddressPaymentRequest lnAddressRequest:
        return lnAddressRequest.address;
      case final BitcoinPaymentRequest bitcoinRequest:
        return bitcoinRequest.address;
      case final LiquidPaymentRequest liquidRequest:
        return liquidRequest.address;
      case final PsbtPaymentRequest psbtRequest:
        return psbtRequest.psbt;
    }
  }

  bool get isInputAmountFiat =>
      ![
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

  double get confirmedAmountBtc =>
      confirmedAmountSat != null
          ? ConvertAmount.satsToBtc(confirmedAmountSat!)
          : 0;

  double get confirmedAmountFiat {
    return ConvertAmount.btcToFiat(confirmedAmountBtc, exchangeRate);
  }

  double get confirmedSwapAmountBtc =>
      lightningSwap != null
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
          : inputAmountSat <= selectedWallet!.balanceSat.toInt();

  String sendTypeName() {
    switch (sendAddressType) {
      case SendAddressType.bitcoin:
        return 'Send';
      case SendAddressType.lightning:
        return 'Swap';
      case SendAddressType.liquid:
        return 'Send';
    }
  }

  SendAddressType get sendAddressType => SendAddressType.from(paymentRequest);

  bool get isLightning => sendAddressType == SendAddressType.lightning;
  bool get isLightningBitcoinSwap =>
      isLightning && selectedWallet!.network.isBitcoin;

  bool get swapAmountBelowLimit {
    if (isLightning && inputAmountSat != 0) {
      return selectedSwapLimits != null &&
          inputAmountSat < selectedSwapLimits!.min;
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
    return (selectedWallet!.network.isBitcoin &&
            sendAddressType == SendAddressType.liquid) ||
        (selectedWallet!.network.isLiquid &&
            sendAddressType == SendAddressType.bitcoin);
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

  bool get isChainSwap => chainSwap != null;

  bool get isNormalOnchainSend {
    if (selectedWallet == null) return false;
    return (selectedWallet!.isLiquid &&
            sendAddressType == SendAddressType.liquid) ||
        (selectedWallet!.network.isBitcoin &&
            sendAddressType == SendAddressType.bitcoin);
  }

  FeeOptions? get feeOptions =>
      selectedWallet == null
          ? null
          : selectedWallet!.isLiquid
          ? liquidFeesList
          : bitcoinFeesList;

  int? get absoluteFees =>
      selectedWallet == null
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

  String get displayAmount => sendMax ? 'MAX' : amount;
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

class ExchangeApiException implements Exception {
  final String message;

  ExchangeApiException(this.message);

  @override
  String toString() => message;

  String get title => 'Exchange Api Failed';
}

class FeesException implements Exception {
  final String message;

  FeesException(this.message);

  @override
  String toString() => message;

  String get title => 'Fees Api Failed';
}

class LoadWalletException implements Exception {
  final String message;

  LoadWalletException(this.message);

  @override
  String toString() => message;

  String get title => 'Loading Wallet Failed';
}
