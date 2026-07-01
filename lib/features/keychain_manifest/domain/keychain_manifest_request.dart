import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class KeychainManifestReservedDerivationRequest {
  final String reservationId;
  final String parentFingerprint;
  final List<KeychainManifestWalletMaterializationRequest> materializations;

  const KeychainManifestReservedDerivationRequest({
    required this.reservationId,
    required this.parentFingerprint,
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
