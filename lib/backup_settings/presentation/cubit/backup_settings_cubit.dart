import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_settings_state.dart';
part 'backup_settings_cubit.freezed.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  BackupSettingsCubit() : super(BackupSettingsState());
}
