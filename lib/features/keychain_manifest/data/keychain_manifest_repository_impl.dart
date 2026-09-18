import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';

final class KeychainManifestRepositoryImpl
    implements KeychainManifestRepository {
  final SqliteDatabase _database;
  final WalletMetadataDatasource _wallets;
  final Bip85Repository _bip85;
  final NostrKeyRepository _nostrKeys;

  const KeychainManifestRepositoryImpl({
    required this._database,
    required this._wallets,
    required this._bip85,
    required this._nostrKeys,
  });

  @override
  Future<Result<CapturedKeychainManifest, KeychainManifestFailure>> capture({
    required String sourceFingerprint,
    required String artifactPublicKey,
    required String serverPublicKey,
  }) async {
    try {
      return await _database.transaction(() async {
        final derivationsResult = await _bip85.fetchAll();
        final nostrResult = await _nostrKeys.getAll();
        switch ((derivationsResult, nostrResult)) {
          case (Err(), _):
            return const Err(KeychainManifestStorageFailure());
          case (_, Err(:final failure)):
            return Err(failure);
          case (Ok(value: final allDerivations), Ok(value: final allNostr)):
            final derivations =
                allDerivations
                    .where(
                      (entry) => entry.xprvFingerprint == sourceFingerprint,
                    )
                    .toList()
                  ..sort((a, b) => a.path.compareTo(b.path));
            final nostr =
                allNostr
                    .where(
                      (entry) => entry.parentFingerprint == sourceFingerprint,
                    )
                    .toList()
                  ..sort((a, b) => a.identity.compareTo(b.identity));
            final walletReferences = <String, String>{};
            final wallets = <BackupWallet>[];
            for (final wallet in await _wallets.fetchAll()) {
              final entry = BackupWallet(
                network: wallet.network,
                publicDescriptor: wallet.publicDescriptor,
                signers: wallet.signers
                    .map((signer) => signer.toEntity())
                    .toList(),
                isDefault: wallet.isDefault,
                isHidden: wallet.isHidden,
                label: wallet.label,
                birthday: wallet.birthday?.toUtc(),
              );
              wallets.add(entry);
              walletReferences[wallet.id] = entry.reference;
            }
            wallets.sort((a, b) => a.reference.compareTo(b.reference));
            return Ok(
              CapturedKeychainManifest(
                manifest: KeychainManifest(
                  sourceFingerprint: sourceFingerprint,
                  wallets: wallets,
                  derivations: derivations,
                  nostrKeys: nostr,
                  backupIdentities: [
                    BackupIdentityRecord(
                      parentFingerprint: sourceFingerprint,
                      publicKey: artifactPublicKey,
                      kind: BackupIdentityKind.artifact,
                    ),
                    BackupIdentityRecord(
                      parentFingerprint: sourceFingerprint,
                      publicKey: serverPublicKey,
                      kind: BackupIdentityKind.server,
                    ),
                  ],
                ),
                walletReferences: walletReferences,
              ),
            );
        }
      });
    } on Exception {
      return const Err(KeychainManifestStorageFailure());
    }
  }
}
