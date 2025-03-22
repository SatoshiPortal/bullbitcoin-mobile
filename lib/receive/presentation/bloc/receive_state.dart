part of 'receive_bloc.dart';

enum ReceiveStatus { inProgress, success, error }

@freezed
class ReceiveState with _$ReceiveState {
  // Some default variables are added to the states,
  //  even to the network undefined and error state,
  //  this is to avoid null checks in the business logic and the UI.
  const factory ReceiveState.networkUndefined({
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String amountInputCurrencyCode,
    @Default('') String fiatAmountInput,
    @Default('') String bitcoinAmountInput,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default(0) double exchangeRate,
  }) = NetworkUndefinedReceiveState;
  const factory ReceiveState.bitcoin({
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    required Wallet wallet,
    required List<String> fiatCurrencyCodes,
    required String fiatCurrencyCode,
    required String amountInputCurrencyCode,
    required BitcoinUnit bitcoinUnit,
    required double exchangeRate,
    required String address,
    @Default('') String fiatAmountInput,
    @Default('') String bitcoinAmountInput,
    @Default('') String note,
    @Default('') payjoinQueryParameter,
    @Default(false) bool addressOnly,
  }) = BitcoinReceiveState;
  const factory ReceiveState.lightning({
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    required Wallet wallet,
    required List<String> fiatCurrencyCodes,
    required String fiatCurrencyCode,
    required String amountInputCurrencyCode,
    required BitcoinUnit bitcoinUnit,
    required double exchangeRate,
    @Default('') String fiatAmountInput,
    @Default('') String bitcoinAmountInput,
    @Default('') String note,
    Swap? swap,
  }) = LightningReceiveState;
  const factory ReceiveState.liquid({
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    required Wallet wallet,
    required List<String> fiatCurrencyCodes,
    required String fiatCurrencyCode,
    required String amountInputCurrencyCode,
    required BitcoinUnit bitcoinUnit,
    required double exchangeRate,
    required String address,
    @Default('') String fiatAmountInput,
    @Default('') String bitcoinAmountInput,
    @Default('') String note,
  }) = LiquidReceiveState;
  const factory ReceiveState.error({
    required Object error,
    @Default(ReceiveStatus.inProgress) ReceiveStatus status,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String amountInputCurrencyCode,
    @Default('') String fiatAmountInput,
    @Default('') String bitcoinAmountInput,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default(0) double exchangeRate,
  }) = ErrorReceiveState;
  const ReceiveState._();

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
    if (isFiatAmountInput) {
      if (fiatAmountInput.isEmpty) {
        return BigInt.zero;
      }
      return BigInt.from(
        double.parse(fiatAmountInput) * 100000000 / exchangeRate,
      );
    } else if (bitcoinAmountInput.isEmpty) {
      return BigInt.zero;
    } else if (bitcoinUnit == BitcoinUnit.sats) {
      return BigInt.parse(bitcoinAmountInput);
    } else {
      final amountBtc = double.parse(bitcoinAmountInput);
      return BigInt.from((amountBtc * 100000000).truncate());
    }
  }

  double get amountBtc => amountSat.toDouble() / 100000000;

  double get amountFiat {
    if (isFiatAmountInput) {
      if (fiatAmountInput.isEmpty) {
        return 0;
      }
      return double.parse(fiatAmountInput);
    } else if (bitcoinAmountInput.isEmpty) {
      return 0;
    } else if (bitcoinUnit == BitcoinUnit.sats) {
      return BigInt.parse(bitcoinAmountInput).toDouble() *
          exchangeRate /
          100000000;
    } else {
      return double.parse(bitcoinAmountInput) * exchangeRate;
    }
  }

  bool get hasAmount => amountSat > BigInt.zero;

  bool get hasReceivedFunds => status == ReceiveStatus.success;
}
