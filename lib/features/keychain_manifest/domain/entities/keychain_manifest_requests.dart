import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

final class KeychainManifestWalletBinding {
  final String walletId;
  final Fingerprint childSeedFingerprint;
  final Network network;
  final ScriptType scriptType;

  const KeychainManifestWalletBinding({
    required this.walletId,
    required this.childSeedFingerprint,
    required this.network,
    required this.scriptType,
  });
}
