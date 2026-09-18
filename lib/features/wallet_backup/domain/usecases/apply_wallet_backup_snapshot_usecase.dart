import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

/// The common apply path. Server/file entry points hold the operation queue;
/// every owner mutation below is protected by the durable recovery fence.
final class ApplyWalletBackupSnapshotUsecase {
  final WalletBackupStateRepository _state;
  final WalletBackupCodecRepository _codec;
  final KeychainManifestFacade _catalog;
  final WalletInventoryBackupRepository _wallets;
  final BullVaultBackupRepository _vaults;
  final WalletMetadataBackupRepository _metadata;

  const ApplyWalletBackupSnapshotUsecase({
    required this._state,
    required this._codec,
    required this._catalog,
    required this._wallets,
    required this._vaults,
    required this._metadata,
  });

  @useResult
  Future<Result<WalletBackupRecovery, WalletBackupFailure>> execute(
    WalletBackupSnapshot snapshot, {
    Future<Result<bool, WalletBackupFailure>> Function()? revalidate,
  }) async {
    // Apply the same strict validation to constructed and decoded snapshots.
    final encoded = _codec.encode(snapshot);
    if (encoded case Err(:final failure)) return Err(failure);
    final validated = _codec.decode(
      (encoded as Ok<String, WalletBackupFailure>).value,
    );
    if (validated case Err(:final failure)) return Err(failure);
    final source =
        (validated as Ok<WalletBackupSnapshot, WalletBackupFailure>).value;
    if (await _state.setRecoveryIncomplete(true) case Err(:final failure)) {
      return Err(failure);
    }

    final expected = source.manifest.wallets
        .map((wallet) => wallet.reference)
        .toSet();
    final references = <String, String>{};
    bool catalogRestored = false;
    bool metadataRestored = false;
    WalletBackupRecovery report([WalletBackupFailure? failure]) =>
        WalletBackupRecovery(
          wallets: WalletInventoryRecovery(
            walletReferences: references,
            failedReferences: expected
                .difference(references.keys.toSet())
                .toList(),
          ),
          publicRecordsRestored: catalogRestored,
          metadataRestored: metadataRestored,
          failure: failure,
        );

    switch (await _catalog.restorePublicRecords(source.manifest)) {
      case Err():
        return Ok(report(const WalletBackupStorageFailure()));
      case Ok():
        catalogRestored = true;
    }
    WalletBackupFailure? restoreFailure;
    final vaultReferences = source.vaults
        .map((entry) => entry.reference)
        .toSet();
    final ordinary = source.manifest.wallets
        .where((wallet) => !vaultReferences.contains(wallet.reference))
        .toList();
    for (final result in [
      await _wallets.restore(ordinary),
      await _vaults.restore(source.vaults, source.manifest.wallets),
    ]) {
      switch (result) {
        case Err(:final failure):
          restoreFailure ??= failure;
        case Ok(:final value):
          if (value.walletReferences.keys.any(
            (key) => references.containsKey(key) || !expected.contains(key),
          )) {
            restoreFailure = const WalletBackupInvalidFailure();
          } else {
            references.addAll(value.walletReferences);
          }
          if (!value.complete) {
            restoreFailure ??= const WalletBackupIncompleteFailure();
          }
      }
    }
    if (references.values.toSet().length != references.length) {
      references.clear();
      return Ok(report(const WalletBackupInvalidFailure()));
    }
    if (restoreFailure != null || references.length != expected.length) {
      return Ok(
        report(restoreFailure ?? const WalletBackupIncompleteFailure()),
      );
    }
    switch (await _metadata.apply(source.metadata, references)) {
      case Err(:final failure):
        return Ok(report(failure));
      case Ok():
        metadataRestored = true;
    }
    if (revalidate != null) {
      switch (await revalidate()) {
        case Err(:final failure):
          return Ok(report(failure));
        case Ok(value: false):
          return Ok(report(const WalletBackupConflictFailure()));
        case Ok():
          break;
      }
    }
    if (await _state.setRecoveryIncomplete(false) case Err(:final failure)) {
      return Ok(report(failure));
    }
    return Ok(report());
  }
}
