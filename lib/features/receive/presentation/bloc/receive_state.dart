part of 'receive_bloc.dart';

@freezed
sealed class ReceiveState {
  const factory ReceiveState.initial() = ReceiveInitial;
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
  }) = ReceiveLightning;
  const factory ReceiveState.bitcoin({
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
    @Default(true) bool isPayjoin,
  }) = ReceiveBitcoin;
  const factory ReceiveState.liquid({
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
  }) = ReceiveLiquid;

  const ReceiveState._();

  bool get hasReceived {
    return switch (this) {
      ReceiveLightning(:final isReceived) => isReceived,
      ReceiveBitcoin(:final isReceived) => isReceived,
      ReceiveLiquid(:final isReceived) => isReceived,
      ReceiveInitial() => false,
    };
  }
}
