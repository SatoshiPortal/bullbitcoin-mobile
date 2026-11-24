import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:backups/src/domain/backup_wallet.dart';
import 'package:backups/src/domain/test_wallet_backup_failure.dart';
import 'package:backups/src/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:backups/src/domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'package:backups/src/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:physical_backup_verification/physical_backup_verification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:secrets/secrets.dart' show Secret;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_wallet_backup_bloc.freezed.dart';
part 'test_wallet_backup_event.dart';
part 'test_wallet_backup_state.dart';

class TestWalletBackupBloc
    extends Bloc<TestWalletBackupEvent, TestWalletBackupState> {
  final CompleteBackupVerificationUsecase _completeBackupVerificationUsecase;
  final LoadWalletsForNetworkUsecase _loadWalletsForNetworkUsecase;
  final GetSecretFromFingerprintUsecase _getSecretFromFingerprintUsecase;

  TestWalletBackupBloc({
    required this._completeBackupVerificationUsecase,
    required this._loadWalletsForNetworkUsecase,
    required this._getSecretFromFingerprintUsecase,
  }) : super(const TestWalletBackupState()) {
    on<LoadWallets>(_onLoadWallets);
    on<WalletSelected>(_onWalletSelected);
    on<VerifyPhysicalBackup>(_verifyPhysicalBackup);
    on<ClearFailure>(
      (event, emit) => emit(
        state.copyWith(
          failure: null,
          verificationStatus: BackupVerificationStatus.idle,
        ),
      ),
    );
  }

  /// The selected wallet's secret handle, for the sealed displays.
  ///
  /// A handle carries a description and a reference, never material — so
  /// unlike the words it used to return, this is safe to await in a widget
  /// and hand to `MnemonicView` or `MnemonicChallenge`. It is still not put
  /// in bloc state: the freezed `toString()` has no business naming a
  /// secret at all. A failure is typed so the caller can translate it.
  Future<Result<Secret, TestWalletBackupFailure>>
  loadSelectedWalletSecret() async {
    final wallet = state.selectedWallet;
    if (wallet == null) {
      return const Err(TestWalletBackupNoWalletSelectedFailure());
    }
    final fingerprint = wallet.fingerprint;
    if (fingerprint == null) {
      return const Err(TestWalletBackupSeedUnavailableFailure());
    }
    return _getSecretFromFingerprintUsecase.execute(fingerprint.hex);
  }

  Future<void> _onLoadWallets(
    LoadWallets event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    switch (await _loadWalletsForNetworkUsecase.execute()) {
      case Ok(:final value):
        // The use-case rejects an empty list, so first/firstWhere are safe.
        final BackupWallet selected = value.firstWhere(
          (w) => w.isDefault,
          orElse: () => value.first,
        );
        emit(
          state.copyWith(
            wallets: value,
            selectedWallet: selected,
            failure: null,
            verificationStatus: BackupVerificationStatus.idle,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> _onWalletSelected(
    WalletSelected event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedWallet: event.wallet,
        failure: null,
        verificationStatus: BackupVerificationStatus.idle,
      ),
    );
  }

  /// Records a backup the user has just re-entered correctly.
  ///
  /// Secrets checked the words and any passphrase. Backups owns bookkeeping.
  Future<void> _verifyPhysicalBackup(
    VerifyPhysicalBackup event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    final wallet = state.selectedWallet;
    if (wallet == null) {
      emit(
        state.copyWith(
          failure: const TestWalletBackupNoWalletSelectedFailure(),
        ),
      );
      return;
    }
    if (wallet.fingerprint != event.proof.fingerprint) return;

    final result = await _completeBackupVerificationUsecase.execute(
      wallet,
      event.proof,
    );
    if (state.selectedWallet != wallet) return;
    if (result case Err(:final failure)) {
      emit(state.copyWith(failure: failure));
      return;
    }
    emit(
      state.copyWith(
        verificationStatus: BackupVerificationStatus.success,
        failure: null,
      ),
    );
  }
}
