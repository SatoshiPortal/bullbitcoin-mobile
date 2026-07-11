import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Form fields shared by the setup and settings backend-config states, plus the
/// small transitions the shared cubit logic drives. Each concrete state maps a
/// transition onto its own `copyWith`, folding in any state-specific bookkeeping
/// (settings bumps `formRevision`, marks itself edited; setup does not).
mixin SpBackendFormState<S> {
  SpNetwork get network;
  String get blindbitUrl;
  String get electrumUrl;
  SpConnTest get blindbitTest;
  SpConnTest get electrumTest;
  SpFailure? get blindbitTestError;
  SpFailure? get electrumTestError;
  bool get isFetchingDefaults;
  SpFailure? get error;

  /// Rebuild for a freshly chosen network from its backend defaults.
  S applyNetwork(SpNetwork network, SpBackendDefaults defaults);

  /// Fill both URLs from fetched defaults and reset the connection tests.
  S applyDefaults(SpBackendDefaults defaults);

  /// Set one backend URL and reset that backend's connection test.
  S applyUrl(BackendKind kind, String url);

  /// Record a connection-test outcome for one backend.
  S applyConnTest(BackendKind kind, SpConnTest test, SpFailure? error);

  /// Enter the "fetching defaults" state.
  S startFetching();

  /// Leave "fetching defaults" with a failure.
  S failFetching(SpFailure failure);
}

/// Backend-config form behaviour shared by `SpSetupCubit` and `SpSettingsCubit`:
/// network selection, fetching defaults, URL edits, and the connection tests.
/// State-specific extras stay in each cubit's transition methods.
mixin SpBackendFormCubit<S extends SpBackendFormState<S>> on Cubit<S> {
  TestSpBackendUsecase get backendTestUsecase;
  GetSpBackendDefaultsUsecase get getBackendDefaultsUsecase;

  Future<void> setNetwork(SpNetwork network) async {
    emit(
      state.applyNetwork(network, getBackendDefaultsUsecase.execute(network)),
    );
  }

  Future<void> fetchRegtestDefaults() async {
    emit(state.startFetching());
    try {
      final defaults = getBackendDefaultsUsecase.execute(SpNetwork.regtest);
      final failure = defaults.failure;
      if (failure != null) {
        emit(state.failFetching(failure));
        return;
      }
      emit(state.applyDefaults(defaults));
    } catch (e) {
      emit(state.failFetching(SpBackendUnreachable('SP defaults fetch: $e')));
    }
  }

  void setBlindbitUrl(String url) =>
      emit(state.applyUrl(BackendKind.blindbit, url));

  void setElectrumUrl(String url) =>
      emit(state.applyUrl(BackendKind.electrum, url));

  Future<void> testBlindbit() => _testBackend(BackendKind.blindbit);

  Future<void> testElectrum() => _testBackend(BackendKind.electrum);

  Future<void> _testBackend(BackendKind kind) async {
    final url = _urlFor(kind);
    if (url.isEmpty) return;
    emit(state.applyConnTest(kind, SpConnTest.testing, null));
    final err = await backendTestUsecase.test(kind, url);
    // Drop the result if the URL changed under us or the cubit closed.
    if (isClosed || _urlFor(kind) != url) return;
    emit(
      state.applyConnTest(
        kind,
        err == null ? SpConnTest.ok : SpConnTest.failed,
        err,
      ),
    );
  }

  String _urlFor(BackendKind kind) =>
      kind == BackendKind.blindbit ? state.blindbitUrl : state.electrumUrl;
}
