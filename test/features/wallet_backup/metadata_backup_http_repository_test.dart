import 'dart:convert';

import 'package:bb_mobile/features/wallet_backup/data/metadata_backup_http_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _publicKey =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _signature =
    '23c0d3cdf2b0592cebb3ba46ed6ed1e91c1c3e06a93641091e588a86d0241129'
    '892e75738f6dba21739478e4e684d60bb267e5d0af695c0747d4bd084ad77812';

void main() {
  final authentication = WalletBackupAuthentication(
    publicKeyHex: _publicKey,
    signatureHex: _signature,
    timestamp: 1700000000,
  );

  test('fetch uses the frozen route and exact request fields', () async {
    final harness = _Harness({
      'version': 1,
      'found': false,
      'generation': 0,
      'etag': null,
    });
    final result = await harness.repository.fetch(
      authentication: authentication,
    );
    expect(result, isA<Ok<WalletBackupRemoteHead, WalletBackupFailure>>());
    expect(harness.request.method, 'POST');
    expect(
      harness.request.uri.toString(),
      'https://backup.example/api/v1/wallet-backups/fetch',
    );
    expect(harness.request.data, {
      'version': 1,
      'stream': 'wallet_backup',
      'npub': _publicKey,
      'timestamp': 1700000000,
      'signature': _signature,
    });
    expect(harness.request.followRedirects, isFalse);
  });

  test('store accepts only the locally expected receipt', () async {
    final bytes = List<int>.filled(64, 1);
    final ciphertext = WalletBackupCiphertext(base64.encode(bytes));
    final hash = sha256.convert(bytes).toString();
    final expectedEtag = computeWalletBackupEtag(
      publicKeyHex: _publicKey,
      generation: 1,
      ciphertextSha256: hash,
    )!;
    final harness = _Harness({
      'version': 1,
      'generation': 1,
      'etag': expectedEtag,
    });
    final result = await harness.repository.store(
      authentication: authentication,
      current: null,
      ciphertext: ciphertext,
      ciphertextSha256: hash,
    );
    expect(
      result,
      isA<Ok<WalletBackupRemoteCheckpoint, WalletBackupFailure>>().having(
        (value) => value.value.generation,
        'acknowledged generation',
        1,
      ),
    );
    final body = harness.request.data as Map<String, Object?>;
    expect(body['expected_etag'], isNull);
    expect(body['ciphertext_bytes'], 64);

    harness.response = {'version': 1, 'generation': 2, 'etag': expectedEtag};
    expect(
      await harness.repository.store(
        authentication: authentication,
        current: null,
        ciphertext: ciphertext,
        ciphertextSha256: hash,
      ),
      isA<Err<WalletBackupRemoteCheckpoint, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupInvalidRemoteFailure>(),
      ),
    );
  });

  test('verifies fetched ciphertext, hash, byte count, and ETag', () async {
    final bytes = List<int>.generate(64, (index) => index);
    final encoded = base64.encode(bytes);
    final hash = sha256.convert(bytes).toString();
    final etag = computeWalletBackupEtag(
      publicKeyHex: _publicKey,
      generation: 3,
      ciphertextSha256: hash,
    )!;
    final harness = _Harness({
      'version': 1,
      'found': true,
      'generation': 3,
      'etag': etag,
      'ciphertext': encoded,
      'ciphertext_sha256': hash,
      'ciphertext_bytes': 64,
      'updated_at': 1700000000,
    });
    expect(
      await harness.repository.fetch(authentication: authentication),
      isA<Ok<WalletBackupRemoteHead, WalletBackupFailure>>(),
    );
    harness.response = {
      ...harness.response as Map<String, Object?>,
      'ciphertext_bytes': 63,
    };
    expect(
      await harness.repository.fetch(authentication: authentication),
      isA<Err<WalletBackupRemoteHead, WalletBackupFailure>>(),
    );
  });

  test(
    'honors Retry-After locally without a timer or second request',
    () async {
      var now = DateTime.utc(2026);
      final harness = _Harness(
        {'status': 'ERROR', 'code': 'RateLimited', 'reason': 'retry'},
        statusCode: 429,
        headers: Headers.fromMap({
          'retry-after': ['10'],
        }),
        now: () => now,
      );
      expect(
        await harness.repository.fetch(authentication: authentication),
        isA<Err<WalletBackupRemoteHead, WalletBackupFailure>>(),
      );
      expect(harness.requestCount, 1);
      expect(
        await harness.repository.fetch(authentication: authentication),
        isA<Err<WalletBackupRemoteHead, WalletBackupFailure>>(),
      );
      expect(harness.requestCount, 1);
      now = now.add(const Duration(seconds: 10));
      await harness.repository.fetch(authentication: authentication);
      expect(harness.requestCount, 2);
    },
  );

  test('maps every frozen server error without exposing reason text', () async {
    final cases = <(int, String, Type)>[
      (400, 'BackupInvalidRequest', WalletBackupRemoteRejectedFailure),
      (401, 'BackupAuthError', WalletBackupSigningFailure),
      (409, 'BackupHeadConflict', WalletBackupHeadConflictFailure),
      (413, 'BackupBlobTooLarge', WalletBackupTooLargeFailure),
      (503, 'BackupCapacityExceeded', WalletBackupRemoteUnavailableFailure),
      (500, 'InternalError', WalletBackupRemoteUnavailableFailure),
    ];
    for (final (status, code, type) in cases) {
      final harness = _Harness({
        'status': 'ERROR',
        'code': code,
        'reason': 'private backend text',
      }, statusCode: status);
      final result = await harness.repository.fetch(
        authentication: authentication,
      );
      expect((result as Err).failure.runtimeType, type, reason: code);
    }
  });

  test('maps an invalid configured origin without making a request', () async {
    final harness = _Harness(
      const <String, Object?>{},
      origin: () async => throw const _InvalidOrigin(),
    );

    expect(
      await harness.repository.fetch(authentication: authentication),
      isA<Err<WalletBackupRemoteHead, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupInvalidServerOriginFailure>(),
      ),
    );
    expect(harness.requestCount, 0);
  });
}

final class _Harness {
  Object? response;
  final int statusCode;
  final Headers headers;
  late RequestOptions request;
  late final MetadataBackupHttpRepository repository;
  int requestCount = 0;

  _Harness(
    this.response, {
    this.statusCode = 200,
    Headers? headers,
    DateTime Function()? now,
    Future<Uri> Function()? origin,
  }) : headers = headers ?? Headers() {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            request = options;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: statusCode,
                headers: this.headers,
                data: response,
              ),
            );
          },
        ),
      );
    repository = MetadataBackupHttpRepository(
      dio,
      origin ?? () async => Uri.parse('https://backup.example'),
      now: now,
    );
  }
}

final class _InvalidOrigin implements Exception {
  const _InvalidOrigin();
}
