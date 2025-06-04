part of 'wallet_detail_bloc.dart';

@freezed
sealed class WalletDetailEvent with _$WalletDetailEvent {
  const factory WalletDetailEvent.started() = WalletDetailStarted;
  const WalletDetailEvent._();
}
