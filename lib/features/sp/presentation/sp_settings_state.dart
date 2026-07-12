import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';
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
  SpSettingsState applyNetwork(SpNetwork network) => copyWith(
    initialized: true,
    network: network,
    isFetchingDefaults: true,
    blindbitUrl: '',
    electrumUrl: '',
    blindbitTest: SpConnTest.untested,
    electrumTest: SpConnTest.untested,
    blindbitTestError: null,
    electrumTestError: null,
    saved: false,
    error: null,
  );

  @override
  SpSettingsState applyDefaults(SpBackendDefaults defaults) => copyWith(
    initialized: true,
    isFetchingDefaults: false,
    blindbitUrl: defaults.blindbitUrl,
    electrumUrl: defaults.electrumUrl,
    blindbitTest: SpConnTest.untested,
    electrumTest: SpConnTest.untested,
    blindbitTestError: null,
    electrumTestError: null,
    saved: false,
  );

  @override
  SpSettingsState applyUrl(SpBackendKind kind, String url) => switch (kind) {
    SpBackendKind.blindbit => copyWith(
      initialized: true,
      blindbitUrl: url,
      blindbitTest: SpConnTest.untested,
      blindbitTestError: null,
      saved: false,
      error: null,
    ),
    SpBackendKind.electrum => copyWith(
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
    SpBackendKind kind,
    SpConnTest test,
    SpFailure? error,
  ) => switch (kind) {
    SpBackendKind.blindbit => copyWith(
      blindbitTest: test,
      blindbitTestError: error,
    ),
    SpBackendKind.electrum => copyWith(
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
