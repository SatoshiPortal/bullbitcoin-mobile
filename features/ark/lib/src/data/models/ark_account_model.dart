import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

/// Wire record is separate from the package's validated domain identity.
final class ArkAccountModel {
  final String json;
  const ArkAccountModel(this.json);
  factory ArkAccountModel.fromDomain(ArkAccountConfig config) =>
      ArkAccountModel(
        jsonEncode({
          'parent': config.id.parent.hex,
          'network': config.id.network.name,
          'identity': config.id.serverIdentity,
          'ark': config.arkUrl.toString(),
          'primary': config.primaryEsploraUrl.toString(),
          'fallback': config.fallbackEsploraUrl?.toString(),
          'threshold': config.renewalThresholdBlocks,
        }),
      );

  ArkAccountConfig? toDomain() {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final parent = decoded['parent'];
    final network = decoded['network'];
    final identity = decoded['identity'];
    final ark = decoded['ark'];
    final primary = decoded['primary'];
    final fallback = decoded['fallback'];
    final threshold = decoded['threshold'];
    if (parent is! String ||
        network is! String ||
        identity is! String ||
        ark is! String ||
        primary is! String ||
        (fallback != null && fallback is! String) ||
        threshold is! int ||
        threshold <= 0) {
      return null;
    }
    final fingerprint = Fingerprint.tryParse(parent);
    final networks = BitcoinNetwork.values
        .where((n) => n.name == network)
        .toList();
    if (fingerprint == null ||
        networks.length != 1 ||
        identity.isEmpty ||
        identity.length > 512 ||
        identity.trim() != identity) {
      return null;
    }
    final chain = networks.single;
    Uri? endpoint(String value) {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          !(uri.scheme == 'https' ||
              (chain != BitcoinNetwork.mainnet && uri.scheme == 'http'))) {
        return null;
      }
      return uri;
    }

    final arkUrl = endpoint(ark);
    final primaryUrl = endpoint(primary);
    final fallbackUrl = fallback is String ? endpoint(fallback) : null;
    if (arkUrl == null ||
        primaryUrl == null ||
        (fallback != null && fallbackUrl == null)) {
      return null;
    }
    return ArkAccountConfig(
      id: ArkAccountId(
        parent: fingerprint,
        network: chain,
        serverIdentity: identity,
      ),
      arkUrl: arkUrl,
      primaryEsploraUrl: primaryUrl,
      fallbackEsploraUrl: fallbackUrl,
      renewalThresholdBlocks: threshold,
    );
  }
}
