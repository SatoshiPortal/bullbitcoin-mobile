import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class ConfirmBitcoinSendUsecase {
  final WalletRepository _walletRepository;
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final BitcoinBlockchainRepository _bitcoinBlockchainRepository;

  ConfirmBitcoinSendUsecase({
    required WalletRepository walletRepository,
    required BitcoinWalletRepository bitcoinWalletRepository,
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
  })  : _walletRepository = walletRepository,
        _bitcoinWalletRepository = bitcoinWalletRepository,
        _bitcoinBlockchainRepository = bitcoinBlockchainRepository;

  Future<String> execute({
    required String psbt,
    required String walletId,
  }) async {
    try {
      final wallet = await _walletRepository.getWallet(walletId);

      final signedPsbt = await _bitcoinWalletRepository.signPsbt(
        psbt,
        walletId: walletId,
      );

      // Broadcast the signed PSBT to the Bitcoin network
      final txId = await _bitcoinBlockchainRepository.broadcastPsbt(
        signedPsbt,
        isTestnet: wallet.isTestnet,
      );

      return txId;
    } catch (e) {
      throw ConfirmBitcoinSendException(e.toString());
    }
  }
}

class ConfirmBitcoinSendException implements Exception {
  final String message;

  ConfirmBitcoinSendException(this.message);
}
