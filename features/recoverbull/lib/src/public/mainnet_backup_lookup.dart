import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../data/database/recoverbull_wallet_backups.dart';
import '../domain/entities/vault_context.dart';
import '../domain/recoverbull_failure.dart';
import 'recoverbull_facade.dart';

/// Checks RecoverBull's backup evidence for the visible mainnet Bitcoin default.
final class MainnetBackupLookup {
  final WalletInventory _inventory;
  final RecoverBullWalletBackups _backups;
  final RecoverBullFacade Function() _recoverBull;

  const MainnetBackupLookup(this._inventory, this._backups, this._recoverBull);

  Future<Result<bool, RecoverBullFailure>> hasEncryptedBackup() async {
    const network = BitcoinNetwork.mainnet;
    final read = await _inventory.walletsForNetwork(network);
    if (read is! Ok<WalletSelection, SecretFailure> || !read.value.isComplete) {
      return const Err(VaultStorageFailure());
    }
    final wallet = read.value.defaults.firstOrNull;
    if (wallet == null) return const Ok(false);
    final fingerprint = wallet.masterFingerprint;
    if (fingerprint == null) return const Err(VaultStorageFailure());
    final stored = await _backups.read(wallet.id);
    if (stored case Err(:final failure)) return Err(failure);
    final hasRecordedBackup = stored.fold(
      (backup) => backup?.latestEncryptedBackup != null,
      (_) => false,
    );
    final status = await _recoverBull().status(
      VaultContext(fingerprint: fingerprint, network: network),
    );
    return Ok(
      status.fold(
        (backup) =>
            backup.storedAt != null ||
            backup.verifiedAt != null ||
            hasRecordedBackup,
        (_) => hasRecordedBackup,
      ),
    );
  }
}
