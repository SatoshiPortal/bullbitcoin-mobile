import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form_state.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Backend-config form behaviour shared by `SpSetupCubit` and `SpSettingsCubit`:
/// network selection, fetching defaults, URL edits, and the connection tests.
/// It drives the embedded [SpBackendForm] transitions and emits the result
/// through each state's `withForm`; state-specific extras stay in each cubit.
mixin SpBackendFormCubit<S extends SpBackendFormState<S>> on Cubit<S> {
  TestSpBackendUsecase get backendTestUsecase;
  GetSpBackendDefaultsUsecase get getBackendDefaultsUsecase;

  Future<void> setNetwork(SpNetwork network) async {
    emit(state.withForm(state.form.applyNetwork(network)));
    await _landDefaults(network);
  }

  Future<void> fetchRegtestDefaults() async {
    emit(state.withForm(state.form.startFetching()));
    await _landDefaults(SpNetwork.regtest);
  }

  /// Await the async defaults fetch and land it via the shared transitions. A
  /// URL the user edited while the fetch was in flight is kept, so a slow fetch
  /// resolving late does not overwrite typed input.
  Future<void> _landDefaults(SpNetwork network) async {
    final blindbitAtStart = state.form.blindbitUrl;
    final electrumAtStart = state.form.electrumUrl;
    final result = await getBackendDefaultsUsecase.execute(network);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.withForm(
            state.form.applyDefaults(
              value,
              keepBlindbit: state.form.blindbitUrl != blindbitAtStart,
              keepElectrum: state.form.electrumUrl != electrumAtStart,
            ),
          ),
        );
      case Err(:final failure):
        emit(state.withForm(state.form.failFetching(failure)));
    }
  }

  void setBlindbitUrl(String url) =>
      emit(state.withForm(state.form.applyUrl(SpBackendKind.blindbit, url)));

  void setElectrumUrl(String url) =>
      emit(state.withForm(state.form.applyUrl(SpBackendKind.electrum, url)));

  Future<void> testBlindbit() => _testBackend(SpBackendKind.blindbit);

  Future<void> testElectrum() => _testBackend(SpBackendKind.electrum);

  Future<void> _testBackend(SpBackendKind kind) async {
    final url = state.form.urlFor(kind);
    if (url.isEmpty) return;
    emit(
      state.withForm(state.form.applyConnTest(kind, SpConnTest.testing, null)),
    );
    final err = await backendTestUsecase.execute(kind, url);
    // Drop the result if the URL changed under us or the cubit closed.
    if (isClosed || state.form.urlFor(kind) != url) return;
    emit(
      state.withForm(
        state.form.applyConnTest(
          kind,
          err == null ? SpConnTest.ok : SpConnTest.failed,
          err,
        ),
      ),
    );
  }
}
