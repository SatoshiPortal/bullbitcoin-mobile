import 'package:bb_mobile/core/recoverbull/domain/entity/bull_backup.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/errors.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/presentation/state.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullVaultRecoveryCubit
    extends Cubit<RecoverBullVaultRecoveryState> {
  final EncryptedVault _backup;
  final String _backupKey;

  final DecryptVaultUsecase _decryptVaultUsecase;
  final RestoreVaultUsecase _restoreVaultUsecase;
  final TheDirtyUsecase _checkWalletStatusUsecase;

  RecoverBullVaultRecoveryCubit({
    required EncryptedVault backup,
    required String backupKey,
    required TheDirtyUsecase checkWalletStatusUsecase,
    required DecryptVaultUsecase decryptVaultUsecase,
    required RestoreVaultUsecase restoreVaultUsecase,
  }) : _checkWalletStatusUsecase = checkWalletStatusUsecase,
       _backup = backup,
       _backupKey = backupKey,
       _decryptVaultUsecase = decryptVaultUsecase,
       _restoreVaultUsecase = restoreVaultUsecase,
       super(const RecoverBullVaultRecoveryState()) {
    extractMnemonic();
    checkWalletStatus();
  }

  void extractMnemonic() {
    try {
      final decryptedVault = _decryptVaultUsecase.execute(
        backupFile: _backup,
        backupKey: _backupKey,
      );
      emit(state.copyWith(decryptedVault: decryptedVault));
    } catch (e) {
      emit(state.copyWith(error: RecoverBullVaultRecoveryError(e.toString())));
    }
  }

  Future<void> checkWalletStatus() async {
    if (state.decryptedVault == null) return;

    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: state.decryptedVault!.mnemonic,
        language: bip39.Language.english,
        passphrase: '',
      );

      final bip84Status = await _checkWalletStatusUsecase(
        mnemonic,
        ScriptType.bip84,
      );

      emit(state.copyWith(bip84Status: bip84Status));
    } catch (e) {
      emit(state.copyWith(error: RecoverBullVaultRecoveryError(e.toString())));
    }
  }

  Future<void> importWallet() async {
    if (state.decryptedVault == null || state.isImported) return;

    try {
      await _restoreVaultUsecase.execute(decryptedVault: state.decryptedVault!);
      emit(state.copyWith(isImported: true));
    } catch (e) {
      emit(state.copyWith(error: RecoverBullVaultRecoveryError(e.toString())));
    }
  }
}
