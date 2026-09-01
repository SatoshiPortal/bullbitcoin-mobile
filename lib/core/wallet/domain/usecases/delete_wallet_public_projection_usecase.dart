import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';

/// Drops a wallet's locally cached public projection.
///
/// The private capability goes first: an interruption after this point leaves a
/// wallet that cannot sign rather than one that can sign but has no cache
/// (decision 6). Deleting a wallet that was never materialized is a no-op, so
/// the caller can retry.
final class DeleteWalletPublicProjectionUsecase {
  final WalletRepository _wallets;
  final WalletSigningMaterialResolver _resolver;

  const DeleteWalletPublicProjectionUsecase(this._wallets, this._resolver);

  Future<void> execute(String walletId) async {
    if (_resolver.isPrivateCapabilityLoaded(walletId)) {
      _resolver.clearPrivateCapability();
    }
    if (await _wallets.containsWallet(walletId)) {
      await _wallets.deleteWallet(walletId: walletId);
    }
  }
}
