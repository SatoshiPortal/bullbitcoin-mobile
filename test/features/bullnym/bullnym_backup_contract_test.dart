import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockHttpAdapter extends Mock implements HttpClientAdapter {}

void main() {
  final fixture = _fixture();
  final npub = fixture['npub']! as String;
  final secretKey = fixture['test_only_secret_key']! as String;
  final vectors = (fixture['vectors']! as List<Object?>)
      .cast<Map<String, Object?>>();

  setUpAll(() => registerFallbackValue(RequestOptions(path: '')));

  test('matches every frozen Rust signing, signature, and ETag vector', () {
    for (final vector in vectors) {
      final stream = _stream(vector['stream']! as String);
      final generation = vector['generation']! as int;
      final ciphertextHash = vector['ciphertext_sha256'] as String?;
      final message = _unwrap(
        buildWalletBackupSchnorrMessage(
          action: vector['action']! as String,
          stream: stream,
          npubHex: npub,
          generation: generation,
          expectedEtag: vector['expected_etag'] as String? ?? '',
          ciphertextSha256: ciphertextHash ?? '',
          ciphertextBytes: vector['ciphertext_bytes']! as int,
          timestampSecs: vector['timestamp']! as int,
        ),
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
          _unwrap(
            computeWalletBackupEtag(
              stream: stream,
              npubHex: npub,
              generation: generation,
              ciphertextSha256: ciphertextHash ?? '',
            ),
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
    for (final rawCase in fixture['tamper_cases']! as List<Object?>) {
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

      final message = _unwrap(
        buildWalletBackupSchnorrMessage(
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
        ),
      );
      expect(
        bip340.verify(npub, sha256.convert(message).toString(), signature),
        isFalse,
      );
    }
  });

  test('facade sends and validates conditional server requests', () async {
    const timestamp = 1700000000;
    final ciphertext = AuthenticatedBackupCiphertext(
      base64.encode(List<int>.generate(64, (index) => index)),
    );
    final ciphertextHash = sha256
        .convert(base64.decode(ciphertext.value))
        .toString();
    final storedEtag = _unwrap(
      computeWalletBackupEtag(
        stream: BullnymBackupStream.walletMetadata,
        npubHex: npub,
        generation: 1,
        ciphertextSha256: ciphertextHash,
      ),
    );
    final deletedEtag = _unwrap(
      computeWalletBackupEtag(
        stream: BullnymBackupStream.walletMetadata,
        npubHex: npub,
        generation: 2,
        ciphertextSha256: '',
      ),
    );
    final stub = _stubDio([
      {'version': 1, 'found': false, 'generation': 0, 'etag': null},
      {'version': 1, 'generation': 1, 'etag': storedEtag},
      {'version': 1, 'generation': 2, 'etag': deletedEtag},
    ]);
    final facade = BullnymFacade(
      client: BullnymHttpClient.withDio(stub.dio),
      nowSecs: () => timestamp,
    );
    final signer = BullnymAuthSigner(
      npubHex: npub,
      signHashHex: (hash) => bip340.sign(secretKey, hash, '00' * 32),
    );

    final head = _unwrap(
      await facade.fetchBackup(
        signer: signer,
        stream: BullnymBackupStream.walletMetadata,
      ),
    );
    final stored = _unwrap(
      await facade.storeBackup(
        signer: signer,
        stream: BullnymBackupStream.walletMetadata,
        currentHead: head,
        ciphertext: ciphertext,
      ),
    );
    final deleted = _unwrap(
      await facade.deleteBackup(
        signer: signer,
        stream: BullnymBackupStream.walletMetadata,
        currentHead: BullnymBackupHead.present(
          generation: stored.generation,
          etag: stored.etag,
          ciphertext: ciphertext,
          ciphertextSha256: ciphertextHash,
          updatedAtSecs: timestamp,
        ),
      ),
    );

    expect(deleted?.generation, 2);
    expect(stub.requests.map((request) => request.method), [
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect(stub.requests.map((request) => request.path), [
      '/api/v1/wallet-backups/fetch',
      '/api/v1/wallet-backups',
      '/api/v1/wallet-backups',
    ]);
    final store = stub.requests[1].data as Map<String, dynamic>;
    expect(store['stream'], 'wallet_metadata');
    expect(store['generation'], 1);
    expect(store['expected_etag'], isNull);
    expect(store['ciphertext_sha256'], ciphertextHash);
    expect(store['ciphertext_bytes'], 64);
    final delete = stub.requests[2].data as Map<String, dynamic>;
    expect(delete['generation'], 2);
    expect(delete['expected_etag'], storedEtag);
  });
}

({Dio dio, List<RequestOptions> requests}) _stubDio(
  List<Map<String, dynamic>> responses,
) {
  final requests = <RequestOptions>[];
  final adapter = _MockHttpAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://bullpay.test',
      validateStatus: (status) => status != null && status < 600,
    ),
  )..httpClientAdapter = adapter;
  var index = 0;
  when(() => adapter.fetch(any(), any(), any())).thenAnswer((invocation) async {
    final request = invocation.positionalArguments[0] as RequestOptions;
    requests.add(request);
    return ResponseBody.fromString(
      jsonEncode(responses[index++]),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  });
  return (dio: dio, requests: requests);
}

Map<String, Object?> _fixture() =>
    jsonDecode(File('test/fixtures/wallet-backup-v1.json').readAsStringSync())
        as Map<String, Object?>;

BullnymBackupStream _stream(String value) => switch (value) {
  'keychain_manifest' => BullnymBackupStream.keychainManifest,
  'wallet_metadata' => BullnymBackupStream.walletMetadata,
  _ => throw ArgumentError.value(value, 'value'),
};

T _unwrap<T>(Result<T, BullnymFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Expected Ok, got $failure'),
};
