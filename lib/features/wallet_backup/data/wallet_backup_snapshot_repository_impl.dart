import 'package:async/async.dart' show StreamGroup;
import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_snapshot_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class WalletBackupSnapshotRepositoryImpl
    implements WalletBackupSnapshotRepository {
  final SqliteDatabase _database;
  final KeychainManifestFacade _manifest;
  final WalletMetadataBackupRepository _metadata;
  final BullVaultBackupRepository _vaults;
  final WalletMetadataDatasource _wallets;
  final Bip85Datasource _bip85;

  const WalletBackupSnapshotRepositoryImpl({
    required this._database,
    required this._manifest,
    required this._metadata,
    required this._vaults,
    required this._wallets,
    required this._bip85,
  });

  @override
  Stream<void> get changes => StreamGroup.merge([
    _wallets.changes,
    _bip85.changes,
    _manifest.watchNostrKeys(),
    _metadata.changes,
    _vaults.changes,
  ]);

  @override
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> capture(
    BackupCredential credential,
  ) async {
    try {
      // SQL owners share this read transaction. Payjoin uses its existing
      // separate store; the publisher's invalidation epoch covers that race.
      return await _database.transaction(() async {
        final inventory = await _manifest.capture(credential);
        if (inventory case Err()) {
          return const Err(WalletBackupIncompleteFailure());
        }
        final captured =
            (inventory as Ok<CapturedKeychainManifest, KeychainManifestFailure>)
                .value;
        final metadata = await _metadata.capture(captured.walletReferences);
        if (metadata case Err(:final failure)) return Err(failure);
        final vaults = await _vaults.capture(captured.walletReferences);
        if (vaults case Err(:final failure)) return Err(failure);
        return switch ((metadata, vaults)) {
          (Ok(value: final metadata), Ok(value: final vaults)) => Ok(
            WalletBackupSnapshot(
              manifest: captured.manifest,
              metadata: metadata,
              vaults: vaults,
            ),
          ),
          (Err(:final failure), _) => Err(failure),
          (_, Err(:final failure)) => Err(failure),
        };
      });
    } on FormatException {
      return const Err(WalletBackupIncompleteFailure());
    } on Exception {
      return const Err(WalletBackupStorageFailure());
    }
  }
}
