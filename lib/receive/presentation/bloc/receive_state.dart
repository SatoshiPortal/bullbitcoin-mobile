part of 'receive_bloc.dart';

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState.bitcoin({
    required Wallet wallet,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String inputAmountCurrencyCode,
    @Default('') String address,
    @Default('') String inputAmount,
    BigInt? confirmedAmountSat,
    @Default('') String note,
    @Default(false) bool loadingPJ,
    @Default('') String payjoinQueryParameter,
    @Default(false) bool isAddressOnly,
    @Default('') String txId,
    Object? error,
  }) = BitcoinReceiveState;
  const factory ReceiveState.lightning({
    required Wallet wallet,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String inputAmountCurrencyCode,
    @Default('') String inputAmount,
    BigInt? confirmedAmountSat,
    @Default('') String note,
    LnReceiveSwap? swap,
    Object? error,
  }) = LightningReceiveState;
  const factory ReceiveState.liquid({
    required Wallet wallet,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String inputAmountCurrencyCode,
    @Default('') String address,
    @Default('') String inputAmount,
    BigInt? confirmedAmountSat,
    @Default('') String note,
    @Default('') String txId,
    Object? error,
  }) = LiquidReceiveState;
  // Some default and optional variables are added to the network undefined state,
  //  this is to have an initial state to set in the block and avoid null checks
  //  in the business logic and the UI.
  const factory ReceiveState.networkUndefined({
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String inputAmountCurrencyCode,
    @Default('') String inputAmount,
    BigInt? confirmedAmountSat,
    @Default('') String note,
    Object? error,
  }) = NetworkUndefinedReceiveState;
  const ReceiveState._();

  List<String> get inputAmountCurrencyCodes {
    return [
      BitcoinUnit.btc.code,
      BitcoinUnit.sats.code,
      ...fiatCurrencyCodes,
    ];
  }

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
    switch (this) {
      case final BitcoinReceiveState bitcoinState:
        if (bitcoinState.isAddressOnly ||
            (confirmedAmountSat == null &&
                bitcoinState.note.isEmpty &&
                bitcoinState.payjoinQueryParameter.isEmpty)) {
          return bitcoinState.address;
        }
        final bip21Uri = Uri(
          scheme: 'bitcoin',
          path: bitcoinState.address,
          queryParameters: {
            if (confirmedAmountBtc > 0) 'amount': confirmedAmountBtc.toString(),
            if (bitcoinState.note.isNotEmpty) 'message': bitcoinState.note,
            if (bitcoinState.payjoinQueryParameter.isNotEmpty)
              'pj': bitcoinState.payjoinQueryParameter,
          },
        );
        return bip21Uri.toString();
      case final LightningReceiveState lightningState:
        return lightningState.swap?.invoice ?? '';
      case final LiquidReceiveState liquidState:
        if (confirmedAmountSat == null && liquidState.note.isEmpty) {
          return liquidState.address;
        }
        final bip21Uri = Uri(
          scheme: 'liquidnetwork',
          path: liquidState.address,
          queryParameters: {
            if (confirmedAmountBtc > 0) 'amount': confirmedAmountBtc.toString(),
            if (liquidState.note.isNotEmpty) 'message': liquidState.note,
          },
        );
        return bip21Uri.toString();
      case _:
        return '';
    }
  }

  String get addressOrInvoiceOnly {
    switch (this) {
      case final BitcoinReceiveState bitcoinState:
        return bitcoinState.address;
      case final LightningReceiveState lightningState:
        return lightningState.swap?.invoice ?? '';
      case final LiquidReceiveState liquidState:
        return liquidState.address;
      case _:
        return '';
    }
  }

  double get confirmedAmountBtc => confirmedAmountSat != null
      ? confirmedAmountSat!.toDouble() / 100000000
      : 0;

  double get confirmedAmountFiat {
    return confirmedAmountBtc * exchangeRate;
  }

  String get formattedConfirmedAmountBitcoin {
    final currencyFormatter = NumberFormat.currency(
      name: bitcoinUnit.code,
      decimalDigits: bitcoinUnit.decimals,
      customPattern: '#,##0.00 ¤',
    );
    final formatted = currencyFormatter
        .format(
          bitcoinUnit == BitcoinUnit.sats
              ? confirmedAmountSat?.toDouble() ?? 0
              : confirmedAmountBtc,
        )
        .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    return formatted;
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
      final equivalentAmount = bitcoinUnit == BitcoinUnit.sats
          ? inputAmountSat.toDouble()
          : inputAmountBtc;
      final currencyFormatter = NumberFormat.currency(
        name: bitcoinUnit.code,
        decimalDigits: bitcoinUnit.decimals,
        customPattern: '#,##0.00 ¤',
      );
      final formatted = currencyFormatter
          .format(equivalentAmount)
          .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
      return formatted;
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
    switch (this) {
      case final LightningReceiveState state:
        return state.swap != null && state.swap!.status == SwapStatus.claimable;
      case _:
        return false;
    }
  }

  bool get isPaymentReceived {
    switch (this) {
      case final LiquidReceiveState state:
        return state.txId.isNotEmpty;
      case final BitcoinReceiveState state:
        return state.txId.isNotEmpty;
      case final LightningReceiveState state:
        return state.swap != null && state.swap!.status == SwapStatus.completed;
      case _:
        return false;
    }
  }

  bool loadingPayjoin() {
    if (this is BitcoinReceiveState) {
      return (this as BitcoinReceiveState).loadingPJ;
    }
    return false;
  }
}
