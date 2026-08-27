import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

final class WatchWalletCatalogChangesUsecase {
  final WalletRepository _wallet;

  const WatchWalletCatalogChangesUsecase(this._wallet);

  Stream<void> execute() => _wallet.catalogChanges;
}
