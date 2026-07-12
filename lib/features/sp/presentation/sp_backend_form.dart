import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_backend_form.freezed.dart';

/// The backend-config form fields shared by the SP setup and settings states,
/// with the transitions the shared cubit logic drives written once here. The
/// setup and settings states embed one of these and add only their own flags.
@freezed
sealed class SpBackendForm with _$SpBackendForm {
  const factory SpBackendForm({
    @Default(SpNetwork.regtest) SpNetwork network,
    @Default('') String blindbitUrl,
    @Default('') String electrumUrl,
    @Default(SpConnTest.untested) SpConnTest blindbitTest,
    @Default(SpConnTest.untested) SpConnTest electrumTest,
    SpFailure? blindbitTestError,
    SpFailure? electrumTestError,
    @Default(false) bool isFetchingDefaults,
    SpFailure? error,
  }) = _SpBackendForm;

  const SpBackendForm._();

  /// Select a network and enter the "fetching defaults" state, clearing the old
  /// URLs and tests. The fetched defaults land later via [applyDefaults].
  SpBackendForm applyNetwork(SpNetwork network) => copyWith(
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

  /// Fill both URLs from fetched defaults and reset the connection tests.
  SpBackendForm applyDefaults(SpBackendDefaults defaults) => copyWith(
    isFetchingDefaults: false,
    blindbitUrl: defaults.blindbitUrl,
    electrumUrl: defaults.electrumUrl,
    blindbitTest: SpConnTest.untested,
    electrumTest: SpConnTest.untested,
    blindbitTestError: null,
    electrumTestError: null,
  );

  /// Set one backend URL and reset that backend's connection test.
  SpBackendForm applyUrl(SpBackendKind kind, String url) => switch (kind) {
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

  /// Record a connection-test outcome for one backend.
  SpBackendForm applyConnTest(
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

  /// Enter the "fetching defaults" state.
  SpBackendForm startFetching() =>
      copyWith(isFetchingDefaults: true, error: null);

  /// Leave "fetching defaults" with a failure.
  SpBackendForm failFetching(SpFailure failure) =>
      copyWith(isFetchingDefaults: false, error: failure);

  /// The current URL for one backend.
  String urlFor(SpBackendKind kind) =>
      kind == SpBackendKind.blindbit ? blindbitUrl : electrumUrl;
}
