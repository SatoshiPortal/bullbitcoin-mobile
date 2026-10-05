import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpBackendConfig', () {
    test('constructs with non-empty urls', () {
      final config = SpBackendConfig(
        network: BitcoinNetwork.regtest,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );

      expect(config.blindbitUrl, 'http://blindbit.example');
      expect(config.electrumUrl, 'tcp://electrum.example:50001');
    });

    test('rejects an empty blindbit url', () {
      expect(
        () => SpBackendConfig(
          network: BitcoinNetwork.regtest,
          blindbitUrl: '',
          electrumUrl: 'tcp://electrum.example:50001',
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty electrum url', () {
      expect(
        () => SpBackendConfig(
          network: BitcoinNetwork.regtest,
          blindbitUrl: 'http://blindbit.example',
          electrumUrl: '   ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('SpBackendConfig.parse', () {
    Result<SpBackendConfig, SpFailure> parse({
      String blindbitUrl = 'http://blindbit.example',
      String electrumUrl = 'tcp://electrum.example:50001',
      int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
      int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
    }) => SpBackendConfig.parse(
      network: BitcoinNetwork.regtest,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
    );

    SpFailure failureOf(Result<SpBackendConfig, SpFailure> result) =>
        (result as Err<SpBackendConfig, SpFailure>).failure;

    test('builds a config from valid input', () {
      final config = (parse() as Ok<SpBackendConfig, SpFailure>).value;

      expect(config.blindbitUrl, 'http://blindbit.example');
      expect(config.electrumUrl, 'tcp://electrum.example:50001');
    });

    // An ArgumentError here would escape the use cases, which catch Exception.
    test('reports an empty blindbit url as a failure', () {
      expect(failureOf(parse(blindbitUrl: '')), isA<SpConfigInvalid>());
    });

    test('reports a whitespace-only electrum url as a failure', () {
      expect(failureOf(parse(electrumUrl: '   ')), isA<SpConfigInvalid>());
    });

    test('reports a fetch concurrency factor below one', () {
      expect(
        failureOf(parse(fetchConcurrencyFactor: 0)),
        isA<SpConfigInvalid>(),
      );
    });

    test('reports a fetch concurrency factor above the cap', () {
      expect(
        failureOf(
          parse(fetchConcurrencyFactor: SpConfig.maxFetchConcurrencyFactor + 1),
        ),
        isA<SpConfigInvalid>(),
      );
    });

    test('reports a match concurrency factor above the cap', () {
      expect(
        failureOf(
          parse(matchConcurrencyFactor: SpConfig.maxMatchConcurrencyFactor + 1),
        ),
        isA<SpConfigInvalid>(),
      );
    });
  });
}
