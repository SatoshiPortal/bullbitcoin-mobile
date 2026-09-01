import 'dart:typed_data';

import 'package:bull_recoverbull/src/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/data/recoverbull_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
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

  setUp(() {
    remote = _MockRemote();
    repository = RecoverBullRepositoryImpl(
      log: const TestLogSink(),
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
    });

    test('429 without cooldown -> retryIn null (no NPE)', () async {
      stubFetchThrows(recoverbull.KeyServerException(code: 429));

      final result = await fetch();

      final failure = (result as Err<String, RecoverBullFailure>).failure;
      expect(failure, isA<KeyServerRateLimitedFailure>());
      expect((failure as KeyServerRateLimitedFailure).retryIn, isNull);
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
    });

    test('null code -> KeyServerUnavailableFailure', () async {
      stubFetchThrows(recoverbull.KeyServerException());

      final result = await fetch();

      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
    });
  });

  test('non-KeyServer error -> RecoverBullUnexpectedFailure', () async {
    stubFetchThrows(Exception('socket: 1.2.3.4 reset'));

    final result = await fetch();

    final failure = (result as Err<String, RecoverBullFailure>).failure;
    expect(failure, isA<RecoverBullUnexpectedFailure>());
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
