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

  /// What this vault has agreed to publish where, and how far each got.
  @useResult
  Future<Result<List<VaultDescriptorPublication>, BackupSettingsFailure>> load(
    String walletId,
  ) async => switch (await _vaults.descriptorPublications(walletId)) {
    Err() => const Err(BackupSettingsStorageFailure()),
    Ok(:final value) => Ok(value),
  };

  /// Records the person's choice of one destination and returns the new rows.
  ///
  /// Turning a destination off never deletes what was already sent to it: the
  /// artifact stays, so a later check can still say honestly what is out there.
  @useResult
  Future<Result<List<VaultDescriptorPublication>, BackupSettingsFailure>>
  setDestination({
    required String walletId,
    required VaultBackupDestination destination,
    required bool enabled,
  }) async {
    if (await _vaults.setDescriptorBackupDestination(
          walletId: walletId,
          destination: destination,
          enabled: enabled,
        )
        case Err()) {
      return const Err(BackupSettingsStorageFailure());
    }
    return load(walletId);
  }

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

  /// The relay publisher writes the outcome of a send down itself, because it
  /// is the only thing that knows which relays answered; recording a refusal
  /// here as well would count one send twice. What it cannot record is giving
  /// up before it asked any relay, so that failure is recorded here: a row
  /// left idle would read as a publication still to come and offer no retry.
  Future<void> _toNostr(String walletId) async {
    if (await _vaults.publishDescriptorToNostr(walletId) case Err(
      :final failure,
    ) when failure is! BullVaultNostrUnreachableFailure) {
      await _record(walletId, VaultBackupDestination.nostr, accepted: false);
    }
  }

  Future<void> _toServer(String walletId) async {
    final BullVaultDescriptorBackup prepared;
    switch (await _vaults.prepareServerDescriptorBackup(walletId)) {
      case Err():
        // The artifact could not even be built. Recording that failure is what
        // makes the destination retryable; the retry seals it.
        await _record(walletId, VaultBackupDestination.server, accepted: false);
        return;
      case Ok(:final value):
        prepared = value;
    }
    final stored = await _server.publishPrivateDescriptor(
      walletId,
      prepared: prepared,
    );
    await _record(
      walletId,
      VaultBackupDestination.server,
      accepted: stored is Ok<DateTime, WalletBackupFailure>,
    );
  }

  Future<void> _record(
    String walletId,
    VaultBackupDestination destination, {
    required bool accepted,
  }) async {
    final recorded = await _vaults.recordDescriptorPublicationSent(
      walletId: walletId,
      destination: destination,
      accepted: accepted,
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
