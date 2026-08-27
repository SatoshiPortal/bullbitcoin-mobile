import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
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
  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;
  final LoadWalletsForNetworkUsecase _loadWalletsForNetworkUsecase;
  final GetMnemonicFromFingerprintUsecase _getMnemonicFromFingerprintUsecase;
  final VerifyPhysicalBackupUsecase _verifyPhysicalBackupUsecase;

  TestWalletBackupBloc({
    required this._completePhysicalBackupVerificationUsecase,
    required this._loadWalletsForNetworkUsecase,
    required this._getMnemonicFromFingerprintUsecase,
    required this._verifyPhysicalBackupUsecase,
  }) : super(const TestWalletBackupState()) {
    on<LoadWallets>(_onLoadWallets);
    on<WalletSelected>(_onWalletSelected);
    on<VerifyPhysicalBackup>(_verifyPhysicalBackup);
    on<ClearError>(
      (event, emit) => emit(
        state.copyWith(
          statusError: '',
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
  Future<(List<String>, String?)> loadSelectedWalletMnemonic() {
    final wallet = state.selectedWallet;
    if (wallet == null) {
      throw Exception('No wallet selected');
    }
    return _getMnemonicFromFingerprintUsecase.execute(wallet.masterFingerprint);
  }

  Future<void> _onLoadWallets(
    LoadWallets event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      final wallets = await _loadWalletsForNetworkUsecase.execute();
      if (wallets.isEmpty) throw Exception('No wallets found');
      final Wallet selected = wallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => wallets.first,
      );
      emit(
        state.copyWith(
          wallets: wallets,
          selectedWallet: selected,
          verificationStatus: BackupVerificationStatus.idle,
        ),
      );
    } catch (e) {
      emit(state.copyWith(statusError: 'Failed to load wallets: $e'));
    }
  }

  Future<void> _onWalletSelected(
    WalletSelected event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedWallet: event.wallet,
        statusError: '',
        verificationStatus: BackupVerificationStatus.idle,
      ),
    );
  }

  Future<void> _verifyPhysicalBackup(
    VerifyPhysicalBackup event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      final wallet = state.selectedWallet;
      if (wallet == null) {
        emit(state.copyWith(statusError: 'No wallet selected'));
        return;
      }

      final isCorrect = await _verifyPhysicalBackupUsecase.execute(
        fingerprint: wallet.masterFingerprint,
        mnemonic: event.reorderedWords,
      );

      if (isCorrect) {
        await _completePhysicalBackupVerificationUsecase.execute();
        emit(
          state.copyWith(
            verificationStatus: BackupVerificationStatus.success,
            statusError: '',
          ),
        );
      } else {
        emit(
          state.copyWith(verificationStatus: BackupVerificationStatus.failure),
        );
      }
    } catch (e) {
      emit(state.copyWith(statusError: 'Verification failed: $e'));
    }
  }
}
