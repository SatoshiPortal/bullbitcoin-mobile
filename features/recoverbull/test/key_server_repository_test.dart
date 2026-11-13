import 'dart:io';
import 'dart:convert';

import 'package:bull_recoverbull/src/data/key_server_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

void main() {
  late HttpServer server;
  late KeyServerRepositoryImpl repository;
  var status = 200;
  var body = 'not JSON';
  var closed = 0;
  String? storedEnvelope;
  var roundTrip = false;

  setUp(() async {
    status = 200;
    body = 'not JSON';
    closed = 0;
    storedEnvelope = null;
    roundTrip = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (roundTrip) {
        final payload =
            jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        if (request.uri.path == '/store') {
          storedEnvelope = payload['encrypted_secret'] as String;
          request.response.statusCode = 201;
        } else {
          request.response.write(
            jsonEncode({
              'encrypted_secret': storedEnvelope,
              'attempt_status': {
                'version': 1,
                'total_attempts': 1,
                'total_requests': 2,
                'failed_attempts': 0,
                'remaining_attempts': 4,
                'window_started_at': '2026-11-09T00:01:02Z',
                'resets_at': '2026-11-09T12:01:02Z',
              },
            }),
          );
        }
        await request.response.close();
        return;
      }
      request.response.statusCode = status;
      request.response.headers.set('Retry-After', '15');
      request.response.write(body);
      await request.response.close();
    });
    repository = KeyServerRepositoryImpl(
      server: Uri.parse('http://127.0.0.1:${server.port}'),
      transport: HttpClient(),
      releaseRoute: () async => closed++,
    );
  });

  tearDown(() async {
    await repository.close();
    await server.close(force: true);
  });

  test('malformed info crosses the real client as badResponse', () async {
    final result = await repository.probe();
    expect(result, isA<Err<void, RecoverBullFailure>>());
    switch (result) {
      case Err(failure: KeyServerFailure(:final kind)):
        expect(kind, KeyServerFailureKind.badResponse);
      default:
        fail('Expected a typed server failure');
    }
  });

  test('outage retains backoff without becoming a targeted lockout', () async {
    status = 503;
    final result = await repository.attempts({'ab' * 32});
    switch (result) {
      case Err(failure: KeyServerFailure(:final kind, :final retryAfter)):
        expect(kind, KeyServerFailureKind.unavailable);
        expect(retryAfter, const Duration(seconds: 15));
      default:
        fail('Expected an unavailable server');
    }
  });

  test('close releases the owned route exactly once', () async {
    await Future.wait([repository.close(), repository.close()]);
    expect(closed, 1);
    expect(await repository.probe(), isA<Err<void, RecoverBullFailure>>());
  });

  test('only a targeted 429 is a lockout', () async {
    status = 429;
    final poll = await repository.attempts({'ab' * 32});
    switch (poll) {
      case Err(failure: KeyServerFailure(:final kind)):
        expect(kind, KeyServerFailureKind.unavailable);
      default:
        fail('Expected unavailable telemetry');
    }
    final vault = EncryptedVault(
      id: '11' * 32,
      salt: '22' * 16,
      ciphertext: List.filled(64, 0),
      createdAt: DateTime.utc(2026),
    );
    switch (await repository.fetch(vault, 'synthetic password')) {
      case Err(failure: KeyServerFailure(:final kind)):
        expect(kind, KeyServerFailureKind.locked);
      default:
        fail('Expected targeted lockout');
    }
  });

  test('fetch preserves authenticated key and exact attempt status', () async {
    roundTrip = true;
    final vault = EncryptedVault(
      id: '11' * 32,
      salt: '22' * 16,
      ciphertext: List.filled(64, 0),
      createdAt: DateTime.utc(2026),
    );
    final key = VaultKey('ab' * 32);
    expect(await repository.store(vault, 'synthetic password', key), isA<Ok>());
    switch (await repository.fetch(vault, 'synthetic password')) {
      case Ok(:final value):
        expect(value.key.hex, key.hex);
        expect(value.observation?.requests, 2);
        expect(value.observation?.attempts, 1);
        expect(
          value.observation?.windowStartedAt,
          DateTime.utc(2026, 11, 9, 0, 1, 2),
        );
      case Err():
        fail('Expected authenticated fetch');
    }
  });
}
