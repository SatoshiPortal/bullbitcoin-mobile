import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/tor/domain/value_objects/tor_proxy_config.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

class _MockRemote extends Mock implements RecoverBullRemoteDatasource {}

class _MockSettings extends Mock implements RecoverbullSettingsDatasource {}

class _MockTorConfig extends Mock implements TorConfigPort {}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(const TorProxyConfig(port: 0));
  });

  late _MockRemote remote;
  late RecoverBullRepository repository;

  setUp(() {
    remote = _MockRemote();
    final torConfig = _MockTorConfig();
    when(
      () => torConfig.getAvailableExternalTorConfig(),
    ).thenAnswer((_) async => null);
    repository = RecoverBullRepository(
      remoteDatasource: remote,
      recoverbullSettingsDatasource: _MockSettings(),
      torConfigPort: torConfig,
    );
  });

  void stubFetchThrows(Object error) {
    when(
      () => remote.fetch(
        any(),
        any(),
        any(),
        externalProxy: any(named: 'externalProxy'),
      ),
    ).thenThrow(error);
  }

  // identifier/salt must be valid hex (the repo HEX-decodes them).
  Future<Result<String, RecoverBullCoreFailure>> fetch() =>
      repository.fetchVaultKey('00', 'password', '00');

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
      () => remote.fetch(
        any(),
        any(),
        any(),
        externalProxy: any(named: 'externalProxy'),
      ),
    ).thenAnswer((_) async => [0xab, 0xcd]);

    final result = await fetch();

    expect(result, isA<Ok<String, RecoverBullCoreFailure>>());
    expect((result as Ok<String, RecoverBullCoreFailure>).value, 'abcd');
  });
}
