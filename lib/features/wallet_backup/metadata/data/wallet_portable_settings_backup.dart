import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/core/utils/mempool_url_parser.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

typedef WalletExists = Future<bool> Function(String walletId);

final class WalletPortableSettingsBackup {
  final SettingsRepository settings;
  final AutoSwapSettingsRepository autoswap;
  final ElectrumServerRepository electrumServers;
  final ElectrumSettingsRepository electrumSettings;
  final MempoolServerRepository mempoolServers;
  final MempoolSettingsRepository mempoolSettings;
  final PayjoinPolicyAccess payjoin;
  final WalletExists walletExists;

  const WalletPortableSettingsBackup({
    required this.settings,
    required this.autoswap,
    required this.electrumServers,
    required this.electrumSettings,
    required this.mempoolServers,
    required this.mempoolSettings,
    required this.payjoin,
    required this.walletExists,
  });

  Future<WalletPortableSettings> read() async {
    final app = await settings.fetch();
    final autoswapValue = await autoswap.getAutoSwapParams();
    final electrum = <WalletElectrumSettings>[];
    for (final network in ElectrumServerNetwork.values) {
      final servers = [
        ..._value(await electrumServers.fetchCustomServers(network: network)),
      ]..sort((a, b) => a.priority.compareTo(b.priority));
      final networkSettings = _value(
        await electrumSettings.fetchByNetwork(network),
      );
      electrum.add(
        WalletElectrumSettings(
          network: network,
          customServers: servers.map((server) => server.url),
          validateDomain: networkSettings.validateDomain,
          stopGap: networkSettings.stopGap,
          timeout: networkSettings.timeout,
          retry: networkSettings.retry,
        ),
      );
    }
    final mempool = <WalletMempoolSettings>[];
    for (final network in MempoolServerNetwork.values) {
      final server = _value(await mempoolServers.fetchCustomServer(network));
      final networkSettings = _value(
        await mempoolSettings.fetchByNetwork(network),
      );
      mempool.add(
        WalletMempoolSettings(
          network: network,
          customServer: server?.fullUrl,
          useForFeeEstimation: networkSettings.useForFeeEstimation,
        ),
      );
    }
    final payjoinValue = _value(await payjoin.load());
    return WalletPortableSettings(
      bitcoinUnit: app.bitcoinUnit,
      fiatCurrency: app.currencyCode,
      language: app.language,
      themeMode: app.themeMode,
      hideAmounts: app.hideAmounts ?? false,
      autoswap: WalletAutoswapSettings(
        enabled: autoswapValue.enabled,
        balanceThresholdSats: autoswapValue.balanceThresholdSats,
        triggerBalanceSats: autoswapValue.triggerBalanceSats,
        feeThresholdPercent: autoswapValue.feeThresholdPercent,
        alwaysBlock: autoswapValue.alwaysBlock,
        recipientWalletRef: autoswapValue.recipientWalletId,
      ),
      electrum: electrum,
      mempool: mempool,
      payjoin: WalletPayjoinSettings(
        enabled: payjoinValue.enabled,
        minimumAmountSats: payjoinValue.minimumAmount.value.toInt(),
        sessionLifetimeSeconds: payjoinValue.sessionLifetime.inSeconds,
      ),
    );
  }

  Future<void> restore(WalletPortableSettings desired) async {
    await settings.setBitcoinUnit(desired.bitcoinUnit);
    await settings.setCurrency(desired.fiatCurrency);
    if (desired.language case final language?) {
      await settings.setLanguage(language);
    }
    await settings.setThemeMode(desired.themeMode);
    await settings.setHideAmounts(desired.hideAmounts);

    final currentAutoswap = await autoswap.getAutoSwapParams();
    final recipient = desired.autoswap.recipientWalletRef;
    final recipientExists = recipient != null && await walletExists(recipient);
    await autoswap.updateAutoSwapParams(
      AutoSwap(
        enabled: desired.autoswap.enabled && recipientExists,
        balanceThresholdSats: desired.autoswap.balanceThresholdSats,
        triggerBalanceSats: desired.autoswap.triggerBalanceSats,
        feeThresholdPercent: desired.autoswap.feeThresholdPercent,
        alwaysBlock: desired.autoswap.alwaysBlock,
        recipientWalletId: recipientExists ? recipient : null,
        blockTillNextExecution: currentAutoswap.blockTillNextExecution,
        showWarning: currentAutoswap.showWarning,
      ),
    );

    for (final desiredNetwork in desired.electrum) {
      final current = _value(
        await electrumServers.fetchCustomServers(
          network: desiredNetwork.network,
        ),
      );
      for (
        var priority = 0;
        priority < desiredNetwork.customServers.length;
        priority++
      ) {
        _value(
          await electrumServers.save(
            ElectrumServer.existing(
              url: desiredNetwork.customServers[priority],
              network: desiredNetwork.network,
              isCustom: true,
              priority: priority,
            ),
          ),
        );
      }
      final desiredUrls = desiredNetwork.customServers.toSet();
      for (final server in current) {
        if (!desiredUrls.contains(server.url)) {
          _value(await electrumServers.delete(url: server.url));
        }
      }
      final settings = _value(
        await electrumSettings.fetchByNetwork(desiredNetwork.network),
      );
      settings.update(
        newStopGap: desiredNetwork.stopGap,
        newTimeout: desiredNetwork.timeout,
        newRetry: desiredNetwork.retry,
        newValidateDomain: desiredNetwork.validateDomain,
      );
      _value(await electrumSettings.save(settings));
    }

    for (final desiredNetwork in desired.mempool) {
      final current = _value(
        await mempoolServers.fetchCustomServer(desiredNetwork.network),
      );
      final custom = desiredNetwork.customServer;
      if (custom == null) {
        if (current != null) {
          _value(
            await mempoolServers.deleteCustomServer(desiredNetwork.network),
          );
        }
      } else {
        final parsed = MempoolUrlParser.parse(custom);
        final server = _value(
          MempoolServer.tryCreateCustom(
            url: parsed.cleanUrl,
            network: desiredNetwork.network,
            enableSsl: parsed.enableSsl,
          ),
        );
        _value(await mempoolServers.save(server));
      }
      _value(
        await mempoolSettings.save(
          MempoolSettings.create(
            network: desiredNetwork.network,
            useForFeeEstimation: desiredNetwork.useForFeeEstimation,
          ),
        ),
      );
    }

    _value(
      await payjoin.setMinimumAmount(
        Sats.fromInt(desired.payjoin.minimumAmountSats),
      ),
    );
    _value(
      await payjoin.setSessionLifetime(
        Duration(seconds: desired.payjoin.sessionLifetimeSeconds),
      ),
    );
    _value(await payjoin.setEnabled(desired.payjoin.enabled));
  }
}

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err() => throw const _WalletPortableSettingsAccessException(),
};

final class _WalletPortableSettingsAccessException implements Exception {
  const _WalletPortableSettingsAccessException();
}
