import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';

import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class BroadcastLiquidTransactionUsecase {
  final LiquidBlockchainRepository _liquidBlockchain;

  BroadcastLiquidTransactionUsecase({
    required LiquidBlockchainRepository liquidBlockchainRepository,
  }) : _liquidBlockchain = liquidBlockchainRepository;

  Future<String> execute(Uint8List transaction,
      {required Network network}) async {
    try {
      final txId = await _liquidBlockchain.broadcastTransaction(
        transaction,
        network: network,
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
