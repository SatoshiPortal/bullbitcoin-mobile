import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Thin setup cubit: collects network + backend config, then delegates wallet
/// creation to [CreateSpWalletUsecase] (which gates, clears stale revoked
/// state, derives keys, and creates the on-disk account through the port). The
/// shared backend-config form (network/defaults/URL/tests) lives in
/// [SpBackendFormCubit].
class SpSetupCubit extends Cubit<SpSetupState>
    with SpBackendFormCubit<SpSetupState> {
  final CreateSpWalletUsecase _createSpWalletUsecase;
  final TestSpBackendUsecase _testSpBackendUsecase;
  final GetSpBackendDefaultsUsecase _getSpBackendDefaultsUsecase;

  SpSetupCubit({
    required this._createSpWalletUsecase,
    required this._testSpBackendUsecase,
    required this._getSpBackendDefaultsUsecase,
  }) : super(const SpSetupState(isFetchingDefaults: true)) {
    // Regtest defaults come from the infra over FFI; fetch them off the UI
    // isolate once the cubit exists instead of blocking construction.
    unawaited(setNetwork(SpNetwork.regtest));
  }

  @override
  TestSpBackendUsecase get backendTestUsecase => _testSpBackendUsecase;

  @override
  GetSpBackendDefaultsUsecase get getBackendDefaultsUsecase =>
      _getSpBackendDefaultsUsecase;

  Future<void> create() async {
    if (!state.canCreate) return;
    emit(state.copyWith(isCreating: true, error: null));
    final result = await _createSpWalletUsecase.execute(
      network: state.network,
      blindbitUrl: state.blindbitUrl,
      electrumUrl: state.electrumUrl,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        // Wallet creation emits SpSetupChanged on the repository update stream;
        // the wallet feature observes it and reloads. SP does not push to the
        // wallet bloc.
        emit(state.copyWith(isCreating: false, created: true));
      case Err(:final failure):
        emit(state.copyWith(isCreating: false, error: failure));
    }
  }
}
