import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/utils/mempool_url_parser.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

/// Only preferences that belong in a portable backup. Device security, Tor,
/// credentials and transient execution state remain with their existing owners.
final class WalletPortableSettingsBackup {
  final PortableAppSettings app;
  final PortableAutoSwapSettings autoSwap;
  final PayjoinPolicy payjoin;
  final List<PortableElectrumSettings> electrum;
  final List<PortableMempoolSettings> mempool;

  WalletPortableSettingsBackup({
    required this.app,
    required this.autoSwap,
    required this.payjoin,
    required List<PortableElectrumSettings> electrum,
    required List<PortableMempoolSettings> mempool,
  }) : electrum = List.unmodifiable(electrum),
       mempool = List.unmodifiable(mempool) {
    if (electrum.length != ElectrumServerNetwork.values.length ||
        electrum.map((e) => e.network).toSet().length != electrum.length ||
        mempool.length != MempoolServerNetwork.values.length ||
        mempool.map((e) => e.network).toSet().length != mempool.length) {
      throw const FormatException('Incomplete network preferences');
    }
    // The upstream server owner keys by URL, not (network, URL).
    final urls = electrum.expand((e) => e.servers).map((s) => s.url).toList();
    if (urls.toSet().length != urls.length) {
      throw const FormatException('Duplicate Electrum server');
    }
  }
}

final class PortableAppSettings {
  final BitcoinUnit bitcoinUnit;
  final String currency;
  final Language language;
  final AppThemeMode themeMode;
  final bool hideAmounts;

  PortableAppSettings({
    required this.bitcoinUnit,
    required this.currency,
    required this.language,
    required this.themeMode,
    required this.hideAmounts,
  }) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const FormatException('Invalid currency code');
    }
  }
}

final class PortableAutoSwapSettings {
  final bool enabled;
  final int balanceThresholdSats;
  final int triggerBalanceSats;
  final double feeThresholdPercent;
  final bool alwaysBlock;
  final String? recipientWalletReference;

  PortableAutoSwapSettings({
    required this.enabled,
    required this.balanceThresholdSats,
    required this.triggerBalanceSats,
    required this.feeThresholdPercent,
    required this.alwaysBlock,
    required this.recipientWalletReference,
  }) {
    if (balanceThresholdSats < 0 ||
        triggerBalanceSats < 0 ||
        !feeThresholdPercent.isFinite ||
        feeThresholdPercent < 0 ||
        feeThresholdPercent > AutoSwap.maximumFeeThresholdPercent ||
        (recipientWalletReference != null &&
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(recipientWalletReference!))) {
      throw const FormatException('Invalid auto-swap preferences');
    }
    final values = AutoSwap(
      enabled: enabled,
      balanceThresholdSats: balanceThresholdSats,
      triggerBalanceSats: triggerBalanceSats,
      feeThresholdPercent: feeThresholdPercent,
      recipientWalletId: recipientWalletReference,
    );
    // Ben's initial state is enabled without a recipient. It cannot execute;
    // recovery keeps it disabled until an actual recipient has been resolved.
    if (recipientWalletReference != null && values.violation != null) {
      throw const FormatException('Invalid auto-swap thresholds');
    }
  }
}

final class PortableElectrumServer {
  final String url;
  final int priority;

  PortableElectrumServer({required this.url, required this.priority}) {
    final uri = ElectrumServerUrl(url).uri;
    if (url.length > 2048 ||
        priority < 0 ||
        uri == null ||
        !{'ssl', 'tcp'}.contains(uri.scheme) ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid Electrum server');
    }
  }
}

final class PortableElectrumSettings {
  final ElectrumServerNetwork network;
  final List<PortableElectrumServer> servers;
  final bool validateDomain;
  final int stopGap;
  final int timeout;
  final int retry;

  PortableElectrumSettings({
    required this.network,
    required List<PortableElectrumServer> servers,
    required this.validateDomain,
    required this.stopGap,
    required this.timeout,
    required this.retry,
  }) : servers = List.unmodifiable(servers) {
    if (stopGap < 0 ||
        stopGap > ElectrumSettings.maxStopGap ||
        timeout < 1 ||
        timeout > ElectrumSettings.maxTimeout ||
        retry < 0 ||
        servers.map((s) => s.url).toSet().length != servers.length) {
      throw const FormatException('Invalid Electrum preferences');
    }
  }
}

final class PortableMempoolSettings {
  final MempoolServerNetwork network;
  final String? customUrl;
  final bool useForFeeEstimation;

  PortableMempoolSettings({
    required this.network,
    required this.customUrl,
    required this.useForFeeEstimation,
  }) {
    final url = customUrl;
    if (url != null &&
        (url.length > 2048 ||
            !(url.startsWith('https://') || url.startsWith('http://')) ||
            MempoolUrlParser.tryParse(url) == null)) {
      throw const FormatException('Invalid Mempool server');
    }
  }
}
