import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_http_transport.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_remote_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';

import '../backup_snapshot_fixture.dart';

class _Adapter implements HttpClientAdapter {
  FutureOr<ResponseBody> Function(RequestOptions) respond = (_) =>
      ResponseBody.fromString('{}', 500);
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final ciphertext = WalletBackupCiphertext(List.generate(64, (i) => i));
  late _Adapter adapter;
  late Dio dio;
  late DateTime now;
  late WalletBackupRemoteRepositoryImpl repository;
  setUp(() {
    adapter = _Adapter();
    dio = Dio()..httpClientAdapter = adapter;
    now = DateTime.utc(2026, 9, 18);
    repository = WalletBackupRemoteRepositoryImpl(
      BackupServerHttpTransport(
        dio: dio,
        origin: Uri.parse('http://localhost:8234'),
        now: () => now,
        timeout: const Duration(seconds: 2),
      ),
      now: () => now,
    );
  });
  tearDown(() => dio.close(force: true));
  ResponseBody reply(Map<String, Object?> json, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(json),
        status,
        headers: {
          'content-type': ['application/json'],
        },
      );
  String etag(int generation, {bool deleted = false}) =>
      BackupServerProtocol.etag(
        identity: credential.serverPublicKey,
        generation: generation,
        ciphertextHash: deleted ? null : ciphertext.hash,
      );
  void verifySignature(RequestOptions request, String action) {
    final body = jsonDecode(request.data as String) as Map<String, dynamic>;
    expect(body['npub'], credential.serverPublicKey);
    expect(request.followRedirects, isFalse);
    expect(
      Schnorr.verify(
        publicKey: body['npub'] as String,
        signature: body['signature'] as String,
        message: BackupServerProtocol.authHash(
          action: action,
          identity: body['npub'] as String,
          generation: body['generation'] as int? ?? 0,
          expectedEtag: body['expected_etag'] as String?,
          ciphertextHash: body['ciphertext_sha256'] as String?,
          ciphertextBytes: body['ciphertext_bytes'] as int? ?? 0,
          timestamp: body['timestamp'] as int,
        ),
      ),
      isTrue,
    );
  }

  test(
    'authentication and etags match the seven independent backend vectors',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/features/wallet_backup/data/fixtures/bull_backup_protocol_v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final raw in fixture['vectors'] as List) {
        final vector = raw as Map<String, dynamic>;
        final digest = BackupServerProtocol.authHash(
          action: vector['action'] as String,
          identity: fixture['npub'] as String,
          generation: vector['generation'] as int,
          expectedEtag: vector['expected_etag'] as String?,
          ciphertextHash: vector['ciphertext_sha256'] as String?,
          ciphertextBytes: vector['ciphertext_bytes'] as int,
          timestamp: vector['timestamp'] as int,
        );
        expect(
          digest,
          vector['signed_message_sha256'],
          reason: vector['name'] as String,
        );
        expect(
          Schnorr.verify(
            publicKey: fixture['npub'] as String,
            message: digest,
            signature: vector['signature'] as String,
          ),
          isTrue,
        );
        if (vector['result_etag'] != null) {
          expect(
            BackupServerProtocol.etag(
              identity: fixture['npub'] as String,
              generation: vector['generation'] as int,
              ciphertextHash: vector['ciphertext_sha256'] as String?,
            ),
            vector['result_etag'],
          );
        }
      }
    },
  );
  test(
    'fetch, conditional store and delete sign the actual request and verify acknowledgements',
    () async {
      adapter.respond = (_) =>
          reply({'version': 1, 'found': false, 'generation': 0, 'etag': null});
      final absent =
          (await repository.fetch(credential)
                  as Ok<WalletBackupRemoteHead, WalletBackupFailure>)
              .value;
      expect(absent.generation, 0);
      verifySignature(adapter.requests.last, 'backup-fetch');
      expect(adapter.requests.last.uri.path, '/api/v1/wallet-backups/fetch');
      adapter.respond = (_) =>
          reply({'version': 1, 'generation': 1, 'etag': etag(1)});
      expect(
        await repository.store(
          credential,
          ciphertext,
          generation: 1,
          expectedEtag: null,
        ),
        isA<Ok<WalletBackupCheckpoint, WalletBackupFailure>>(),
      );
      verifySignature(adapter.requests.last, 'backup-store');
      final body =
          jsonDecode(adapter.requests.last.data as String)
              as Map<String, dynamic>;
      expect(body.containsKey('expected_etag'), isTrue);
      expect(body['expected_etag'], isNull);
      expect(base64.decode(body['ciphertext'] as String), ciphertext.bytes);
      adapter.respond = (_) => reply({
        'version': 1,
        'generation': 2,
        'etag': etag(2, deleted: true),
      });
      expect(
        await repository.delete(
          credential,
          generation: 2,
          expectedEtag: etag(1),
        ),
        isA<Ok>(),
      );
      verifySignature(adapter.requests.last, 'backup-delete');
      expect(adapter.requests.last.method, 'DELETE');
    },
  );
  test(
    'live responses require matching length, hash and derived etag',
    () async {
      final live = {
        'version': 1,
        'found': true,
        'generation': 1,
        'etag': etag(1),
        'ciphertext': base64.encode(ciphertext.bytes),
        'ciphertext_sha256': ciphertext.hash,
        'ciphertext_bytes': ciphertext.length,
        'updated_at': now.millisecondsSinceEpoch ~/ 1000,
      };
      adapter.respond = (_) => reply(live);
      expect(
        (await repository.fetch(credential)
                as Ok<WalletBackupRemoteHead, WalletBackupFailure>)
            .value
            .ciphertext!
            .hash,
        ciphertext.hash,
      );
      for (final tamper in [
        <String, Object?>{'ciphertext_bytes': 1},
        {'ciphertext_sha256': '0' * 64},
        {'etag': '0' * 64},
        {'generation': 0},
        {'ciphertext': 'not base64'},
      ]) {
        adapter.respond = (_) => reply({...live, ...tamper});
        expect(await repository.fetch(credential), isA<Err>());
      }
    },
  );
  test('absent and tombstone states cannot conceal a live payload', () async {
    adapter.respond = (_) => reply({
      'version': 1,
      'found': false,
      'generation': 2,
      'etag': etag(2, deleted: true),
      'updated_at': now.millisecondsSinceEpoch ~/ 1000,
    });
    expect(await repository.fetch(credential), isA<Ok>());
    adapter.respond = (_) => reply({
      'version': 1,
      'found': false,
      'generation': 0,
      'etag': null,
      'ciphertext': base64.encode(ciphertext.bytes),
    });
    expect(await repository.fetch(credential), isA<Err>());
  });
  test(
    'one transport Retry-After gate covers fetch, store and delete',
    () async {
      adapter.respond = (_) => ResponseBody.fromString(
        '{}',
        429,
        headers: {
          'retry-after': ['30'],
        },
      );
      final first = await repository.fetch(credential);
      expect(first, isA<Err<WalletBackupRemoteHead, WalletBackupFailure>>());
      expect(
        await repository.store(
          credential,
          ciphertext,
          generation: 1,
          expectedEtag: null,
        ),
        isA<Err>(),
      );
      expect(
        await repository.delete(
          credential,
          generation: 2,
          expectedEtag: etag(1),
        ),
        isA<Err>(),
      );
      expect(adapter.requests, hasLength(1));
      now = now.add(const Duration(seconds: 29));
      expect(await repository.fetch(credential), isA<Err>());
      expect(adapter.requests, hasLength(1));
      now = now.add(const Duration(seconds: 1));
      adapter.respond = (_) =>
          reply({'version': 1, 'found': false, 'generation': 0, 'etag': null});
      expect(await repository.fetch(credential), isA<Ok>());
      expect(adapter.requests, hasLength(2));
    },
  );
  test(
    'HTTP-date retry, conflict and credential rejection preserve actionable failures',
    () async {
      adapter.respond = (_) => ResponseBody.fromString(
        '{}',
        429,
        headers: {
          'retry-after': [
            HttpDate.format(now.add(const Duration(seconds: 75))),
          ],
        },
      );
      final limited =
          await repository.fetch(credential)
              as Err<WalletBackupRemoteHead, WalletBackupFailure>;
      expect(
        (limited.failure as WalletBackupRateLimitedFailure).retryAt,
        now.add(const Duration(seconds: 75)),
      );
      now = now.add(const Duration(seconds: 75));
      adapter.respond = (_) => reply({}, status: 409);
      expect(
        (await repository.fetch(credential) as Err).failure,
        isA<WalletBackupConflictFailure>(),
      );
      adapter.respond = (_) => reply({}, status: 401);
      expect(
        (await repository.fetch(credential) as Err).failure,
        isA<WalletBackupCredentialFailure>(),
      );
    },
  );
  test(
    'streamed oversize and hanging responses are bounded and cancelled',
    () async {
      var closed = false;
      adapter.respond = (_) => ResponseBody(
        Stream.value(Uint8List(1572865)),
        200,
        onClose: () => closed = true,
      );
      expect(
        (await repository.fetch(credential) as Err).failure,
        isA<WalletBackupTooLargeFailure>(),
      );
      expect(closed, isTrue);
      final hanging = StreamController<Uint8List>();
      addTearDown(hanging.close);
      adapter.respond = (_) => ResponseBody(hanging.stream, 200);
      final short = WalletBackupRemoteRepositoryImpl(
        BackupServerHttpTransport(
          dio: dio,
          origin: Uri.parse('http://localhost'),
          timeout: const Duration(milliseconds: 30),
        ),
        now: () => now,
      );
      expect(
        (await short.fetch(credential) as Err).failure,
        isA<WalletBackupNetworkFailure>(),
      );
    },
  );
  test(
    'changed acknowledgements and invalid generations cannot be accepted',
    () async {
      adapter.respond = (_) =>
          reply({'version': 1, 'generation': 2, 'etag': etag(2)});
      expect(
        await repository.store(
          credential,
          ciphertext,
          generation: 1,
          expectedEtag: null,
        ),
        isA<Err>(),
      );
      final count = adapter.requests.length;
      expect(
        await repository.store(
          credential,
          ciphertext,
          generation: 0,
          expectedEtag: null,
        ),
        isA<Err>(),
      );
      expect(
        await repository.delete(
          credential,
          generation: 2,
          expectedEtag: 'not-an-etag',
        ),
        isA<Err>(),
      );
      expect(adapter.requests, hasLength(count));
    },
  );
}
