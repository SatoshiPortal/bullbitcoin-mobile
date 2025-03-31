import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';

class BroadcastOriginalTransactionUsecase {
  final PayjoinRepository _payjoin;
  final ElectrumServerRepository _electrumServerRepository;
  final WalletMetadataRepository _walletMetadataRepository;

  BroadcastOriginalTransactionUsecase({
    required PayjoinRepository payjoinRepository,
    required ElectrumServerRepository electrumServerRepository,
    required WalletMetadataRepository walletMetadataRepository,
  })  : _payjoin = payjoinRepository,
        _electrumServerRepository = electrumServerRepository,
        _walletMetadataRepository = walletMetadataRepository;

  Future<PayjoinReceiver> execute(PayjoinReceiver payjoin) async {
    try {
      if (payjoin.originalTxBytes == null) {
        throw BroadcastOriginalTransactionException(
          'No original transaction bytes to broadcast found for payjoin:'
          ' ${payjoin.id}',
        );
      }

      // Get the network from the wallet metadata using the walletId from the
      //  payjoin to be able to get the correct Electrum server to broadcast the
      //  transaction.
      final walletMetadata = await _walletMetadataRepository.get(
        payjoin.walletId,
      );

      if (walletMetadata == null) {
        throw BroadcastOriginalTransactionException(
          'Wallet metadata not found for walletId: ${payjoin.walletId}',
        );
      }

      final network = walletMetadata.network;
      final electrumServer = await _electrumServerRepository.getElectrumServer(
        network: network,
      );

      // Broadcast the original transaction using the Electrum server
      return await _payjoin.broadcastOriginalTransaction(
        payjoinId: payjoin.id,
        originalTxBytes: payjoin.originalTxBytes!,
        electrumServer: electrumServer,
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
