import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';

class KeychainRecoveryWalletMaterializationBatch {
  final String parentFingerprint;
  final int bip85Index;
  final String deterministicAlias;
  final List<KeychainManifestWalletMaterializationIntent> intents;

  const KeychainRecoveryWalletMaterializationBatch({
    required this.parentFingerprint,
    required this.bip85Index,
    required this.deterministicAlias,
    required this.intents,
  });
}

class KeychainRecoveryMaterializedWallet {
  final KeychainManifestWalletMaterializationIntent intent;
  final Network network;
  final String childSeedFingerprint;
  final bool created;

  const KeychainRecoveryMaterializedWallet({
    required this.intent,
    required this.network,
    required this.childSeedFingerprint,
    required this.created,
  });
}

class KeychainRecoveryWalletMaterializationResult {
  final List<KeychainRecoveryMaterializedWallet> materializedWallets;
  final List<KeychainRecoveryWalletRestoreOutcome> failedOutcomes;

  /// The derivation-proven BIP85 path reported by the wallet materialization
  /// layer. Non-null whenever [materializedWallets] is not empty.
  final String? derivationPath;

  const KeychainRecoveryWalletMaterializationResult({
    required this.materializedWallets,
    required this.failedOutcomes,
    this.derivationPath,
  });
}

abstract class KeychainRecoveryWalletMaterializerPort {
  Future<KeychainRecoveryWalletMaterializationResult> materialize(
    KeychainRecoveryWalletMaterializationBatch batch,
  );
}
