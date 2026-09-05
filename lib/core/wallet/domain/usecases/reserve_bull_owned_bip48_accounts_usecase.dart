import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class ReserveBullOwnedBip48AccountsUsecase {
  final Bip48AccountRepository _repository;
  final SeedVerificationPort _seedVerification;

  const ReserveBullOwnedBip48AccountsUsecase(
    this._repository,
    this._seedVerification,
  );

  @useResult
  Future<Result<void, Bip48AccountAllocationFailure>> execute({
    required Network network,
    required List<WalletSigner> signers,
  }) async {
    final accounts =
        <
          ({String fingerprint, int account, String xpub}),
          ({WalletDescriptorKey key, bool requiresOwnership})
        >{};
    for (final signer in signers) {
      for (final key in signer.descriptorKeys) {
        final path = key.derivationPath;
        if (!Bip48Derivation.isAccountPath(path)) continue;
        final account = Bip48Derivation.account(
          path,
          coinType: network.coinType,
        );
        if (account == null || key.masterFingerprint.isEmpty) {
          return const Err(Bip48AccountAllocationFailure());
        }
        final identity = (
          fingerprint: key.masterFingerprint.toLowerCase(),
          account: account,
          xpub: key.xpub,
        );
        final existing = accounts[identity];
        accounts[identity] = (
          key: key,
          requiresOwnership:
              (existing?.requiresOwnership ?? false) ||
              signer.signer == SignerEntity.local,
        );
      }
    }

    for (final entry in accounts.entries) {
      final identity = entry.key;
      final usage = entry.value;
      final key = usage.key;
      final matches = await _seedVerification.matchesXpubs(
        fingerprint: identity.fingerprint,
        keys: [(derivationPath: key.derivationPath!, xpub: identity.xpub)],
      );
      if (!matches) {
        if (usage.requiresOwnership) {
          return const Err(Bip48AccountAllocationFailure());
        }
        continue;
      }
      final reserved = await _repository.reserve(
        seedFingerprint: identity.fingerprint,
        coinType: network.coinType,
        account: identity.account,
      );
      if (reserved case Err()) return reserved;
    }
    return const Ok(null);
  }
}
