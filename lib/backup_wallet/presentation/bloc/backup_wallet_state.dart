part of 'backup_wallet_bloc.dart';

@freezed
sealed class BackupWalletState with _$BackupWalletState {
  const factory BackupWalletState({
    @Default('') String filePath,
    @Default(false) bool isSubmitting,
    @Default('') String error,
  }) = _BackupWalletState;
  factory BackupWalletState.error(String error) => BackupWalletState(
        isSubmitting: false,
        error: error,
      );
}
