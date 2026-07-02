import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Product-neutral instructions for materializing wallets from one reserved
/// BIP85 child mnemonic.
class DeterministicWalletsRequest {
  final int bip85Index;
  final String bip85Alias;
  final Environment environment;
  final List<DeterministicWalletSpec> walletSpecs;

  const DeterministicWalletsRequest({
    required this.bip85Index,
    required this.bip85Alias,
    required this.environment,
    required this.walletSpecs,
  });
}

class DeterministicWalletSpec {
  final String id;
  final Network network;
  final ScriptType scriptType;
  final String? label;
  final bool isDefault;
  final bool sync;

  const DeterministicWalletSpec({
    required this.id,
    required this.network,
    required this.scriptType,
    this.label,
    required this.isDefault,
    required this.sync,
  });
}

class PreparedDeterministicWallets {
  final List<PreparedDeterministicWallet> wallets;

  /// The BIP85 derivation path that was actually derived for the child seed,
  /// as reported by the derivation layer (registry-relative, e.g.
  /// `39'/0'/12'/100'`). Consumers that persist recovery metadata must record
  /// this proven path rather than re-declaring the reserved path themselves.
  final String derivationPath;
  final String parentFingerprint;
  final String childSeedFingerprint;
  final bool childSeedStoredDuringAttempt;

  const PreparedDeterministicWallets({
    required this.wallets,
    required this.derivationPath,
    required this.parentFingerprint,
    required this.childSeedFingerprint,
    required this.childSeedStoredDuringAttempt,
  });

  bool get shouldDeleteChildSeedOnRollback {
    final hasReusedWallets = wallets.any((wallet) => !wallet.created);
    return childSeedStoredDuringAttempt && !hasReusedWallets;
  }
}

class PreparedDeterministicWallet {
  final String specId;
  final String walletId;
  final Network network;
  final ScriptType scriptType;
  final String? label;
  final String externalPublicDescriptor;
  final String internalPublicDescriptor;
  final bool created;

  const PreparedDeterministicWallet({
    required this.specId,
    required this.walletId,
    required this.network,
    required this.scriptType,
    this.label,
    required this.externalPublicDescriptor,
    required this.internalPublicDescriptor,
    required this.created,
  });
}
