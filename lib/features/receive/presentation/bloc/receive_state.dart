part of 'receive_bloc.dart';

@freezed
sealed class ReceiveState {
  const factory ReceiveState.initial() = _Initial;
  const factory ReceiveState.lightning({
    required Wallet wallet,
    @Default(false) bool isFiatInput,
    required String fiatCurrencyCode,
    required double exchangeRate,
    required BitcoinUnit bitcoinUnit,
    @Default('') String fiatInputAmount,
    @Default('') String bitcoinInputAmount,
    @Default('') String description,
    BigInt? feeAmountSat,
    @Default('') String invoice,
    @Default(false) bool isReceived,
  }) = _Lightning;
  const factory ReceiveState.bitcoin({
    required Wallet wallet,
    String? amountInput,
    BigInt? amountSat,
    @Default(true) bool isPayjoin,
  }) = _Bitcoin;
  const factory ReceiveState.liquid({
    required Wallet wallet,
    String? amountInput,
    BigInt? amountSat,
  }) = _Liquid;
  const factory ReceiveState.success({
    required Wallet wallet,
  }) = _Success;
}
