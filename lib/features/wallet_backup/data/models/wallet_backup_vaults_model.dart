import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';

/// The vaults section: BullVault recovery packages, verbatim.
///
/// The package bytes are the vault feature's own codec output; this codec only
/// frames them, checks that the framing facts agree with the package, bounds
/// the section and fixes the order.
final class WalletBackupVaultsCodec {
  static const currentVersion = 1;
  static const maxEntries = 32;
  static const _payloadKeys = {'version', 'vaults'};
  static const _entryKeys = {
    'walletRef',
    'label',
    'status',
    'network',
    'lineageId',
    'vaultGeneration',
    'recoveryPackage',
  };

  final InspectVaultRecoveryPackage _inspect;

  const WalletBackupVaultsCodec({required this._inspect});

  String encode(List<WalletBackupVaultEntry> entries) {
    final sorted = [...entries]..sort(WalletBackupVaultEntry.compare);
    _bound(sorted);
    return jsonEncode({
      'version': currentVersion,
      'vaults': [for (final entry in sorted) _toJson(entry)],
    });
  }

  List<WalletBackupVaultEntry> decode(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      throw const FormatException('Vaults must be valid JSON');
    }
    final object = _object(decoded, 'vaults');
    _exactKeys(object, _payloadKeys, 'vaults');
    if (object['version'] != currentVersion) {
      throw const FormatException('Unsupported vaults version');
    }
    final values = object['vaults'];
    if (values is! List) throw const FormatException('Vaults must be a list');
    final entries = [
      for (final value in values) _fromJson(_object(value, 'vault')),
    ]..sort(WalletBackupVaultEntry.compare);
    _bound(entries);
    return List.unmodifiable(entries);
  }

  Map<String, Object?> _toJson(WalletBackupVaultEntry entry) => {
    'walletRef': entry.walletRef,
    'label': entry.label,
    'status': entry.status,
    'network': entry.network.name,
    'lineageId': entry.lineageId,
    'vaultGeneration': entry.vaultGeneration,
    'recoveryPackage': entry.recoveryPackage,
  };

  WalletBackupVaultEntry _fromJson(Map<String, Object?> json) {
    _exactKeys(json, _entryKeys, 'vault');
    final networkName = _string(json, 'network');
    final network = Network.values
        .where((value) => value.name == networkName)
        .firstOrNull;
    final generation = json['vaultGeneration'];
    final package = _string(json, 'recoveryPackage');
    if (network == null || generation is! int) {
      throw const FormatException('Invalid vault entry');
    }
    final WalletBackupVaultEntry entry;
    try {
      entry = WalletBackupVaultEntry(
        walletRef: _string(json, 'walletRef'),
        label: _nullableString(json, 'label'),
        status: _string(json, 'status'),
        network: network,
        lineageId: _string(json, 'lineageId'),
        vaultGeneration: generation,
        recoveryPackage: package,
      );
    } on ArgumentError {
      throw const FormatException('Invalid vault entry');
    }
    final facts = _inspect(entry.recoveryPackage);
    if (facts == null ||
        facts.network != entry.network ||
        facts.lineageId != entry.lineageId ||
        facts.vaultGeneration != entry.vaultGeneration) {
      throw const FormatException('Vault entry does not match its package');
    }
    return entry;
  }

  static void _bound(List<WalletBackupVaultEntry> entries) {
    if (entries.length > maxEntries) {
      throw const FormatException('Too many vaults');
    }
    final refs = <String>{};
    for (final entry in entries) {
      if (!refs.add(entry.walletRef)) {
        throw const FormatException('Duplicate vault entry');
      }
    }
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

void _exactKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String description,
) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw FormatException('$description contains missing or unknown fields');
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('$key must be a string');
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('$key must be a string or null');
}
