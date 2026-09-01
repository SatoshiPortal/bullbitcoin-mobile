import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/mempool_url_parser.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_limits.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

const int walletMetadataSnapshotVersion = 1;

final class WalletMetadataLabel {
  final LabelType type;
  final String reference;
  final String label;
  final String? origin;

  const WalletMetadataLabel({
    required this.type,
    required this.reference,
    required this.label,
    this.origin,
  });

  String get identity => '$label\u0000$reference';
}

final class WalletPortableSettings {
  final BitcoinUnit bitcoinUnit;
  final String fiatCurrency;
  final Language? language;
  final AppThemeMode themeMode;
  final bool hideAmounts;
  final WalletAutoswapSettings autoswap;
  final List<WalletElectrumSettings> electrum;
  final List<WalletMempoolSettings> mempool;
  final WalletPayjoinSettings payjoin;

  WalletPortableSettings({
    required this.bitcoinUnit,
    required String fiatCurrency,
    required this.language,
    required this.themeMode,
    required this.hideAmounts,
    required this.autoswap,
    required Iterable<WalletElectrumSettings> electrum,
    required Iterable<WalletMempoolSettings> mempool,
    required this.payjoin,
  }) : fiatCurrency = fiatCurrency.trim().toUpperCase(),
       electrum = List.unmodifiable(
         [...electrum]
           ..sort((a, b) => a.network.index.compareTo(b.network.index)),
       ),
       mempool = List.unmodifiable(
         [...mempool]
           ..sort((a, b) => a.network.index.compareTo(b.network.index)),
       ) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(this.fiatCurrency) ||
        this.electrum.length != ElectrumServerNetwork.values.length ||
        this.electrum.map((value) => value.network).toSet().length !=
            ElectrumServerNetwork.values.length ||
        this.mempool.length != MempoolServerNetwork.values.length ||
        this.mempool.map((value) => value.network).toSet().length !=
            MempoolServerNetwork.values.length) {
      throw ArgumentError('Invalid portable settings');
    }
  }
}

final class WalletAutoswapSettings {
  final bool enabled;
  final int balanceThresholdSats;
  final int triggerBalanceSats;
  final double feeThresholdPercent;
  final bool alwaysBlock;
  final String? recipientWalletRef;

  WalletAutoswapSettings({
    required this.enabled,
    required this.balanceThresholdSats,
    required this.triggerBalanceSats,
    required this.feeThresholdPercent,
    required this.alwaysBlock,
    String? recipientWalletRef,
  }) : recipientWalletRef = _optional(recipientWalletRef) {
    if (balanceThresholdSats < 0 ||
        triggerBalanceSats < 0 ||
        !feeThresholdPercent.isFinite ||
        feeThresholdPercent < 0) {
      throw ArgumentError('Invalid autoswap settings');
    }
  }
}

final class WalletElectrumSettings {
  final ElectrumServerNetwork network;
  final List<String> customServers;
  final bool validateDomain;
  final int stopGap;
  final int timeout;
  final int retry;

  WalletElectrumSettings({
    required this.network,
    required Iterable<String> customServers,
    required this.validateDomain,
    required this.stopGap,
    required this.timeout,
    required this.retry,
  }) : customServers = List.unmodifiable(customServers) {
    if (this.customServers.toSet().length != this.customServers.length ||
        this.customServers.any((value) => !_validElectrumServer(value)) ||
        stopGap < 0 ||
        stopGap > ElectrumSettings.maxStopGap ||
        timeout <= 0 ||
        timeout > ElectrumSettings.maxTimeout ||
        retry < 0) {
      throw ArgumentError('Invalid Electrum settings');
    }
  }
}

final class WalletMempoolSettings {
  final MempoolServerNetwork network;
  final String? customServer;
  final bool useForFeeEstimation;

  WalletMempoolSettings({
    required this.network,
    String? customServer,
    required this.useForFeeEstimation,
  }) : customServer = _optional(customServer) {
    if (this.customServer != null &&
        MempoolUrlParser.tryParse(this.customServer!) == null) {
      throw ArgumentError('Invalid mempool settings');
    }
  }
}

final class WalletPayjoinSettings {
  final bool enabled;
  final int minimumAmountSats;
  final int sessionLifetimeSeconds;

  WalletPayjoinSettings({
    required this.enabled,
    required this.minimumAmountSats,
    required this.sessionLifetimeSeconds,
  }) {
    if (BigInt.from(minimumAmountSats) <
            PayjoinPolicy.minimumAllowedAmount.value ||
        BigInt.from(minimumAmountSats) >
            PayjoinPolicy.maximumAllowedAmount.value ||
        sessionLifetimeSeconds <
            PayjoinPolicy.minimumSessionLifetime.inSeconds ||
        sessionLifetimeSeconds >
            PayjoinPolicy.maximumSessionLifetime.inSeconds) {
      throw ArgumentError('Invalid Payjoin settings');
    }
  }
}

/// The complete protected-data payload in backup format v1.
///
/// It is deliberately explicit. A future category changes this format instead
/// of registering an opaque record type.
final class WalletMetadataSnapshot {
  final List<WalletMetadataLabel> labels;
  final List<FrozenWalletOutpoint> frozenOutpoints;
  final List<WalletPreferences> walletPreferences;
  final WalletPortableSettings settings;

  factory WalletMetadataSnapshot({
    required List<WalletMetadataLabel> labels,
    required List<FrozenWalletOutpoint> frozenOutpoints,
    required List<WalletPreferences> walletPreferences,
    required WalletPortableSettings settings,
  }) {
    final total =
        labels.length + frozenOutpoints.length + walletPreferences.length;
    if (total > WalletMetadataBackupLimits.maxLogicalRecords) {
      throw ArgumentError.value(total, 'records');
    }
    _requireUnique(labels.map((value) => value.identity), 'label');
    _requireUnique(
      frozenOutpoints.map(
        (value) => '${value.walletId}\u0000${value.txId}:${value.vout}',
      ),
      'frozen outpoint',
    );
    _requireUnique(
      walletPreferences.map((value) => value.walletRef),
      'wallet preference',
    );
    if (walletPreferences.any((value) => !value.hasRepresentedValue)) {
      throw ArgumentError('empty wallet preference');
    }

    final sortedLabels = List<WalletMetadataLabel>.of(labels)
      ..sort((left, right) => left.identity.compareTo(right.identity));
    final sortedFreezes = List<FrozenWalletOutpoint>.of(frozenOutpoints)
      ..sort((left, right) {
        final wallet = left.walletId.compareTo(right.walletId);
        if (wallet != 0) return wallet;
        final txid = left.txId.compareTo(right.txId);
        return txid != 0 ? txid : left.vout.compareTo(right.vout);
      });
    final sortedPreferences = List<WalletPreferences>.of(walletPreferences)
      ..sort((left, right) => left.walletRef.compareTo(right.walletRef));
    return WalletMetadataSnapshot._(
      labels: List.unmodifiable(sortedLabels),
      frozenOutpoints: List.unmodifiable(sortedFreezes),
      walletPreferences: List.unmodifiable(sortedPreferences),
      settings: settings,
    );
  }

  const WalletMetadataSnapshot._({
    required this.labels,
    required this.frozenOutpoints,
    required this.walletPreferences,
    required this.settings,
  });
}

void _requireUnique(Iterable<String> values, String description) {
  final items = values.toList(growable: false);
  if (items.toSet().length != items.length) {
    throw ArgumentError('duplicate $description identity');
  }
}

String? _optional(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

bool _validElectrumServer(String value) {
  final match = RegExp(
    r'^(?:(?:ssl|tcp)://)?([A-Za-z0-9.-]+):(\d{1,5})$',
  ).firstMatch(value);
  if (match == null) return false;
  final port = int.tryParse(match.group(2)!);
  return port != null && port >= 1 && port <= 65535;
}
