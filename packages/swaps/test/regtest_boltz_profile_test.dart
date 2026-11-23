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

  test('regtest requires an explicit build host', () {
    const host = String.fromEnvironment('BULL_REGTEST_HOST');
    if (host.isEmpty) {
      expect(
        () => RegtestBoltzProfile.forNetwork(NetworkEnv.regtest),
        throwsArgumentError,
      );
    } else {
      expect(
        RegtestBoltzProfile.forNetwork(NetworkEnv.regtest)?.api.host,
        Uri.parse('http://$host').host,
      );
    }
  });
}
