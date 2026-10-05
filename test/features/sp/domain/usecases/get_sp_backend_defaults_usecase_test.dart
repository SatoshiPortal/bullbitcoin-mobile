import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../sp_fakes.dart';

void main() {
  late FakeSpBackendProbe probe;
  late GetSpBackendDefaultsUsecase usecase;

  setUp(() {
    probe = FakeSpBackendProbe();
    usecase = GetSpBackendDefaultsUsecase(probe: probe);
  });

  Future<SpBackendDefaults> defaultsFor(BitcoinNetwork network) async {
    final result = await usecase.execute(network);
    return (result as Ok<SpBackendDefaults, SpFailure>).value;
  }

  group('static networks', () {
    test('mainnet resolves to the mainnet endpoints', () async {
      final defaults = await defaultsFor(BitcoinNetwork.mainnet);

      expect(defaults.blindbitUrl, 'https://blindbit.pythcoiner.dev');
      expect(defaults.electrumUrl, 'ssl://electrum.pythcoiner.dev:50002');
      expect(probe.fetchRegtestDefaultsCalls, 0);
    });

    test('signet resolves to the signet endpoints', () async {
      final defaults = await defaultsFor(BitcoinNetwork.signet);

      expect(defaults.blindbitUrl, 'https://blindbit-signet.bullbitcoin.com');
      expect(
        defaults.electrumUrl,
        'ssl://electrum-signet.bullbitcoin.com:50002',
      );
      expect(probe.fetchRegtestDefaultsCalls, 0);
    });

    test('testnet resolves to the testnet endpoints', () async {
      final defaults = await defaultsFor(BitcoinNetwork.testnet);

      expect(defaults.blindbitUrl, 'https://blindbit-testnet.bullbitcoin.com');
      expect(
        defaults.electrumUrl,
        'ssl://electrum-testnet.bullbitcoin.com:50002',
      );
      expect(probe.fetchRegtestDefaultsCalls, 0);
    });
  });

  group('regtest', () {
    test('reads the running regtest infra through the probe', () async {
      probe.regtestDefaults = const Ok(
        SpBackendDefaults(
          blindbitUrl: 'http://127.0.0.1:8000',
          electrumUrl: 'tcp://127.0.0.1:50001',
        ),
      );

      final defaults = await defaultsFor(BitcoinNetwork.regtest);

      expect(defaults.blindbitUrl, 'http://127.0.0.1:8000');
      expect(defaults.electrumUrl, 'tcp://127.0.0.1:50001');
      expect(probe.fetchRegtestDefaultsCalls, 1);
    });

    test('forwards the probe failure instead of falling back', () async {
      probe.regtestDefaults = const Err(
        SpBackendUnreachable('regtest infra down'),
      );

      final result = await usecase.execute(BitcoinNetwork.regtest);

      final failure = (result as Err<SpBackendDefaults, SpFailure>).failure;
      expect(failure, isA<SpBackendUnreachable>());
      expect(failure.logMessage, 'regtest infra down');
    });
  });
}
