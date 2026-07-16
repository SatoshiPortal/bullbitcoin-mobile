part of 'transfer_bloc.dart';

@freezed
sealed class TransferState with _$TransferState {
  const factory TransferState({
    @Default(false) bool isStarting,
    Exception? startError,
    @Default([]) List<Wallet> wallets,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default('sats') String inputAmountCurrencyCode,
    @Default([]) List<String> fiatCurrencyCodes,
    FeeOptions? liquidNetworkFees,
    FeeOptions? bitcoinNetworkFees,
    (SwapLimits, SwapFees)? btcToLbtcSwapLimitsAndFees,
    (SwapLimits, SwapFees)? lbtcToBtcSwapLimitsAndFees,
    Wallet? fromWallet,
    Wallet? toWallet,
    int? maxAmountSat,
    @Default(false) bool isCreatingSwap,
    @Default(false) bool continueClicked,
    SwapCreationException? swapCreationException,
    ChainSwap? swap,
    @Default('') String signedPsbt,
    int? bitcoinAbsoluteFeesSat,
    int? liquidAbsoluteFeesSat,
    @Default(false) bool isConfirming,
    ConfirmTransactionException? confirmTransactionException,
    // Set when a freshly-built Bitcoin tx fails the relay-floor re-assert
    // (an absolute custom fee that cleared the pre-build gate against a stale
    // vsize but lands below the floor at the real, larger vsize). Mirrors
    // SendState.buildTransactionException — surfaced on the confirm page and
    // accompanied by a cleared signedPsbt so the below-relay tx can't broadcast.
    BuildTransactionException? buildTransactionException,
    @Default('') String txId,
    @Default(false) bool sendToExternal,
    @Default('') String externalAddress,
    String? externalAddressError,
    @Default(true) bool receiveExactAmount,
    @Default('') String amount,
    // Preserves programmatic Max/BIP21 satoshis when fiat display rounds to
    // two decimals. Manual edits clear it and are converted from [amount].
    int? exactInputAmountSat,
    String? receiveAddress,
    @Default(true) bool replaceByFee,
    @Default([]) List<WalletUtxo> selectedUtxos,
    @Default(FeeSelection.fastest) FeeSelection selectedFeeOption,
    NetworkFee? customFee,
    // Arm/disarm snapshot — set by TransferCustomFeeArmed, cleared by
    // TransferCustomFeeChanged / TransferFeeOptionSelected /
    // TransferCustomFeeDisarmed. Internal to the custom-fee modal flow;
    // gates the rollback. UI must not read these directly.
    FeeSelection? armPriorSelection,
    NetworkFee? armPriorCustomFee,
    // Real-fee previews + cached unsigned PSBTs per FeeSelection slot.
    // Mirrors SendState.feePreviewCache exactly — see that doc for the
    // BDK-coin-selection rationale. Cleared on any input-shape change.
    @Default(BitcoinFeePreviewCache.empty)
    BitcoinFeePreviewCache feePreviewCache,
    List<WalletUtxo>? utxos,
    int? bitcoinTxSize,
    double? exchangeRate,
    String? fiatCurrencyCode,
  }) = _TransferState;
  const TransferState._();

  String get displayToCurrencyCode {
    return '${toWallet?.isLiquid ?? false ? 'L-' : ''}${bitcoinUnit.code}';
  }

  bool get isInputAmountFiat => ![
    BitcoinUnit.btc.code,
    BitcoinUnit.sats.code,
  ].contains(inputAmountCurrencyCode);

  String get displayInputAmountCurrencyCode {
    if (isInputAmountFiat) return inputAmountCurrencyCode;
    return '${fromWallet?.isLiquid ?? false ? 'L-' : ''}$inputAmountCurrencyCode';
  }

  String get displayEquivalentCurrencyCode {
    if (isInputAmountFiat) {
      return '${fromWallet?.isLiquid ?? false ? 'L-' : ''}${bitcoinUnit.code}';
    }
    return fiatCurrencyCode ?? '';
  }

  String get formattedInputAmountEquivalent {
    if (isInputAmountFiat) {
      if (bitcoinUnit == BitcoinUnit.sats) {
        return FormatAmount.sats(inputAmountSat);
      }
      return FormatAmount.btc(ConvertAmount.satsToBtc(inputAmountSat));
    }

    return FormatAmount.fiat(
      ConvertAmount.satsToFiat(inputAmountSat, exchangeRate ?? 0),
      fiatCurrencyCode ?? '',
    );
  }

  SwapLimits? get swapLimits {
    if (sendToExternal) {
      if (fromWallet?.isLiquid == false) {
        return btcToLbtcSwapLimitsAndFees?.$1;
      } else if (fromWallet?.isLiquid == true) {
        return lbtcToBtcSwapLimitsAndFees?.$1;
      }
    } else {
      if (fromWallet?.isLiquid == false && toWallet?.isLiquid == true) {
        return btcToLbtcSwapLimitsAndFees?.$1;
      } else if (fromWallet?.isLiquid == true && toWallet?.isLiquid == false) {
        return lbtcToBtcSwapLimitsAndFees?.$1;
      }
    }
    return null;
  }

  SwapFees? get swapFees {
    if (sendToExternal) {
      if (fromWallet?.isLiquid == false) {
        return btcToLbtcSwapLimitsAndFees?.$2;
      } else if (fromWallet?.isLiquid == true) {
        return lbtcToBtcSwapLimitsAndFees?.$2;
      }
    } else {
      if (fromWallet?.isLiquid == false && toWallet?.isLiquid == true) {
        return btcToLbtcSwapLimitsAndFees?.$2;
      } else if (fromWallet?.isLiquid == true && toWallet?.isLiquid == false) {
        return lbtcToBtcSwapLimitsAndFees?.$2;
      }
    }
    return null;
  }

  int getSwapFeesSat(int fromAmountSat) {
    final fees = swapFees;
    return fees?.totalFees(fromAmountSat) ?? 0;
  }

  int get inputAmountSat {
    if (exactInputAmountSat != null) return exactInputAmountSat!;
    if (isInputAmountFiat) {
      if (exchangeRate == null || exchangeRate! <= 0) return 0;
      return ConvertAmount.fiatToSats(
        double.tryParse(amount) ?? 0,
        exchangeRate!,
      );
    } else if (inputAmountCurrencyCode == BitcoinUnit.sats.code) {
      return int.tryParse(amount) ?? 0;
    } else {
      return ConvertAmount.btcToSats(double.tryParse(amount) ?? 0);
    }
  }

  String get formattedInputAmount {
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(inputAmountSat);
    }
    return FormatAmount.btc(ConvertAmount.satsToBtc(inputAmountSat));
  }

  String get maxAmountInput {
    return formatSatsForInput(maxAmountSat ?? 0, includeCurrency: false);
  }

  String formatSatsForInput(int amountSat, {bool includeCurrency = true}) {
    late final String amount;
    if (isInputAmountFiat) {
      amount = ConvertAmount.btcToFiat(
        ConvertAmount.satsToBtc(amountSat),
        exchangeRate ?? 0,
      ).toString();
    } else if (inputAmountCurrencyCode == BitcoinUnit.sats.code) {
      amount = amountSat.toString();
    } else {
      amount = ConvertAmount.satsToBtc(amountSat).toString();
    }
    return includeCurrency ? '$amount $displayInputAmountCurrencyCode' : amount;
  }

  int? get absoluteFees {
    if (fromWallet?.isLiquid == true) {
      return liquidAbsoluteFeesSat;
    } else {
      return bitcoinAbsoluteFeesSat;
    }
  }

  String get absoluteFeesFormatted {
    if (absoluteFees == null) return '0';
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(absoluteFees!);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(absoluteFees!));
    }
  }

  bool get isSameChainTransfer {
    if (sendToExternal) return false;
    return fromWallet?.isLiquid == false && toWallet?.isLiquid == false;
  }

  bool get shouldShowAdvancedOptions {
    return fromWallet?.isLiquid == false;
  }

  bool get shouldShowReceiveExactAmount {
    return fromWallet != null && !isSameChainTransfer;
  }

  /// Max is a trigger, not a flag: the amount simply equals the computed
  /// maximum, however it got there. A max send drains the wallet, which is
  /// incompatible with guaranteeing an exact receivable amount.
  bool get isMaxSelected {
    final max = maxAmountSat;
    return max != null && max > 0 && inputAmountSat == max;
  }

  int get selectedUtxoTotalSat {
    return selectedUtxos.fold(
      0,
      (previousValue, element) => previousValue + element.amountSat.toInt(),
    );
  }

  bool get isCoinSelectionValid {
    if (selectedUtxos.isEmpty) return false;
    return selectedUtxoTotalSat >= confirmedAmountSat;
  }

  int get confirmedAmountSat {
    if (isSameChainTransfer) {
      return inputAmountSat;
    }
    if (swap != null && swap is ChainSwap) {
      return (swap as ChainSwap).paymentAmount;
    }
    return inputAmountSat;
  }

  NetworkFee? get selectedFee {
    if (fromWallet == null) return null;
    switch (selectedFeeOption) {
      case FeeSelection.fastest:
        return fromWallet!.isLiquid
            ? liquidNetworkFees?.fastest
            : bitcoinNetworkFees?.fastest;
      case FeeSelection.economic:
        return fromWallet!.isLiquid
            ? liquidNetworkFees?.economic
            : bitcoinNetworkFees?.economic;
      case FeeSelection.slow:
        return fromWallet!.isLiquid
            ? liquidNetworkFees?.slow
            : bitcoinNetworkFees?.slow;
      case FeeSelection.custom:
        return customFee;
    }
  }

  String get formattedSelectedUtxoTotal {
    if (bitcoinUnit == BitcoinUnit.sats) {
      return FormatAmount.sats(selectedUtxoTotalSat);
    } else {
      return FormatAmount.btc(ConvertAmount.satsToBtc(selectedUtxoTotalSat));
    }
  }

  bool get isInsufficientBalance {
    if (fromWallet == null) return false;
    if (inputAmountSat <= 0) return false;
    return inputAmountSat > fromWallet!.balanceSat.toInt();
  }

  bool get hasAmountError {
    return amountValidationError != null || isInsufficientBalance;
  }

  String? get amountValidationError {
    if (amount.isEmpty) return null;

    if (inputAmountSat <= 0) return null;

    final balanceSat = fromWallet?.balanceSat.toInt() ?? 0;
    if (inputAmountSat > balanceSat) return null;

    final limits = swapLimits;
    if (limits == null) return null;

    if (limits.min > inputAmountSat) {
      return 'Minimum amount is ${formatSatsForInput(limits.min)}';
    }

    if (limits.max < inputAmountSat) {
      return 'Maximum amount is ${formatSatsForInput(limits.max)}';
    }

    return null;
  }
}
