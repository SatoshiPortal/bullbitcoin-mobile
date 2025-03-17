part of 'backup_wallet_bloc.dart';

@freezed
sealed class BackupWalletState with _$BackupWalletState {
  const factory BackupWalletState({
    @Default(false) bool isSubmitting,
    @Default(false) bool isSuccess,
    @Default(false) bool isFailure,
    @Default('') String error,
  }) = _BackupWalletState;
}
