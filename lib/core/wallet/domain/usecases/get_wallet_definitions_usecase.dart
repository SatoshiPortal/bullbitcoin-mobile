import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_definition_repository.dart';

final class GetWalletDefinitionsUsecase {
  final WalletDefinitionRepository _wallet;

  const GetWalletDefinitionsUsecase(this._wallet);

  Future<List<WalletDefinition>> execute() => _wallet.getWalletDefinitions();
}
