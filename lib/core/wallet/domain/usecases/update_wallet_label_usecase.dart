import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

/// Writes the label a wallet shows while it is mounted.
///
/// For a passphrase wallet this is a projection: the manifest record stays
/// canonical for its identity metadata (decision 2).
final class UpdateWalletLabelUsecase {
  final WalletRepository _wallets;

  const UpdateWalletLabelUsecase(this._wallets);

  Future<void> execute({required String walletId, required String label}) =>
      _wallets.updateWalletLabel(walletId: walletId, label: label);
}
