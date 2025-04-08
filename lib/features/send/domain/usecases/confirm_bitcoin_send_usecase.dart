import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class ConfirmBitcoinSendUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final BitcoinBlockchainRepository _bitcoinBlockchainRepository;
  final WalletRepository _walletRepository;

  ConfirmBitcoinSendUsecase({
    required BitcoinWalletRepository bitcoinWalletRepository,
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required WalletRepository walletRepository,
  })  : _bitcoinWalletRepository = bitcoinWalletRepository,
        _bitcoinBlockchainRepository = bitcoinBlockchainRepository,
        _walletRepository = walletRepository;
  Future<String> execute({
    required String psbt,
    required String walletId,
  }) async {
    try {
      final wallet = await _walletRepository.getWallet(walletId);

      // Check if the wallet is a Bitcoin wallet
      if (!wallet.network.isBitcoin) {
        throw Exception('Wallet $walletId is not a Bitcoin wallet');
      }

      // Sign the PSBT using the Bitcoin wallet repository
      final signedPsbt =
          await _bitcoinWalletRepository.signPsbt(psbt, walletId: walletId);

      // Broadcast the signed PSBT to the Bitcoin network
      final txId = await _bitcoinBlockchainRepository.broadcastPsbt(
        signedPsbt,
        isTestnet: wallet.network.isTestnet,
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
