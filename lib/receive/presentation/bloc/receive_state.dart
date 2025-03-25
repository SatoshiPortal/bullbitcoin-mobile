part of 'receive_bloc.dart';

enum ReceiveStatus { inProgress, success, error }

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState.bitcoin({
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    required Wallet wallet,
    required List<String> fiatCurrencyCodes,
    required String defaultFiatCurrencyCode,
    required double defaultFiatCurrencyExchangeRate,
    required String amountInputCurrencyCode,
    required double amountInputCurrencyExchangeRate,
    required BitcoinUnit bitcoinUnit,
    required String address,
    @Default('') String amountInput,
    @Default('') String note,
    @Default('') String payjoinQueryParameter,
    @Default(false) bool isAddressOnly,
    Object? error,
  }) = BitcoinReceiveState;
  const factory ReceiveState.lightning({
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    required Wallet wallet,
    required List<String> fiatCurrencyCodes,
    required String defaultFiatCurrencyCode,
    required double defaultFiatCurrencyExchangeRate,
    required String amountInputCurrencyCode,
    required double amountInputCurrencyExchangeRate,
    required BitcoinUnit bitcoinUnit,
    @Default('') String amountInput,
    @Default('') String note,
    LnReceiveSwap? swap,
    Object? error,
  }) = LightningReceiveState;
  const factory ReceiveState.liquid({
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    required Wallet wallet,
    required List<String> fiatCurrencyCodes,
    required String defaultFiatCurrencyCode,
    required double defaultFiatCurrencyExchangeRate,
    required String amountInputCurrencyCode,
    required double amountInputCurrencyExchangeRate,
    required BitcoinUnit bitcoinUnit,
    required String address,
    @Default('') String amountInput,
    @Default('') String note,
    Object? error,
  }) = LiquidReceiveState;
  // Some default and optional variables are added to the network undefined state,
  //  this is to have an initial state to set in the block and avoid null checks
  //  in the business logic and the UI.
  const factory ReceiveState.networkUndefined({
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String defaultFiatCurrencyCode,
    @Default(0) double defaultFiatCurrencyExchangeRate,
    @Default('') String amountInputCurrencyCode,
    @Default(0) double amountInputCurrencyExchangeRate,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default('') String amountInput,
    @Default('') String note,
    Object? error,
  }) = NetworkUndefinedReceiveState;
  const ReceiveState._();

  String get qrData {
    switch (this) {
      case final BitcoinReceiveState bitcoinState:
        if (bitcoinState.isAddressOnly ||
            (bitcoinState.amountSat == BigInt.zero &&
                bitcoinState.note.isEmpty &&
                bitcoinState.payjoinQueryParameter.isEmpty)) {
          return bitcoinState.address;
        }
        final bip21Uri = Uri(
          scheme: 'bitcoin',
          path: bitcoinState.address,
          queryParameters: {
            if (bitcoinState.amountSat > BigInt.zero)
              'amount': bitcoinState.amountBtc.toString(),
            if (bitcoinState.note.isNotEmpty) 'message': bitcoinState.note,
            if (bitcoinState.payjoinQueryParameter.isNotEmpty)
              'pj': bitcoinState.payjoinQueryParameter,
          },
        );
        return bip21Uri.toString();
      case final LightningReceiveState lightningState:
        return lightningState.swap?.invoice ?? '';
      case final LiquidReceiveState liquidState:
        if (liquidState.amountSat == BigInt.zero && liquidState.note.isEmpty) {
          return liquidState.address;
        }
        final bip21Uri = Uri(
          scheme: 'liquidnetwork',
          path: liquidState.address,
          queryParameters: {
            if (liquidState.amountSat > BigInt.zero)
              'amount': liquidState.amountBtc.toString(),
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

  List<String> get amountInputCurrencyCodes {
    return [
      BitcoinUnit.btc.code,
      BitcoinUnit.sats.code,
      ...fiatCurrencyCodes,
    ];
  }

  bool get isFiatAmountInput => ![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
      .contains(amountInputCurrencyCode);

  BigInt get amountSat {
    if (amountInput.isEmpty) {
      return BigInt.zero;
    } else if (isFiatAmountInput) {
      final amountFiat = double.tryParse(amountInput) ?? 0;
      return BigInt.from(
        amountFiat * 100000000 / amountInputCurrencyExchangeRate,
      );
    } else if (amountInputCurrencyCode == BitcoinUnit.sats.code) {
      return BigInt.tryParse(amountInput) ?? BigInt.zero;
    } else {
      final amountBtc = double.tryParse(amountInput) ?? 0;
      return BigInt.from((amountBtc * 100000000).truncate());
    }
  }

  double get amountBtc => amountSat.toDouble() / 100000000;

  double get amountDefaultFiatCurrency {
    return amountBtc * defaultFiatCurrencyExchangeRate;
  }

  String get formattedBitcoinAmount {
    final currencyFormatter = NumberFormat.currency(
      name: BitcoinUnit.btc.code,
      decimalDigits: bitcoinUnit.decimals,
      customPattern: '#,##0.00 ¤',
    );
    final formatted = currencyFormatter
        .format(
          bitcoinUnit == BitcoinUnit.sats ? amountSat : amountBtc,
        )
        .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    return formatted;
  }

  String get formattedAmountEquivalent {
    final amountEquivalentCurrencyCode =
        isFiatAmountInput ? bitcoinUnit.code : defaultFiatCurrencyCode;
    final currencyFormatter = isFiatAmountInput
        ? NumberFormat.currency(
            name: amountEquivalentCurrencyCode,
            decimalDigits: bitcoinUnit.decimals,
            customPattern: '#,##0.00 ¤',
          )
        : NumberFormat.currency(
            name: amountEquivalentCurrencyCode,
            customPattern: '#,##0.00 ¤',
          );
    final amountEquivalent = isFiatAmountInput
        ? bitcoinUnit == BitcoinUnit.sats
            ? currencyFormatter.format(amountSat.toInt())
            : currencyFormatter.format(amountBtc)
        : currencyFormatter.format(amountDefaultFiatCurrency);

    return amountEquivalent;
  }

  String get formattedDefaultFiatCurrencyEquivalent {
    final currencyFormatter = NumberFormat.currency(
      name: defaultFiatCurrencyCode,
      customPattern: '#,##0.00 ¤',
    );
    return currencyFormatter.format(amountDefaultFiatCurrency);
  }

  bool get hasAmount => amountSat > BigInt.zero;

  bool get hasReceivedFunds => status == ReceiveStatus.success;
}
