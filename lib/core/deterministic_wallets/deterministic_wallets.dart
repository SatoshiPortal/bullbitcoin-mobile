import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

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

  bool get shouldDeleteChildSeedOnRollback =>
      childSeedStoredDuringAttempt && wallets.every((wallet) => wallet.created);
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

final class DeterministicWalletMismatchException implements Exception {
  const DeterministicWalletMismatchException();
}
