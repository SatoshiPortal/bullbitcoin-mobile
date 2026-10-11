import 'dart:collection';
import 'dart:convert';

import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/data/bip85_derivation_model.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_portable_settings_backup.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show Sats;

/// The only wire model for the scoped snapshot. No transport, timestamps of
/// publication, local test receipts, secrets, or runtime settings enter it.
final class WalletBackupSnapshotModel {
  static const kind = 'bullbitcoin-data-backup';
  static const version = 1;
  final Map<String, dynamic> json;

  const WalletBackupSnapshotModel(this.json);

  factory WalletBackupSnapshotModel.fromEntity(
    WalletBackupSnapshot snapshot,
    String Function(BullVaultRecoveryPackage) encodePackage,
  ) {
    final manifest = snapshot.manifest;
    for (final derivation in manifest.derivations) {
      _validateDerivation(derivation);
    }
    final metadata = snapshot.metadata;
    final settings = metadata.settings;
    return WalletBackupSnapshotModel({
      'kind': kind,
      'version': version,
      'inventory': {
        'sourceFingerprint': manifest.sourceFingerprint,
        'wallets': _sorted(manifest.wallets.map(_wallet)),
        'derivations': _sorted(
          manifest.derivations.map(
            (entry) => {
              'path': entry.path,
              'fingerprint': entry.xprvFingerprint,
              'alias': entry.alias,
              'status': entry.status.name,
              'application': entry.application.name,
              'index': entry.index,
            },
          ),
        ),
        'nostrKeys': _sorted(
          manifest.nostrKeys.map(
            (key) => {
              'parentFingerprint': key.parentFingerprint,
              'identity': key.identity,
              'publicKey': key.publicKey,
              'purpose': key.purpose,
              'description': key.description,
              'createdAt': key.createdAt.millisecondsSinceEpoch,
              'updatedAt': key.updatedAt.millisecondsSinceEpoch,
            },
          ),
        ),
        'backupIdentities': _sorted(
          manifest.backupIdentities.map(
            (identity) => {
              'parentFingerprint': identity.parentFingerprint,
              'publicKey': identity.publicKey,
              'derivationSteps': identity.derivationSteps,
            },
          ),
        ),
      },
      'vaults': _sorted(
        snapshot.vaults.map(
          (entry) => {
            'reference': entry.reference,
            'status': entry.status.name,
            'recoveryPackage': jsonDecode(encodePackage(entry.recoveryPackage)),
          },
        ),
      ),
      'metadata': {
        'labels': _sorted(
          metadata.labels.map(
            (label) => {
              'type': label.type.name,
              'reference': label.reference,
              'label': label.label,
              'origin': label.origin,
            },
          ),
        ),
        'frozenOutputs': _sorted(
          metadata.frozenOutputs.map(
            (output) => {
              'walletReference': output.walletReference,
              'txId': output.txId,
              'vout': output.vout,
            },
          ),
        ),
        'settings': {
          'app': {
            'bitcoinUnit': settings.app.bitcoinUnit.name,
            'currency': settings.app.currency,
            'language': settings.app.language.name,
            'themeMode': settings.app.themeMode.name,
            'hideAmounts': settings.app.hideAmounts,
          },
          'autoSwap': {
            'enabled': settings.autoSwap.enabled,
            'balanceThresholdSats': settings.autoSwap.balanceThresholdSats,
            'triggerBalanceSats': settings.autoSwap.triggerBalanceSats,
            'feeThresholdPercent': settings.autoSwap.feeThresholdPercent,
            'alwaysBlock': settings.autoSwap.alwaysBlock,
            'recipientWalletReference':
                settings.autoSwap.recipientWalletReference,
          },
          'payjoin': {
            'enabled': settings.payjoin.enabled,
            'minimumAmount': settings.payjoin.minimumAmount.value.toInt(),
            'sessionLifetimeSeconds':
                settings.payjoin.sessionLifetime.inSeconds,
          },
          'electrum': _sorted(
            settings.electrum.map(
              (network) => {
                'network': network.network.name,
                'servers': _sorted(
                  network.servers.map(
                    (server) => {
                      'url': server.url,
                      'priority': server.priority,
                    },
                  ),
                ),
                'validateDomain': network.validateDomain,
                'stopGap': network.stopGap,
                'timeout': network.timeout,
                'retry': network.retry,
              },
            ),
          ),
          'mempool': _sorted(
            settings.mempool.map(
              (network) => {
                'network': network.network.name,
                'customUrl': network.customUrl,
                'useForFeeEstimation': network.useForFeeEstimation,
              },
            ),
          ),
        },
      },
    });
  }

  WalletBackupSnapshot toEntity(
    BullVaultRecoveryPackage Function(String) decodePackage,
  ) {
    final root = _record(json, {
      'kind',
      'version',
      'inventory',
      'vaults',
      'metadata',
    });
    final inventory = _record(root['inventory'], {
      'sourceFingerprint',
      'wallets',
      'derivations',
      'nostrKeys',
      'backupIdentities',
    });
    final metadata = _record(root['metadata'], {
      'labels',
      'frozenOutputs',
      'settings',
    });
    return WalletBackupSnapshot(
      manifest: KeychainManifest(
        sourceFingerprint: _text(inventory['sourceFingerprint']),
        wallets: _list(inventory['wallets']).map(_readWallet).toList(),
        derivations: _list(inventory['derivations']).map((value) {
          final entry = _record(value, {
            'path',
            'fingerprint',
            'alias',
            'status',
            'application',
            'index',
          });
          final derivation = Bip85DerivationEntity(
            path: _text(entry['path']),
            xprvFingerprint: _text(entry['fingerprint']),
            alias: _nullableText(entry['alias']),
            status: _enum(entry['status'], Bip85Status.values),
            application: _enum(entry['application'], Bip85Application.values),
            index: _integer(entry['index']),
          );
          _validateDerivation(derivation);
          return derivation;
        }).toList(),
        nostrKeys: _list(inventory['nostrKeys']).map((value) {
          final key = _record(value, {
            'parentFingerprint',
            'identity',
            'publicKey',
            'purpose',
            'description',
            'createdAt',
            'updatedAt',
          });
          return NostrKeyRecord(
            parentFingerprint: _text(key['parentFingerprint']),
            identity: _integer(key['identity']),
            publicKey: _text(key['publicKey']),
            purpose: _text(key['purpose']),
            description: _text(key['description']),
            createdAt: _date(key['createdAt']),
            updatedAt: _date(key['updatedAt']),
          );
        }).toList(),
        backupIdentities: _list(inventory['backupIdentities']).map((value) {
          final key = _record(value, {
            'parentFingerprint',
            'publicKey',
            'derivationSteps',
          });
          return BackupIdentityRecord.fromInstruction(
            parentFingerprint: _text(key['parentFingerprint']),
            publicKey: _text(key['publicKey']),
            derivationSteps: _list(key['derivationSteps']).map(_text).toList(),
          );
        }).toList(),
      ),
      vaults: _list(root['vaults']).map((value) {
        final entry = _record(value, {
          'reference',
          'status',
          'recoveryPackage',
        });
        return BullVaultBackupEntry(
          reference: _text(entry['reference']),
          status: _enum(entry['status'], BullVaultLifecycleStatus.values),
          recoveryPackage: decodePackage(jsonEncode(entry['recoveryPackage'])),
        );
      }).toList(),
      metadata: WalletMetadataBackup(
        labels: _list(metadata['labels']).map((value) {
          final label = _record(value, {
            'type',
            'reference',
            'label',
            'origin',
          });
          final text = _text(label['label']);
          if (LabelEntity.sanitizeLabel(text) != text) {
            throw const FormatException('Noncanonical label');
          }
          return LabelEntity(
            id: 0,
            type: _enum(label['type'], LabelType.values),
            reference: _text(label['reference']),
            label: text,
            origin: _nullableText(label['origin']),
          );
        }).toList(),
        frozenOutputs: _list(metadata['frozenOutputs']).map((value) {
          final output = _record(value, {'walletReference', 'txId', 'vout'});
          return BackupFrozenOutput(
            walletReference: _nullableText(output['walletReference']),
            txId: _text(output['txId']),
            vout: _integer(output['vout']),
          );
        }).toList(),
        settings: _readSettings(metadata['settings']),
      ),
    );
  }

  String canonicalJson() => jsonEncode(_canonical(json));

  static Object? _canonical(Object? value) => switch (value) {
    final Map<String, dynamic> map => SplayTreeMap<String, dynamic>.from(
      map.map((key, value) => MapEntry(key, _canonical(value))),
    ),
    final List list => list.map(_canonical).toList(),
    _ => value,
  };

  static List<Map<String, dynamic>> _sorted(
    Iterable<Map<String, dynamic>> entries,
  ) => entries.toList()
    ..sort(
      (a, b) => jsonEncode(_canonical(a)).compareTo(jsonEncode(_canonical(b))),
    );

  static Map<String, dynamic> _wallet(BackupWallet wallet) => {
    'reference': wallet.reference,
    'network': wallet.network.name,
    'publicDescriptor': wallet.publicDescriptor,
    'isDefault': wallet.isDefault,
    'isHidden': wallet.isHidden,
    'label': wallet.label,
    'birthday': wallet.birthday?.millisecondsSinceEpoch,
    'signers': [
      for (final signer in wallet.signers)
        {
          'id': signer.id,
          'signer': signer.signer.name,
          'signerDevice': signer.signerDevice?.name,
          'registrationName': signer.registrationName,
          'localSeedFingerprint': signer.localSeedFingerprint,
          'descriptorKeys': [
            for (final key in signer.descriptorKeys)
              {
                'id': key.id,
                'signerId': key.signerId,
                'masterFingerprint': key.masterFingerprint,
                'xpubFingerprint': key.xpubFingerprint,
                'xpub': key.xpub,
                'derivationPath': key.derivationPath,
                'descriptorPath': key.descriptorPath,
                'requiresPassphrase': key.requiresPassphrase,
              },
          ],
        },
    ],
  };

  static BackupWallet _readWallet(Object? value) {
    final wallet = _record(value, {
      'reference',
      'network',
      'publicDescriptor',
      'isDefault',
      'isHidden',
      'label',
      'birthday',
      'signers',
    });
    return BackupWallet(
      reference: _text(wallet['reference']),
      network: _enum(wallet['network'], Network.values),
      publicDescriptor: _text(wallet['publicDescriptor']),
      isDefault: _boolean(wallet['isDefault']),
      isHidden: _boolean(wallet['isHidden']),
      label: _nullableText(wallet['label']),
      birthday: wallet['birthday'] == null ? null : _date(wallet['birthday']),
      signers: _list(wallet['signers']).map((value) {
        final signer = _record(value, {
          'id',
          'signer',
          'signerDevice',
          'registrationName',
          'localSeedFingerprint',
          'descriptorKeys',
        });
        final id = _nonempty(signer['id']);
        final kind = _enum(signer['signer'], SignerEntity.values);
        final localFingerprint = _nullableText(signer['localSeedFingerprint']);
        final registrationName = _nullableText(signer['registrationName']);
        final keys = _list(signer['descriptorKeys']).map((value) {
          final key = _record(value, {
            'id',
            'signerId',
            'masterFingerprint',
            'xpubFingerprint',
            'xpub',
            'derivationPath',
            'descriptorPath',
            'requiresPassphrase',
          });
          final fingerprint = _text(key['masterFingerprint']);
          final xpubFingerprint = _text(key['xpubFingerprint']);
          final xpub = _text(key['xpub']);
          if (_text(key['signerId']) != id ||
              [
                fingerprint,
                xpubFingerprint,
                xpub,
              ].every((s) => s.trim().isEmpty)) {
            throw const FormatException('Invalid descriptor key');
          }
          return WalletDescriptorKey(
            id: _nonempty(key['id']),
            signerId: id,
            masterFingerprint: fingerprint,
            xpubFingerprint: xpubFingerprint,
            xpub: xpub,
            derivationPath: _nullableText(key['derivationPath']),
            descriptorPath: _text(key['descriptorPath']),
            requiresPassphrase: _boolean(key['requiresPassphrase']),
          );
        }).toList();
        if (keys.isEmpty ||
            registrationName != null && registrationName.trim().isEmpty ||
            localFingerprint != null &&
                (localFingerprint.trim().isEmpty ||
                    kind != SignerEntity.local)) {
          throw const FormatException('Invalid signer annotation');
        }
        return WalletSigner(
          id: id,
          signer: kind,
          signerDevice: signer['signerDevice'] == null
              ? null
              : _enum(signer['signerDevice'], SignerDeviceEntity.values),
          registrationName: registrationName,
          localSeedFingerprint: localFingerprint,
          descriptorKeys: keys,
        );
      }).toList(),
    );
  }

  static WalletPortableSettingsBackup _readSettings(Object? value) {
    final settings = _record(value, {
      'app',
      'autoSwap',
      'payjoin',
      'electrum',
      'mempool',
    });
    final app = _record(settings['app'], {
      'bitcoinUnit',
      'currency',
      'language',
      'themeMode',
      'hideAmounts',
    });
    final swaps = _record(settings['autoSwap'], {
      'enabled',
      'balanceThresholdSats',
      'triggerBalanceSats',
      'feeThresholdPercent',
      'alwaysBlock',
      'recipientWalletReference',
    });
    final payjoin = _record(settings['payjoin'], {
      'enabled',
      'minimumAmount',
      'sessionLifetimeSeconds',
    });
    final amount = _integer(payjoin['minimumAmount']);
    final lifetime = _integer(payjoin['sessionLifetimeSeconds']);
    if (amount < PayjoinPolicy.minimumAllowedAmount.value.toInt() ||
        amount > PayjoinPolicy.maximumAllowedAmount.value.toInt() ||
        lifetime < PayjoinPolicy.minimumSessionLifetime.inSeconds ||
        lifetime > PayjoinPolicy.maximumSessionLifetime.inSeconds) {
      throw const FormatException('Invalid Payjoin preferences');
    }
    return WalletPortableSettingsBackup(
      app: PortableAppSettings(
        bitcoinUnit: _enum(app['bitcoinUnit'], BitcoinUnit.values),
        currency: _text(app['currency']),
        language: _enum(app['language'], Language.values),
        themeMode: _enum(app['themeMode'], AppThemeMode.values),
        hideAmounts: _boolean(app['hideAmounts']),
      ),
      autoSwap: PortableAutoSwapSettings(
        enabled: _boolean(swaps['enabled']),
        balanceThresholdSats: _integer(swaps['balanceThresholdSats']),
        triggerBalanceSats: _integer(swaps['triggerBalanceSats']),
        feeThresholdPercent: _number(swaps['feeThresholdPercent']),
        alwaysBlock: _boolean(swaps['alwaysBlock']),
        recipientWalletReference: _nullableText(
          swaps['recipientWalletReference'],
        ),
      ),
      payjoin: PayjoinPolicy(
        enabled: _boolean(payjoin['enabled']),
        minimumAmount: Sats.fromInt(amount),
        sessionLifetime: Duration(seconds: lifetime),
      ),
      electrum: _list(settings['electrum']).map((value) {
        final network = _record(value, {
          'network',
          'servers',
          'validateDomain',
          'stopGap',
          'timeout',
          'retry',
        });
        return PortableElectrumSettings(
          network: _enum(network['network'], ElectrumServerNetwork.values),
          servers: _list(network['servers']).map((value) {
            final server = _record(value, {'url', 'priority'});
            return PortableElectrumServer(
              url: _text(server['url']),
              priority: _integer(server['priority']),
            );
          }).toList(),
          validateDomain: _boolean(network['validateDomain']),
          stopGap: _integer(network['stopGap']),
          timeout: _integer(network['timeout']),
          retry: _integer(network['retry']),
        );
      }).toList(),
      mempool: _list(settings['mempool']).map((value) {
        final network = _record(value, {
          'network',
          'customUrl',
          'useForFeeEstimation',
        });
        return PortableMempoolSettings(
          network: _enum(network['network'], MempoolServerNetwork.values),
          customUrl: _nullableText(network['customUrl']),
          useForFeeEstimation: _boolean(network['useForFeeEstimation']),
        );
      }).toList(),
    );
  }

  static void _validateDerivation(Bip85DerivationEntity entry) {
    final model = Bip85DerivationModel.fromEntity(entry);
    final parts = entry.path.split('/');
    if (entry.path.length > 200 ||
        parts.length < 2 ||
        parts.any(
          (part) =>
              !RegExp(r"^(0|[1-9][0-9]*)'$").hasMatch(part) ||
              (int.tryParse(part.replaceAll("'", '')) ??
                      (Bip85Reservations.maxIndex + 1)) >
                  Bip85Reservations.maxIndex,
        ) ||
        parts.first != "${model.application.number}'" ||
        entry.index < 0 ||
        entry.index > Bip85Reservations.maxIndex ||
        parts.last != "${entry.index}'" ||
        Bip85Reservations.isReservedPath(entry.path)) {
      throw const FormatException('Invalid public derivation');
    }
  }

  static Map<String, dynamic> _record(Object? value, Set<String> fields) {
    if (value is! Map<String, dynamic> ||
        value.length != fields.length ||
        !fields.containsAll(value.keys)) {
      throw const FormatException('Unexpected snapshot fields');
    }
    return value;
  }

  static List<dynamic> _list(Object? value) =>
      value is List ? value : throw const FormatException('Expected list');
  static String _text(Object? value) =>
      value is String ? value : throw const FormatException('Expected text');
  static String _nonempty(Object? value) {
    final text = _text(value);
    if (text.trim().isEmpty) {
      throw const FormatException('Expected nonempty text');
    }
    return text;
  }

  static String? _nullableText(Object? value) =>
      value == null ? null : _text(value);
  static int _integer(Object? value) =>
      value is int ? value : throw const FormatException('Expected integer');
  static bool _boolean(Object? value) =>
      value is bool ? value : throw const FormatException('Expected boolean');
  static double _number(Object? value) => value is num && value.isFinite
      ? value.toDouble()
      : throw const FormatException('Expected finite number');
  static DateTime _date(Object? value) {
    final milliseconds = _integer(value);
    if (milliseconds < 0 || milliseconds > 8640000000000000) {
      throw const FormatException('Invalid date');
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  static T _enum<T extends Enum>(Object? value, List<T> entries) =>
      entries.where((entry) => entry.name == value).firstOrNull ??
      (throw const FormatException('Unknown snapshot value'));
}
