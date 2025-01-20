import 'package:bb_mobile/_model/backup.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'manual_state.freezed.dart';

@freezed
class ManualState with _$ManualState {
  const factory ManualState({
    @Default(false) bool loading,
    @Default([]) List<Backup> loadedBackups,
    @Default({
      "mnemonic": true,
      "passphrase": true,
      "descriptors": true,
      "labels": true,
      "script": true,
    })
    Map<String, bool> selectedBackupOptions,
    @Default('') String backupKeyMnemonic,
    @Default('') String backupId,
    @Default('') String backupPath,
    @Default('') String backupName,
    @Default('') String backupKey,
    // //  To avoid multiple backups being created when the user clicks the button multiple times
    // @Default(false) bool isBackupSaved,
    @Default('') String error,
  }) = _ManualState;
}
