part of 'backup_wallet_bloc.dart';

@freezed
class BackupWalletEvent with _$BackupWalletEvent {
  const factory BackupWalletEvent.started() = _Started;
}
