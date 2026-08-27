import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';

final class GetWalletRecoveryInventoryUsecase {
  final WalletRepository _wallet;

  const GetWalletRecoveryInventoryUsecase(this._wallet);

  Future<List<WalletDefinition>> execute() =>
      _wallet.getWalletRecoveryInventory();
}
