import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form_state.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_settings_state.freezed.dart';

@freezed
sealed class SpSettingsState
    with _$SpSettingsState, SpBackendFormState<SpSettingsState> {
  const factory SpSettingsState({
    @Default(SpBackendForm()) SpBackendForm form,
    @Default(false) bool initialized,
    @Default(false) bool isSaving,
    @Default(false) bool saved,
    @Default([]) List<SpNotifLogLine> console,
  }) = _SpSettingsState;

  const SpSettingsState._();

  // A wrong address can't be saved: both URLs must pass a connection test
  // (which cannot pass on an empty URL, so no separate non-empty check).
  bool get canSave =>
      form.blindbitTest == SpConnTest.ok &&
      form.electrumTest == SpConnTest.ok &&
      !isSaving;

  // Any form change marks the settings initialized and clears the saved flag:
  // the current form no longer matches what was last saved.
  @override
  SpSettingsState withForm(SpBackendForm form) =>
      copyWith(form: form, initialized: true, saved: false);
}
