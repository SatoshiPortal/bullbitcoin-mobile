import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart';
import 'package:secrets/secrets.dart'
    show UseSecretFailure, WalletRegistrationNotFoundFailure;
import 'package:secrets/storage.dart' show SecretsInventory;

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_content.dart';
import '../domain/entities/backup_inventory.dart';
import '../domain/ports/backup_secrets_port.dart';

/// The Secrets side of a metadata backup, over the foreground inventory.
final class MetadataBackupSecrets implements BackupSecretsPort {
  final SecretsInventory _inventory;

  const MetadataBackupSecrets(this._inventory);

  @override
  Future<Result<String, BackupMetadataFailure>> viewScope() async =>
      switch (await _inventory.backupViewScope()) {
        Ok(:final value) => Ok(value),
        Err() => const Err(BackupMetadataNotReadyFailure()),
      };

  @override
  Future<Result<List<BackupDerivation>, BackupMetadataFailure>> derivations(
    BackupGroup group,
  ) async {
    final parent = group.secretReference;
    if (parent == null) return const Ok([]);
    return switch (await _inventory.listDerivations()) {
      Ok(:final value) => Ok([
        for (final record in value)
          if (record.parentFingerprint == parent)
            BackupDerivation(
              path: record.path,
              application: record.application,
              status: record.status,
              alias: record.alias,
            ),
      ]),
      Err() => const Err(BackupMetadataUnexpectedFailure()),
    };
  }

  @override
  Future<Result<SecretsRestoreReport, BackupMetadataFailure>> restore(
    BackupGroup group,
    BackupContent content,
  ) async {
    // Only the accounts this group already owns on this phone: a backup
    // authenticated for one group never edits another group's wallet.
    final own = {
      for (final wallet in group.wallets)
        (wallet.externalDescriptor, wallet.internalDescriptor),
    };
    final candidates = [
      for (final wallet in content.wallets)
        if (own.contains((
          wallet.externalDescriptor,
          wallet.internalDescriptor,
        )))
          wallet,
    ];
    // Resolve every match before the first write: an ambiguous one is
    // refused as a whole.
    for (final wallet in candidates) {
      final match = await _inventory.matchPublicWallet(
        network: wallet.network,
        external: wallet.externalDescriptor,
        internal: wallet.internalDescriptor,
      );
      if (match case Err(:final failure)
          when failure is! WalletRegistrationNotFoundFailure) {
        return const Err(BackupMetadataIncompatibleFailure());
      }
    }
    var matched = 0;
    var labels = 0;
    var birthdays = 0;
    for (final wallet in candidates) {
      final applied = await _inventory.restorePublicWalletProperties(
        network: wallet.network,
        external: wallet.externalDescriptor,
        internal: wallet.internalDescriptor,
        label: wallet.label,
        birthday: wallet.birthday,
      );
      switch (applied) {
        case Ok(:final value):
          matched++;
          if (value.label) labels++;
          if (value.birthday) birthdays++;
        case Err(failure: WalletRegistrationNotFoundFailure()):
          break;
        case Err():
          return const Err(BackupMetadataUnexpectedFailure());
      }
    }

    var added = 0;
    var updated = 0;
    var refused = false;
    final parent = group.secretReference;
    if (parent != null && content.derivations.isNotEmpty) {
      final fingerprint = Fingerprint.tryParse(parent);
      if (fingerprint == null) {
        return const Err(BackupMetadataUnexpectedFailure());
      }
      final merged = await _inventory.mergeDerivationArchive(
        parent: fingerprint,
        records: [
          for (final record in content.derivations)
            RecordedDerivation(
              path: record.path,
              parentFingerprint: fingerprint.hex,
              application: record.application,
              status: record.status,
              alias: record.alias,
            ),
        ],
      );
      switch (merged) {
        case Ok(:final value):
          added = value.added;
          updated = value.updated;
        case Err(failure: UseSecretFailure()):
          refused = true;
        case Err():
          return const Err(BackupMetadataUnexpectedFailure());
      }
    }
    return Ok(
      SecretsRestoreReport(
        walletsMatched: matched,
        walletsUnmatched: candidates.length - matched,
        walletLabelsApplied: labels,
        walletBirthdaysApplied: birthdays,
        derivationsAdded: added,
        derivationsUpdated: updated,
        derivationsRefused: refused,
      ),
    );
  }
}
