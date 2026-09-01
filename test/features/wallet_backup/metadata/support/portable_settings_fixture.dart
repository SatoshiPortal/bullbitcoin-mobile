import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';

WalletPortableSettings portableSettingsFixture() => WalletPortableSettings(
  bitcoinUnit: BitcoinUnit.sats,
  fiatCurrency: 'USD',
  language: Language.unitedStatesEnglish,
  themeMode: AppThemeMode.dark,
  hideAmounts: true,
  autoswap: WalletAutoswapSettings(
    enabled: false,
    balanceThresholdSats: 1000000,
    triggerBalanceSats: 2000000,
    feeThresholdPercent: 3,
    alwaysBlock: false,
  ),
  electrum: [
    for (final network in ElectrumServerNetwork.values)
      WalletElectrumSettings(
        network: network,
        customServers: const [],
        validateDomain: true,
        stopGap: 20,
        timeout: 10,
        retry: 3,
      ),
  ],
  mempool: [
    for (final network in MempoolServerNetwork.values)
      WalletMempoolSettings(network: network, useForFeeEstimation: true),
  ],
  payjoin: WalletPayjoinSettings(
    enabled: false,
    minimumAmountSats: 10000,
    sessionLifetimeSeconds: 86400,
  ),
);
