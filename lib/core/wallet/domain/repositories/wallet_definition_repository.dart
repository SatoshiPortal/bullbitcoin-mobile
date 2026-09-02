import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';

abstract interface class WalletDefinitionRepository {
  Stream<void> get catalogChanges;

  Future<List<WalletDefinition>> getWalletDefinitions();

  Future<WalletDefinitionRestoreResult> restoreWalletDefinition(
    WalletDefinition definition,
  );
}
