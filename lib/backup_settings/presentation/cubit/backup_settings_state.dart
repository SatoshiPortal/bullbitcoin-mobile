part of 'backup_settings_cubit.dart';

@freezed
class BackupSettingsState with _$BackupSettingsState {
  factory BackupSettingsState({@Default('') String encryted}) =
      _BackupSettingsState;
}
