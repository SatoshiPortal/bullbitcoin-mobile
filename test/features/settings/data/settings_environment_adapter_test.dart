import 'package:mempool/mempool.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/settings/data/settings_environment_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsRepository {}

void main() {
  late _Settings settings;
  late SettingsEnvironmentAdapter adapter;

  void stubEnvironment(Environment environment) {
    when(settings.fetch).thenAnswer(
      (_) async => SettingsEntity(
        environment: environment,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
  }

  setUp(() {
    settings = _Settings();
    adapter = SettingsEnvironmentAdapter(settingsRepository: settings);
  });

  for (final (environment, network) in [
    (Environment.mainnet, BitcoinNetwork.mainnet),
    (Environment.testnet, BitcoinNetwork.testnet),
  ]) {
    test('returns the active ${network.name} network', () async {
      stubEnvironment(environment);

      expect(
        await adapter.getEnvironment(),
        isA<Ok<BitcoinNetwork, MempoolFailure>>().having(
          (result) => result.value,
          'network',
          network,
        ),
      );
    });
  }

  test('rejects regtest before selecting a mempool server', () async {
    stubEnvironment(Environment.regtest);

    expect(
      await adapter.getEnvironment(),
      isA<Err<BitcoinNetwork, MempoolFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<MempoolUnsupportedNetworkFailure>(),
      ),
    );
  });

  test('maps a settings read error to a mempool failure', () async {
    when(settings.fetch).thenThrow(Exception('settings unavailable'));

    expect(
      await adapter.getEnvironment(),
      isA<Err<BitcoinNetwork, MempoolFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<MempoolUnexpectedFailure>(),
      ),
    );
  });
}
