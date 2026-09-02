import 'package:bb_mobile/core/wallet/domain/repositories/wallet_definition_repository.dart';

final class WatchWalletCatalogChangesUsecase {
  final WalletDefinitionRepository _wallet;

  const WatchWalletCatalogChangesUsecase(this._wallet);

  Stream<void> execute() => _wallet.catalogChanges;
}
