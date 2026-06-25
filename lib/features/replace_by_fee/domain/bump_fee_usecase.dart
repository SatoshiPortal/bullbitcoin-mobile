import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';

class BumpFeeUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;

  BumpFeeUsecase({required this._bitcoinWalletRepository});

  Future<String> execute({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
  }) async {
    try {
      final psbt = await _bitcoinWalletRepository.bumpFee(
        walletId: walletId,
        txid: txid,
        newFeeRate: newFeeRate,
      );
      return psbt;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      // Re-throw BDK exceptions to be caught and handled by the cubit
      rethrow;
    }
  }
}
