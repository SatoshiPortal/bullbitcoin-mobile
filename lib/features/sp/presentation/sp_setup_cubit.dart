import 'package:bb_mobile/features/sp/domain/usecases/check_sp_setup_entry_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resume_sp_setup_usecase.dart';
import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form_mixin.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Thin setup cubit: collects network + backend config, then delegates wallet
/// creation to [CreateSpWalletUsecase] (which gates, clears stale revoked
/// state, derives keys, and creates the on-disk account through the port). The
/// shared backend-config form (network/defaults/URL/tests) lives in
/// [SpBackendFormMixin].
class SpSetupCubit extends Cubit<SpSetupState>
    with SpBackendFormMixin<SpSetupState> {
  final CreateSpWalletUsecase _createSpWalletUsecase;
  final GetSpSecretUsecase _getSpSecretUsecase;
  final ResumeSpSetupUsecase _resumeSpSetupUsecase;
  final CheckSpSetupEntryUsecase _checkSpSetupEntryUsecase;
  final TestSpBackendUsecase _testSpBackendUsecase;
  final GetSpBackendDefaultsUsecase _getSpBackendDefaultsUsecase;

  SpSetupCubit({
    required this._createSpWalletUsecase,
    required this._getSpSecretUsecase,
    required this._resumeSpSetupUsecase,
    required this._checkSpSetupEntryUsecase,
    required this._testSpBackendUsecase,
    required this._getSpBackendDefaultsUsecase,
  }) : super(
         const SpSetupState(form: SpBackendForm(isFetchingDefaults: true)),
       ) {
    unawaited(_inspectEntry());
  }

  Future<void> _inspectEntry() async {
    final result = await _checkSpSetupEntryUsecase.execute();
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(
          state.copyWith(
            isInspecting: false,
            entryFailure: failure,
            form: state.form.copyWith(
              isFetchingDefaults: false,
              error: failure,
            ),
          ),
        );
      case Ok(value: true):
        emit(
          state.copyWith(
            isInspecting: false,
            created: true,
            existingVerified: true,
          ),
        );
      case Ok():
        emit(state.copyWith(isInspecting: false));
        await setNetwork(BitcoinNetwork.mainnet);
    }
  }

  @override
  TestSpBackendUsecase get backendTestUsecase => _testSpBackendUsecase;

  @override
  GetSpBackendDefaultsUsecase get getBackendDefaultsUsecase =>
      _getSpBackendDefaultsUsecase;

  @override
  Future<void> setNetwork(BitcoinNetwork network) async {
    if (state.isInspecting || state.entryFailure != null || state.created) {
      return;
    }
    await super.setNetwork(network);
    await Future.wait([testBlindbit(), testElectrum()]);
  }

  void setScanStart(SpScanStart scanStart) =>
      emit(state.copyWith(scanStart: scanStart));

  Future<
    Result<List<({String id, String label, bool hasPassphrase})>, SpFailure>
  >
  candidates(BitcoinNetwork network) {
    if (state.isInspecting || state.entryFailure != null || state.created) {
      return Future.value(const Err(SpConfigInvalid('SP setup is not ready')));
    }
    return _getSpSecretUsecase.candidates(network);
  }

  /// Explicitly retries only the persisted pending binding.
  Future<void> retryPendingSetup() async {
    if (state.isCreating || state.isInspecting) return;
    if (state.entryFailure is! SpRecoveryRequired &&
        state.error is! SpRecoveryRequired) {
      return;
    }
    emit(
      state.copyWith(isCreating: true, form: state.form.copyWith(error: null)),
    );
    final result = await _resumeSpSetupUsecase.execute();
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(isCreating: false, created: true));
      case Err(:final failure):
        emit(
          state.copyWith(
            isCreating: false,
            entryFailure: failure is SpSessionBusy
                ? const SpRecoveryRequired()
                : failure,
            form: state.form.copyWith(error: failure),
          ),
        );
    }
  }

  Future<void> create(String walletId) async {
    if (!state.canCreate) return;
    emit(
      state.copyWith(isCreating: true, form: state.form.copyWith(error: null)),
    );
    final result = await _createSpWalletUsecase.execute(
      network: state.network,
      walletId: walletId,
      blindbitUrl: state.blindbitUrl,
      electrumUrl: state.electrumUrl,
      scanFromNow: state.scanStart == SpScanStart.fromNow,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        // Wallet creation emits SpSetupChanged on the repository update stream;
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
