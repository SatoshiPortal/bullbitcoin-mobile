import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_definition_repository.dart';

final class RestoreWalletDefinitionUsecase {
  final WalletDefinitionRepository _wallet;

  const RestoreWalletDefinitionUsecase(this._wallet);

  Future<WalletDefinitionRestoreResult> execute(WalletDefinition definition) =>
      _wallet.restoreWalletDefinition(definition);
}
