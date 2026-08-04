import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;
import 'package:bull_tor/tor.dart';

class _MockRemote extends Mock implements RecoverBullRemoteDatasource {}

class _MockSettings extends Mock implements RecoverbullSettingsDatasource {}

void main() {
  final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9050);

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(endpoint);
  });

  late _MockRemote remote;
  late RecoverBullRepository repository;

  setUp(() {
    remote = _MockRemote();
    repository = RecoverBullRepository(
      remoteDatasource: remote,
      recoverbullSettingsDatasource: _MockSettings(),
    );
  });

  void stubFetchThrows(Object error) {
    when(
      () => remote.fetch(any(), any(), any(), endpoint: any(named: 'endpoint')),
    ).thenThrow(error);
  }

  // identifier/salt must be valid hex (the repo HEX-decodes them).
  Future<Result<String, RecoverBullCoreFailure>> fetch() =>
      repository.fetchVaultKey('00', 'password', '00', endpoint);

  group('RecoverBullRepository.fetchVaultKey maps KeyServerException', () {
    test('401 -> KeyServerInvalidCredentialsFailure (no raw leak)', () async {
      stubFetchThrows(
        recoverbull.KeyServerException(code: 401, message: 'unauthorized xyz'),
      );

      final result = await fetch();

      expect(result, isA<Err<String, RecoverBullCoreFailure>>());
      final failure = (result as Err<String, RecoverBullCoreFailure>).failure;
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

      final failure = (result as Err<String, RecoverBullCoreFailure>).failure;
      expect(failure, isA<KeyServerRateLimitedFailure>());
      expect((failure as KeyServerRateLimitedFailure).retryIn, isNotNull);
    });

    test('429 without cooldown -> retryIn null (no NPE)', () async {
      stubFetchThrows(recoverbull.KeyServerException(code: 429));

      final result = await fetch();

      final failure = (result as Err<String, RecoverBullCoreFailure>).failure;
      expect(failure, isA<KeyServerRateLimitedFailure>());
      expect((failure as KeyServerRateLimitedFailure).retryIn, isNull);
    });

    test('other 4xx -> KeyServerRejectedFailure', () async {
      stubFetchThrows(recoverbull.KeyServerException(code: 403));

      final result = await fetch();

      expect(
        (result as Err<String, RecoverBullCoreFailure>).failure,
        isA<KeyServerRejectedFailure>(),
      );
    });

    test('5xx -> KeyServerUnavailableFailure', () async {
      stubFetchThrows(recoverbull.KeyServerException(code: 503));

      final result = await fetch();

      expect(
        (result as Err<String, RecoverBullCoreFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
    });

    test('null code -> KeyServerUnavailableFailure', () async {
      stubFetchThrows(recoverbull.KeyServerException());

      final result = await fetch();

      expect(
        (result as Err<String, RecoverBullCoreFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
    });
  });

  test('non-KeyServer error -> RecoverBullUnexpectedCoreFailure', () async {
    stubFetchThrows(Exception('socket: 1.2.3.4 reset'));

    final result = await fetch();

    final failure = (result as Err<String, RecoverBullCoreFailure>).failure;
    expect(failure, isA<RecoverBullUnexpectedCoreFailure>());
  });

  test('success -> Ok with hex-encoded key', () async {
    when(
      () => remote.fetch(any(), any(), any(), endpoint: any(named: 'endpoint')),
    ).thenAnswer((_) async => [0xab, 0xcd]);

    final result = await fetch();

    expect(result, isA<Ok<String, RecoverBullCoreFailure>>());
    expect((result as Ok<String, RecoverBullCoreFailure>).value, 'abcd');
  });

  // Guards the package:hex -> package:convert codec swap and the
  // `_normalizeHex` input handling. The repository HEX-decodes `identifier`
  // and `salt` before the network call, so `fetchVaultKey` is the observable
  // seam: a decodable input reaches the mocked `remote.fetch`, a malformed one
  // is rejected before any network I/O.
  group('hex input normalization and strict decoding (identifier/salt)', () {
    void stubFetchOk() {
      when(
        () =>
            remote.fetch(any(), any(), any(), endpoint: any(named: 'endpoint')),
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
        endpoint,
      );

      expect(result, isA<Ok<String, RecoverBullCoreFailure>>());
      // Pin the decoded bytes, not just that the call happened: proves the
      // spaces were stripped and the codec produced the right bytes, rather
      // than merely not throwing. fetch(identifier, password, salt) — the two
      // captureAny() slots yield [identifier, salt] in order.
      final captured = verify(
        () => remote.fetch(
          captureAny(),
          any(),
          captureAny(),
          endpoint: any(named: 'endpoint'),
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
        endpoint,
      );

      expect(result, isA<Ok<String, RecoverBullCoreFailure>>());
      // Proves convert case-folds (RFC 4648): 'ABCD'/'EF01' decode to the same
      // bytes as lowercase, with no manual .toLowerCase() in _normalizeHex.
      final captured = verify(
        () => remote.fetch(
          captureAny(),
          any(),
          captureAny(),
          endpoint: any(named: 'endpoint'),
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
        endpoint,
      );

      expect(result, isA<Err<String, RecoverBullCoreFailure>>());
      expect(
        (result as Err<String, RecoverBullCoreFailure>).failure,
        isA<RecoverBullUnexpectedCoreFailure>(),
      );
      verifyNever(
        () =>
            remote.fetch(any(), any(), any(), endpoint: any(named: 'endpoint')),
      );
    });

    test('non-hex input is rejected before any network call', () async {
      stubFetchOk();

      final result = await repository.fetchVaultKey(
        'zz',
        'password',
        '00',
        endpoint,
      );

      expect(
        (result as Err<String, RecoverBullCoreFailure>).failure,
        isA<RecoverBullUnexpectedCoreFailure>(),
      );
      verifyNever(
        () =>
            remote.fetch(any(), any(), any(), endpoint: any(named: 'endpoint')),
      );
    });
  });
}
