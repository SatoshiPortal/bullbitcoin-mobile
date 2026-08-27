import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';

final class RestoreWalletDefinitionUsecase {
  final WalletRepository _wallet;

  const RestoreWalletDefinitionUsecase(this._wallet);

  Future<WalletDefinitionRestoreResult> execute(WalletDefinition definition) =>
      _wallet.restoreWalletDefinition(definition);
}
