import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/manipulated_transaction_exception.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';
import 'package:bb_mobile/core/wallet/domain/unverifiable_transaction_exception.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
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

  /// A replacement can only be priced when the original fee is known.
  /// Zero is a known fee and must retain the replacement path.
  @useResult
  Result<int, ReplaceByFeeFailure> validateOriginalFee(int? knownFeeSat) =>
      switch (knownFeeSat) {
        null => const Err(ReplaceByFeeUnknownOriginalFeeFailure()),
        final fee => Ok(fee),
      };

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

  /// Pre-flight check for the RBF screen: refuses to offer a bump when the
  /// original transaction's signatures don't verify (a planted transaction,
  /// GHSA-6jp4-8v48-cc5v). [execute] re-runs the same check fail-closed.
  @useResult
  Future<Result<void, ReplaceByFeeFailure>> verifyOriginalTransaction({
    required String walletId,
    required String txid,
  }) async {
    try {
      final status = await _bitcoinWalletRepository
          .getTransactionSignatureStatus(walletId: walletId, txid: txid);
      return switch (status) {
        TransactionSignatureStatus.valid => const Ok(null),
        TransactionSignatureStatus.invalid => const Err(
          ReplaceByFeeManipulatedTransactionFailure(),
        ),
        TransactionSignatureStatus.unverifiable => const Err(
          ReplaceByFeeUnverifiableTransactionFailure(),
        ),
      };
    } catch (e, st) {
      log.severe(
        message: 'Failed to verify original transaction for RBF',
        error: e,
        trace: st,
      );
      return Err(ReplaceByFeeUnexpectedFailure(e.toString()));
    }
  }

  @useResult
  Future<Result<String, ReplaceByFeeFailure>> execute({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
    required int? originalFeeSat,
  }) async {
    switch (validateOriginalFee(originalFeeSat)) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        break;
    }
    try {
      final psbt = await _bitcoinWalletRepository.bumpFee(
        walletId: walletId,
        txid: txid,
        newFeeRate: newFeeRate,
      );
      final broadcastedTxid = await _broadcastBitcoinTransactionUsecase.execute(
        psbt,
        isPsbt: true,
        walletId: walletId,
      );
      return Ok(broadcastedTxid);
    } on ManipulatedTransactionException catch (e, st) {
      log.severe(
        message: 'Refused to bump a transaction with invalid signatures',
        error: e,
        trace: st,
      );
      return const Err(ReplaceByFeeManipulatedTransactionFailure());
    } on UnverifiableTransactionException catch (e, st) {
      log.warning(
        'Refused to bump a transaction whose signatures could not be verified',
        error: e,
        trace: st,
      );
      return const Err(ReplaceByFeeUnverifiableTransactionFailure());
    } on bdk.FeeRateTooLowCreateTxException catch (e) {
      log.warning(
        'BDK rejected replacement fee rate',
        error: 'Required rate: ${e.required_}',
      );
      return const Err(ReplaceByFeeFeeRateTooLowFailure());
    } catch (e, st) {
      log.severe(message: 'Bump fee failed', error: e, trace: st);
      return Err(ReplaceByFeeUnexpectedFailure(e.toString()));
    }
  }
}
