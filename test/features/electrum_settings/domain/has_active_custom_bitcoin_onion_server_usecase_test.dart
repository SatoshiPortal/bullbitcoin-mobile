import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/electrum_settings/domain/usecases/has_active_custom_bitcoin_onion_server_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Servers extends Mock implements ElectrumServerRepository {}

SettingsEntity _settings() => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

void main() {
  setUpAll(() {
    registerFallbackValue(ElectrumServerNetwork.bitcoinMainnet);
  });

  late _Settings settings;
  late _Servers servers;

  setUp(() {
    settings = _Settings();
    servers = _Servers();
    when(settings.fetch).thenAnswer((_) async => _settings());
    when(
      () => servers.fetchActiveServers(network: any(named: 'network')),
    ).thenAnswer((_) async => const Ok([]));
  });

  test('recognizes onion and onion-dot custom Bitcoin servers', () async {
    when(
      () => servers.fetchActiveServers(network: any(named: 'network')),
    ).thenAnswer(
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
        settings,
      ).execute(),
      isTrue,
    );
  });

  test('ignores clearnet, non-custom, and Liquid servers', () async {
    when(
      () => servers.fetchActiveServers(network: any(named: 'network')),
    ).thenAnswer(
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
        settings,
      ).execute(),
      isFalse,
    );
  });
}
