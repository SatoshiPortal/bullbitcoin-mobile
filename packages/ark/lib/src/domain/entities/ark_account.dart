import 'package:primitives/primitives.dart';

enum ArkBackend { bark }

final class ArkAccountId {
  final Fingerprint parent;
  final ArkBackend backend;
  final BitcoinNetwork network;
  final String serverIdentity;

  ArkAccountId({
    required this.parent,
    this.backend = ArkBackend.bark,
    required this.network,
    required this.serverIdentity,
  }) {
    if (serverIdentity.isEmpty ||
        serverIdentity.length > 512 ||
        serverIdentity.trim() != serverIdentity) {
      throw ArgumentError('Invalid Ark server identity');
    }
  }

  /// Unambiguous public identity, hashed by the storage layer for paths.
  String get canonical =>
      '${parent.hex}|${backend.name}|${network.name}|'
      '${serverIdentity.length}:$serverIdentity';

  @override
  bool operator ==(Object other) =>
      other is ArkAccountId && canonical == other.canonical;
  @override
  int get hashCode => canonical.hashCode;
}

final class ArkAccountConfig {
  final ArkAccountId id;
  final Uri arkUrl;
  final Uri primaryEsploraUrl;
  final Uri? fallbackEsploraUrl;
  final int renewalThresholdBlocks;

  ArkAccountConfig({
    required this.id,
    required this.arkUrl,
    required this.primaryEsploraUrl,
    this.fallbackEsploraUrl,
    this.renewalThresholdBlocks = 1008,
  }) {
    for (final url in [arkUrl, primaryEsploraUrl, fallbackEsploraUrl]) {
      if (url == null) continue;
      if (!url.hasAuthority ||
          url.userInfo.isNotEmpty ||
          url.hasFragment ||
          url.hasQuery ||
          !(url.scheme == 'https' ||
              (id.network != BitcoinNetwork.mainnet && url.scheme == 'http'))) {
        throw ArgumentError('Invalid Ark endpoint');
      }
    }
    if (renewalThresholdBlocks <= 0) {
      throw ArgumentError('Invalid renewal threshold');
    }
  }
}
