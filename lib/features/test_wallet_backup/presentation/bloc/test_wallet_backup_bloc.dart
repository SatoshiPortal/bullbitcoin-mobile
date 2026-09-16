import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
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
  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;
  final LoadWalletsForNetworkUsecase _loadWalletsForNetworkUsecase;
  final GetSecretFromFingerprintUsecase _getSecretFromFingerprintUsecase;

  TestWalletBackupBloc({
    required this._completePhysicalBackupVerificationUsecase,
    required this._loadWalletsForNetworkUsecase,
    required this._getSecretFromFingerprintUsecase,
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

  /// The selected wallet's secret handle, for the sealed displays.
  ///
  /// A handle carries a description and a reference, never material — so
  /// unlike the words it used to return, this is safe to await in a widget
  /// and hand to `MnemonicView` or `MnemonicChallenge`. It is still not put
  /// in bloc state: the freezed `toString()` has no business naming a
  /// secret at all.
  Future<Secret> loadSelectedWalletSecret() {
    final wallet = state.selectedWallet;
    if (wallet == null) {
      throw Exception('No wallet selected');
    }
    return _getSecretFromFingerprintUsecase.execute(wallet.masterFingerprint);
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

  /// Records a backup the user has just re-entered correctly.
  ///
  /// The comparison itself happened in `MnemonicChallenge`, through
  /// `Secret.verifyWords` — inside the package, on words this layer never
  /// saw. What is left here is the bookkeeping.
  Future<void> _verifyPhysicalBackup(
    VerifyPhysicalBackup event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      if (state.selectedWallet == null) {
        emit(state.copyWith(statusError: 'No wallet selected'));
        return;
      }
      await _completePhysicalBackupVerificationUsecase.execute();
      emit(
        state.copyWith(
          verificationStatus: BackupVerificationStatus.success,
          statusError: '',
        ),
      );
    } catch (e) {
      emit(state.copyWith(statusError: 'Verification failed: $e'));
    }
  }
}
