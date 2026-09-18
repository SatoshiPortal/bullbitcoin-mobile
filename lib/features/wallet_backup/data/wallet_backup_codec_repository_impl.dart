import 'dart:convert';
import 'package:bb_mobile/features/wallet_backup/data/backup_json.dart';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_file_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:crypto/crypto.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:nostr/nostr.dart' as nostr;

final class WalletBackupCodecRepositoryImpl
    implements WalletBackupCodecRepository {
  static const maximumPlaintextBytes = WalletBackupCiphertext.maximumBytes - 64;
  final BullVaultFacade _vaults;

  const WalletBackupCodecRepositoryImpl(this._vaults);

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
      final model = WalletBackupFileModel(
        format: format.name,
        publicKey: credential.artifactPublicKey,
        signature: credential.signArtifactHash(
          _fileDigest(format, credential.artifactPublicKey, signedContent),
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
        message: _fileDigest(format, model.publicKey, signedContent),
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
      return Ok(WalletBackupFile(format: format, snapshot: verified));
    } on Exception {
      return const Err(WalletBackupInvalidFailure());
    }
  }

  static String _fileDigest(
    WalletBackupFileFormat format,
    String publicKey,
    String content,
  ) => sha256
      .convert(
        utf8.encode(
          [
            WalletBackupFileModel.fileKind,
            '1',
            format.name,
            publicKey,
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
}
