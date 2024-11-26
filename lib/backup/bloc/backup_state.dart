import 'package:bb_mobile/_model/backup.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_state.freezed.dart';

@freezed
class BackupState with _$BackupState {
  const factory BackupState({
    @Default(true) bool loading,
    @Default([]) List<Backup> backups,
    @Default('') String backupId,
    @Default('') String backupKey,
    @Default('') String error,
  }) = _BackupState;
}
