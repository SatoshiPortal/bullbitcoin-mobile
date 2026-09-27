import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:secrets/secrets.dart' show Secret;
import 'package:flutter_bloc/flutter_bloc.dart';
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
  /// secret at all. A failure is typed so the caller can translate it; the
  /// reason stayed in the logs at the use-case boundary.
  Future<Result<Secret, TestWalletBackupFailure>>
  loadSelectedWalletSecret() async {
    final wallet = state.selectedWallet;
    if (wallet == null) {
      return const Err(TestWalletBackupNoWalletSelectedFailure());
    }
    return _getSecretFromFingerprintUsecase.execute(wallet.masterFingerprint);
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

  /// Records a backup the user has just re-entered correctly.
  ///
  /// The comparison itself happened in `MnemonicChallenge`, through
  /// `secret.verify.mnemonic` — inside the package, on words this layer never
  /// saw. What is left here is the bookkeeping.
  Future<void> _verifyPhysicalBackup(
    VerifyPhysicalBackup event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    if (state.selectedWallet == null) {
      emit(
        state.copyWith(
          failure: const TestWalletBackupNoWalletSelectedFailure(),
        ),
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
