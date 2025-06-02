part of 'buy_bloc.dart';

@freezed
sealed class BuyEvent with _$BuyEvent {
  const factory BuyEvent.started() = _BuyStarted;
}
