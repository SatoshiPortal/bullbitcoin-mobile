import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart'
    as core;
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/utils/recoverbull_bip85.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

/// Reads existing seeds only. No server, wallet creation or backup-status writes.
class DeriveVaultKeyUsecase {
  final PickVaultUsecase _pickVault;
  final GetAllSeedsUsecase _seeds;
  final RecoverBullRepository _recoverBull;

  DeriveVaultKeyUsecase(this._pickVault, this._seeds, this._recoverBull);

  Future<Result<String, RecoverBullFailure>> execute() async {
    final EncryptedVault vault;
    switch (await _pickVault.execute()) {
      case Ok(:final value):
        vault = value;
      case Err(failure: core.InvalidVaultFileFailure()):
        return const Err(InvalidVaultFileFormatFailure());
      case Err():
        return const Err(SelectVaultFailure());
    }
    final String path;
    try {
      path = vault.derivationPath;
    } on EncryptedVaultMissingPath {
      return const Err(VaultKeyPathUnavailableFailure());
    }
    // Retain the recorded index's hardening: legacy files can be unhardened.
    final match = RegExp(r"^(?:m/)?1608'/0'/([0-9]{1,10})'?$").firstMatch(path);
    if (match == null ||
        match.end != path.length ||
        int.parse(match.group(1)!) >= 1 << 31) {
      return const Err(VaultKeyPathUnavailableFailure());
    }

    final seeds = await _seeds.execute();
    switch (seeds) {
      case Err():
        return const Err(VaultSeedUnavailableFailure());
      case Ok(:final value):
        if (value.isEmpty) return const Err(VaultSeedUnavailableFailure());
        for (final seed in value) {
          try {
            final key = RecoverbullBip85Utils.deriveBackupKey(
              Bip32Keys.fromSeed(seed.bytes).toBase58(),
              path,
            );
            switch (_recoverBull.restoreVault(vault: vault, vaultKey: key)) {
              case Ok(value: final decrypted):
                // A generic RecoverBull envelope is not necessarily a money
                // backup. Verify its payload as well as authenticated decryption.
                Mnemonic.fromWords(words: decrypted.mnemonic);
                return Ok(key);
              case Err():
                continue;
            }
          } on Exception {
            // Third-party parsing errors can contain private input. Do not log
            // or attach them to a failure, even when another seed is tried next.
            continue;
          }
        }
        return const Err(VaultLocalKeyMismatchFailure());
    }
  }
}
