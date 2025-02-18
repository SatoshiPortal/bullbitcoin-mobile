part of 'receive_bloc.dart';

@freezed
sealed class ReceiveState {
  const factory ReceiveState.initial() = _Initial;
  const factory ReceiveState.lightning({
    required Wallet wallet,
  }) = _Lightning;
  const factory ReceiveState.bitcoin({
    required Wallet wallet,
    @Default(true) bool isPayjoin,
  }) = _Bitcoin;
  const factory ReceiveState.liquid({
    required Wallet wallet,
  }) = _Liquid;
  const factory ReceiveState.swap({
    required Wallet wallet,
  }) = _Swap;
  const factory ReceiveState.success({
    required Wallet wallet,
  }) = _Success;
}
