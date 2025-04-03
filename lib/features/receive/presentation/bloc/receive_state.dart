part of 'receive_bloc.dart';

enum ReceiveType {
  bitcoin,
  lightning,
  liquid,
}

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    @Default(ReceiveType.lightning) ReceiveType type,
    Wallet? wallet,
    BitcoinUnit? bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String inputAmountCurrencyCode,
    @Default('') String inputAmount,
    BigInt? confirmedAmountSat,
    @Default('') String bitcoinAddress,
    LnReceiveSwap? lightningSwap,
    SwapLimits? swapLimits,
    @Default('') String liquidAddress,
    @Default('') String note,
    PayjoinReceiver? payjoin,
    @Default(false) bool isAddressOnly,
    @Default('') String txId,
    Object? error,
  }) = _ReceiveState;
  const ReceiveState._();

  List<String> get inputAmountCurrencyCodes {
    return [
      BitcoinUnit.btc.code,
      BitcoinUnit.sats.code,
      ...fiatCurrencyCodes,
    ];
  }

  bool get swapLimitsFetched => swapLimits != null;
  bool get isInputAmountFiat => ![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
      .contains(inputAmountCurrencyCode);

  BigInt get inputAmountSat {
    BigInt amountSat = BigInt.zero;

    if (inputAmount.isNotEmpty) {
      if (isInputAmountFiat) {
        final amountFiat = double.tryParse(inputAmount) ?? 0;
        amountSat = BigInt.from(
          amountFiat * 100000000 / exchangeRate,
        );
      } else if (inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        amountSat = BigInt.tryParse(inputAmount) ?? BigInt.zero;
      } else {
        final amountBtc = double.tryParse(inputAmount) ?? 0;
        amountSat = BigInt.from((amountBtc * 100000000).truncate());
      }
    }

    return amountSat;
  }

  double get inputAmountBtc => inputAmountSat.toDouble() / 100000000;

  double get inputAmountFiat {
    return inputAmountBtc * exchangeRate;
  }

  String get qrData {
    switch (type) {
      case ReceiveType.bitcoin:
        if (bitcoinAddress.isEmpty) {
          return '';
        }
        if (isAddressOnly ||
            (confirmedAmountSat == null && note.isEmpty && payjoin == null)) {
          return bitcoinAddress;
        }

        Uri bip21Uri = Uri(
          scheme: 'bitcoin',
          path: bitcoinAddress,
          queryParameters: {
            if (confirmedAmountBtc > 0) 'amount': confirmedAmountBtc.toString(),
            if (note.isNotEmpty) 'message': note,
          },
        );

        // Add payjoin parameters if available
        if (payjoin != null) {
          final pjUri = Uri.parse(payjoin!.pjUri);
          final queryParameters = {
            if (bip21Uri.queryParameters.isNotEmpty)
              ...bip21Uri.queryParameters,
            'pj': pjUri.queryParameters['pj'],
            'pjos': pjUri.queryParameters['pjos'],
          };
          bip21Uri = bip21Uri.replace(
            queryParameters: queryParameters,
          );
        }
        return bip21Uri.toString();
      case ReceiveType.lightning:
        return lightningSwap?.invoice ?? '';
      case ReceiveType.liquid:
        if (liquidAddress.isEmpty) {
          return '';
        }
        if (confirmedAmountSat == null && note.isEmpty) {
          return liquidAddress;
        }
        final bip21Uri = Uri(
          scheme: 'liquidnetwork',
          path: liquidAddress,
          queryParameters: {
            if (confirmedAmountBtc > 0) 'amount': confirmedAmountBtc.toString(),
            if (note.isNotEmpty) 'message': note,
          },
        );
        return bip21Uri.toString();
    }
  }

  String get addressOrInvoiceOnly {
    switch (type) {
      case ReceiveType.bitcoin:
        return bitcoinAddress;
      case ReceiveType.lightning:
        return lightningSwap?.invoice ?? '';
      case ReceiveType.liquid:
        return liquidAddress;
    }
  }

  double get confirmedAmountBtc => confirmedAmountSat != null
      ? confirmedAmountSat!.toDouble() / 100000000
      : 0;

  double get confirmedAmountFiat {
    return confirmedAmountBtc * exchangeRate;
  }

  String get formattedConfirmedAmountBitcoin {
    if (bitcoinUnit == null) {
      return '';
    } else if (bitcoinUnit == BitcoinUnit.sats) {
      // For sats, use integer formatting without decimals
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit!.code,
        decimalDigits: 0, // Use 0 decimals for sats
        customPattern: '#,##0 ¤',
      );
      return currencyFormatter.format(confirmedAmountSat?.toInt() ?? 0);
    } else {
      // For BTC, use the standard decimal formatting
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit!.code,
        decimalDigits: bitcoinUnit!.decimals,
        customPattern: '#,##0.00 ¤',
      );
      final formatted = currencyFormatter
          .format(confirmedAmountBtc)
          .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
      return formatted;
    }
  }

  String get formattedConfirmedAmountFiat {
    final currencyFormatter = NumberFormat.currency(
      name: fiatCurrencyCode,
      customPattern: '#,##0.00 ¤',
    );
    final formatted = currencyFormatter.format(confirmedAmountFiat);
    return formatted;
  }

  String get formattedAmountInputEquivalent {
    if (isInputAmountFiat) {
      // If the input is in fiat, the equivalent should be in bitcoin
      if (bitcoinUnit == null) {
        return '';
      } else if (bitcoinUnit == BitcoinUnit.sats) {
        // For sats, use integer formatting without decimals
        final currencyFormatter = NumberFormat.currency(
          name: bitcoinUnit!.code,
          decimalDigits: 0, // Use 0 decimals for sats
          customPattern: '#,##0 ¤',
        );
        return currencyFormatter.format(inputAmountSat.toInt());
      } else {
        // For BTC, use the standard decimal formatting
        final currencyFormatter = NumberFormat.currency(
          name: bitcoinUnit!.code,
          decimalDigits: bitcoinUnit!.decimals,
          customPattern: '#,##0.00 ¤',
        );
        final formatted = currencyFormatter
            .format(inputAmountBtc)
            .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
        return formatted;
      }
    } else {
      // If the input is in bitcoin, the equivalent should be in fiat
      final currencyFormatter = NumberFormat.currency(
        name: fiatCurrencyCode,
        customPattern: '#,##0.00 ¤',
      );
      final formatted = currencyFormatter.format(inputAmountFiat);
      return formatted;
    }
  }

  bool get isPaymentInProgress {
    switch (type) {
      case ReceiveType.bitcoin:
        // From the moment the payjoin request is received, it can be broadcasted,
        // so we consider it in progress since it is a valid transaction from the sender
        // and the user can choose to broadcast it.
        return payjoin != null && payjoin!.status == PayjoinStatus.requested;
      case ReceiveType.lightning:
        return lightningSwap != null &&
            lightningSwap!.status == SwapStatus.claimable;
      case ReceiveType.liquid:
        return false;
    }
  }

  bool get isPaymentReceived {
    switch (type) {
      case ReceiveType.bitcoin:
        return txId.isNotEmpty;
      case ReceiveType.lightning:
        return lightningSwap != null &&
            lightningSwap!.status == SwapStatus.completed;
      case ReceiveType.liquid:
        return txId.isNotEmpty;
    }
  }

  bool get isPayjoinLoading {
    if (type == ReceiveType.bitcoin) {
      return payjoin == null &&
          error is! ReceivePayjoinException &&
          !isAddressOnly;
    }
    return false;
  }

  bool get isLightning => type == ReceiveType.lightning;

  bool get swapAmountBelowLimit {
    if (isLightning && inputAmount.isNotEmpty) {
      return swapLimits != null && inputAmountSat.toInt() < swapLimits!.min;
    }
    return false;
  }

  bool get swapAmountAboveLimit {
    if (isLightning) {
      return swapLimits != null && inputAmountSat.toInt() > swapLimits!.max;
    }
    return false;
  }

  bool get isAmountValid =>
      inputAmount.isEmpty || swapAmountBelowLimit || swapAmountAboveLimit;

  LnReceiveSwap? get getSwap {
    if (type == ReceiveType.lightning) {
      return lightningSwap;
    }

    return null;
  }
}
