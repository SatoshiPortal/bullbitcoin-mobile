import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:crypto/crypto.dart';
import 'package:recoverbull/recoverbull.dart';

final class WalletBackupCodecRepositoryImpl
    implements WalletBackupCodecRepository {
  static const maximumPlaintextBytes = WalletBackupCiphertext.maximumBytes - 64;
  final BullVaultFacade _vaults;

  const WalletBackupCodecRepositoryImpl(this._vaults);

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
      _checkDepth(source);
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return const Err(WalletBackupInvalidFailure());
      }
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

  // The supported schema is less than 16 levels deep. Reject hostile nesting
  // before dart:convert recurses; quoted brackets do not count as structure.
  static void _checkDepth(String source) {
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (final character in source.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (character == 92) {
          escaped = true;
        } else if (character == 34) {
          quoted = false;
        }
      } else if (character == 34) {
        quoted = true;
      } else if (character == 123 || character == 91) {
        if (++depth > 16) {
          throw const FormatException('Snapshot nesting exceeds schema');
        }
      } else if (character == 125 || character == 93) {
        if (--depth < 0) {
          throw const FormatException('Invalid snapshot structure');
        }
      }
    }
  }
}
