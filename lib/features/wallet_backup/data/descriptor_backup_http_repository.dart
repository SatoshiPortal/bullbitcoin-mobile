import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_http_transport.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/private_descriptor_record.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/private_descriptor_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/private_descriptor_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_server_config.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// The descriptor record API on the Data Backup origin.
///
/// Store is signed and immutable; lookup is unsigned, because knowing a token
/// is the read capability. No descriptor error code collides with a wallet
/// backup one.
/// `DateTime` holds 8640000000000000 milliseconds either side of the epoch.
const _maxSecondsSinceEpoch = 8640000000000;

final class DescriptorBackupHttpRepository
    implements PrivateDescriptorRemoteRepository {
  final BackupServerHttpTransport _transport;

  const DescriptorBackupHttpRepository(this._transport);

  factory DescriptorBackupHttpRepository.fromDio(
    Dio dio,
    WalletBackupOriginProvider origin, {
    DateTime Function()? now,
  }) => DescriptorBackupHttpRepository(
    BackupServerHttpTransport(dio, origin, now: now),
  );

  factory DescriptorBackupHttpRepository.defaults({
    WalletBackupOriginProvider origin = defaultWalletBackupOrigin,
  }) => DescriptorBackupHttpRepository(
    BackupServerHttpTransport.defaults(origin: origin),
  );

  @override
  Future<Result<DateTime, WalletBackupFailure>> store({
    required WalletBackupAuthentication authentication,
    required Uint8List ciphertext,
    required List<String> lookupTokens,
  }) async {
    if (!isCanonicalPrivateDescriptorTokens(lookupTokens) ||
        ciphertext.isEmpty ||
        ciphertext.length > privateDescriptorMaxCiphertextBytes) {
      return const Err(WalletBackupRemoteRejectedFailure());
    }
    final hash = sha256.convert(ciphertext).toString();
    final result = await _request(
      path: '/api/v1/descriptor-backups',
      body: {
        'version': privateDescriptorProtocolVersion,
        'npub': authentication.publicKeyHex,
        'ciphertext': base64.encode(ciphertext),
        'ciphertext_sha256': hash,
        'ciphertext_bytes': ciphertext.length,
        'lookup_tokens': lookupTokens,
        'timestamp': authentication.timestamp,
        'signature': authentication.signatureHex,
      },
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _decodeReceipt(value, hash),
    };
  }

  @override
  Future<Result<PrivateDescriptorLookupPage, WalletBackupFailure>> lookup(
    List<String> lookupTokens, {
    String? cursor,
  }) async {
    if (!isCanonicalPrivateDescriptorTokens(lookupTokens)) {
      return const Err(WalletBackupRemoteRejectedFailure());
    }
    final result = await _request(
      path: '/api/v1/descriptor-backups/lookup',
      body: {
        'version': privateDescriptorProtocolVersion,
        'lookup_tokens': lookupTokens,
        'cursor': ?cursor,
      },
      maxResponseBytes: privateDescriptorMaxLookupResponseBytes,
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _decodeLookup(value),
    };
  }

  Future<Result<Map<String, Object?>, WalletBackupFailure>> _request({
    required String path,
    required Map<String, Object?> body,
    int maxResponseBytes = walletBackupSmallResponseBytes,
  }) => _transport.request(
    method: 'POST',
    path: path,
    body: body,
    maxResponseBytes: maxResponseBytes,
    decodeServerFailure: _decodeServerFailure,
  );

  WalletBackupFailure _decodeServerFailure(
    int? status,
    Headers headers,
    Map<String, Object?> json,
  ) => switch ((status, json['code'])) {
    (400, 'DescriptorInvalidRequest') =>
      const WalletBackupRemoteRejectedFailure(),
    (401, 'DescriptorAuthError') => const WalletBackupSigningFailure(),
    (403, 'DescriptorPublisherQuotaExceeded') =>
      const WalletBackupPublisherQuotaFailure(),
    (409, 'DescriptorRecordConflict') =>
      const WalletBackupHeadConflictFailure(),
    (413, 'DescriptorBlobTooLarge') => const WalletBackupTooLargeFailure(),
    (429, 'DescriptorRateLimited') => _transport.rateLimited(headers),
    (503, 'DescriptorCapacityExceeded') =>
      const WalletBackupRemoteUnavailableFailure(),
    (500, 'InternalError') => const WalletBackupRemoteUnavailableFailure(),
    _ => const WalletBackupInvalidRemoteFailure(),
  };

  /// The acknowledgement has to name the exact bytes that were sent, so a
  /// receipt for something else is never recorded as this record's.
  Result<DateTime, WalletBackupFailure> _decodeReceipt(
    Map<String, Object?> json,
    String ciphertextSha256,
  ) {
    final createdAt = json['created_at'];
    if (!backupServerHasOnly(json, const {
          'version',
          'ciphertext_sha256',
          'created_at',
        }) ||
        json['version'] != privateDescriptorProtocolVersion ||
        json['ciphertext_sha256'] != ciphertextSha256 ||
        !_isSecondsSinceEpoch(createdAt)) {
      return const Err(WalletBackupInvalidRemoteFailure());
    }
    return Ok(_time(createdAt! as int));
  }

  Result<PrivateDescriptorLookupPage, WalletBackupFailure> _decodeLookup(
    Map<String, Object?> json,
  ) {
    final rows = json['records'];
    final cursor = json['next_cursor'];
    if (!backupServerHasOnly(json, const {
          'version',
          'next_cursor',
          'records',
        }) ||
        json['version'] != privateDescriptorProtocolVersion ||
        (cursor != null && cursor is! String) ||
        rows is! List ||
        // A page longer than the client will hold was not written by the
        // service this app talks to; nothing in it is decoded.
        rows.length > privateDescriptorMaxRecordsPerPage) {
      return const Err(WalletBackupInvalidRemoteFailure());
    }
    final records = <PrivateDescriptorRecord>[];
    for (final row in rows) {
      final record = backupServerObject(row);
      final encoded = record?['ciphertext'];
      final hash = record?['ciphertext_sha256'];
      final byteLength = record?['ciphertext_bytes'];
      final createdAt = record?['created_at'];
      // Every field is checked for its type before it is used as one: a
      // server that answers with a number where a hash belongs is a failure
      // this recovery reports, not an error thrown past its boundary.
      if (record == null ||
          !backupServerHasOnly(record, const {
            'ciphertext',
            'ciphertext_sha256',
            'ciphertext_bytes',
            'created_at',
          }) ||
          encoded is! String ||
          hash is! String ||
          !isWalletBackupHash(hash) ||
          byteLength is! int ||
          !_isSecondsSinceEpoch(createdAt)) {
        return const Err(WalletBackupInvalidRemoteFailure());
      }
      final ciphertext = _decodeCiphertext(encoded);
      if (ciphertext == null ||
          ciphertext.length != byteLength ||
          sha256.convert(ciphertext).toString() != hash) {
        return const Err(WalletBackupInvalidRemoteFailure());
      }
      records.add(
        PrivateDescriptorRecord(
          ciphertext: ciphertext,
          ciphertextSha256: hash,
          createdAt: _time(createdAt! as int),
        ),
      );
    }
    return Ok(
      PrivateDescriptorLookupPage(
        records: records,
        nextCursor: cursor as String?,
      ),
    );
  }

  /// Standard base64 with padding, canonical: re-encoding the decoded bytes has
  /// to reproduce the string exactly, so no two spellings name one record.
  Uint8List? _decodeCiphertext(String value) {
    if (value.isEmpty || value.trim() != value) return null;
    final Uint8List bytes;
    try {
      bytes = base64.decode(value);
    } on FormatException {
      return null;
    }
    return base64.encode(bytes) == value &&
            bytes.isNotEmpty &&
            bytes.length <= privateDescriptorMaxCiphertextBytes
        ? bytes
        : null;
  }

  /// Whether [value] is a Unix second count `DateTime` can actually hold.
  ///
  /// Checked before the conversion rather than after it, because the
  /// conversion throws and this is a value a hostile server chooses.
  bool _isSecondsSinceEpoch(Object? value) =>
      value is int && value >= 0 && value <= _maxSecondsSinceEpoch;

  DateTime _time(int secondsSinceEpoch) => DateTime.fromMillisecondsSinceEpoch(
    secondsSinceEpoch * 1000,
    isUtc: true,
  );
}
