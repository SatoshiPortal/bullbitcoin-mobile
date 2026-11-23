import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_wallet_failure.dart';

abstract interface class ArkFundingSigningAuthority {
  /// Commits the possible signer exposure before any key access.
  @useResult
  Future<Result<void, ArkWalletFailure>> recordOrdinarySigning({
    required String walletId,
    required BitcoinNetwork network,
    required String unsignedPsbt,
  });
}

abstract interface class ArkInstallationEvidence {
  /// Positively proves that Ark has never been initialized and still has no
  /// custody state. A failed read must never be treated as absence.
  Future<bool> remainsUnprovisioned();
}

final class ArkFundingSigningGuard {
  final ArkFundingSigningAuthority? _authority;
  final ArkInstallationEvidence? _installation;

  const ArkFundingSigningGuard({required this._authority, this._installation});

  @useResult
  Future<Result<void, ArkWalletFailure>> admit({
    required String walletId,
    required Network network,
    required String unsignedPsbt,
  }) async {
    if (network is! BitcoinNetwork) {
      return const Err(ArkValidationFailure());
    }
    // Only these explicitly non-Ark networks retain ordinary signing
    // without the Ark authority. A new network never gains a default bypass.
    if (const {
          BitcoinNetwork.mainnet,
          BitcoinNetwork.testnet,
          BitcoinNetwork.signet,
        }.contains(network) &&
        !NetworkCapabilities.supports(network, NetworkCapability.ark)) {
      return const Ok(null);
    }
    final authority = _authority;
    try {
      if (authority != null) {
        return await authority.recordOrdinarySigning(
          walletId: walletId,
          network: network,
          unsignedPsbt: unsignedPsbt,
        );
      }
      if (network == BitcoinNetwork.regtest &&
          await _installation?.remainsUnprovisioned() == true) {
        return const Ok(null);
      }
    } on Exception {
      return const Err(ArkStorageFailure());
    }
    return const Err(ArkStorageFailure());
  }
}
