import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';

extension KeychainManifestNostrKeyDisplay on KeychainManifestEntry {
  bool get isSystemNostrKey {
    final key = materializations.singleOrNull;
    return key is KeychainManifestNostrKey &&
        key.keyKind == KeychainManifestNostrKeyKind.reserved;
  }
}
