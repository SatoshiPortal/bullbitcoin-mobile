import 'dart:async';

import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/delete_automated_keychain_backup_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_settings_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/publish_automated_keychain_backup_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/set_automated_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/presentation/get_paid_settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class GetPaidSettingsCubit extends Cubit<GetPaidSettingsState> {
  final GetGetPaidSettingsUsecase getSettings;
  final SetAutomatedBackupEnabledUsecase setEnabled;
  final PublishAutomatedKeychainBackupUsecase publish;
  final DeleteAutomatedKeychainBackupUsecase deleteBackup;
  StreamSubscription<GetPaidSettings>? _settingsSubscription;

  GetPaidSettingsCubit({
    required this.getSettings,
    required this.setEnabled,
    required this.publish,
    required this.deleteBackup,
  }) : super(const GetPaidSettingsState());

  Future<void> load() async {
    emit(state.copyWith(status: GetPaidSettingsStatus.loading));
    await _settingsSubscription?.cancel();
    _settingsSubscription = getSettings.watch().listen(
      (settings) => emit(
        state.copyWith(
          status: GetPaidSettingsStatus.loaded,
          settings: settings,
        ),
      ),
      onError: (_, _) =>
          emit(state.copyWith(status: GetPaidSettingsStatus.failure)),
    );
  }

  Future<void> toggleAutomatedBackup(bool enabled) async {
    if (state.settings == null || state.busy) return;
    emit(state.copyWith(saving: true));
    try {
      await setEnabled.execute(enabled);
    } catch (_) {
      emit(state.copyWith(status: GetPaidSettingsStatus.failure));
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  Future<void> backupNow() async {
    if (state.settings == null || state.busy) return;
    emit(state.copyWith(backingUp: true));
    try {
      await publish.execute();
    } catch (_) {
      emit(state.copyWith(status: GetPaidSettingsStatus.failure));
    } finally {
      emit(state.copyWith(backingUp: false));
    }
  }

  Future<void> deleteRemoteBackup() async {
    final settings = state.settings;
    if (settings == null || settings.automatedBackupEnabled || state.busy) {
      return;
    }
    emit(state.copyWith(deleting: true));
    try {
      await deleteBackup.execute();
    } catch (_) {
      emit(state.copyWith(status: GetPaidSettingsStatus.failure));
    } finally {
      emit(state.copyWith(deleting: false));
    }
  }

  @override
  Future<void> close() async {
    await _settingsSubscription?.cancel();
    return super.close();
  }
}
