part of 'receive_bloc.dart';

enum ReceiveType { bitcoin, lightning, liquid }

@freezed
abstract class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    ReceiveType? type,
    Wallet? wallet,
    BitcoinUnit? bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String inputAmountCurrencyCode,
    @Default('') String inputAmount,
    int? confirmedAmountSat,
    WalletAddress? bitcoinAddress,
    LnReceiveSwap? lightningSwap,
    SwapLimits? swapLimits,
    WalletAddress? liquidAddress,
    @Default('') String note,
    PayjoinReceiver? payjoin,
    ReceivePayjoinException? receivePayjoinException,
    @Default(false) bool isAddressOnly,
    WalletTransaction? tx,
    Object? error,
    AmountException? amountException,
    @Default(false) bool creatingSwap,
  }) = _ReceiveState;
  const ReceiveState._();

  List<String> get inputAmountCurrencyCodes {
    return [BitcoinUnit.btc.code, BitcoinUnit.sats.code, ...fiatCurrencyCodes];
  }

  bool get swapLimitsFetched => swapLimits != null;
  bool get isInputAmountFiat =>
      ![
        BitcoinUnit.btc.code,
        BitcoinUnit.sats.code,
      ].contains(inputAmountCurrencyCode);

  int get inputAmountSat {
    int amountSat = 0;

    if (inputAmount.isNotEmpty) {
      if (isInputAmountFiat) {
        final amountFiat = double.tryParse(inputAmount) ?? 0;
        amountSat = ConvertAmount.fiatToSats(amountFiat, exchangeRate);
      } else if (inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        amountSat = int.tryParse(inputAmount) ?? 0;
      } else {
        final amountBtc = double.tryParse(inputAmount) ?? 0;
        amountSat = ConvertAmount.btcToSats(amountBtc);
      }
    }

    return amountSat;
  }

  double get inputAmountBtc => ConvertAmount.satsToBtc(inputAmountSat);

  double get inputAmountFiat {
    return ConvertAmount.btcToFiat(inputAmountBtc, exchangeRate);
  }

  // The QR code data should always show the full payment request when all parameters are available,
  //  this way the QR code doesn't change from an address only QR to a BIP21 uri with payjoin parameters while loading.
  String get qrData => paymentRequest;

  // The clipboard data should permit the user to copy just the address or invoice
  // from the moment it is available and not wait for the full payment request like payjoin
  // parameters. Once the full payment request is available, it should be copied instead of
  // just the address or invoice of course.
  String get clipboardData =>
      paymentRequest.isEmpty ? addressOrInvoiceOnly : paymentRequest;

  // The payment request can be an address, invoice or bip21 URI depending on
  // the type of receive and some set parameters. It waits for all data to
  // be available before returning anything.
  String get paymentRequest {
    switch (type) {
      case ReceiveType.bitcoin:
        if (bitcoinAddress == null || isPayjoinLoading) {
          // Wait for the address and also for the payjoin in case not only the
          // address should be shown.
          return '';
        }
        if (isAddressOnly ||
            (confirmedAmountSat == null && note.isEmpty && payjoin == null)) {
          return bitcoinAddress!.address;
        }

        Uri bip21Uri = Uri(
          scheme: 'bitcoin',
          path: bitcoinAddress!.address,
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
            if (pjUri.queryParameters['pjos'] != null)
              'pjos': pjUri.queryParameters['pjos'],
            'pj': pjUri.queryParameters['pj'],
          };
          bip21Uri = bip21Uri.replace(queryParameters: queryParameters);
        }
        return bip21Uri.toString();
      case ReceiveType.lightning:
        return lightningSwap?.invoice ?? '';
      case ReceiveType.liquid:
        if (liquidAddress == null) return '';

        if (confirmedAmountSat == null && note.isEmpty) {
          return liquidAddress!.address;
        }
        final bip21Uri = Uri(
          scheme: 'liquidnetwork',
          path: liquidAddress!.address,
          queryParameters: {
            if (confirmedAmountBtc > 0) 'amount': confirmedAmountBtc.toString(),
            if (note.isNotEmpty) 'message': note,
            'assetid':
                wallet != null && wallet!.network == Network.liquidMainnet
                    ? AssetConstants.lbtcMainnet
                    : AssetConstants.lbtcTestnet,
          },
        );
        return bip21Uri.toString();
      case _:
        return '';
    }
  }

  String get addressOrInvoiceOnly {
    switch (type) {
      case ReceiveType.bitcoin:
        return bitcoinAddress?.address ?? '';
      case ReceiveType.lightning:
        return lightningSwap?.invoice ?? '';
      case ReceiveType.liquid:
        return liquidAddress?.address ?? '';
      case _:
        return '';
    }
  }

  double get confirmedAmountBtc =>
      ConvertAmount.satsToBtc(confirmedAmountSat ?? 0);

  double get confirmedAmountFiat {
    return ConvertAmount.btcToFiat(confirmedAmountBtc, exchangeRate);
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

  bool get isBitcoin {
    switch (type) {
      case ReceiveType.bitcoin:
        return true;
      case ReceiveType.lightning:
        return lightningSwap != null &&
            lightningSwap!.type == SwapType.lightningToBitcoin;
      case ReceiveType.liquid:
        return false;
      case _:
        return false;
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
            lightningSwap!.status == SwapStatus.paid;
      case ReceiveType.liquid:
        return false;
      case _:
        return false;
    }
  }

  bool get isPaymentReceived {
    switch (type) {
      case ReceiveType.bitcoin:
        return tx != null;
      case ReceiveType.lightning:
        return lightningSwap != null &&
            lightningSwap!.status == SwapStatus.completed;
      case ReceiveType.liquid:
        return tx != null;
      case _:
        return false;
    }
  }

  bool get isPayjoinLoading {
    if (type == ReceiveType.bitcoin) {
      return wallet != null &&
          wallet!.signsLocally &&
          !isAddressOnly &&
          payjoin == null &&
          receivePayjoinException == null;
    }
    return false;
  }

  bool get isPayjoinAvailable {
    if (type == ReceiveType.bitcoin) {
      return wallet != null &&
          wallet!.signsLocally &&
          !isAddressOnly &&
          payjoin != null;
    }
    return false;
  }

  double get payjoinAmountFiat {
    final payjoinAmountSat = payjoin?.amountSat ?? 0;
    final payjoinAmountBtc = ConvertAmount.satsToBtc(payjoinAmountSat);
    return ConvertAmount.btcToFiat(payjoinAmountBtc, exchangeRate);
  }

  bool get isLightning => type == ReceiveType.lightning;

  bool get isInputAmountBelowLimit {
    if (isLightning && swapLimits != null) {
      return inputAmountSat < swapLimits!.min;
    }
    return false;
  }

  bool get isInputAmountAboveLimit {
    if (isLightning && swapLimits != null) {
      return inputAmountSat > swapLimits!.max;
    }
    return false;
  }

  LnReceiveSwap? get getSwap {
    if (type == ReceiveType.lightning) {
      return lightningSwap;
    }

    return null;
  }

  String get address => switch (type) {
    ReceiveType.bitcoin => bitcoinAddress?.address ?? '',
    ReceiveType.lightning => lightningSwap?.receiveAddress ?? '',
    ReceiveType.liquid => liquidAddress?.address ?? '',
    _ => '',
  };

  String get abbreviatedAddress => StringFormatting.truncateMiddle(address);

  String get txId => switch (type) {
    ReceiveType.lightning => lightningSwap?.receiveTxid ?? '',
    _ => tx?.txId ?? '',
  };
  String get abbreviatedTxId => StringFormatting.truncateMiddle(txId);

  Transaction get transaction =>
      Transaction(walletTransaction: tx, swap: lightningSwap, payjoin: payjoin);
}

@freezed
sealed class AmountException with _$AmountException implements Exception {
  const factory AmountException.belowSwapLimit(int limitAmountSat) =
      BelowSwapLimitAmountException;
  const factory AmountException.aboveSwapLimit(int limitAmountSat) =
      AboveSwapLimitAmountException;
  const factory AmountException.aboveBitcoinProtocolLimit(int limitAmountSat) =
      AboveBitcoinProtocolLimitAmountException;
  const AmountException._();

  String get message {
    switch (this) {
      case BelowSwapLimitAmountException _:
        return 'Amount below swap limit of ${FormatAmount.sats(limitAmountSat)}';
      case AboveSwapLimitAmountException _:
        return 'Amount above swap limit of ${FormatAmount.sats(limitAmountSat)}';
      case AboveBitcoinProtocolLimitAmountException _:
        return 'Amount above Bitcoin protocol limit.';
    }
  }
}

class AboveBitcoinProtocolLimitAmountException extends AmountException {
  @override
  final int limitAmountSat;
  const AboveBitcoinProtocolLimitAmountException(this.limitAmountSat)
    : super._();
}
