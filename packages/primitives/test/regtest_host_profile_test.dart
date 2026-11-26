import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('requires the explicit build host', () {
    const expected = String.fromEnvironment('BULL_REGTEST_HOST');
    if (expected.isEmpty) {
      expect(
        () => RegtestHostProfile.forNetwork(NetworkEnv.regtest),
        throwsArgumentError,
      );
    } else {
      expect(
        RegtestHostProfile.forNetwork(NetworkEnv.regtest)?.host,
        Uri.parse('http://$expected').host,
      );
    }
  });

  test('both regtest chains share the captured host', () {
    for (final network in <Network>[
      BitcoinNetwork.regtest,
      LiquidNetwork.regtest,
    ]) {
      final profile = RegtestHostProfile.forNetwork(
        network.env,
        host: 'regtest.example',
      );
      expect(profile?.host, 'regtest.example');
    }
  });

  test('other environments never construct or validate a regtest profile', () {
    for (final environment in NetworkEnv.values) {
      if (environment == NetworkEnv.regtest) {
        continue;
      }
      expect(
        RegtestHostProfile.forNetwork(environment, host: 'http://invalid/'),
        isNull,
      );
    }
  });

  test('normalizes a DNS host and accepts bracketed IPv6', () {
    expect(
      RegtestHostProfile.forNetwork(
        NetworkEnv.regtest,
        host: 'Regtest.Example',
      )?.host,
      'regtest.example',
    );
    expect(
      RegtestHostProfile.forNetwork(NetworkEnv.regtest, host: '[::1]')?.host,
      '::1',
    );
  });

  for (final host in [
    '',
    ' localhost',
    'local host',
    'http://localhost',
    'localhost:9001',
    'localhost/',
    'user@localhost',
    'localhost?query',
    'localhost#fragment',
  ]) {
    test('refuses an invalid regtest host: $host', () {
      expect(
        () => RegtestHostProfile.forNetwork(NetworkEnv.regtest, host: host),
        throwsArgumentError,
      );
    });
  }
}
