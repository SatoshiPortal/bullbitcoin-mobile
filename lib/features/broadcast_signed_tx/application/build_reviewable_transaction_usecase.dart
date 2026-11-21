import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_mapper.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:electrum/electrum.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show BitcoinTx;

class BuildReviewableTransactionUsecase {
  final Electrum _electrum;

  BuildReviewableTransactionUsecase({required this._electrum});

  /// Resolve input values from their parent transactions. External transactions
  /// carry no wallet ownership data, so their change output remains unknown.
  @useResult
  Future<Result<ReviewableTransaction, TransactionReviewFailure>> execute(
    BitcoinTx bitcoinTx, {
    required Future<BitcoinNetwork?> network,
  }) async {
    try {
      final bitcoinNetwork = await network;
      if (bitcoinNetwork == null) {
        return const Err(TransactionReviewNoServersFailure());
      }
      final tx = TransactionReviewMapper.fromBitcoinTx(
        bitcoinTx,
        network: bitcoinNetwork,
      );
      final resolvedInputs = <ResolvedInput>[];
      for (final input in tx.inputs) {
        final result = await _electrum.fetchBitcoinTransaction(
          txid: input.previousTxId,
          network: bitcoinNetwork,
        );
        final BitcoinTx parentTx;
        switch (result) {
          case Ok(:final value):
            parentTx = value;
          case Err(:final failure):
            return Err(_mapFailure(failure));
        }
        if (parentTx.txid != input.previousTxId ||
            input.previousVout < 0 ||
            input.previousVout >= parentTx.outputs.length) {
          return Err(
            TransactionReviewInputResolutionFailure(
              parentTxId: input.previousTxId,
              vout: input.previousVout,
            ),
          );
        }
        final parentOutput = TransactionReviewMapper.output(
          parentTx.outputs[input.previousVout],
          input.previousVout,
          network: bitcoinNetwork,
        );
        resolvedInputs.add(
          ResolvedInput(
            valueSat: parentOutput.valueSat,
            previousTxId: input.previousTxId,
            previousVout: input.previousVout,
            address: parentOutput.address,
          ),
        );
      }
      return Ok(
        ReviewableTransaction(transaction: tx, resolvedInputs: resolvedInputs),
      );
    } on Exception catch (error, trace) {
      log.severe(
        message: 'Unexpected failure building reviewable transaction',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(
        TransactionReviewUnexpectedFailure(error.runtimeType.toString()),
      );
    }
  }

  TransactionReviewFailure _mapFailure(ElectrumFailure failure) =>
      switch (failure) {
        ElectrumTransactionFetchFailure(:final txid) =>
          TransactionReviewFetchFailure(txid: txid),
        ElectrumUnsupportedNetworkFailure() =>
          const TransactionReviewNoServersFailure(),
        ElectrumNoTransactionServersFailure(:final network) =>
          TransactionReviewNoServersFailure(network: network.toString()),
        _ => TransactionReviewUnexpectedFailure(failure.logMessage),
      };
}
