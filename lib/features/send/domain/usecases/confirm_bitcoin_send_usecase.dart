import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';

class ConfirmBitcoinSendUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final BitcoinBlockchainRepository _bitcoinBlockchainRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final LiquidBlockchainRepository _liquidBlockchainRepository;

  ConfirmBitcoinSendUsecase({
    required BitcoinWalletRepository bitcoinWalletRepository,
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required LiquidWalletRepository liquidWalletRepository,
    required LiquidBlockchainRepository liquidBlockchainRepository,
  })  : _bitcoinWalletRepository = bitcoinWalletRepository,
        _bitcoinBlockchainRepository = bitcoinBlockchainRepository,
        _liquidWalletRepository = liquidWalletRepository,
        _liquidBlockchainRepository = liquidBlockchainRepository;

  Future<String> execute({
    required String psbt,
    required Wallet wallet,
  }) async {
    try {
      if (wallet.network.isLiquid) {
        final signedPsbt = await _liquidWalletRepository.signPset(
          psbt,
          walletId: wallet.id,
        );

        final txId = await _liquidBlockchainRepository.broadcastTransaction(
          signedPsbt,
          isTestnet: wallet.network.isTestnet,
        );

        return txId;
      } else {
        final signedPsbt = await _bitcoinWalletRepository.signPsbt(
          psbt,
          walletId: wallet.id,
        );

        // Broadcast the signed PSBT to the Bitcoin network
        final txId = await _bitcoinBlockchainRepository.broadcastPsbt(
          signedPsbt,
          isTestnet: wallet.network.isTestnet,
        );

        return txId;
      }
    } catch (e) {
      throw ConfirmBitcoinSendException(e.toString());
    }
  }
}

class ConfirmBitcoinSendException implements Exception {
  final String message;

  ConfirmBitcoinSendException(this.message);
}
