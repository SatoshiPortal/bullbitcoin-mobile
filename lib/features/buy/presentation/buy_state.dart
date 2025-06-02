part of 'buy_bloc.dart';

@freezed
sealed class BuyState with _$BuyState {
  const factory BuyState() = _BuyState;
  const BuyState._();
}
