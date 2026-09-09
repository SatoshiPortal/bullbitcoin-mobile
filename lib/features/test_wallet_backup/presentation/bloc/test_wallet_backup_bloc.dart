import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_physical_backup_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_wallet_backup_bloc.freezed.dart';
part 'test_wallet_backup_event.dart';
part 'test_wallet_backup_state.dart';

class TestWalletBackupBloc
    extends Bloc<TestWalletBackupEvent, TestWalletBackupState> {
  final CompleteBackupVerificationUsecase _completeBackupVerificationUsecase;
  final LoadWalletsForNetworkUsecase _loadWalletsForNetworkUsecase;
  final GetMnemonicFromFingerprintUsecase _getMnemonicFromFingerprintUsecase;
  final VerifyPhysicalBackupUsecase _verifyPhysicalBackupUsecase;

  TestWalletBackupBloc({
    required this._completeBackupVerificationUsecase,
    required this._loadWalletsForNetworkUsecase,
    required this._getMnemonicFromFingerprintUsecase,
    required this._verifyPhysicalBackupUsecase,
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

  /// Reads the selected wallet's secret at the point of use.
  ///
  /// The mnemonic and passphrase are returned directly to the caller and are
  /// never held in bloc state: secrets must stay ephemeral and must never
  /// appear in the freezed `toString()` of the state.
  /// Returns a [Result] rather than storing the outcome in state, because
  /// the success value IS the secret. A failure is typed so the caller can
  /// translate it; the raw reason stayed in the logs at the use-case
  /// boundary.
  Future<Result<(List<String>, String?), TestWalletBackupFailure>>
  loadSelectedWalletMnemonic() async {
    final wallet = state.selectedWallet;
    if (wallet == null) {
      return const Err(TestWalletBackupNoWalletSelectedFailure());
    }
    return _getMnemonicFromFingerprintUsecase.execute(wallet.masterFingerprint);
  }

  Future<void> _onLoadWallets(
    LoadWallets event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    switch (await _loadWalletsForNetworkUsecase.execute()) {
      case Ok(:final value):
        // The use-case rejects an empty list, so first/firstWhere are safe.
        final Wallet selected = value.firstWhere(
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

    final bool isCorrect;
    switch (await _verifyPhysicalBackupUsecase.execute(
      fingerprint: wallet.masterFingerprint,
      mnemonic: event.reorderedWords,
    )) {
      case Ok(:final value):
        isCorrect = value;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return;
    }

    if (!isCorrect) {
      // A wrong answer is an outcome of the test, not a failure: it has its
      // own status and its own screen, and must not surface an error.
      emit(
        state.copyWith(verificationStatus: BackupVerificationStatus.failure),
      );
      return;
    }

    if (await _completeBackupVerificationUsecase.execute() case Err(
      :final failure,
    )) {
      // The words were right but recording it failed. Reported rather than
      // swallowed: the flow would otherwise claim success while the wallet
      // still shows its backup as untested.
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
