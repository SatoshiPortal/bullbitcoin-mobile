import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/data/descriptor_backup_http_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/private_descriptor_record.dart';
import 'package:bb_mobile/features/wallet_backup/domain/private_descriptor_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// The descriptor record contract's worked example. The secret key behind this
/// publisher is the well-known test value 0x…02; it holds no funds.
const _npub =
    'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
const _ciphertextBase64 = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=';
const _ciphertextSha256 =
    '630dcd2966c4336691125448bbb25b4ff412a49c732db2c8abc1b8581bd710dd';
const _timestamp = 1700000000;
const _tokens = [
  '450cd9cbf7106322d2fb54e832e887b40c184b20fc9e3c00713cc028ad0a33b0',
  '5584950beaee85f952a735b5ce757c3748c3e6d14126e2cdee4e404d04c9eaf8',
  'f958bb05dfc2e285bba3ea769d919e234478148eb520a77e77f2eaf803768237',
];
const _signingMessageDigest =
    '998b66f190914e030659666f5930469dcd251f50b7447da250c5b270dc3f601c';
const _signature =
    '846c726739dfd0436434c8b6a4c8b9e747f6516adcdf69bb1548fb65e82099143eb4'
    '0273d80c3565441558f2c049a3af57f84319a81f19c177dec64ecd58be8a';

final _ciphertext = Uint8List.fromList(base64.decode(_ciphertextBase64));

void main() {
  final authentication = WalletBackupAuthentication(
    publicKeyHex: _npub,
    signatureHex: _signature,
    timestamp: _timestamp,
  );

  test('signs the exact bytes the contract pins', () {
    final message = buildPrivateDescriptorSigningMessage(
      publicKeyHex: _npub,
      ciphertextSha256: _ciphertextSha256,
      ciphertextBytes: _ciphertext.length,
      lookupTokens: _tokens,
      timestamp: _timestamp,
    );
    expect(message, isNotNull);
    expect(utf8.decode(message!).split('\u0000'), [
      privateDescriptorAuthenticationDomain,
      privateDescriptorStoreAction,
      _npub,
      _ciphertextSha256,
      '32',
      '3',
      ..._tokens,
      '$_timestamp',
    ]);
    final digest = sha256.convert(message);
    expect(digest.toString(), _signingMessageDigest);
    // The published signature verifies over that digest, so these really are
    // the bytes the server authenticates.
    expect(
      ECPublic.fromHex('02$_npub').verifyBip340Signature(
        digest: digest.bytes,
        signature: hex.decode(_signature),
        tweak: false,
      ),
      isTrue,
    );
    // A wallet backup signature can never be replayed here, and the reverse is
    // equally impossible.
    expect(
      privateDescriptorAuthenticationDomain,
      isNot(walletBackupAuthenticationDomain),
    );
  });

  test('an unsignable request is never sent', () {
    for (final tokens in [
      <String>[],
      [_tokens[1], _tokens[0]],
      [_tokens[0], _tokens[0]],
      [_tokens[0].toUpperCase()],
      List.filled(privateDescriptorMaxTokens + 1, _tokens[0]),
    ]) {
      expect(
        buildPrivateDescriptorSigningMessage(
          publicKeyHex: _npub,
          ciphertextSha256: _ciphertextSha256,
          ciphertextBytes: 32,
          lookupTokens: tokens,
          timestamp: _timestamp,
        ),
        isNull,
        reason: tokens.toString(),
      );
    }
  });

  test(
    'store sends the contract body and takes only its own receipt',
    () async {
      final harness = _Harness({
        'version': 1,
        'ciphertext_sha256': _ciphertextSha256,
        'created_at': _timestamp,
      });
      final result = await harness.repository.store(
        authentication: authentication,
        ciphertext: _ciphertext,
        lookupTokens: _tokens,
      );
      expect(
        result,
        isA<Ok<DateTime, WalletBackupFailure>>().having(
          (value) => value.value,
          'created at',
          DateTime.utc(2023, 11, 14, 22, 13, 20),
        ),
      );
      expect(harness.request.method, 'POST');
      expect(
        harness.request.uri.toString(),
        'https://backup.example/api/v1/descriptor-backups',
      );
      expect(harness.request.followRedirects, isFalse);
      expect(harness.request.data, {
        'version': 1,
        'npub': _npub,
        'ciphertext': _ciphertextBase64,
        'ciphertext_sha256': _ciphertextSha256,
        'ciphertext_bytes': 32,
        'lookup_tokens': _tokens,
        'timestamp': _timestamp,
        'signature': _signature,
      });

      harness.response = {
        'version': 1,
        'ciphertext_sha256': 'f' * 64,
        'created_at': _timestamp,
      };
      expect(
        await harness.repository.store(
          authentication: authentication,
          ciphertext: _ciphertext,
          lookupTokens: _tokens,
        ),
        isA<Err<DateTime, WalletBackupFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<WalletBackupInvalidRemoteFailure>(),
        ),
      );
    },
  );

  test('an uncanonical token set never reaches the server', () async {
    final harness = _Harness(const <String, Object?>{});
    for (final tokens in [
      [_tokens[1], _tokens[0]],
      [_tokens[0], _tokens[0]],
      <String>[],
    ]) {
      expect(
        await harness.repository.store(
          authentication: authentication,
          ciphertext: _ciphertext,
          lookupTokens: tokens,
        ),
        isA<Err<DateTime, WalletBackupFailure>>(),
      );
      expect(
        await harness.repository.lookup(tokens),
        isA<Err<PrivateDescriptorLookupPage, WalletBackupFailure>>(),
      );
    }
    expect(harness.requestCount, 0);
  });

  test('lookup is unsigned and returns verified candidates', () async {
    final harness = _Harness({
      'version': 1,
      'next_cursor': null,
      'records': [
        {
          'ciphertext': _ciphertextBase64,
          'ciphertext_sha256': _ciphertextSha256,
          'ciphertext_bytes': 32,
          'created_at': _timestamp,
        },
      ],
    });
    final result = await harness.repository.lookup([_tokens.first]);
    expect(
      harness.request.uri.toString(),
      'https://backup.example/api/v1/descriptor-backups/lookup',
    );
    expect(harness.request.data, {
      'version': 1,
      'lookup_tokens': [_tokens.first],
    });
    expect(result, isA<Ok<PrivateDescriptorLookupPage, WalletBackupFailure>>());
    final lookup =
        (result as Ok<PrivateDescriptorLookupPage, WalletBackupFailure>).value;
    expect(lookup.nextCursor, isNull);
    expect(lookup.records.single.ciphertext, _ciphertext);
    expect(lookup.records.single.ciphertextSha256, _ciphertextSha256);
  });

  test('a page that stopped carries its cursor back unchanged', () async {
    final harness = _Harness({
      'version': 1,
      'next_cursor': 'AQAAAAAAAAPoAAAAAAAAAAAAAAAAAAAAAA==',
      'records': <Object?>[],
    });

    final result = await harness.repository.lookup([_tokens.first]);

    expect(
      result,
      isA<Ok<PrivateDescriptorLookupPage, WalletBackupFailure>>()
          .having(
            (value) => value.value.nextCursor,
            'next cursor',
            'AQAAAAAAAAPoAAAAAAAAAAAAAAAAAAAAAA==',
          )
          .having((value) => value.value.records, 'records', isEmpty),
    );

    await harness.repository.lookup([
      _tokens.first,
    ], cursor: 'AQAAAAAAAAPoAAAAAAAAAAAAAAAAAAAAAA==');

    expect(harness.request.data, {
      'version': 1,
      'lookup_tokens': [_tokens.first],
      'cursor': 'AQAAAAAAAAPoAAAAAAAAAAAAAAAAAAAAAA==',
    });
  });

  test('a page longer than this client holds is never decoded', () async {
    final harness = _Harness({
      'version': 1,
      'next_cursor': null,
      'records': [
        for (
          var index = 0;
          index < privateDescriptorMaxRecordsPerPage + 1;
          index++
        )
          {
            'ciphertext': _ciphertextBase64,
            'ciphertext_sha256': _ciphertextSha256,
            'ciphertext_bytes': 32,
            'created_at': _timestamp,
          },
      ],
    });

    expect(
      await harness.repository.lookup([_tokens.first]),
      isA<Err<PrivateDescriptorLookupPage, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupInvalidRemoteFailure>(),
      ),
    );
  });

  test('a response past the read bound is refused, not buffered', () async {
    final harness = _Harness(
      null,
      rawBody:
          '{"version":1,"next_cursor":null,"records":[],"padding":"'
          '${'a' * (privateDescriptorMaxLookupResponseBytes + 1)}"}',
    );

    expect(
      await harness.repository.lookup([_tokens.first]),
      isA<Err<PrivateDescriptorLookupPage, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupInvalidRemoteFailure>(),
      ),
    );
  });

  test('a record that is not what it says it is fails the response', () async {
    for (final record in [
      // Hash of something else.
      {
        'ciphertext': _ciphertextBase64,
        'ciphertext_sha256': 'a' * 64,
        'ciphertext_bytes': 32,
        'created_at': _timestamp,
      },
      // Byte count of something else.
      {
        'ciphertext': _ciphertextBase64,
        'ciphertext_sha256': _ciphertextSha256,
        'ciphertext_bytes': 31,
        'created_at': _timestamp,
      },
      // Non-canonical base64: two spellings would name one record.
      {
        'ciphertext': '$_ciphertextBase64\n',
        'ciphertext_sha256': _ciphertextSha256,
        'ciphertext_bytes': 32,
        'created_at': _timestamp,
      },
      // An unknown field is a protocol this client does not speak.
      {
        'ciphertext': _ciphertextBase64,
        'ciphertext_sha256': _ciphertextSha256,
        'ciphertext_bytes': 32,
        'created_at': _timestamp,
        'publisher': _npub,
      },
    ]) {
      final harness = _Harness({
        'version': 1,
        'next_cursor': null,
        'records': [record],
      });
      expect(
        await harness.repository.lookup([_tokens.first]),
        isA<Err<PrivateDescriptorLookupPage, WalletBackupFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<WalletBackupInvalidRemoteFailure>(),
        ),
        reason: record.toString(),
      );
    }
  });

  test('every documented error code has one meaning', () async {
    const mapping = {
      (400, 'DescriptorInvalidRequest'): WalletBackupRemoteRejectedFailure,
      (401, 'DescriptorAuthError'): WalletBackupSigningFailure,
      (403, 'DescriptorPublisherQuotaExceeded'):
          WalletBackupPublisherQuotaFailure,
      (409, 'DescriptorRecordConflict'): WalletBackupHeadConflictFailure,
      (413, 'DescriptorBlobTooLarge'): WalletBackupTooLargeFailure,
      (503, 'DescriptorCapacityExceeded'): WalletBackupRemoteUnavailableFailure,
      (500, 'InternalError'): WalletBackupRemoteUnavailableFailure,
      // A wallet backup code is never a descriptor answer.
      (400, 'BackupInvalidRequest'): WalletBackupInvalidRemoteFailure,
    };
    for (final entry in mapping.entries) {
      final harness = _Harness({
        'status': 'ERROR',
        'code': entry.key.$2,
        'reason': 'private backend text',
      }, statusCode: entry.key.$1);
      final result = await harness.repository.lookup([_tokens.first]);
      expect(
        (result as Err).failure.runtimeType,
        entry.value,
        reason: entry.key.toString(),
      );
    }
  });

  test('a rate limit closes the local gate for as long as it asked', () async {
    final harness = _Harness(
      {
        'status': 'ERROR',
        'code': 'DescriptorRateLimited',
        'reason': 'private backend text',
      },
      statusCode: 429,
      headers: Headers.fromMap({
        'retry-after': ['120'],
      }),
      now: () => DateTime.utc(2027),
    );
    expect(
      await harness.repository.lookup([_tokens.first]),
      isA<Err<PrivateDescriptorLookupPage, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupRateLimitedFailure>().having(
          (failure) => failure.retryAfter,
          'retry after',
          const Duration(seconds: 120),
        ),
      ),
    );
    expect(harness.requestCount, 1);
    expect(
      await harness.repository.lookup([_tokens.first]),
      isA<Err<PrivateDescriptorLookupPage, WalletBackupFailure>>(),
    );
    expect(harness.requestCount, 1, reason: 'the gate answered locally');
  });
}

final class _Harness {
  Object? response;

  /// A body sent as it stands, for answers no JSON encoder would produce.
  String? rawBody;
  final int statusCode;
  final Headers headers;
  late RequestOptions request;
  late final DescriptorBackupHttpRepository repository;
  int requestCount = 0;

  _Harness(
    this.response, {
    this.statusCode = 200,
    Headers? headers,
    DateTime Function()? now,
    this.rawBody,
  }) : headers = headers ?? Headers() {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            request = options;
            handler.resolve(
              Response<ResponseBody>(
                requestOptions: options,
                statusCode: statusCode,
                headers: this.headers,
                data: ResponseBody.fromString(
                  rawBody ?? jsonEncode(response),
                  statusCode,
                ),
              ),
            );
          },
        ),
      );
    repository = DescriptorBackupHttpRepository.fromDio(
      dio,
      () async => Uri.parse('https://backup.example'),
      now: now,
    );
  }
}
