import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_settings_state.freezed.dart';

@freezed
sealed class SpSettingsState
    with _$SpSettingsState
    implements SpBackendFormState<SpSettingsState> {
  const factory SpSettingsState({
    @Default(false) bool initialized,
    @Default(SpNetwork.regtest) SpNetwork network,
    @Default('') String blindbitUrl,
    @Default('') String electrumUrl,
    // Bumped on programmatic URL changes (load/fetch/network) so the text fields
    // (keyed on it) rebuild; NOT bumped on user typing, to preserve the cursor.
    @Default(0) int formRevision,
    @Default(SpConnTest.untested) SpConnTest blindbitTest,
    @Default(SpConnTest.untested) SpConnTest electrumTest,
    SpFailure? blindbitTestError,
    SpFailure? electrumTestError,
    @Default(false) bool isFetchingDefaults,
    @Default(false) bool isSaving,
    @Default(false) bool saved,
    SpFailure? error,
    @Default([]) List<SpNotifLogLine> console,
  }) = _SpSettingsState;

  const SpSettingsState._();

  // A wrong address can't be saved: both URLs must pass a connection test
  // (which cannot pass on an empty URL, so no separate non-empty check).
  bool get canSave =>
      blindbitTest == SpConnTest.ok &&
      electrumTest == SpConnTest.ok &&
      !isSaving;

  @override
  SpSettingsState applyNetwork(SpNetwork network, SpBackendDefaults defaults) {
    final base = defaults.isOk
        ? SpSettingsState(
            initialized: true,
            network: network,
            blindbitUrl: defaults.blindbitUrl,
            electrumUrl: defaults.electrumUrl,
          )
        : SpSettingsState(
            initialized: true,
            network: network,
            error: defaults.failure,
          );
    return base.copyWith(console: console, formRevision: formRevision + 1);
  }

  @override
  SpSettingsState applyDefaults(SpBackendDefaults defaults) => copyWith(
    initialized: true,
    isFetchingDefaults: false,
    blindbitUrl: defaults.blindbitUrl,
    electrumUrl: defaults.electrumUrl,
    formRevision: formRevision + 1,
    blindbitTest: SpConnTest.untested,
    electrumTest: SpConnTest.untested,
    blindbitTestError: null,
    electrumTestError: null,
    saved: false,
  );

  @override
  SpSettingsState applyUrl(BackendKind kind, String url) => switch (kind) {
    BackendKind.blindbit => copyWith(
      initialized: true,
      blindbitUrl: url,
      blindbitTest: SpConnTest.untested,
      blindbitTestError: null,
      saved: false,
      error: null,
    ),
    BackendKind.electrum => copyWith(
      initialized: true,
      electrumUrl: url,
      electrumTest: SpConnTest.untested,
      electrumTestError: null,
      saved: false,
      error: null,
    ),
  };

  @override
  SpSettingsState applyConnTest(
    BackendKind kind,
    SpConnTest test,
    SpFailure? error,
  ) => switch (kind) {
    BackendKind.blindbit => copyWith(
      blindbitTest: test,
      blindbitTestError: error,
    ),
    BackendKind.electrum => copyWith(
      electrumTest: test,
      electrumTestError: error,
    ),
  };

  @override
  SpSettingsState startFetching() => copyWith(
    initialized: true,
    isFetchingDefaults: true,
    saved: false,
    error: null,
  );

  @override
  SpSettingsState failFetching(SpFailure failure) =>
      copyWith(isFetchingDefaults: false, error: failure);
}
