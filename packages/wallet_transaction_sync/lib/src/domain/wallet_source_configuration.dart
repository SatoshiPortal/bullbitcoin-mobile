import 'dart:convert';

import 'package:crypto/crypto.dart';

sealed class WalletSourceConfiguration {
  const WalletSourceConfiguration();

  /// Non-reversible fingerprint of the wallet-identity part of this
  /// configuration. Backend endpoints, tuning options, and local storage
  /// locations are deliberately excluded: replacing an Electrum server or
  /// moving the database directory must not be judged a wallet replacement.
  String get fingerprint {
    final encoded = jsonEncode(_canonical(identityMap()));
    return sha256.convert(utf8.encode(encoded)).toString();
  }

  /// The fields that define which wallet this is (descriptors, network,
  /// source kind) — the input of [fingerprint].
  Map<String, Object?> identityMap();

  Map<String, Object?> toMap();
}

final class BdkElectrumConfiguration extends WalletSourceConfiguration {
  final String externalPublicDescriptor;
  final String internalPublicDescriptor;
  final bool isTestnet;
  final List<String> electrumUrls;
  final int stopGap;
  final bool validateDomain;
  final String databaseFilePath;

  const BdkElectrumConfiguration({
    required this.externalPublicDescriptor,
    required this.internalPublicDescriptor,
    required this.isTestnet,
    required this.electrumUrls,
    required this.stopGap,
    required this.validateDomain,
    required this.databaseFilePath,
  });

  @override
  Map<String, Object?> identityMap() => {
    'kind': 'bdk_electrum',
    'externalPublicDescriptor': externalPublicDescriptor,
    'internalPublicDescriptor': internalPublicDescriptor,
    'isTestnet': isTestnet,
  };

  @override
  Map<String, Object?> toMap() => {
    ...identityMap(),
    'electrumUrls': electrumUrls,
    'stopGap': stopGap,
    'validateDomain': validateDomain,
    'databaseFilePath': databaseFilePath,
  };

  @override
  String toString() =>
      'BdkElectrumConfiguration(testnet: $isTestnet, urls: ${electrumUrls.length})';
}

final class LwkElectrumConfiguration extends WalletSourceConfiguration {
  final String confidentialPublicDescriptor;
  final bool isTestnet;
  final List<String> electrumUrls;
  final bool validateDomain;
  final String databaseRootPath;
  final int? timeout;
  final int? stopAtIndex;

  const LwkElectrumConfiguration({
    required this.confidentialPublicDescriptor,
    required this.isTestnet,
    required this.electrumUrls,
    required this.validateDomain,
    required this.databaseRootPath,
    this.timeout,
    this.stopAtIndex,
  });

  @override
  Map<String, Object?> identityMap() => {
    'kind': 'lwk_electrum',
    'confidentialPublicDescriptor': confidentialPublicDescriptor,
    'isTestnet': isTestnet,
  };

  @override
  Map<String, Object?> toMap() => {
    'kind': 'lwk_electrum',
    'isTestnet': isTestnet,
    'electrumUrls': electrumUrls,
    'validateDomain': validateDomain,
    'databaseRootPath': databaseRootPath,
    if (timeout != null) 'timeout': timeout,
    if (stopAtIndex != null) 'stopAtIndex': stopAtIndex,
  };

  @override
  String toString() =>
      'LwkElectrumConfiguration(testnet: $isTestnet, urls: ${electrumUrls.length})';
}

final class OpaqueSourceConfiguration extends WalletSourceConfiguration {
  final String token;

  const OpaqueSourceConfiguration(this.token);

  @override
  Map<String, Object?> identityMap() => {'kind': 'opaque', 'token': token};

  @override
  Map<String, Object?> toMap() => identityMap();

  @override
  String toString() => 'OpaqueSourceConfiguration';
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return <String, Object?>{
      for (final entry in entries)
        entry.key.toString(): _canonical(entry.value),
    };
  }
  if (value is Iterable) return value.map(_canonical).toList();
  return value;
}
