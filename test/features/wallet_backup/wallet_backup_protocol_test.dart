import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_server_config.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses the production backup origin when no override is supplied',
    () async {
      expect(walletBackupDefaultServerUrl, 'https://backup.bull-wallet.com');
      expect(
        await defaultWalletBackupOrigin(),
        Uri.parse('https://backup.bull-wallet.com'),
      );
    },
  );

  test('matches every vector from standalone server v0.1.0', () {
    // Server fixture at 152648008882c73f7a81fd590ef7819f3b1cc64d.
    // SHA-256: 84b64d530c407c28df32bd3ef659842152784874595f28ebaaed250227404da1
    final fixture =
        jsonDecode(
              File(
                'test/features/wallet_backup/fixtures/wallet-backup-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final publicKey = fixture['npub'] as String;
    for (final raw in fixture['vectors'] as List<dynamic>) {
      final vector = raw as Map<String, dynamic>;
      final action = WalletBackupAction.values.singleWhere(
        (value) => value.wireName == vector['action'],
      );
      final message = buildWalletBackupSigningMessage(
        action: action,
        publicKeyHex: publicKey,
        generation: vector['generation'] as int,
        expectedEtag: vector['expected_etag'] as String? ?? '',
        ciphertextSha256: vector['ciphertext_sha256'] as String? ?? '',
        ciphertextBytes: vector['ciphertext_bytes'] as int,
        timestamp: vector['timestamp'] as int,
      );
      expect(hex.encode(message!), vector['signed_message_hex']);
      expect(
        sha256.convert(message).toString(),
        vector['signed_message_sha256'],
      );
      if (vector['result_etag'] case final String etag) {
        expect(
          computeWalletBackupEtag(
            publicKeyHex: publicKey,
            generation: vector['generation'] as int,
            ciphertextSha256: vector['ciphertext_sha256'] as String? ?? '',
          ),
          etag,
        );
      }
    }
  });

  test('enforces the standalone server ciphertext limit', () {
    final atLimit = base64.encode(
      List<int>.filled(WalletBackupCiphertext.maximumByteLength, 1),
    );
    expect(WalletBackupCiphertext.tryParse(atLimit), isNotNull);
    final overLimit = base64.encode(
      List<int>.filled(WalletBackupCiphertext.maximumByteLength + 1, 1),
    );
    expect(WalletBackupCiphertext.tryParse(overLimit), isNull);
  });

  test('accepts only an origin and debug loopback HTTP', () {
    expect(
      parseWalletBackupServerOrigin('https://backup.example.com'),
      Uri.parse('https://backup.example.com'),
    );
    expect(
      parseWalletBackupServerOrigin(
        'http://127.0.0.1',
        allowInsecureLoopback: true,
      ),
      Uri.parse('http://127.0.0.1'),
    );
    for (final invalid in [
      'http://example.com',
      'https://user@example.com',
      'https://example.com/path',
      'https://example.com?query=1',
      'https://example.com/#fragment',
    ]) {
      expect(
        parseWalletBackupServerOrigin(invalid, allowInsecureLoopback: false),
        isNull,
      );
    }
  });
}
