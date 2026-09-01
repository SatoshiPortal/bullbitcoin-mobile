import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_portable_settings_backup.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Autoswap extends Mock implements AutoSwapSettingsRepository {}

class _ElectrumServers extends Mock implements ElectrumServerRepository {}

class _ElectrumSettings extends Mock implements ElectrumSettingsRepository {}

class _MempoolServers extends Mock implements MempoolServerRepository {}

class _MempoolSettings extends Mock implements MempoolSettingsRepository {}

class _Payjoin extends Mock implements PayjoinPolicyAccess {}

void main() {
  late _Settings settings;
  late _Autoswap autoswap;
  late _ElectrumServers electrumServers;
  late _ElectrumSettings electrumSettings;
  late _MempoolServers mempoolServers;
  late _MempoolSettings mempoolSettings;
  late _Payjoin payjoin;
  late WalletPortableSettingsBackup backup;

  void stubReads({String? socks}) {
    for (final network in ElectrumServerNetwork.values) {
      when(
        () => electrumServers.fetchCustomServers(network: network),
      ).thenAnswer((_) async => const Ok([]));
      when(() => electrumSettings.fetchByNetwork(network)).thenAnswer(
        (_) async => Ok(
          ElectrumSettings(
            stopGap: 20,
            timeout: 10,
            retry: 3,
            validateDomain: true,
            network: network,
            socks5: socks,
          ),
        ),
      );
    }
    for (final network in MempoolServerNetwork.values) {
      when(
        () => mempoolServers.fetchCustomServer(network),
      ).thenAnswer((_) async => const Ok(null));
      when(() => mempoolSettings.fetchByNetwork(network)).thenAnswer(
        (_) async => Ok(
          MempoolSettings.create(network: network, useForFeeEstimation: true),
        ),
      );
    }
    when(() => payjoin.load()).thenAnswer(
      (_) async => Ok(
        PayjoinPolicy(
          enabled: true,
          minimumAmount: Sats.fromInt(10000),
          sessionLifetime: const Duration(hours: 1),
        ),
      ),
    );
  }

  void stubWrites() {
    when(() => settings.setBitcoinUnit(any())).thenAnswer((_) async {});
    when(() => settings.setCurrency(any())).thenAnswer((_) async {});
    when(() => settings.setLanguage(any())).thenAnswer((_) async {});
    when(() => settings.setThemeMode(any())).thenAnswer((_) async {});
    when(() => settings.setHideAmounts(any())).thenAnswer((_) async {});
    when(() => autoswap.updateAutoSwapParams(any())).thenAnswer((_) async {});
    when(
      () => electrumServers.save(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => electrumServers.delete(url: any(named: 'url')),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => electrumSettings.save(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => mempoolServers.save(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => mempoolServers.deleteCustomServer(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => mempoolSettings.save(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => payjoin.setMinimumAmount(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    when(
      () => payjoin.setSessionLifetime(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    when(
      () => payjoin.setEnabled(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
  }

  setUpAll(() {
    registerFallbackValue(
      ElectrumServer.existing(
        url: 'ssl://fallback.example:50002',
        network: ElectrumServerNetwork.bitcoinMainnet,
        isCustom: true,
        priority: 0,
      ),
    );
    registerFallbackValue(
      ElectrumSettings(
        stopGap: 20,
        timeout: 10,
        retry: 3,
        validateDomain: true,
        network: ElectrumServerNetwork.bitcoinMainnet,
      ),
    );
    registerFallbackValue(
      MempoolServer.existing(
        url: 'fallback.example',
        network: MempoolServerNetwork.bitcoinMainnet,
        isCustom: true,
      ),
    );
    registerFallbackValue(
      MempoolSettings.create(network: MempoolServerNetwork.bitcoinMainnet),
    );
    registerFallbackValue(Sats.fromInt(1000));
    registerFallbackValue(BitcoinUnit.sats);
    registerFallbackValue(Language.unitedStatesEnglish);
    registerFallbackValue(AppThemeMode.system);
    registerFallbackValue(Environment.mainnet);
    registerFallbackValue(MempoolServerNetwork.bitcoinMainnet);
    registerFallbackValue(const Duration(minutes: 1));
    registerFallbackValue(const AutoSwap());
  });

  setUp(() {
    settings = _Settings();
    autoswap = _Autoswap();
    electrumServers = _ElectrumServers();
    electrumSettings = _ElectrumSettings();
    mempoolServers = _MempoolServers();
    mempoolSettings = _MempoolSettings();
    payjoin = _Payjoin();
    backup = WalletPortableSettingsBackup(
      settings: settings,
      autoswap: autoswap,
      electrumServers: electrumServers,
      electrumSettings: electrumSettings,
      mempoolServers: mempoolServers,
      mempoolSettings: mempoolSettings,
      payjoin: payjoin,
      walletExists: (_) async => false,
    );
    stubWrites();
  });

  test('reads only the approved portable settings', () async {
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CRC',
        language: Language.spanish,
        hideAmounts: true,
        isSuperuser: true,
        isDevModeEnabled: true,
        useTorProxy: true,
        torProxyPort: 9999,
        themeMode: AppThemeMode.dark,
        isErrorReportingEnabled: true,
        exchangeTestnetBasicAuthUsername: 'secret-user',
        exchangeTestnetBasicAuthPassword: 'secret-password',
      ),
    );
    when(
      () => autoswap.getAutoSwapParams(),
    ).thenAnswer((_) async => const AutoSwap(showWarning: false));
    stubReads();

    final value = await backup.read();

    expect(value.bitcoinUnit, BitcoinUnit.btc);
    expect(value.fiatCurrency, 'CRC');
    expect(value.language, Language.spanish);
    expect(value.themeMode, AppThemeMode.dark);
    expect(value.hideAmounts, isTrue);
    expect(value.electrum, hasLength(4));
    expect(value.mempool, hasLength(4));
    expect(value.payjoin.minimumAmountSats, 10000);
  });

  test(
    'restores portable values while preserving device-local state',
    () async {
      when(() => autoswap.getAutoSwapParams()).thenAnswer(
        (_) async =>
            const AutoSwap(blockTillNextExecution: true, showWarning: false),
      );
      stubReads(socks: '127.0.0.1:9050');
      final desired = _desiredSettings();

      await backup.restore(desired);

      final savedAutoswap =
          verify(
                () => autoswap.updateAutoSwapParams(captureAny()),
              ).captured.single
              as AutoSwap;
      expect(savedAutoswap.enabled, isFalse);
      expect(savedAutoswap.recipientWalletId, isNull);
      expect(savedAutoswap.blockTillNextExecution, isTrue);
      expect(savedAutoswap.showWarning, isFalse);
      final savedElectrum = verify(
        () => electrumSettings.save(captureAny()),
      ).captured.cast<ElectrumSettings>();
      expect(savedElectrum, everyElement(hasSocks('127.0.0.1:9050')));
      verifyNever(() => settings.setEnvironment(any()));
      verifyNever(() => settings.setUseTorProxy(any()));
      verifyNever(() => settings.setTorProxyPort(any()));
      verifyNever(() => settings.setIsSuperuser(any()));
      verifyNever(() => settings.setIsDevMode(any()));
      verifyNever(() => settings.setErrorReportingEnabled(any()));
      verifyNever(
        () => settings.setExchangeTestnetBasicAuth(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  test('repository read failures remain recoverable exceptions', () async {
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => autoswap.getAutoSwapParams(),
    ).thenAnswer((_) async => const AutoSwap());
    stubReads();
    when(
      () => electrumServers.fetchCustomServers(
        network: ElectrumServerNetwork.bitcoinMainnet,
      ),
    ).thenAnswer((_) async => const Err(ElectrumLoadFailure()));

    await expectLater(backup.read(), throwsA(isA<Exception>()));
  });

  test('repository write failures remain recoverable exceptions', () async {
    when(
      () => autoswap.getAutoSwapParams(),
    ).thenAnswer((_) async => const AutoSwap());
    stubReads();
    when(
      () => electrumSettings.save(any()),
    ).thenAnswer((_) async => const Err(ElectrumSaveFailure()));

    await expectLater(
      backup.restore(_desiredSettings()),
      throwsA(isA<Exception>()),
    );
  });
}

WalletPortableSettings _desiredSettings() => WalletPortableSettings(
  bitcoinUnit: BitcoinUnit.sats,
  fiatCurrency: 'USD',
  language: Language.unitedStatesEnglish,
  themeMode: AppThemeMode.light,
  hideAmounts: false,
  autoswap: WalletAutoswapSettings(
    enabled: true,
    balanceThresholdSats: 1000000,
    triggerBalanceSats: 2000000,
    feeThresholdPercent: 2,
    alwaysBlock: true,
    recipientWalletRef: 'missing-wallet',
  ),
  electrum: [
    for (final network in ElectrumServerNetwork.values)
      WalletElectrumSettings(
        network: network,
        customServers: const [],
        validateDomain: false,
        stopGap: 25,
        timeout: 15,
        retry: 4,
      ),
  ],
  mempool: [
    for (final network in MempoolServerNetwork.values)
      WalletMempoolSettings(network: network, useForFeeEstimation: false),
  ],
  payjoin: WalletPayjoinSettings(
    enabled: false,
    minimumAmountSats: 20000,
    sessionLifetimeSeconds: 7200,
  ),
);

Matcher hasSocks(String value) => predicate<ElectrumSettings>(
  (settings) => settings.socks5 == value,
  'preserves Electrum SOCKS',
);
