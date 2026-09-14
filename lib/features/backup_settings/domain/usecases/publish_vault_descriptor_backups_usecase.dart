import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Sends each selected destination the descriptor artifact it is owed.
///
/// This is where the two destinations meet: the vault feature owns the bytes
/// and the relay route, the backup feature owns the server transport, and
/// neither imports the other. Nothing here is scheduled — a retry happens when
/// someone asks for one.
final class PublishVaultDescriptorBackupsUsecase {
  final BullVaultFacade _vaults;
  final WalletBackupFacade _server;

  const PublishVaultDescriptorBackupsUsecase(this._vaults, this._server);

  /// Publishes to every destination this vault has selected.
  @useResult
  Future<Result<List<VaultDescriptorPublication>, BackupSettingsFailure>>
  execute(String walletId) => _publish(walletId, outstandingOnly: false);

  /// Resends the stored artifact to the destinations that never acknowledged
  /// it. Nothing is sealed again, so a retry cannot create a second record or
  /// a second event for a descriptor that already has one.
  @useResult
  Future<Result<List<VaultDescriptorPublication>, BackupSettingsFailure>>
  retryPendingPublications(String walletId) =>
      _publish(walletId, outstandingOnly: true);

  Future<Result<List<VaultDescriptorPublication>, BackupSettingsFailure>>
  _publish(String walletId, {required bool outstandingOnly}) async {
    final List<VaultDescriptorPublication> rows;
    switch (await _vaults.descriptorPublications(walletId)) {
      case Err():
        return const Err(BackupSettingsStorageFailure());
      case Ok(:final value):
        rows = value;
    }
    for (final row in rows) {
      if (!row.enabled) continue;
      if (outstandingOnly && !row.outstanding) continue;
      await switch (row.destination) {
        VaultBackupDestination.nostr => _toNostr(walletId),
        VaultBackupDestination.server => _toServer(walletId),
      };
    }
    return switch (await _vaults.descriptorPublications(walletId)) {
      Err() => const Err(BackupSettingsStorageFailure()),
      Ok(:final value) => Ok(value),
    };
  }

  /// The relay publisher writes its own outcome down, because it is the only
  /// thing that knows which relays answered.
  Future<void> _toNostr(String walletId) =>
      _vaults.publishDescriptorToNostr(walletId);

  Future<void> _toServer(String walletId) async {
    final BullVaultDescriptorBackup prepared;
    switch (await _vaults.prepareServerDescriptorBackup(walletId)) {
      case Err():
        // The artifact could not even be built, so there was no attempt to
        // record against the destination.
        return;
      case Ok(:final value):
        prepared = value;
    }
    final stored = await _server.publishPrivateDescriptor(
      walletId,
      prepared: prepared,
    );
    final recorded = await _vaults.recordDescriptorPublicationSent(
      walletId: walletId,
      destination: VaultBackupDestination.server,
      accepted: stored is Ok<DateTime, WalletBackupFailure>,
    );
    if (recorded case Err(:final failure)) {
      // The outcome is lost, not the artifact: the row stays pending and the
      // next retry resends the same bytes to the same immutable record.
      log.warning(
        'Descriptor publication outcome not recorded',
        error: failure.runtimeType,
      );
    }
  }
}
