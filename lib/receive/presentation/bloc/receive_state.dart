part of 'receive_bloc.dart';

enum ReceiveStatus { initial, inProgress, success, error }

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState.lightning({
    @Default(ReceiveStatus.initial) ReceiveStatus status,
    Wallet? wallet,
    @Default([]) List<String> amountInputCurrencies,
    @Default('SAT') String amountInputCurrencyCode,
    @Default('0') String fiatAmountInput,
    @Default('0') String bitcoinAmountInput,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default(0) double exchangeRate,
    String? fiatCurrencyCode,
    @Default('') String note,
    Swap? swap,
  }) = LightningReceiveState;

  const factory ReceiveState.bitcoin({
    @Default(ReceiveStatus.initial) ReceiveStatus status,
    Wallet? wallet,
    @Default('') String address,
    String? payjoinQueryParameter,
    @Default([]) List<String> amountInputCurrencies,
    @Default('SAT') String amountInputCurrencyCode,
    @Default('0') String fiatAmountInput,
    @Default('0') String bitcoinAmountInput,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default(0) double exchangeRate,
    String? fiatCurrencyCode,
    @Default('') String note,
    @Default(false) bool addressOnly,
  }) = BitcoinReceiveState;

  const factory ReceiveState.liquid({
    @Default(ReceiveStatus.initial) ReceiveStatus status,
    Wallet? wallet,
    @Default('') String address,
    @Default([]) List<String> amountInputCurrencies,
    @Default('SAT') String amountInputCurrencyCode,
    @Default('0') String fiatAmountInput,
    @Default('0') String bitcoinAmountInput,
    @Default(BitcoinUnit.sats) BitcoinUnit bitcoinUnit,
    @Default(0) double exchangeRate,
    String? fiatCurrencyCode,
    @Default('') String note,
  }) = LiquidReceiveState;
  const ReceiveState._();

  bool get isFiatAmountInput => ![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
      .contains(amountInputCurrencyCode);

  BigInt get amountSat {
    if (isFiatAmountInput) {
      return BigInt.from(
          double.parse(fiatAmountInput) * 100000000 / exchangeRate);
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
      return double.parse(fiatAmountInput);
    } else if (bitcoinUnit == BitcoinUnit.sats) {
      return BigInt.parse(bitcoinAmountInput).toDouble() *
          exchangeRate /
          100000000;
    } else {
      return double.parse(bitcoinAmountInput) * exchangeRate;
    }
  }

  bool get hasReceivedFunds => status == ReceiveStatus.success;
}
