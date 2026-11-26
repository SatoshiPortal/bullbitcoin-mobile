import 'dart:convert';
import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

LocalRegtestHost _local(String host) =>
    RegtestHostProfile.forNetwork(NetworkEnv.regtest, host: host)!
        as LocalRegtestHost;

const _hosted = RegtestHostedDefines(
  electrumBitcoin: 'ssl://electrum.example:443',
  electrumLiquid: 'ssl://electrum.example:8443',
  esploraBitcoin: 'https://esplora.example',
  esploraLiquid: 'https://liquid.example',
  boltzApi: 'https://boltz.example/v2',
  boltzWebSocket: 'wss://boltz.example/v2/ws',
  recoverBull: 'http://keyserver.onion',
);

RegtestHostedDefines _with({
  String? electrumBitcoin,
  String? electrumLiquid,
  String? esploraBitcoin,
  String? esploraLiquid,
  String? boltzApi,
  String? boltzWebSocket,
  String? recoverBull,
}) => RegtestHostedDefines(
  electrumBitcoin: electrumBitcoin ?? _hosted.electrumBitcoin,
  electrumLiquid: electrumLiquid ?? _hosted.electrumLiquid,
  esploraBitcoin: esploraBitcoin ?? _hosted.esploraBitcoin,
  esploraLiquid: esploraLiquid ?? _hosted.esploraLiquid,
  boltzApi: boltzApi ?? _hosted.boltzApi,
  boltzWebSocket: boltzWebSocket ?? _hosted.boltzWebSocket,
  recoverBull: recoverBull ?? _hosted.recoverBull,
);

RegtestHostProfile? _hostedProfile(RegtestHostedDefines defines) =>
    RegtestHostProfile.forNetwork(
      NetworkEnv.regtest,
      host: '',
      hosted: defines,
    );

void main() {
  test('a local build host overrides the hosted stack', () {
    const expected = String.fromEnvironment('BULL_REGTEST_HOST');
    if (expected.isEmpty) {
      expect(
        RegtestHostProfile.forNetwork(NetworkEnv.regtest),
        isA<HostedRegtestStack>(),
      );
    } else {
      expect(
        (RegtestHostProfile.forNetwork(NetworkEnv.regtest)! as LocalRegtestHost)
            .host,
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
      expect((profile! as LocalRegtestHost).host, 'regtest.example');
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
    expect(_local('Regtest.Example').host, 'regtest.example');
    expect(_local('[::1]').host, '::1');
  });

  // An empty host selects no local stack, leaving the hosted one.
  for (final host in [
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

  group('hosted stack', () {
    test('selects every hosted endpoint', () {
      final profile = _hostedProfile(_hosted);
      final endpoints = (profile! as HostedRegtestStack).endpoints;
      expect(
        endpoints.electrumBitcoin,
        Uri.parse('ssl://electrum.example:443'),
      );
      expect(
        endpoints.electrumLiquid,
        Uri.parse('ssl://electrum.example:8443'),
      );
      expect(endpoints.esploraBitcoin, Uri.parse('https://esplora.example'));
      expect(endpoints.esploraLiquid, Uri.parse('https://liquid.example'));
      expect(endpoints.boltzApi, Uri.parse('https://boltz.example/v2'));
      expect(endpoints.boltzWebSocket, Uri.parse('wss://boltz.example/v2/ws'));
      expect(endpoints.recoverBull, Uri.parse('http://keyserver.onion'));
    });

    test('other environments ignore the hosted defines', () {
      for (final environment in NetworkEnv.values) {
        if (environment == NetworkEnv.regtest) continue;
        expect(
          RegtestHostProfile.forNetwork(
            environment,
            host: '',
            hosted: const RegtestHostedDefines(electrumBitcoin: 'invalid'),
          ),
          isNull,
        );
      }
    });

    test('a local host takes precedence over the hosted stack', () {
      expect(
        RegtestHostProfile.forNetwork(
          NetworkEnv.regtest,
          host: 'localhost',
          hosted: _hosted,
        ),
        isA<LocalRegtestHost>(),
      );
    });

    test('an empty configuration offers no regtest', () {
      expect(
        () => RegtestHostProfile.forNetwork(
          NetworkEnv.regtest,
          host: '',
          hosted: const RegtestHostedDefines(
            electrumBitcoin: '',
            electrumLiquid: '',
            esploraBitcoin: '',
            esploraLiquid: '',
            boltzApi: '',
            boltzWebSocket: '',
            recoverBull: '',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('the built-in defaults are the shared hosted stack', () {
      final file = File('../../tools/regtest/hosted.json');
      final config = (jsonDecode(file.readAsStringSync()) as Map)
          .cast<String, String>();
      const defaults = RegtestHostedDefines();
      expect(
        {
          'BULL_REGTEST_HOSTED_ELECTRUM_BITCOIN': defaults.electrumBitcoin,
          'BULL_REGTEST_HOSTED_ELECTRUM_LIQUID': defaults.electrumLiquid,
          'BULL_REGTEST_HOSTED_ESPLORA_BITCOIN': defaults.esploraBitcoin,
          'BULL_REGTEST_HOSTED_ESPLORA_LIQUID': defaults.esploraLiquid,
          'BULL_REGTEST_HOSTED_BOLTZ_API': defaults.boltzApi,
          'BULL_REGTEST_HOSTED_BOLTZ_WS': defaults.boltzWebSocket,
          'BULL_REGTEST_HOSTED_RECOVERBULL': defaults.recoverBull,
        },
        {
          for (final entry in config.entries)
            if (entry.key.startsWith('BULL_REGTEST_HOSTED_'))
              entry.key: entry.value,
        },
      );
      expect(_hostedProfile(defaults), isA<HostedRegtestStack>());
    });

    final invalid = <String, RegtestHostedDefines>{
      'missing endpoint': _with(esploraLiquid: ''),
      'plaintext Electrum': _with(electrumBitcoin: 'tcp://electrum.example:1'),
      'Electrum without port': _with(electrumLiquid: 'ssl://electrum.example'),
      'Electrum with a path': _with(electrumBitcoin: 'ssl://e.example:1/x'),
      'plaintext Esplora': _with(esploraBitcoin: 'http://esplora.example'),
      'Esplora with credentials': _with(esploraLiquid: 'https://u@l.example'),
      'Boltz API with a query': _with(boltzApi: 'https://boltz.example/v2?x'),
      'plaintext Boltz websocket': _with(boltzWebSocket: 'ws://b.example/ws'),
      'Boltz websocket without /ws': _with(boltzWebSocket: 'wss://b.example'),
      'plaintext RecoverBull on clearnet': _with(
        recoverBull: 'http://keyserver.example',
      ),
      'endpoint with whitespace': _with(esploraBitcoin: 'https://e .example'),
    };
    for (final MapEntry(key: name, value: defines) in invalid.entries) {
      test('refuses an invalid hosted stack: $name', () {
        expect(() => _hostedProfile(defines), throwsArgumentError);
      });
    }

    test('accepts RecoverBull over HTTPS on clearnet', () {
      final profile = _hostedProfile(
        _with(recoverBull: 'https://keyserver.example'),
      );
      expect(
        (profile! as HostedRegtestStack).endpoints.recoverBull.host,
        'keyserver.example',
      );
    });
  });
}
