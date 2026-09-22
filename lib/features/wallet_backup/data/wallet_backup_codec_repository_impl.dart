import 'dart:async';
import 'package:async/async.dart' show StreamGroup;
import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'dart:convert';
import 'package:bb_mobile/features/wallet_backup/data/backup_json.dart';

import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_file_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:nostr/nostr.dart' as nostr;

final class WalletBackupCodecRepositoryImpl
    implements WalletBackupCodecRepository {
  static const maximumPlaintextBytes = WalletBackupCiphertext.maximumBytes - 64;
  final BullVaultFacade _vaults;

  final SqliteDatabase _database;
  final KeychainManifestFacade _manifest;
  final WalletMetadataBackupRepository _metadata;
  final WalletInventoryBackupRepository _inventory;
  final WalletMetadataDatasource _wallets;
  final Bip85Datasource _bip85;
  final _changes = StreamController<void>.broadcast(sync: true);
  StreamSubscription<void>? _ownerSubscription;
  int _revision = 0;
  bool _disposed = false;

  WalletBackupCodecRepositoryImpl({
    required this._vaults,
    required this._database,
    required this._manifest,
    required this._metadata,
    required this._inventory,
    required this._wallets,
    required this._bip85,
  });

  @override
  Result<Set<WalletBackupDifference>, WalletBackupFailure> differences(
    WalletBackupSnapshot left,
    WalletBackupSnapshot right,
  ) {
    final a = encode(left), b = encode(right);
    if (a case Err(:final failure)) return Err(failure);
    if (b case Err(:final failure)) return Err(failure);
    final aJson =
        jsonDecode((a as Ok<String, WalletBackupFailure>).value)
            as Map<String, dynamic>;
    final bJson =
        jsonDecode((b as Ok<String, WalletBackupFailure>).value)
            as Map<String, dynamic>;
    return Ok(
      Set.unmodifiable({
        for (final part in WalletBackupDifference.values)
          if (jsonEncode(aJson[part.name]) != jsonEncode(bJson[part.name]))
            part,
      }),
    );
  }

  @override
  Result<String, WalletBackupFailure> encodeFile(
    WalletBackupSnapshot snapshot,
    BackupCredential credential, {
    required WalletBackupFileFormat format,
  }) {
    if (!_matchesCredential(snapshot, credential)) {
      return const Err(WalletBackupCredentialFailure());
    }
    try {
      final String signedContent;
      final Object payload;
      switch (format) {
        case WalletBackupFileFormat.encrypted:
          final encrypted = encrypt(snapshot, credential);
          if (encrypted case Err(:final failure)) return Err(failure);
          signedContent = base64.encode(
            (encrypted as Ok<WalletBackupCiphertext, WalletBackupFailure>)
                .value
                .bytes,
          );
          payload = signedContent;
        case WalletBackupFileFormat.readable:
          final encoded = encode(snapshot);
          if (encoded case Err(:final failure)) return Err(failure);
          signedContent = (encoded as Ok<String, WalletBackupFailure>).value;
          payload = jsonDecode(signedContent) as Object;
      }
      final createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      final model = WalletBackupFileModel(
        format: format.name,
        createdAt: createdAt,
        publicKey: credential.artifactPublicKey,
        signature: credential.signArtifactHash(
          _fileDigest(
            format,
            credential.artifactPublicKey,
            signedContent,
            createdAt,
          ),
        ),
        payload: payload,
      );
      final source = jsonEncode(model.toJson());
      return utf8.encode(source).length > WalletBackupFile.maximumBytes
          ? const Err(WalletBackupTooLargeFailure())
          : Ok(source);
    } on Exception {
      return const Err(WalletBackupInvalidFailure());
    }
  }

  @override
  Result<WalletBackupFile, WalletBackupFailure> decodeFile(
    String source, {
    BackupCredential? credential,
  }) {
    if (source.length > WalletBackupFile.maximumBytes ||
        utf8.encode(source).length > WalletBackupFile.maximumBytes) {
      return const Err(WalletBackupTooLargeFailure());
    }
    try {
      final model = WalletBackupFileModel.fromJson(readBackupJson(source));
      if (model.createdAt < 0 || model.createdAt > 8640000000000000) {
        return const Err(WalletBackupInvalidFailure());
      }
      if (model.kind != WalletBackupFileModel.fileKind || model.version != 1) {
        return const Err(WalletBackupUnsupportedFailure());
      }
      final WalletBackupFileFormat format;
      switch (model.format) {
        case 'encrypted':
          format = WalletBackupFileFormat.encrypted;
        case 'readable':
          format = WalletBackupFileFormat.readable;
        default:
          return const Err(WalletBackupUnsupportedFailure());
      }
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(model.publicKey) ||
          !RegExp(r'^[0-9a-f]{128}$').hasMatch(model.signature)) {
        return const Err(WalletBackupInvalidFailure());
      }
      final String signedContent;
      WalletBackupSnapshot? snapshot;
      WalletBackupCiphertext? ciphertext;
      switch (format) {
        case WalletBackupFileFormat.encrypted:
          if (model.payload is! String) {
            return const Err(WalletBackupInvalidFailure());
          }
          signedContent = model.payload as String;
          ciphertext = WalletBackupCiphertext(base64.decode(signedContent));
          if (base64.encode(ciphertext.bytes) != signedContent) {
            return const Err(WalletBackupInvalidFailure());
          }
        case WalletBackupFileFormat.readable:
          if (model.payload is! Map<String, dynamic>) {
            return const Err(WalletBackupInvalidFailure());
          }
          final decoded = decode(jsonEncode(model.payload));
          if (decoded case Err(:final failure)) return Err(failure);
          snapshot =
              (decoded as Ok<WalletBackupSnapshot, WalletBackupFailure>).value;
          final canonical = encode(snapshot);
          if (canonical case Err(:final failure)) return Err(failure);
          signedContent = (canonical as Ok<String, WalletBackupFailure>).value;
      }
      if (!nostr.Schnorr.verify(
        publicKey: model.publicKey,
        message: _fileDigest(
          format,
          model.publicKey,
          signedContent,
          model.createdAt,
        ),
        signature: model.signature,
      )) {
        return const Err(WalletBackupInvalidFailure());
      }
      if (ciphertext != null) {
        if (credential == null) {
          return const Err(WalletBackupCredentialFailure());
        }
        final decoded = decrypt(ciphertext, credential);
        if (decoded case Err(:final failure)) return Err(failure);
        snapshot =
            (decoded as Ok<WalletBackupSnapshot, WalletBackupFailure>).value;
      }
      final verified = snapshot!;
      if (verified.manifest.backupIdentities
              .singleWhere(
                (identity) => identity.kind == BackupIdentityKind.artifact,
              )
              .publicKey !=
          model.publicKey) {
        return const Err(WalletBackupInvalidFailure());
      }
      if (credential != null && !_matchesCredential(verified, credential)) {
        return const Err(WalletBackupCredentialFailure());
      }
      return Ok(
        WalletBackupFile(
          format: format,
          snapshot: verified,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            model.createdAt,
            isUtc: true,
          ),
        ),
      );
    } on Exception {
      return const Err(WalletBackupInvalidFailure());
    }
  }

  static String _fileDigest(
    WalletBackupFileFormat format,
    String publicKey,
    String content,
    int createdAt,
  ) => sha256
      .convert(
        utf8.encode(
          [
            WalletBackupFileModel.fileKind,
            '1',
            format.name,
            publicKey,
            createdAt.toString(),
            content,
          ].join('\u0000'),
        ),
      )
      .toString();

  @override
  Result<String, WalletBackupFailure> encode(WalletBackupSnapshot snapshot) {
    try {
      final source = WalletBackupSnapshotModel.fromEntity(
        snapshot,
        _vaults.encodeRecoveryPackage,
      ).canonicalJson();
      if (utf8.encode(source).length > maximumPlaintextBytes) {
        return const Err(WalletBackupTooLargeFailure());
      }
      return Ok(source);
    } on Exception {
      return const Err(WalletBackupInvalidFailure());
    }
  }

  @override
  Result<String, WalletBackupFailure> contentHash(
    WalletBackupSnapshot snapshot,
  ) => encode(
    snapshot,
  ).map((source) => sha256.convert(utf8.encode(source)).toString());

  @override
  Result<WalletBackupSnapshot, WalletBackupFailure> decode(String source) {
    if (source.length > maximumPlaintextBytes ||
        utf8.encode(source).length > maximumPlaintextBytes) {
      return const Err(WalletBackupTooLargeFailure());
    }
    try {
      final decoded = readBackupJson(source);
      if (decoded['version'] is! int ||
          decoded['kind'] != WalletBackupSnapshotModel.kind ||
          decoded['version'] != WalletBackupSnapshotModel.version) {
        return const Err(WalletBackupUnsupportedFailure());
      }
      return Ok(
        WalletBackupSnapshotModel(decoded).toEntity(
          (source) => switch (_vaults.decodeRecoveryPackage(source)) {
            Ok(:final value) => value,
            Err() => throw const FormatException('Invalid vault package'),
          },
        ),
      );
    } on Exception {
      return const Err(WalletBackupInvalidFailure());
    }
  }

  @override
  Result<WalletBackupCiphertext, WalletBackupFailure> encrypt(
    WalletBackupSnapshot snapshot,
    BackupCredential credential,
  ) {
    if (!_matchesCredential(snapshot, credential)) {
      return const Err(WalletBackupCredentialFailure());
    }
    switch (encode(snapshot)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        try {
          final encrypted = RecoverBull.createBackup(
            backupKey: credential.encryptionKey,
            secret: utf8.encode(value),
          );
          return Ok(WalletBackupCiphertext(encrypted.ciphertext));
        } on Exception {
          return const Err(WalletBackupCredentialFailure());
        }
    }
  }

  @override
  Result<WalletBackupSnapshot, WalletBackupFailure> decrypt(
    WalletBackupCiphertext ciphertext,
    BackupCredential credential,
  ) {
    try {
      // The public library API verifies the embedded HMAC. Its carrier's ID,
      // salt and date are not used by this cipher or serialized into our format.
      // Length/alignment are checked before the library splits the ciphertext.
      final plaintext = RecoverBull.restoreBackup(
        backupKey: credential.encryptionKey,
        backup: BullBackup(
          createdAt: 0,
          id: const [],
          salt: const [],
          ciphertext: ciphertext.bytes,
        ),
      );
      switch (decode(utf8.decode(plaintext))) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          return _matchesCredential(value, credential)
              ? Ok(value)
              : const Err(WalletBackupCredentialFailure());
      }
    } on Exception {
      return const Err(WalletBackupCredentialFailure());
    }
  }

  static bool _matchesCredential(
    WalletBackupSnapshot snapshot,
    BackupCredential credential,
  ) =>
      (credential.sourceFingerprint == null ||
          credential.sourceFingerprint ==
              snapshot.manifest.sourceFingerprint) &&
      snapshot.manifest.backupIdentities.every(
        (identity) =>
            identity.publicKey ==
            switch (identity.kind) {
              BackupIdentityKind.artifact => credential.artifactPublicKey,
              BackupIdentityKind.server => credential.serverPublicKey,
            },
      );
  @override
  Stream<void> get changes {
    _observeOwners();
    return _changes.stream;
  }

  @override
  int get revision {
    _observeOwners();
    return _revision;
  }

  void _observeOwners() {
    if (_disposed || _ownerSubscription != null) return;
    // Owner async* streams may wait indefinitely for another event on cancel.
    // Keep one subscription for this owner; consumers cancel only our relay.
    _ownerSubscription =
        StreamGroup.merge([
          _wallets.changes,
          _bip85.changes,
          _manifest.watchNostrKeys(),
          _metadata.changes,
          _inventory.vaultChanges,
        ]).listen(
          (_) {
            if (_revision >= 0) _revision++;
            _changes.add(null);
          },
          onError: (Object _) {
            _revision = -1;
            _changes.addError(const WalletBackupStorageFailure());
          },
        );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revision = -1;
    _ownerSubscription?.cancel().ignore();
    _changes.close().ignore();
  }

  @override
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> capture(
    BackupCredential credential,
  ) async {
    try {
      // SQL owners share this read transaction; Payjoin keeps its existing separate store, and the publisher's invalidation epoch covers that race.
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
        final vaults = await _inventory.captureVaults(
          captured.walletReferences,
        );
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
