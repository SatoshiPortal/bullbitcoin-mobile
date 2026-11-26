import 'package:swaps/src/domain/entities/regtest_boltz_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('production does not parse or expose the regtest host', () {
    for (final environment in [
      NetworkEnv.mainnet,
      NetworkEnv.testnet,
      NetworkEnv.signet,
    ]) {
      expect(
        RegtestBoltzProfile.forNetwork(environment, host: 'invalid/host'),
        isNull,
      );
    }
  });

  test('regtest keeps Boltz HTTP and websocket on independent ports', () {
    final profile = RegtestBoltzProfile.forNetwork(
      NetworkEnv.regtest,
      host: 'localhost',
    );
    expect(profile?.api.toString(), 'http://localhost:9001/v2');
    expect(profile?.webSocket.toString(), 'ws://localhost:9004');
    expect(profile?.bitcoinExplorer.toString(), 'http://localhost:3000');
    expect(profile?.liquidExplorer.toString(), 'http://localhost:3001');
  });

  test('a hosted stack takes its Boltz and explorer endpoints', () {
    final profile = RegtestBoltzProfile.forNetwork(
      NetworkEnv.regtest,
      host: '',
      hosted: const RegtestHostedDefines(
        electrumBitcoin: 'ssl://electrum.example:443',
        electrumLiquid: 'ssl://electrum.example:8443',
        esploraBitcoin: 'https://esplora.example',
        esploraLiquid: 'https://liquid.example',
        boltzApi: 'https://boltz.example/v2',
        boltzWebSocket: 'wss://boltz.example/v2/ws',
        recoverBull: 'http://keyserver.onion',
      ),
    );
    expect(profile?.api.toString(), 'https://boltz.example/v2');
    // The stream client appends `/ws` to this base.
    expect(profile?.webSocket.toString(), 'wss://boltz.example/v2');
    expect(profile?.bitcoinExplorer.toString(), 'https://esplora.example');
    expect(profile?.liquidExplorer.toString(), 'https://liquid.example');
  });

  test('the build selects the local host or the hosted stack', () {
    const host = String.fromEnvironment('BULL_REGTEST_HOST');
    final api = RegtestBoltzProfile.forNetwork(NetworkEnv.regtest)?.api;
    if (host.isEmpty) {
      expect(api?.scheme, 'https');
    } else {
      expect(api?.host, Uri.parse('http://$host').host);
    }
  });
}
