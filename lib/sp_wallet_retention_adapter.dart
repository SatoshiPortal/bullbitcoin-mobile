import 'package:bb_mobile/core/wallet/domain/ports/wallet_retention_port.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:primitives/primitives.dart';

/// Composition-root bridge from generic destruction policy to the SP owner.
/// Callers hold WalletMutationGuard across this check and the mutation.
class SpWalletRetentionAdapter implements WalletRetentionPort {
  final SpFacade Function() _facade;
  final bool _allowDestructiveOperations;

  SpWalletRetentionAdapter({
    required this._facade,
    required this._allowDestructiveOperations,
  });

  @override
  Future<bool> retainsWallet(String walletId) => _retains(walletId: walletId);

  @override
  Future<bool> retainsSecret(Fingerprint secretId) =>
      _retains(secretId: secretId);

  Future<bool> _retains({String? walletId, Fingerprint? secretId}) async {
    if (!_allowDestructiveOperations) return true;
    try {
      switch (await _facade().retainsSource(
        walletId: walletId,
        secretId: secretId,
      )) {
        case Ok(:final value):
          return value;
        case Err():
          throw const WalletRetentionCheckFailed();
      }
    } catch (_) {
      // Lookup and storage failures must not disclose source metadata or
      // permit destruction when the owner cannot be consulted.
      throw const WalletRetentionCheckFailed();
    }
  }
}

class WalletRetentionCheckFailed implements Exception {
  const WalletRetentionCheckFailed();

  @override
  String toString() => 'Wallet retention cannot be verified';
}
