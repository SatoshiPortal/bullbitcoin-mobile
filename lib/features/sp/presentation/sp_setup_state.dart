import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
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
  SpSetupState applyNetwork(SpNetwork network, SpBackendDefaults defaults) =>
      defaults.isOk
      ? SpSetupState(
          network: network,
          blindbitUrl: defaults.blindbitUrl,
          electrumUrl: defaults.electrumUrl,
        )
      : SpSetupState(network: network, error: defaults.failure);

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
  SpSetupState applyUrl(BackendKind kind, String url) => switch (kind) {
    BackendKind.blindbit => copyWith(
      blindbitUrl: url,
      blindbitTest: SpConnTest.untested,
      blindbitTestError: null,
      error: null,
    ),
    BackendKind.electrum => copyWith(
      electrumUrl: url,
      electrumTest: SpConnTest.untested,
      electrumTestError: null,
      error: null,
    ),
  };

  @override
  SpSetupState applyConnTest(
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
  SpSetupState startFetching() =>
      copyWith(isFetchingDefaults: true, error: null);

  @override
  SpSetupState failFetching(SpFailure failure) =>
      copyWith(isFetchingDefaults: false, error: failure);
}
