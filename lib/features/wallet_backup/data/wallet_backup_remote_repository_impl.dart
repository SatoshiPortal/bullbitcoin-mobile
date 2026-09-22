import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_http_transport.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class WalletBackupRemoteRepositoryImpl
    implements WalletBackupRemoteRepository {
  final BackupServerHttpTransport _transport;
  final DateTime Function() _now;

  const WalletBackupRemoteRepositoryImpl(
    this._transport, {
    this._now = _utcNow,
  });

  @override
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch(
    BackupCredential credential,
  ) async {
    try {
      final reply = await _transport.send(
        method: 'POST',
        path: '/api/v1/wallet-backups/fetch',
        body: _signed(credential, action: 'backup-fetch'),
      );
      return switch (reply) {
        Err(:final failure) => Err(failure),
        Ok(:final value) => Ok(_readHead(value, credential.serverPublicKey)),
      };
    } on Exception {
      return const Err(WalletBackupInvalidFailure());
    }
  }

  @override
  Future<Result<WalletBackupCheckpoint, WalletBackupFailure>> store(
    BackupCredential credential,
    WalletBackupCiphertext ciphertext, {
    required int generation,
    required String? expectedEtag,
  }) async {
    try {
      _validateMutation(generation, expectedEtag);
      final expected = BackupServerProtocol.etag(
        identity: credential.serverPublicKey,
        generation: generation,
        ciphertextHash: ciphertext.hash,
      );
      final reply = await _transport.send(
        method: 'PUT',
        path: '/api/v1/wallet-backups',
        body: {
          ..._signed(
            credential,
            action: 'backup-store',
            generation: generation,
            expectedEtag: expectedEtag,
            ciphertext: ciphertext,
          ),
          'generation': generation,
          'expected_etag': expectedEtag,
          'ciphertext': base64.encode(ciphertext.bytes),
          'ciphertext_sha256': ciphertext.hash,
          'ciphertext_bytes': ciphertext.length,
        },
      );
      switch (reply) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          _verifyReceipt(value, generation, expected);
          return Ok(
            WalletBackupCheckpoint(
              generation: generation,
              etag: expected,
              ciphertextHash: ciphertext.hash,
            ),
          );
      }
    } on Exception {
      return const Err(WalletBackupInvalidFailure());
    }
  }

  @override
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> delete(
    BackupCredential credential, {
    required int generation,
    required String expectedEtag,
  }) async {
    try {
      _validateMutation(generation, expectedEtag);
      final expected = BackupServerProtocol.etag(
        identity: credential.serverPublicKey,
        generation: generation,
        ciphertextHash: null,
      );
      final reply = await _transport.send(
        method: 'DELETE',
        path: '/api/v1/wallet-backups',
        body: {
          ..._signed(
            credential,
            action: 'backup-delete',
            generation: generation,
            expectedEtag: expectedEtag,
          ),
          'generation': generation,
          'expected_etag': expectedEtag,
        },
      );
      switch (reply) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          _verifyReceipt(value, generation, expected);
          return Ok(
            WalletBackupRemoteHead(generation: generation, etag: expected),
          );
      }
    } on Exception {
      return const Err(WalletBackupInvalidFailure());
    }
  }

  Map<String, Object?> _signed(
    BackupCredential credential, {
    required String action,
    int generation = 0,
    String? expectedEtag,
    WalletBackupCiphertext? ciphertext,
  }) {
    final timestamp = _now().millisecondsSinceEpoch ~/ 1000;
    if (timestamp < 0) throw const FormatException('Invalid clock');
    return {
      'version': BackupServerProtocol.version,
      'stream': BackupServerProtocol.stream,
      // The published field name is npub, but the server requires x-only hex.
      'npub': credential.serverPublicKey, 'timestamp': timestamp,
      'signature': credential.signServerHash(
        BackupServerProtocol.authHash(
          action: action,
          identity: credential.serverPublicKey,
          generation: generation,
          expectedEtag: expectedEtag,
          ciphertextHash: ciphertext?.hash,
          ciphertextBytes: ciphertext?.length ?? 0,
          timestamp: timestamp,
        ),
      ),
    };
  }

  static WalletBackupRemoteHead _readHead(
    Map<String, dynamic> json,
    String identity,
  ) {
    _checkFields(
      json,
      required: {'version', 'found', 'generation', 'etag'},
      optional: {
        'ciphertext',
        'ciphertext_sha256',
        'ciphertext_bytes',
        'updated_at',
      },
    );
    final generation = _generation(json['generation'], allowZero: true);
    final found = json['found'];
    if (found is! bool || json['etag'] != null && json['etag'] is! String) {
      throw const FormatException('Invalid head');
    }
    final etag = json['etag'] as String?;
    WalletBackupCiphertext? ciphertext;
    if (found) {
      final encoded = json['ciphertext'];
      if (encoded is! String ||
          encoded.length >
              ((WalletBackupCiphertext.maximumBytes + 2) ~/ 3) * 4) {
        throw const FormatException('Invalid ciphertext');
      }
      final bytes = base64.decode(encoded);
      if (base64.encode(bytes) != encoded) {
        throw const FormatException('Noncanonical ciphertext');
      }
      ciphertext = WalletBackupCiphertext(bytes);
      if (json['ciphertext_sha256'] != ciphertext.hash ||
          json['ciphertext_bytes'] is! int ||
          json['ciphertext_bytes'] != ciphertext.length) {
        throw const FormatException(
          'Ciphertext does not match advertised hash',
        );
      }
    } else if (json.containsKey('ciphertext') ||
        json.containsKey('ciphertext_sha256') ||
        json.containsKey('ciphertext_bytes')) {
      throw const FormatException('Unexpected absent backup payload');
    }
    if (generation > 0 &&
        etag !=
            BackupServerProtocol.etag(
              identity: identity,
              generation: generation,
              ciphertextHash: ciphertext?.hash,
            )) {
      throw const FormatException('Backup etag does not match content');
    }
    final seconds = json['updated_at'];
    if (seconds != null &&
        (seconds is! int || seconds < 0 || seconds > 8640000000000)) {
      throw const FormatException('Invalid backup date');
    }
    return WalletBackupRemoteHead(
      generation: generation,
      etag: etag,
      ciphertext: ciphertext,
      updatedAt: seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (seconds as int) * 1000,
              isUtc: true,
            ),
    );
  }

  static void _verifyReceipt(
    Map<String, dynamic> json,
    int generation,
    String etag,
  ) {
    _checkFields(json, required: {'version', 'generation', 'etag'});
    if (_generation(json['generation']) != generation || json['etag'] != etag) {
      throw const FormatException('Server acknowledged different content');
    }
  }

  static void _checkFields(
    Map<String, dynamic> json, {
    required Set<String> required,
    Set<String> optional = const {},
  }) {
    if (!json.keys.toSet().containsAll(required) ||
        !{...required, ...optional}.containsAll(json.keys) ||
        json['version'] is! int ||
        json['version'] != BackupServerProtocol.version) {
      throw const FormatException('Invalid BULL response');
    }
  }

  static int _generation(Object? value, {bool allowZero = false}) {
    if (value is! int ||
        value < (allowZero ? 0 : 1) ||
        value > BackupServerProtocol.maximumGeneration) {
      throw const FormatException('Invalid backup generation');
    }
    return value;
  }

  static void _validateMutation(int generation, String? expectedEtag) {
    _generation(generation);
    if (expectedEtag != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedEtag)) {
      throw const FormatException('Invalid expected etag');
    }
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
