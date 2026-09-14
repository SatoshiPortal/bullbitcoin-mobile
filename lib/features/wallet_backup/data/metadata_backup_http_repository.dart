import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_http_transport.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_server_config.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

final class MetadataBackupHttpRepository
    implements WalletBackupRemoteRepository {
  final BackupServerHttpTransport _transport;

  const MetadataBackupHttpRepository(this._transport);

  factory MetadataBackupHttpRepository.fromDio(
    Dio dio,
    WalletBackupOriginProvider origin, {
    DateTime Function()? now,
  }) => MetadataBackupHttpRepository(
    BackupServerHttpTransport(dio, origin, now: now),
  );

  factory MetadataBackupHttpRepository.defaults({
    WalletBackupOriginProvider origin = defaultWalletBackupOrigin,
  }) => MetadataBackupHttpRepository(
    BackupServerHttpTransport.defaults(origin: origin),
  );

  @override
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch({
    required WalletBackupAuthentication authentication,
  }) async {
    final result = await _request(
      method: 'POST',
      path: '/api/v1/wallet-backups/fetch',
      body: {
        'version': walletBackupProtocolVersion,
        'stream': walletBackupStream,
        ..._authenticationBody(authentication),
      },
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _decodeHead(value, authentication.publicKeyHex),
    };
  }

  @override
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> store({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint? current,
    required WalletBackupCiphertext ciphertext,
    required String ciphertextSha256,
  }) async {
    final generation = (current?.generation ?? 0) + 1;
    final result = await _request(
      method: 'PUT',
      path: '/api/v1/wallet-backups',
      body: {
        'version': walletBackupProtocolVersion,
        'stream': walletBackupStream,
        'generation': generation,
        'expected_etag': current?.etag,
        'ciphertext': ciphertext.value,
        'ciphertext_sha256': ciphertextSha256,
        'ciphertext_bytes': ciphertext.byteLength,
        ..._authenticationBody(authentication),
      },
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _decodeReceipt(
        value,
        generation: generation,
        expectedEtag: computeWalletBackupEtag(
          publicKeyHex: authentication.publicKeyHex,
          generation: generation,
          ciphertextSha256: ciphertextSha256,
        ),
        ciphertextSha256: ciphertextSha256,
      ),
    };
  }

  @override
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> delete({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint current,
  }) async {
    final generation = current.generation + 1;
    final result = await _request(
      method: 'DELETE',
      path: '/api/v1/wallet-backups',
      body: {
        'version': walletBackupProtocolVersion,
        'stream': walletBackupStream,
        'generation': generation,
        'expected_etag': current.etag,
        ..._authenticationBody(authentication),
      },
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _decodeReceipt(
        value,
        generation: generation,
        expectedEtag: computeWalletBackupEtag(
          publicKeyHex: authentication.publicKeyHex,
          generation: generation,
          ciphertextSha256: '',
        ),
        ciphertextSha256: null,
      ),
    };
  }

  Future<Result<Map<String, Object?>, WalletBackupFailure>> _request({
    required String method,
    required String path,
    required Map<String, Object?> body,
  }) => _transport.request(
    method: method,
    path: path,
    body: body,
    // A fetch carries the whole encrypted snapshot; base64 costs a third more
    // than the bytes it encodes, and the envelope around it is small.
    maxResponseBytes:
        WalletBackupCiphertext.maximumByteLength * 2 +
        walletBackupSmallResponseBytes,
    decodeServerFailure: _decodeServerFailure,
  );

  WalletBackupFailure _decodeServerFailure(
    int? status,
    Headers headers,
    Map<String, Object?> json,
  ) {
    final code = json['code'];
    return switch ((status, code)) {
      (400, 'BackupInvalidRequest') =>
        const WalletBackupRemoteRejectedFailure(),
      (401, 'BackupAuthError') => const WalletBackupSigningFailure(),
      (409, 'BackupHeadConflict') => const WalletBackupHeadConflictFailure(),
      (413, 'BackupBlobTooLarge') => const WalletBackupTooLargeFailure(),
      (429, 'RateLimited') => _transport.rateLimited(headers),
      (503, 'BackupCapacityExceeded') =>
        const WalletBackupRemoteUnavailableFailure(),
      (500, 'InternalError') => const WalletBackupRemoteUnavailableFailure(),
      _ => const WalletBackupInvalidRemoteFailure(),
    };
  }

  Result<WalletBackupRemoteHead, WalletBackupFailure> _decodeHead(
    Map<String, Object?> json,
    String publicKeyHex,
  ) {
    if (!backupServerHasOnly(json, const {
          'version',
          'found',
          'generation',
          'etag',
          'ciphertext',
          'ciphertext_sha256',
          'ciphertext_bytes',
          'updated_at',
        }) ||
        json['version'] != walletBackupProtocolVersion ||
        json['found'] is! bool ||
        json['generation'] is! int ||
        (json['generation'] as int) < 0 ||
        (json['etag'] != null && json['etag'] is! String)) {
      return const Err(WalletBackupInvalidRemoteFailure());
    }
    final found = json['found'] as bool;
    final generation = json['generation'] as int;
    final etag = json['etag'] as String?;
    if (!found) {
      final updatedAt = json['updated_at'];
      final validTombstone =
          generation > 0 &&
          isWalletBackupHash(etag) &&
          updatedAt is int &&
          updatedAt >= 0 &&
          etag ==
              computeWalletBackupEtag(
                publicKeyHex: publicKeyHex,
                generation: generation,
                ciphertextSha256: '',
              );
      final validAbsence = generation == 0 && etag == null && updatedAt == null;
      if ((!validAbsence && !validTombstone) ||
          json['ciphertext'] != null ||
          json['ciphertext_sha256'] != null ||
          json['ciphertext_bytes'] != null) {
        return const Err(WalletBackupInvalidRemoteFailure());
      }
      return Ok(
        WalletBackupRemoteHead.absent(generation: generation, etag: etag),
      );
    }
    final ciphertextValue = json['ciphertext'];
    final hash = json['ciphertext_sha256'];
    final byteLength = json['ciphertext_bytes'];
    final updatedAt = json['updated_at'];
    if (generation <= 0 ||
        !isWalletBackupHash(etag) ||
        ciphertextValue is! String ||
        hash is! String ||
        !isWalletBackupHash(hash) ||
        byteLength is! int ||
        updatedAt is! int ||
        updatedAt < 0) {
      return const Err(WalletBackupInvalidRemoteFailure());
    }
    final ciphertext = WalletBackupCiphertext.tryParse(ciphertextValue);
    if (ciphertext == null ||
        ciphertext.byteLength != byteLength ||
        sha256.convert(base64.decode(ciphertext.value)).toString() != hash ||
        etag !=
            computeWalletBackupEtag(
              publicKeyHex: publicKeyHex,
              generation: generation,
              ciphertextSha256: hash,
            )) {
      return const Err(WalletBackupInvalidRemoteFailure());
    }
    return Ok(
      WalletBackupRemoteHead.present(
        generation: generation,
        etag: etag!,
        ciphertext: ciphertext,
        ciphertextSha256: hash,
      ),
    );
  }

  Result<WalletBackupRemoteCheckpoint, WalletBackupFailure> _decodeReceipt(
    Map<String, Object?> json, {
    required int generation,
    required String? expectedEtag,
    required String? ciphertextSha256,
  }) {
    if (!backupServerHasOnly(json, const {'version', 'generation', 'etag'}) ||
        json['version'] != walletBackupProtocolVersion ||
        json['generation'] != generation ||
        expectedEtag == null ||
        json['etag'] != expectedEtag) {
      return const Err(WalletBackupInvalidRemoteFailure());
    }
    return Ok(
      WalletBackupRemoteCheckpoint(
        generation: generation,
        etag: expectedEtag,
        ciphertextSha256: ciphertextSha256,
      ),
    );
  }
}

Map<String, Object?> _authenticationBody(
  WalletBackupAuthentication authentication,
) => {
  'npub': authentication.publicKeyHex,
  'timestamp': authentication.timestamp,
  'signature': authentication.signatureHex,
};
