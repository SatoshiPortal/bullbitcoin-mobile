import 'dart:typed_data';
import 'dart:async';

import 'package:bull_recoverbull/src/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/data/recoverbull_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;
import 'dart:io';

import 'package:bull_tor/tor.dart';
import '../support/log_sink.dart';

class _MockRemote extends Mock implements RecoverBullRemoteDatasource {}

class _MockSettings extends Mock implements RecoverbullSettingsDatasource {}

RecoverBullTorRoute _fallbackRoute() => RecoverBullTorRoute(
  TorRoute(
    source: TorSource.embedded,
    endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9050),
    evidence: TorReadinessEvidence.embeddedBootstrap,
  ),
  () async {},
  HttpClient(),
);

void main() {
  final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9050);

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(endpoint);
    registerFallbackValue(_fallbackRoute());
  });

  late _MockRemote remote;
  late RecoverBullRepositoryImpl repository;
  late RecoverBullTorRoute route;
  late TestLogSink logSink;

  setUp(() {
    remote = _MockRemote();
    logSink = TestLogSink.recording();
    repository = RecoverBullRepositoryImpl(
      log: logSink,
      remoteDatasource: remote,
      recoverbullSettingsDatasource: _MockSettings(),
    );
    route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: endpoint,
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      () async {},
      HttpClient(),
    );
  });

  void stubFetchThrows(Object error) {
    when(
      () => remote.fetch(any(), any(), any(), route: any(named: 'route')),
    ).thenThrow(error);
  }

  void stubFetchWithStatusThrows(Object error) {
    when(
      () => remote.fetchWithStatus(
        any(),
        any(),
        any(),
        route: any(named: 'route'),
      ),
    ).thenThrow(error);
  }

  // identifier/salt must be valid hex (the repo HEX-decodes them).
  Future<Result<String, RecoverBullFailure>> fetch() =>
      repository.fetchVaultKey('00', 'password', '00', route);

  group('RecoverBullRepository.fetchVaultKey maps KeyServerException', () {
    test('401 -> KeyServerInvalidCredentialsFailure (no raw leak)', () async {
      stubFetchThrows(
        recoverbull.KeyServerException(code: 401, message: 'unauthorized xyz'),
      );

      final result = await fetch();

      expect(result, isA<Err<String, RecoverBullFailure>>());
      final failure = (result as Err<String, RecoverBullFailure>).failure;
      expect(failure, isA<KeyServerInvalidCredentialsFailure>());
      expect(
        logSink.entries.single.message,
        'recoverbull.key.fetch.invalid_credentials code=401',
      );
      expect(logSink.entries.single.level, 'warning');
    });

    test('429 -> KeyServerRateLimitedFailure with retryIn', () async {
      stubFetchThrows(
        recoverbull.KeyServerException(
          code: 429,
          requestedAt: DateTime.utc(2020),
          cooldownInMinutes: 5,
        ),
      );

      final result = await fetch();

      final failure = (result as Err<String, RecoverBullFailure>).failure;
      expect(failure, isA<KeyServerRateLimitedFailure>());
      expect((failure as KeyServerRateLimitedFailure).retryIn, isNotNull);
      expect(
        logSink.entries.single.message,
        'recoverbull.key.fetch.rate_limited code=429 attempts=unknown retry_after_seconds=unknown',
      );
    });

    test('429 without cooldown -> retryIn null (no NPE)', () async {
      stubFetchThrows(recoverbull.KeyServerException(code: 429));

      final result = await fetch();

      final failure = (result as Err<String, RecoverBullFailure>).failure;
      expect(failure, isA<KeyServerRateLimitedFailure>());
      expect((failure as KeyServerRateLimitedFailure).retryIn, isNull);
      expect(
        logSink.entries.single.message,
        'recoverbull.key.fetch.rate_limited code=429 attempts=unknown retry_after_seconds=unknown',
      );
    });

    test('429 prefers the server Retry-After value', () async {
      const retryAfter = Duration(seconds: 47);
      stubFetchThrows(
        recoverbull.KeyServerException(
          code: 429,
          retryAfter: retryAfter,
          requestedAt: DateTime.utc(2020),
          cooldownInMinutes: 5,
        ),
      );

      final result = await fetch();
      final failure =
          (result as Err<String, RecoverBullFailure>).failure
              as KeyServerRateLimitedFailure;

      expect(failure, isA<KeyServerRateLimitedFailure>());
      expect(failure.retryIn, retryAfter);
    });

    test('other 4xx -> KeyServerRejectedFailure', () async {
      stubFetchThrows(recoverbull.KeyServerException(code: 403));

      final result = await fetch();

      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<KeyServerRejectedFailure>(),
      );
    });

    test('5xx -> KeyServerUnavailableFailure', () async {
      stubFetchThrows(recoverbull.KeyServerException(code: 503));

      final result = await fetch();

      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
      expect(
        logSink.entries.single.message,
        'recoverbull.key.fetch.unavailable code=503',
      );
    });

    test('null code -> KeyServerUnavailableFailure', () async {
      stubFetchThrows(recoverbull.KeyServerException());

      final result = await fetch();

      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
      expect(
        logSink.entries.single.message,
        'recoverbull.key.fetch.unavailable code=unknown',
      );
    });
  });

  test('non-KeyServer error -> RecoverBullUnexpectedFailure', () async {
    stubFetchThrows(Exception('socket: 1.2.3.4 reset'));

    final result = await fetch();

    final failure = (result as Err<String, RecoverBullFailure>).failure;
    expect(failure, isA<RecoverBullUnexpectedFailure>());
    expect(
      logSink.entries.single.message,
      startsWith('recoverbull.key.fetch.unexpected error_type='),
    );
    expect(logSink.entries.single.error, isNull);
    expect(logSink.entries.single.trace, isNotNull);
  });

  test('fetch timeout is a classified warning', () async {
    stubFetchThrows(TimeoutException('timed out'));

    await fetch();

    expect(logSink.entries.single.message, 'recoverbull.key.fetch.timeout');
    expect(logSink.entries.single.level, 'warning');
  });

  test(
    'fetchWithStatus timeout returns unavailable and logs a warning',
    () async {
      stubFetchWithStatusThrows(TimeoutException('sentinel timeout'));

      final result = await repository.fetchVaultKeyWithStatus(
        '00',
        'password',
        '00',
        route,
      );

      expect(
        (result as Err<VaultKeyFetchResult, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
      expect(logSink.entries.single.message, 'recoverbull.key.fetch.timeout');
    },
  );

  test('fetchWithStatus logs safe rate-limit metadata', () async {
    stubFetchWithStatusThrows(
      recoverbull.KeyServerException(
        code: 429,
        attempts: 3,
        retryAfter: const Duration(seconds: 47),
        message: 'sentinel payload',
      ),
    );

    await repository.fetchVaultKeyWithStatus('00', 'password', '00', route);

    expect(
      logSink.entries.single.message,
      'recoverbull.key.fetch.rate_limited code=429 attempts=3 retry_after_seconds=47',
    );
    expect(logSink.entries.single.error, isNull);
  });

  test(
    'fetchWithStatus success logs the absence of attempt metadata',
    () async {
      when(
        () => remote.fetchWithStatus(
          any(),
          any(),
          any(),
          route: any(named: 'route'),
        ),
      ).thenAnswer(
        (_) async => recoverbull.FetchBackupKeyResult(
          backupKey: [0xab, 0xcd],
          attemptStatus: null,
        ),
      );

      final result = await repository.fetchVaultKeyWithStatus(
        '00',
        'password',
        '00',
        route,
      );

      expect(result, isA<Ok<VaultKeyFetchResult, RecoverBullFailure>>());
      expect(
        logSink.entries.single.message,
        'recoverbull.key.fetch.succeeded attempt_status=absent '
        'attempts_total=unknown attempts_failed=unknown '
        'attempts_remaining=unknown',
      );
    },
  );

  test(
    'trashWithStatus timeout returns unavailable and logs a warning',
    () async {
      when(
        () => remote.trashWithStatus(
          any(),
          any(),
          any(),
          route: any(named: 'route'),
        ),
      ).thenThrow(TimeoutException('sentinel timeout'));

      final result = await repository.trashVaultKeyWithStatus(
        '00',
        'password',
        '00',
        route,
      );

      expect(
        (result as Err<VaultKeyFetchResult, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
      expect(logSink.entries.single.message, 'recoverbull.key.trash.timeout');
      expect(logSink.entries.single.level, 'warning');
    },
  );

  test(
    'expected errors are classified once and never expose input secrets',
    () async {
      const secret = 'sentinel-secret';
      stubFetchThrows(
        recoverbull.KeyServerException(code: 401, message: secret),
      );

      await repository.fetchVaultKey(secret, secret, '00', route);

      expect(logSink.entries, hasLength(1));
      expect(logSink.entries.single.message, isNot(contains(secret)));
      expect(logSink.entries.single.error, isNull);
    },
  );

  group('store and trash classify key-server failures safely', () {
    final expectedCases = <({int? code, Matcher failure, String event})>[
      (
        code: 401,
        failure: isA<KeyServerInvalidCredentialsFailure>(),
        event: 'invalid_credentials code=401',
      ),
      (
        code: 429,
        failure: isA<KeyServerRateLimitedFailure>(),
        event: 'rate_limited code=429 attempts=3 retry_after_seconds=47',
      ),
      (
        code: 503,
        failure: isA<KeyServerUnavailableFailure>(),
        event: 'unavailable code=503',
      ),
      (
        code: null,
        failure: isA<KeyServerUnavailableFailure>(),
        event: 'unavailable code=unknown',
      ),
    ];

    recoverbull.KeyServerException exceptionFor(int? code) =>
        recoverbull.KeyServerException(
          code: code,
          attempts: code == 429 ? 3 : null,
          retryAfter: code == 429 ? const Duration(seconds: 47) : null,
          message: 'sentinel server payload',
        );

    for (final expected in expectedCases) {
      test('store classifies code ${expected.code ?? 'unknown'}', () async {
        when(
          () => remote.store(
            any(),
            any(),
            any(),
            any(),
            route: any(named: 'route'),
          ),
        ).thenThrow(exceptionFor(expected.code));

        final result = await repository.storeVaultKey(
          '00',
          'password',
          '00',
          '00',
          route,
        );

        expect(
          (result as Err<Null, RecoverBullFailure>).failure,
          expected.failure,
        );
        expect(
          logSink.entries.single.message,
          'recoverbull.key.store.${expected.event}',
        );
        expect(logSink.entries.single.level, 'warning');
        expect(logSink.entries.single.message, isNot(contains('sentinel')));
        expect(logSink.entries.single.error, isNull);
      });

      test('trash classifies code ${expected.code ?? 'unknown'}', () async {
        when(
          () => remote.trashWithStatus(
            any(),
            any(),
            any(),
            route: any(named: 'route'),
          ),
        ).thenThrow(exceptionFor(expected.code));

        final result = await repository.trashVaultKeyWithStatus(
          '00',
          'password',
          '00',
          route,
        );

        expect(
          (result as Err<VaultKeyFetchResult, RecoverBullFailure>).failure,
          expected.failure,
        );
        expect(
          logSink.entries.single.message,
          'recoverbull.key.trash.${expected.event}',
        );
        expect(logSink.entries.single.level, 'warning');
        expect(logSink.entries.single.message, isNot(contains('sentinel')));
        expect(logSink.entries.single.error, isNull);
      });
    }

    test('store timeout is an unavailable warning', () async {
      when(
        () => remote.store(
          any(),
          any(),
          any(),
          any(),
          route: any(named: 'route'),
        ),
      ).thenThrow(TimeoutException('sentinel timeout'));

      final result = await repository.storeVaultKey(
        '00',
        'password',
        '00',
        '00',
        route,
      );

      expect(
        (result as Err<Null, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
      expect(logSink.entries.single.message, 'recoverbull.key.store.timeout');
      expect(logSink.entries.single.level, 'warning');
    });

    test('unexpected store exception exposes only its type', () async {
      when(
        () => remote.store(
          any(),
          any(),
          any(),
          any(),
          route: any(named: 'route'),
        ),
      ).thenThrow(StateError('sentinel payload'));

      await repository.storeVaultKey('00', 'password', '00', '00', route);

      expect(
        logSink.entries.single.message,
        'recoverbull.key.store.unexpected error_type=StateError',
      );
      expect(logSink.entries.single.error, isNull);
      expect(
        logSink.entries.single.trace.toString(),
        isNot(contains('sentinel')),
      );
    });

    test('unexpected trash exception exposes only its type', () async {
      when(
        () => remote.trashWithStatus(
          any(),
          any(),
          any(),
          route: any(named: 'route'),
        ),
      ).thenThrow(StateError('sentinel payload'));

      await repository.trashVaultKeyWithStatus('00', 'password', '00', route);

      expect(
        logSink.entries.single.message,
        'recoverbull.key.trash.unexpected error_type=StateError',
      );
      expect(logSink.entries.single.error, isNull);
      expect(
        logSink.entries.single.trace.toString(),
        isNot(contains('sentinel')),
      );
    });
  });

  test(
    'createVault derives, assembles, and preserves the path in an isolate',
    () async {
      final mnemonic = Mnemonic.fromWords(
        words: List.generate(11, (index) => 'zoo') + ['wrong'],
      );
      final rootXprv = Bip32Keys.fromSeed(
        Uint8List.fromList(mnemonic.seed),
      ).toBase58();
      const path = "1608'/0'/632486385'";
      const expectedVaultKey =
          '32255e6651db67fa5b5a44240b6a5d2189cb58666bcc3830c35aff5a2b01b84f';
      const plaintext = '{"mnemonic":[],"masterFingerprint":"deadbeef"}';

      final result = await repository.createVault(
        rootXprv: rootXprv,
        plaintext: plaintext,
        derivationPath: path,
      );

      expect(
        result,
        isA<
          Ok<({EncryptedVault vault, String vaultKey}), RecoverBullFailure>
        >(),
      );
      final created =
          (result
                  as Ok<
                    ({EncryptedVault vault, String vaultKey}),
                    RecoverBullFailure
                  >)
              .value;
      expect(created.vaultKey, expectedVaultKey);
      expect(created.vault.derivationPath, path);
      final restored = repository.restoreVault(
        vault: created.vault,
        vaultKey: created.vaultKey,
      );
      expect(restored, isA<Ok<DecryptedVault, RecoverBullFailure>>());
      expect(
        (restored as Ok<DecryptedVault, RecoverBullFailure>)
            .value
            .masterFingerprint,
        'deadbeef',
      );
    },
  );

  test(
    'createVault invalid input returns the existing failure without output',
    () async {
      final result = await repository.createVault(
        rootXprv: 'not-an-xprv',
        plaintext: '{}',
        derivationPath: "1608'/0'/42'",
      );

      expect(
        result,
        isA<
          Err<({EncryptedVault vault, String vaultKey}), RecoverBullFailure>
        >(),
      );
      expect(
        (result
                as Err<
                  ({EncryptedVault vault, String vaultKey}),
                  RecoverBullFailure
                >)
            .failure,
        isA<RecoverBullUnexpectedFailure>(),
      );
    },
  );

  test('success -> Ok with hex-encoded key', () async {
    when(
      () => remote.fetch(any(), any(), any(), route: any(named: 'route')),
    ).thenAnswer((_) async => [0xab, 0xcd]);

    final result = await fetch();

    expect(result, isA<Ok<String, RecoverBullFailure>>());
    expect((result as Ok<String, RecoverBullFailure>).value, 'abcd');
  });

  group('RecoverBullRepository.checkConnection', () {
    test('maps HTTP 503 to temporary unavailability', () async {
      when(
        () => remote.checkConnection(any()),
      ).thenThrow(recoverbull.KeyServerException(code: 503));

      final result = await repository.checkConnection(route);

      expect(result, isA<Err<Null, RecoverBullFailure>>());
      expect(
        (result as Err<Null, RecoverBullFailure>).failure,
        isA<RecoverBullTemporarilyUnavailableFailure>(),
      );
    });

    test('maps timeout to health check timeout', () async {
      when(
        () => remote.checkConnection(any()),
      ).thenThrow(TimeoutException('health check timed out'));

      final result = await repository.checkConnection(route);

      expect(
        (result as Err<Null, RecoverBullFailure>).failure,
        isA<KeyServerHealthCheckTimeoutFailure>(),
      );
      expect(logSink.entries.single.message, 'recoverbull.health.timeout');
    });

    test('maps other errors to unavailable', () async {
      when(
        () => remote.checkConnection(any()),
      ).thenThrow(Exception('network unavailable'));

      final result = await repository.checkConnection(route);

      expect(
        (result as Err<Null, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
    });
  });

  // Guards the package:hex -> package:convert codec swap and the
  // `_normalizeHex` input handling. The repository HEX-decodes `identifier`
  // and `salt` before the network call, so `fetchVaultKey` is the observable
  // seam: a decodable input reaches the mocked `remote.fetch`, a malformed one
  // is rejected before any network I/O.
  group('hex input normalization and strict decoding (identifier/salt)', () {
    void stubFetchOk() {
      when(
        () => remote.fetch(any(), any(), any(), route: any(named: 'route')),
      ).thenAnswer((_) async => [0xab, 0xcd]);
    }

    test('whitespace-formatted input still decodes (normalized, not '
        'rejected)', () async {
      stubFetchOk();

      // The reveal screen groups the key into space-separated 4-char chunks;
      // a user may retype it that way. Normalization must strip the spaces so
      // the value still decodes, preserving the tolerance package:hex gave
      // implicitly.
      final result = await repository.fetchVaultKey(
        'de ad be ef',
        'password',
        '00 11',
        route,
      );

      expect(result, isA<Ok<String, RecoverBullFailure>>());
      // Pin the decoded bytes, not just that the call happened: proves the
      // spaces were stripped and the codec produced the right bytes, rather
      // than merely not throwing. fetch(identifier, password, salt) — the two
      // captureAny() slots yield [identifier, salt] in order.
      final captured = verify(
        () => remote.fetch(
          captureAny(),
          any(),
          captureAny(),
          route: any(named: 'route'),
        ),
      ).captured;
      expect(captured[0], [0xde, 0xad, 0xbe, 0xef]);
      expect(captured[1], [0x00, 0x11]);
    });

    test('uppercase input still decodes', () async {
      stubFetchOk();

      final result = await repository.fetchVaultKey(
        'ABCD',
        'password',
        'EF01',
        route,
      );

      expect(result, isA<Ok<String, RecoverBullFailure>>());
      // Proves convert case-folds (RFC 4648): 'ABCD'/'EF01' decode to the same
      // bytes as lowercase, with no manual .toLowerCase() in _normalizeHex.
      final captured = verify(
        () => remote.fetch(
          captureAny(),
          any(),
          captureAny(),
          route: any(named: 'route'),
        ),
      ).captured;
      expect(captured[0], [0xab, 0xcd]);
      expect(captured[1], [0xef, 0x01]);
    });

    test('odd-length input is rejected before any network call '
        '(no silent zero-padding)', () async {
      stubFetchOk();

      // Under package:hex "abc" was silently decoded as "0abc" -> a different,
      // wrong key, and the request proceeded. Under package:convert it throws,
      // is caught, and mapped to a failure *before* remote.fetch is reached.
      final result = await repository.fetchVaultKey(
        'abc',
        'password',
        '00',
        route,
      );

      expect(result, isA<Err<String, RecoverBullFailure>>());
      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<RecoverBullUnexpectedFailure>(),
      );
      verifyNever(
        () => remote.fetch(any(), any(), any(), route: any(named: 'route')),
      );
    });

    test('non-hex input is rejected before any network call', () async {
      stubFetchOk();

      final result = await repository.fetchVaultKey(
        'zz',
        'password',
        '00',
        route,
      );

      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<RecoverBullUnexpectedFailure>(),
      );
      verifyNever(
        () => remote.fetch(any(), any(), any(), route: any(named: 'route')),
      );
    });
  });
}
