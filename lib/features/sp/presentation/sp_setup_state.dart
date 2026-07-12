import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_setup_state.freezed.dart';

@freezed
sealed class SpSetupState
    with _$SpSetupState
    implements SpBackendFormState<SpSetupState> {
  const factory SpSetupState({
    @Default(SpNetwork.regtest) SpNetwork network,
    @Default('') String blindbitUrl,
    @Default('') String electrumUrl,
    @Default(SpConnTest.untested) SpConnTest blindbitTest,
    @Default(SpConnTest.untested) SpConnTest electrumTest,
    SpFailure? blindbitTestError,
    SpFailure? electrumTestError,
    @Default(false) bool isFetchingDefaults,
    @Default(false) bool isCreating,
    @Default(false) bool created,
    SpFailure? error,
  }) = _SpSetupState;

  const SpSetupState._();

  // A wrong address can't create a wallet: both URLs must pass a connection
  // test (which cannot pass on an empty URL, so no separate non-empty check).
  bool get canCreate =>
      blindbitTest == SpConnTest.ok &&
      electrumTest == SpConnTest.ok &&
      !isCreating;

  @override
  SpSetupState applyNetwork(SpNetwork network) => copyWith(
    network: network,
    isFetchingDefaults: true,
    blindbitUrl: '',
    electrumUrl: '',
    blindbitTest: SpConnTest.untested,
    electrumTest: SpConnTest.untested,
    blindbitTestError: null,
    electrumTestError: null,
    error: null,
  );

  @override
  SpSetupState applyDefaults(SpBackendDefaults defaults) => copyWith(
    isFetchingDefaults: false,
    blindbitUrl: defaults.blindbitUrl,
    electrumUrl: defaults.electrumUrl,
    blindbitTest: SpConnTest.untested,
    electrumTest: SpConnTest.untested,
    blindbitTestError: null,
    electrumTestError: null,
  );

  @override
  SpSetupState applyUrl(SpBackendKind kind, String url) => switch (kind) {
    SpBackendKind.blindbit => copyWith(
      blindbitUrl: url,
      blindbitTest: SpConnTest.untested,
      blindbitTestError: null,
      error: null,
    ),
    SpBackendKind.electrum => copyWith(
      electrumUrl: url,
      electrumTest: SpConnTest.untested,
      electrumTestError: null,
      error: null,
    ),
  };

  @override
  SpSetupState applyConnTest(
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
  SpSetupState startFetching() =>
      copyWith(isFetchingDefaults: true, error: null);

  @override
  SpSetupState failFetching(SpFailure failure) =>
      copyWith(isFetchingDefaults: false, error: failure);
}
