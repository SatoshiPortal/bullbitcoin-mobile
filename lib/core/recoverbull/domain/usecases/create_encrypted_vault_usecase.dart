import 'package:secrets/secrets.dart' as secrets;
import 'package:primitives/primitives.dart' show Fingerprint;

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateEncryptedVaultUsecase {
  final secrets.Secrets _secrets;
  final WalletRepository _walletRepository;

  CreateEncryptedVaultUsecase({
    required this._secrets,
    required this._walletRepository,
  });

  // Orchestrates wallet + seed (still-throwing core repos) and the recoverbull
  // repo. The local try/catch is the boundary for the wallet/seed calls; the
  // recoverbull repo already returns a Result that we forward.
  /// [passphraseExcluded] is the package's `WordsOnly` verdict: the wallet
  /// has a passphrase and the vault format has no field for it, so this
  /// file alone restores a different wallet. The user must keep the
  /// passphrase with the backup — `Secrets.restoreVault` takes it back.
  Future<
    Result<
      ({EncryptedVault vault, String vaultKey, bool passphraseExcluded}),
      RecoverBullCoreFailure
    >
  >
  execute() async {
    try {
      final defaultBitcoinWallets = await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
      );

      if (defaultBitcoinWallets.isEmpty) {
        return const Err(
          RecoverBullUnexpectedCoreFailure('No default Bitcoin wallet found'),
        );
      }

      // The default wallet is used to derive the backup key
      final defaultWallet = defaultBitcoinWallets.first;
      await _walletRepository.updateEncryptedBackupTime(
        time: DateTime.now(),
        walletId: defaultWallet.id,
      );
      final secret = switch (await _secrets.fetch(
        Fingerprint(defaultWallet.masterFingerprint),
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };
      if (!secret.info.isMnemonic) {
        return const Err(
          RecoverBullUnexpectedCoreFailure(
            'Default seed is not a mnemonic seed',
          ),
        );
      }
      // The plaintext keeps exactly the keys and encodings `DecryptedVault.toJson` has always written — built from the same type, minus the words, which the package writes itself. Every existing vault and the key server read this shape.
      final metadata = DecryptedVault(
        mnemonic: const [],
        masterFingerprint: defaultWallet.masterFingerprint,
        isEncryptedVaultTested: defaultWallet.isEncryptedVaultTested,
        isPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
        latestEncryptedBackup: defaultWallet.latestEncryptedBackup,
        latestPhysicalBackup: defaultWallet.latestPhysicalBackup,
      ).toJson()..remove('mnemonic');
      final scope = switch (await secret.backup.vault(metadata: metadata)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };
      final passphraseExcluded = scope is secrets.WordsOnly;
      if (passphraseExcluded) {
        log.warning(
          'VAULT_WORDS_ONLY: vault for ${defaultWallet.masterFingerprint} '
          'carries the words alone; the passphrase is not in the file',
        );
      }
      return Ok((
        vault: EncryptedVault(file: scope.value.file),
        vaultKey: scope.value.key,
        passphraseExcluded: passphraseExcluded,
      ));
    } catch (e, st) {
      log.severe(message: 'createEncryptedVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
