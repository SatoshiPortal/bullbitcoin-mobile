import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class BroadcastOriginalTransactionUsecase {
  final PayjoinRepository _payjoin;
  final WalletRepository _wallet;

  BroadcastOriginalTransactionUsecase({
    required PayjoinRepository payjoinRepository,
    required WalletRepository walletRepository,
  })  : _payjoin = payjoinRepository,
        _wallet = walletRepository;

  Future<PayjoinReceiver> execute(PayjoinReceiver payjoin) async {
    try {
      if (payjoin.originalTxBytes == null) {
        throw BroadcastOriginalTransactionException(
          'No original transaction bytes to broadcast found for payjoin:'
          ' ${payjoin.id}',
        );
      }

      // Get the network from the wallet to make sure we are
      // broadcasting the transaction to the correct network.
      // No need to sync the wallet data, since we just need the network info
      // which is static.
      final wallet = await _wallet.getWallet(
        payjoin.walletId,
      );

      final network = wallet.network;

      // Broadcast the original transaction using the Electrum server
      return await _payjoin.broadcastOriginalTransaction(
        payjoinId: payjoin.id,
        originalTxBytes: payjoin.originalTxBytes!,
        network: network,
      );
    } catch (e) {
      throw BroadcastOriginalTransactionException('$e');
    }
  }
}

class BroadcastOriginalTransactionException implements Exception {
  final String message;

  BroadcastOriginalTransactionException(this.message);
}
