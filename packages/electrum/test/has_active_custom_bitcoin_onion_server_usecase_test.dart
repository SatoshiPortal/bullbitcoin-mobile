import 'package:electrum/testing.dart';
import 'package:electrum/electrum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Environment extends Mock implements EnvironmentPort {}

class _Servers extends Mock implements ElectrumServerRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(ElectrumServerNetwork.bitcoinMainnet);
  });

  late _Environment environment;
  late _Servers servers;

  setUp(() {
    environment = _Environment();
    servers = _Servers();
    when(environment.getEnvironment)
        .thenAnswer((_) async => ElectrumEnvironment.mainnet);
    when(() => servers.fetchActiveServers(network: any(named: 'network')))
        .thenAnswer((_) async => const Ok([]));
  });

  test('recognizes onion and onion-dot custom Bitcoin servers', () async {
    when(() => servers.fetchActiveServers(network: any(named: 'network')))
        .thenAnswer(
          (_) async => Ok([
            ElectrumServer.existing(
              url: 'ssl://one.onion.:50002',
              network: ElectrumServerNetwork.bitcoinMainnet,
              isCustom: true,
              priority: 0,
            ),
          ]),
        );

    expect(
      await HasActiveCustomBitcoinOnionServerUsecase(
        servers,
        environment,
      ).execute(),
      isTrue,
    );
  });

  test('ignores clearnet, non-custom, and Liquid servers', () async {
    when(() => servers.fetchActiveServers(network: any(named: 'network')))
        .thenAnswer(
          (_) async => Ok([
            ElectrumServer.existing(
              url: 'ssl://one.example:50002',
              network: ElectrumServerNetwork.bitcoinMainnet,
              isCustom: true,
              priority: 0,
            ),
            ElectrumServer.existing(
              url: 'ssl://two.onion:50002',
              network: ElectrumServerNetwork.bitcoinMainnet,
              isCustom: false,
              priority: 1,
            ),
          ]),
        );

    expect(
      await HasActiveCustomBitcoinOnionServerUsecase(
        servers,
        environment,
      ).execute(),
      isFalse,
    );
  });
}
