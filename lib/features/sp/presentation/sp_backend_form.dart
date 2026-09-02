import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_connection_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_backend_form.freezed.dart';

/// The backend-config form fields shared by the SP setup and settings states,
/// with the transitions the shared cubit logic drives written once here. The
/// setup and settings states embed one of these and add only their own flags.
@freezed
sealed class SpBackendForm with _$SpBackendForm {
  const factory SpBackendForm({
    @Default(BitcoinNetwork.mainnet) BitcoinNetwork network,
    @Default('') String blindbitUrl,
    @Default('') String electrumUrl,
    @Default(SpConfig.defaultFetchConcurrencyFactor) int fetchConcurrencyFactor,
    @Default(SpConfig.defaultMatchConcurrencyFactor) int matchConcurrencyFactor,
    @Default(SpConnectionStatus.untested) SpConnectionStatus blindbitStatus,
    @Default(SpConnectionStatus.untested) SpConnectionStatus electrumStatus,
    SpFailure? blindbitStatusError,
    SpFailure? electrumStatusError,
    @Default(false) bool isFetchingDefaults,
    SpFailure? error,
  }) = _SpBackendForm;

  const SpBackendForm._();

  /// Select a network and enter the "fetching defaults" state, clearing the old
  /// URLs and tests. The fetched defaults land later via [applyDefaults].
  SpBackendForm applyNetwork(BitcoinNetwork network) => copyWith(
    network: network,
    isFetchingDefaults: true,
    blindbitUrl: '',
    electrumUrl: '',
    blindbitStatus: SpConnectionStatus.untested,
    electrumStatus: SpConnectionStatus.untested,
    fetchConcurrencyFactor: SpConfig.defaultFetchConcurrencyFactor,
    matchConcurrencyFactor: SpConfig.defaultMatchConcurrencyFactor,
    blindbitStatusError: null,
    electrumStatusError: null,
    error: null,
  );

  /// Fill both URLs from fetched defaults and reset the connection tests. Keeps
  /// a field (and its test) the user edited while the fetch was in flight
  /// ([keepBlindbit] / [keepElectrum]) so a slow fetch does not overwrite typed
  /// input.
  SpBackendForm applyDefaults(
    SpBackendDefaults defaults, {
    bool keepBlindbit = false,
    bool keepElectrum = false,
  }) => copyWith(
    isFetchingDefaults: false,
    blindbitUrl: keepBlindbit ? blindbitUrl : defaults.blindbitUrl,
    electrumUrl: keepElectrum ? electrumUrl : defaults.electrumUrl,
    blindbitStatus: keepBlindbit ? blindbitStatus : SpConnectionStatus.untested,
    electrumStatus: keepElectrum ? electrumStatus : SpConnectionStatus.untested,
    blindbitStatusError: keepBlindbit ? blindbitStatusError : null,
    electrumStatusError: keepElectrum ? electrumStatusError : null,
  );

  /// Set one backend URL and reset that backend's connection test.
  SpBackendForm applyUrl(SpBackendKind kind, String url) => switch (kind) {
    SpBackendKind.blindbit => copyWith(
      blindbitUrl: url,
      blindbitStatus: SpConnectionStatus.untested,
      blindbitStatusError: null,
      error: null,
    ),
    SpBackendKind.electrum => copyWith(
      electrumUrl: url,
      electrumStatus: SpConnectionStatus.untested,
      electrumStatusError: null,
      error: null,
    ),
  };

  /// Record a connection-test outcome for one backend.
  SpBackendForm applyConnectionStatus(
    SpBackendKind kind,
    SpConnectionStatus test,
    SpFailure? error,
  ) => switch (kind) {
    SpBackendKind.blindbit => copyWith(
      blindbitStatus: test,
      blindbitStatusError: error,
    ),
    SpBackendKind.electrum => copyWith(
      electrumStatus: test,
      electrumStatusError: error,
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

  SpBackendForm applyFetchConcurrencyFactor(int factor) => copyWith(
    fetchConcurrencyFactor: factor.clamp(1, SpConfig.maxFetchConcurrencyFactor),
    error: null,
  );

  SpBackendForm applyMatchConcurrencyFactor(int factor) => copyWith(
    matchConcurrencyFactor: factor.clamp(1, SpConfig.maxMatchConcurrencyFactor),
    error: null,
  );
}
