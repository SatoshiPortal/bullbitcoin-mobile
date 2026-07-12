import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';
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

  /// Select a network and enter the "fetching defaults" state, clearing the
  /// old URLs and tests. The fetched defaults land later via [applyDefaults].
  S applyNetwork(SpNetwork network);

  /// Fill both URLs from fetched defaults and reset the connection tests.
  S applyDefaults(SpBackendDefaults defaults);

  /// Set one backend URL and reset that backend's connection test.
  S applyUrl(SpBackendKind kind, String url);

  /// Record a connection-test outcome for one backend.
  S applyConnTest(SpBackendKind kind, SpConnTest test, SpFailure? error);

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
    emit(state.applyNetwork(network));
    await _landDefaults(network);
  }

  Future<void> fetchRegtestDefaults() async {
    emit(state.startFetching());
    await _landDefaults(SpNetwork.regtest);
  }

  /// Await the async defaults fetch and land it via the shared transitions.
  Future<void> _landDefaults(SpNetwork network) async {
    final result = await getBackendDefaultsUsecase.execute(network);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.applyDefaults(value));
      case Err(:final failure):
        emit(state.failFetching(failure));
    }
  }

  void setBlindbitUrl(String url) =>
      emit(state.applyUrl(SpBackendKind.blindbit, url));

  void setElectrumUrl(String url) =>
      emit(state.applyUrl(SpBackendKind.electrum, url));

  Future<void> testBlindbit() => _testBackend(SpBackendKind.blindbit);

  Future<void> testElectrum() => _testBackend(SpBackendKind.electrum);

  Future<void> _testBackend(SpBackendKind kind) async {
    final url = _urlFor(kind);
    if (url.isEmpty) return;
    emit(state.applyConnTest(kind, SpConnTest.testing, null));
    final err = await backendTestUsecase.execute(kind, url);
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

  String _urlFor(SpBackendKind kind) =>
      kind == SpBackendKind.blindbit ? state.blindbitUrl : state.electrumUrl;
}
