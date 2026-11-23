import 'package:silent/src/domain/usecases/get_sp_active_network_usecase.dart';

import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:silent/src/domain/usecases/test_sp_backend_usecase.dart';
import 'package:silent/src/presentation/sp_backend_form.dart';
import 'package:silent/src/presentation/sp_backend_form_mixin.dart';
import 'package:silent/src/presentation/sp_setup_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Thin setup cubit: collects network + backend config, then delegates wallet
/// creation to [CreateSpWalletUsecase] (which gates, clears stale revoked
/// state, derives keys, and creates the on-disk account through the port). The
/// shared backend-config form (network/defaults/URL/tests) lives in
/// [SpBackendFormMixin].
class SpSetupCubit extends Cubit<SpSetupState>
    with SpBackendFormMixin<SpSetupState> {
  final GetSpActiveNetworkUsecase _getSpActiveNetworkUsecase;
  final CreateSpWalletUsecase _createSpWalletUsecase;
  final TestSpBackendUsecase _testSpBackendUsecase;
  final GetSpBackendDefaultsUsecase _getSpBackendDefaultsUsecase;

  SpSetupCubit({
    required this._getSpActiveNetworkUsecase,
    required this._createSpWalletUsecase,
    required this._testSpBackendUsecase,
    required this._getSpBackendDefaultsUsecase,
  }) : super(
         const SpSetupState(form: SpBackendForm(isFetchingDefaults: true)),
       ) {
    // Defaults may come from infra over FFI; fetch them off the UI
    // isolate once the cubit exists instead of blocking construction.
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final result = await _getSpActiveNetworkUsecase.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        await setNetwork(value);
      case Err(:final failure):
        emit(
          state.copyWith(
            form: state.form.copyWith(
              isFetchingDefaults: false,
              error: failure,
            ),
          ),
        );
    }
  }

  @override
  TestSpBackendUsecase get backendTestUsecase => _testSpBackendUsecase;

  @override
  GetSpBackendDefaultsUsecase get getBackendDefaultsUsecase =>
      _getSpBackendDefaultsUsecase;

  @override
  Future<void> setNetwork(BitcoinNetwork network) async {
    await super.setNetwork(network);
    await Future.wait([testBlindbit(), testElectrum()]);
  }

  void setScanStart(SpScanStart scanStart) =>
      emit(state.copyWith(scanStart: scanStart));

  Future<void> create() async {
    if (!state.canCreate) return;
    emit(
      state.copyWith(isCreating: true, form: state.form.copyWith(error: null)),
    );
    final result = await _createSpWalletUsecase.execute(
      network: state.network,
      blindbitUrl: state.blindbitUrl,
      electrumUrl: state.electrumUrl,
      scanFromNow: state.scanStart == SpScanStart.fromNow,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        // Wallet creation emits SilentSetupChanged on the repository update stream;
        // the wallet feature observes it and reloads. SP does not push to the
        // wallet bloc.
        emit(state.copyWith(isCreating: false, created: true));
      case Err(:final failure):
        emit(
          state.copyWith(
            isCreating: false,
            form: state.form.copyWith(error: failure),
          ),
        );
    }
  }
}
