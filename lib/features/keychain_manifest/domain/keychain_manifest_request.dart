import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class KeychainManifestReservedDerivationRequest {
  final String reservationId;
  final String parentFingerprint;

  /// The BIP85 path that was actually derived when the child seed was
  /// materialized. Recording refuses the request when this proven path does
  /// not match the registry reservation's exact path.
  final String derivationPath;
  final List<KeychainManifestWalletMaterializationRequest> materializations;

  const KeychainManifestReservedDerivationRequest({
    required this.reservationId,
    required this.parentFingerprint,
    required this.derivationPath,
    required this.materializations,
  });
}

class KeychainManifestWalletMaterializationRequest {
  final String walletId;
  final String childSeedFingerprint;
  final Network network;
  final String walletPurpose;
  final ScriptType scriptType;

  const KeychainManifestWalletMaterializationRequest({
    required this.walletId,
    required this.childSeedFingerprint,
    required this.network,
    required this.walletPurpose,
    required this.scriptType,
  });
}
