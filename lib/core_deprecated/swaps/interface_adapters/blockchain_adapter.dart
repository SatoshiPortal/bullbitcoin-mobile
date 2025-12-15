import 'package:bb_mobile/core_deprecated/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/ports/blockchain_port.dart';

class BlockchainAdapter implements BlockchainPort {
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransactionUsecase;

  BlockchainAdapter({
    required BroadcastLiquidTransactionUsecase
    broadcastLiquidTransactionUsecase,
  }) : _broadcastLiquidTransactionUsecase = broadcastLiquidTransactionUsecase;

  @override
  Future<String> broadcastLiquidTransaction({
    required String signedPset,
    required bool isTestnet,
  }) {
    return _broadcastLiquidTransactionUsecase.execute(
      signedPset,
      isTestnet: isTestnet,
    );
  }
}
