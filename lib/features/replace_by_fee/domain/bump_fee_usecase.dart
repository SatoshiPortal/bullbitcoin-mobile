import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:meta/meta.dart';

class BumpFeeUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;

  BumpFeeUsecase({
    required this._bitcoinWalletRepository,
    required this._broadcastBitcoinTransactionUsecase,
    required this._getNetworkFeesUsecase,
  });

  @useResult
  Future<Result<FeeOptions, ReplaceByFeeFailure>> getNetworkFees() async {
    try {
      final fees = await _getNetworkFeesUsecase.execute(isLiquid: false);
      return Ok(fees);
    } catch (e, st) {
      log.warning('Failed to fetch network fees for RBF', error: e, trace: st);
      return const Err(ReplaceByFeeNetworkFeesFailure());
    }
  }

  @useResult
  Future<Result<String, ReplaceByFeeFailure>> execute({
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
      final broadcastedTxid = await _broadcastBitcoinTransactionUsecase.execute(
        psbt,
        isPsbt: true,
      );
      return Ok(broadcastedTxid);
    } on bdk.FeeRateTooLowCreateTxException {
      return const Err(ReplaceByFeeFeeRateTooLowFailure());
    } catch (e, st) {
      log.severe(message: 'Bump fee failed', error: e, trace: st);
      return Err(ReplaceByFeeUnexpectedFailure(e.toString()));
    }
  }
}
