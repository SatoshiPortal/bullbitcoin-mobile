import 'dart:convert';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_limits.dart';

final class WalletMetadataSnapshotCodec {
  static const _rootKeys = {
    'version',
    'labels',
    'frozenOutpoints',
    'walletPreferences',
    'settings',
  };
  static const _labelRequiredKeys = {'type', 'reference', 'label'};
  static const _labelAllowedKeys = {..._labelRequiredKeys, 'origin'};
  static const _freezeKeys = {'walletRef', 'txid', 'vout'};
  static const _preferenceAllowedKeys = {
    'walletRef',
    'label',
    'hideOnHome',
    'autoSweepEnabled',
  };
  static const _settingsKeys = {
    'bitcoinUnit',
    'fiatCurrency',
    'language',
    'theme',
    'hideAmounts',
    'autoswap',
    'electrum',
    'mempool',
    'payjoin',
  };
  static const _autoswapKeys = {
    'enabled',
    'balanceThresholdSats',
    'triggerBalanceSats',
    'feeThresholdPercent',
    'alwaysBlock',
    'recipientWalletRef',
  };
  static const _electrumKeys = {
    'network',
    'customServers',
    'validateDomain',
    'stopGap',
    'timeout',
    'retry',
  };
  static const _mempoolKeys = {
    'network',
    'customServer',
    'useForFeeEstimation',
  };
  static const _payjoinKeys = {
    'enabled',
    'minimumAmountSats',
    'sessionLifetimeSeconds',
  };

  const WalletMetadataSnapshotCodec();

  String encode(WalletMetadataSnapshot snapshot) {
    final payload = jsonEncode({
      'version': walletMetadataSnapshotVersion,
      'labels': snapshot.labels
          .map(
            (value) => {
              'type': _labelTypeName(value.type),
              'reference': value.reference,
              'label': value.label,
              if (value.origin != null) 'origin': value.origin,
            },
          )
          .toList(growable: false),
      'frozenOutpoints': snapshot.frozenOutpoints
          .map(
            (value) => {
              'walletRef': value.walletId,
              'txid': value.txId,
              'vout': value.vout,
            },
          )
          .toList(growable: false),
      'walletPreferences': snapshot.walletPreferences
          .map(
            (value) => {
              'walletRef': value.walletRef,
              if (value.label != null) 'label': value.label,
              if (value.hideOnHome != null) 'hideOnHome': value.hideOnHome,
              if (value.autoSweepEnabled != null)
                'autoSweepEnabled': value.autoSweepEnabled,
            },
          )
          .toList(growable: false),
      'settings': {
        'bitcoinUnit': snapshot.settings.bitcoinUnit.name,
        'fiatCurrency': snapshot.settings.fiatCurrency,
        'language': snapshot.settings.language?.name,
        'theme': snapshot.settings.themeMode.name,
        'hideAmounts': snapshot.settings.hideAmounts,
        'autoswap': {
          'enabled': snapshot.settings.autoswap.enabled,
          'balanceThresholdSats':
              snapshot.settings.autoswap.balanceThresholdSats,
          'triggerBalanceSats': snapshot.settings.autoswap.triggerBalanceSats,
          'feeThresholdPercent': snapshot.settings.autoswap.feeThresholdPercent,
          'alwaysBlock': snapshot.settings.autoswap.alwaysBlock,
          'recipientWalletRef': snapshot.settings.autoswap.recipientWalletRef,
        },
        'electrum': snapshot.settings.electrum
            .map(
              (value) => {
                'network': value.network.name,
                'customServers': value.customServers,
                'validateDomain': value.validateDomain,
                'stopGap': value.stopGap,
                'timeout': value.timeout,
                'retry': value.retry,
              },
            )
            .toList(growable: false),
        'mempool': snapshot.settings.mempool
            .map(
              (value) => {
                'network': value.network.name,
                'customServer': value.customServer,
                'useForFeeEstimation': value.useForFeeEstimation,
              },
            )
            .toList(growable: false),
        'payjoin': {
          'enabled': snapshot.settings.payjoin.enabled,
          'minimumAmountSats': snapshot.settings.payjoin.minimumAmountSats,
          'sessionLifetimeSeconds':
              snapshot.settings.payjoin.sessionLifetimeSeconds,
        },
      },
    });
    _checkSize(payload);
    return payload;
  }

  WalletMetadataSnapshot decode(String payload) {
    try {
      _checkSize(payload);
      final root = _object(jsonDecode(payload), 'document');
      _expectExactKeys(root, _rootKeys, 'document');
      if (_int(root, 'version') != walletMetadataSnapshotVersion) {
        throw const FormatException('Unsupported wallet metadata version');
      }
      final labels = _list(root, 'labels')
          .map((value) {
            final item = _object(value, 'label');
            _expectAllowedKeys(
              item,
              required: _labelRequiredKeys,
              allowed: _labelAllowedKeys,
              description: 'label',
            );
            final origin = item['origin'];
            if (origin != null && origin is! String) {
              throw const FormatException('Invalid label origin');
            }
            return WalletMetadataLabel(
              type: _parseLabelType(_string(item, 'type')),
              reference: _string(item, 'reference'),
              label: _string(item, 'label'),
              origin: origin as String?,
            );
          })
          .toList(growable: false);
      final frozenOutpoints = _list(root, 'frozenOutpoints')
          .map((value) {
            final item = _object(value, 'frozen outpoint');
            _expectExactKeys(item, _freezeKeys, 'frozen outpoint');
            final walletId = _string(item, 'walletRef');
            final txId = _string(item, 'txid').toLowerCase();
            final vout = _int(item, 'vout');
            if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(txId) ||
                vout < 0 ||
                vout > 0xffffffff) {
              throw const FormatException('Invalid frozen outpoint');
            }
            return FrozenWalletOutpoint(
              walletId: walletId,
              txId: txId,
              vout: vout,
            );
          })
          .toList(growable: false);
      final walletPreferences = _list(root, 'walletPreferences')
          .map((value) {
            final item = _object(value, 'wallet preference');
            _expectAllowedKeys(
              item,
              required: const {'walletRef'},
              allowed: _preferenceAllowedKeys,
              description: 'wallet preference',
            );
            final label = item['label'];
            final hidden = item['hideOnHome'];
            final sweep = item['autoSweepEnabled'];
            if ((label != null && label is! String) ||
                (hidden != null && hidden is! bool) ||
                (sweep != null && sweep is! bool)) {
              throw const FormatException('Invalid wallet preference value');
            }
            final walletRef = _string(item, 'walletRef');
            if (walletRef.isEmpty ||
                (label == null && hidden == null && sweep == null)) {
              throw const FormatException('Invalid wallet preference');
            }
            return WalletPreferences(
              walletRef: walletRef,
              label: label as String?,
              hideOnHome: hidden as bool?,
              autoSweepEnabled: sweep as bool?,
            );
          })
          .toList(growable: false);
      final settings = _decodeSettings(_object(root['settings'], 'settings'));
      final total =
          labels.length + frozenOutpoints.length + walletPreferences.length;
      if (total > WalletMetadataBackupLimits.maxLogicalRecords ||
          !_unique(labels.map((value) => value.identity)) ||
          !_unique(
            frozenOutpoints.map(
              (value) => '${value.walletId}\u0000${value.txId}:${value.vout}',
            ),
          ) ||
          !_unique(walletPreferences.map((value) => value.walletRef))) {
        throw const FormatException('Duplicate or excessive wallet metadata');
      }
      return WalletMetadataSnapshot(
        labels: labels,
        frozenOutpoints: frozenOutpoints,
        walletPreferences: walletPreferences,
        settings: settings,
      );
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Invalid wallet metadata', error);
    }
  }

  WalletPortableSettings _decodeSettings(Map<String, Object?> settings) {
    _expectExactKeys(settings, _settingsKeys, 'settings');
    final languageName = _nullableString(settings, 'language');
    final autoswap = _object(settings['autoswap'], 'autoswap settings');
    _expectExactKeys(autoswap, _autoswapKeys, 'autoswap settings');
    final electrum = _list(settings, 'electrum')
        .map((value) {
          final item = _object(value, 'Electrum settings');
          _expectExactKeys(item, _electrumKeys, 'Electrum settings');
          return WalletElectrumSettings(
            network: _enumByName(
              ElectrumServerNetwork.values,
              _string(item, 'network'),
            ),
            customServers: _list(item, 'customServers')
                .map((value) {
                  if (value is! String) {
                    throw const FormatException('Invalid Electrum server');
                  }
                  return value;
                })
                .toList(growable: false),
            validateDomain: _bool(item, 'validateDomain'),
            stopGap: _int(item, 'stopGap'),
            timeout: _int(item, 'timeout'),
            retry: _int(item, 'retry'),
          );
        })
        .toList(growable: false);
    final mempool = _list(settings, 'mempool')
        .map((value) {
          final item = _object(value, 'mempool settings');
          _expectExactKeys(item, _mempoolKeys, 'mempool settings');
          return WalletMempoolSettings(
            network: _enumByName(
              MempoolServerNetwork.values,
              _string(item, 'network'),
            ),
            customServer: _nullableString(item, 'customServer'),
            useForFeeEstimation: _bool(item, 'useForFeeEstimation'),
          );
        })
        .toList(growable: false);
    final payjoin = _object(settings['payjoin'], 'Payjoin settings');
    _expectExactKeys(payjoin, _payjoinKeys, 'Payjoin settings');
    return WalletPortableSettings(
      bitcoinUnit: _enumByName(
        BitcoinUnit.values,
        _string(settings, 'bitcoinUnit'),
      ),
      fiatCurrency: _string(settings, 'fiatCurrency'),
      language: languageName == null
          ? null
          : _enumByName(Language.values, languageName),
      themeMode: _enumByName(AppThemeMode.values, _string(settings, 'theme')),
      hideAmounts: _bool(settings, 'hideAmounts'),
      autoswap: WalletAutoswapSettings(
        enabled: _bool(autoswap, 'enabled'),
        balanceThresholdSats: _int(autoswap, 'balanceThresholdSats'),
        triggerBalanceSats: _int(autoswap, 'triggerBalanceSats'),
        feeThresholdPercent: _number(autoswap, 'feeThresholdPercent'),
        alwaysBlock: _bool(autoswap, 'alwaysBlock'),
        recipientWalletRef: _nullableString(autoswap, 'recipientWalletRef'),
      ),
      electrum: electrum,
      mempool: mempool,
      payjoin: WalletPayjoinSettings(
        enabled: _bool(payjoin, 'enabled'),
        minimumAmountSats: _int(payjoin, 'minimumAmountSats'),
        sessionLifetimeSeconds: _int(payjoin, 'sessionLifetimeSeconds'),
      ),
    );
  }
}

bool _unique(Iterable<String> values) {
  final items = values.toList(growable: false);
  return items.toSet().length == items.length;
}

String _labelTypeName(LabelType type) => switch (type) {
  LabelType.transaction => 'tx',
  LabelType.address => 'addr',
  LabelType.publicKey => 'pubkey',
  LabelType.input => 'input',
  LabelType.output => 'output',
  LabelType.extendedPublicKey => 'xpub',
};

LabelType _parseLabelType(String value) => switch (value) {
  'tx' => LabelType.transaction,
  'addr' => LabelType.address,
  'pubkey' => LabelType.publicKey,
  'input' => LabelType.input,
  'output' => LabelType.output,
  'xpub' => LabelType.extendedPublicKey,
  _ => throw const FormatException('Unsupported BIP329 label type'),
};

void _checkSize(String payload) {
  if (utf8.encode(payload).length >
      WalletMetadataBackupLimits.maxDecryptedSnapshotBytes) {
    throw const FormatException('Wallet metadata exceeds the byte limit');
  }
}

Map<String, Object?> _object(Object? value, String description) {
  if (value is! Map) throw FormatException('$description must be an object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$description keys must be strings');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be a list');
  return List<Object?>.from(value);
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string');
  if (utf8.encode(value).length > WalletMetadataBackupLimits.maxStringBytes) {
    throw FormatException('$key exceeds the byte limit');
  }
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be a number');
  return value.toDouble();
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string or null');
  if (utf8.encode(value).length > WalletMetadataBackupLimits.maxStringBytes) {
    throw FormatException('$key exceeds the byte limit');
  }
  return value;
}

T _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unsupported enum value: $name');
}

void _expectExactKeys(
  Map<String, Object?> value,
  Set<String> keys,
  String description,
) {
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw FormatException('$description fields are invalid');
  }
}

void _expectAllowedKeys(
  Map<String, Object?> value, {
  required Set<String> required,
  required Set<String> allowed,
  required String description,
}) {
  final keys = value.keys.toSet();
  if (!keys.containsAll(required) ||
      keys.any((key) => !allowed.contains(key))) {
    throw FormatException('$description fields are invalid');
  }
}
