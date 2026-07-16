import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = _fixture();
  final npub = fixture['npub']! as String;
  final secretKey = fixture['test_only_secret_key']! as String;
  final vectors = (fixture['vectors']! as List<Object?>)
      .cast<Map<String, Object?>>();

  test('matches every frozen Rust signing, signature, and ETag vector', () {
    for (final vector in vectors) {
      final stream = _stream(vector['stream']! as String);
      final generation = vector['generation']! as int;
      final ciphertextHash = vector['ciphertext_sha256'] as String?;
      final message = buildWalletBackupSchnorrMessage(
        action: vector['action']! as String,
        stream: stream,
        npubHex: npub,
        generation: generation,
        expectedEtag: vector['expected_etag'] as String? ?? '',
        ciphertextSha256: ciphertextHash ?? '',
        ciphertextBytes: vector['ciphertext_bytes']! as int,
        timestampSecs: vector['timestamp']! as int,
      );
      final digest = sha256.convert(message).toString();

      expect(hex.encode(message), vector['signed_message_hex']);
      expect(digest, vector['signed_message_sha256']);
      expect(
        bip340.verify(npub, digest, vector['signature']! as String),
        isTrue,
      );
      expect(bip340.sign(secretKey, digest, '00' * 32), vector['signature']);

      if (generation > 0) {
        expect(
          computeWalletBackupEtag(
            stream: stream,
            npubHex: npub,
            generation: generation,
            ciphertextSha256: ciphertextHash ?? '',
          ),
          vector['result_etag'],
        );
      }

      final ciphertext = vector['ciphertext'] as String?;
      if (ciphertext != null) {
        final bytes = base64.decode(ciphertext);
        expect(bytes.length, vector['ciphertext_bytes']);
        expect(sha256.convert(bytes).toString(), ciphertextHash);
      }
    }
  });

  test('fixture tampering invalidates the frozen signature', () {
    final vector = vectors.firstWhere(
      (item) => item['name'] == 'initial_store',
    );
    final signature = vector['signature']! as String;
    final cases = fixture['tamper_cases']! as List<Object?>;

    for (final rawCase in cases) {
      final tamperCase = rawCase! as Map<String, Object?>;
      final field = tamperCase['field']! as String;
      if (field == 'signature') {
        final tampered =
            '${signature[0] == '0' ? '1' : '0'}${signature.substring(1)}';
        expect(
          bip340.verify(
            npub,
            vector['signed_message_sha256']! as String,
            tampered,
          ),
          isFalse,
        );
        continue;
      }

      final message = buildWalletBackupSchnorrMessage(
        action: field == 'action'
            ? walletBackupDeleteAction
            : vector['action']! as String,
        stream: field == 'stream'
            ? BullnymBackupStream.keychainManifest
            : _stream(vector['stream']! as String),
        npubHex: npub,
        generation: vector['generation']! as int,
        expectedEtag: '',
        ciphertextSha256: field == 'ciphertext_sha256'
            ? '1${(vector['ciphertext_sha256']! as String).substring(1)}'
            : vector['ciphertext_sha256']! as String,
        ciphertextBytes:
            (vector['ciphertext_bytes']! as int) +
            (field == 'ciphertext_bytes' ? 1 : 0),
        timestampSecs:
            (vector['timestamp']! as int) + (field == 'timestamp' ? 1 : 0),
      );
      expect(
        bip340.verify(npub, sha256.convert(message).toString(), signature),
        isFalse,
      );
    }
  });

  test('rejects non-canonical signing fields before network access', () async {
    expect(
      () => buildWalletBackupSchnorrMessage(
        action: walletBackupFetchAction,
        stream: BullnymBackupStream.keychainManifest,
        npubHex: npub.toUpperCase(),
        generation: 0,
        expectedEtag: '',
        ciphertextSha256: '',
        ciphertextBytes: 0,
        timestampSecs: 1,
      ),
      throwsA(isA<BullnymException>()),
    );
    expect(
      () => buildWalletBackupSchnorrMessage(
        action: walletBackupStoreAction,
        stream: BullnymBackupStream.keychainManifest,
        npubHex: npub,
        generation: 1,
        expectedEtag: 'etag',
        ciphertextSha256: 'hash',
        ciphertextBytes: 64,
        timestampSecs: 1,
      ),
      throwsA(isA<BullnymException>()),
    );
  });

  test('facade signs and sends conditional fetch, store, and delete', () async {
    final client = _RecordingClient();
    final facade = BullnymFacade(client: client, nowSecs: () => 1700000000);
    final signer = BullnymAuthSigner(
      npubHex: npub,
      signHashHex: (hash) => bip340.sign(secretKey, hash, '00' * 32),
    );

    final head = await facade.fetchBackup(
      signer: signer,
      stream: BullnymBackupStream.keychainManifest,
    );
    final ciphertext = AuthenticatedBackupCiphertext(
      base64.encode(List<int>.filled(64, 7)),
    );
    final stored = await facade.storeBackup(
      signer: signer,
      stream: BullnymBackupStream.keychainManifest,
      currentHead: head,
      ciphertext: ciphertext,
    );
    await facade.deleteBackup(
      signer: signer,
      stream: BullnymBackupStream.keychainManifest,
      currentHead: BullnymBackupHead.present(
        generation: stored.generation,
        etag: stored.etag,
        ciphertext: ciphertext,
        ciphertextSha256: client.storeRequest!.ciphertextSha256,
        updatedAtSecs: 1700000000,
      ),
    );

    expect(client.fetchRequest!.stream.wireName, 'keychain_manifest');
    expect(client.storeRequest!.generation, 1);
    expect(client.storeRequest!.expectedEtag, isNull);
    expect(client.deleteRequest!.generation, 2);
    expect(client.deleteRequest!.expectedEtag, stored.etag);
  });
}

Map<String, Object?> _fixture() =>
    jsonDecode(File('test/fixtures/wallet-backup-v1.json').readAsStringSync())
        as Map<String, Object?>;

BullnymBackupStream _stream(String value) => switch (value) {
  'keychain_manifest' => BullnymBackupStream.keychainManifest,
  'wallet_metadata' => BullnymBackupStream.walletMetadata,
  _ => throw ArgumentError.value(value, 'value', 'Unknown backup stream'),
};

final class _RecordingClient implements BullnymClientPort {
  BullnymBackupFetchRequest? fetchRequest;
  BullnymBackupStoreRequest? storeRequest;
  BullnymBackupDeleteRequest? deleteRequest;

  @override
  Future<BullnymBackupHead> fetchBackup(
    BullnymBackupFetchRequest request,
  ) async {
    fetchRequest = request;
    return BullnymBackupHead.absent(generation: 0, etag: null);
  }

  @override
  Future<BullnymBackupStoreReceipt> storeBackup(
    BullnymBackupStoreRequest request,
  ) async {
    storeRequest = request;
    return BullnymBackupStoreReceipt(
      generation: request.generation,
      etag: computeWalletBackupEtag(
        stream: request.stream,
        npubHex: request.npubHex,
        generation: request.generation,
        ciphertextSha256: request.ciphertextSha256,
      ),
    );
  }

  @override
  Future<BullnymBackupDeleteReceipt> deleteBackup(
    BullnymBackupDeleteRequest request,
  ) async {
    deleteRequest = request;
    return BullnymBackupDeleteReceipt(
      generation: request.generation,
      etag: computeWalletBackupEtag(
        stream: request.stream,
        npubHex: request.npubHex,
        generation: request.generation,
        ciphertextSha256: '',
      ),
    );
  }

  @override
  Future<void> deleteRegistration(BullnymDeleteRegistrationRequest request) =>
      throw UnimplementedError();

  @override
  Future<BullnymLookupResult> lookupRegistration({required String npubHex}) =>
      throw UnimplementedError();

  @override
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request) =>
      throw UnimplementedError();
}
