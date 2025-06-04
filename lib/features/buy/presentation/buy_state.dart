part of 'buy_bloc.dart';

@freezed
sealed class BuyState with _$BuyState {
  const factory BuyState({@Default({}) Map<String, double> balances}) =
      _BuyState;
  const BuyState._();
}
