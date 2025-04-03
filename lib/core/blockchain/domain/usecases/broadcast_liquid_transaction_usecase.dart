import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';

class BroadcastLiquidTransactionUsecase {
  final LiquidBlockchainRepository _liquidBlockchain;

  BroadcastLiquidTransactionUsecase({
    required LiquidBlockchainRepository liquidBlockchainRepository,
  }) : _liquidBlockchain = liquidBlockchainRepository;

  Future<String> execute(
    Uint8List transaction, {
    required bool isTestnet,
  }) async {
    try {
      final txId = await _liquidBlockchain.broadcastTransaction(
        transaction,
        isTestnet: isTestnet,
      );

      return txId;
    } catch (e) {
      throw FailedToBroadcastTransactionException(e.toString());
    }
  }
}

class FailedToBroadcastTransactionException implements Exception {
  final String message;

  FailedToBroadcastTransactionException(this.message);
}
