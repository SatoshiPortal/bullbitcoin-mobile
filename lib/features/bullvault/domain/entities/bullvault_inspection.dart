import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';

enum BullVaultKeyAccess { available, unavailable, external, passphraseRequired }

final class BullVaultInspection {
  final BullVaultRecord record;
  final Wallet wallet;
  final Map<String, BullVaultKeyAccess> keyAccess;

  BullVaultInspection(
    this.record,
    this.wallet,
    Map<String, BullVaultKeyAccess> keyAccess,
  ) : keyAccess = Map.unmodifiable(keyAccess);

  WalletSigner? signerForKey(BitcoinPolicyKey key) {
    final matches = wallet.signers
        .where((signer) => signer.descriptorKeys.any(key.matches))
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  BullVaultKeyAccess accessForSigner(
    WalletSigner signer, {
    BitcoinPolicyKey? policyKey,
  }) {
    final keys = signer.descriptorKeys.where(
      (key) => policyKey == null || policyKey.matches(key),
    );
    final access = keys
        .map((key) => keyAccess[key.id] ?? BullVaultKeyAccess.unavailable)
        .toSet();
    if (access.isEmpty || access.contains(BullVaultKeyAccess.unavailable)) {
      return BullVaultKeyAccess.unavailable;
    }
    if (access.contains(BullVaultKeyAccess.passphraseRequired)) {
      return BullVaultKeyAccess.passphraseRequired;
    }
    if (access.contains(BullVaultKeyAccess.external)) {
      return BullVaultKeyAccess.external;
    }
    return BullVaultKeyAccess.available;
  }

  Set<BullVaultSignerRole> rolesForSigner(
    WalletSigner signer, {
    BitcoinPolicyKey? policyKey,
  }) {
    String canonical(String xpub) =>
        Bip32Derivation.getBip32Xpub(xpub).toBase58();
    final xpubs = signer.descriptorKeys
        .where((key) => policyKey == null || policyKey.matches(key))
        .map((key) => canonical(key.xpub))
        .toSet();
    final policy = record.recoveryPackage.policy;
    return {
      for (final key in [
        policy.everydayKey,
        ?policy.delayedMobileRecoveryKey,
        policy.coldKey,
        ?policy.secondColdKey,
        ?policy.inheritanceKey,
      ])
        if (xpubs.contains(canonical(key.accountKey.xpub))) key.role,
    };
  }
}
