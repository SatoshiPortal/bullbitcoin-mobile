import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/replace_by_fee/errors.dart';

class BumpFeeUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;

  BumpFeeUsecase({required BitcoinWalletRepository bitcoinWalletRepository})
    : _bitcoinWalletRepository = bitcoinWalletRepository;

  Future<String> execute({
    required String walletId,
    required String txid,
    required double newFeeRate,
  }) async {
    try {
      final psbt = await _bitcoinWalletRepository.bumpFee(
        walletId: walletId,
        txid: txid,
        newFeeRate: newFeeRate,
      );
      return psbt;
    } catch (e) {
      log.severe('$BumpFeeUsecase: $e');
      throw ReplaceByFeeUsecaseError(e.toString());
    }
  }
}
