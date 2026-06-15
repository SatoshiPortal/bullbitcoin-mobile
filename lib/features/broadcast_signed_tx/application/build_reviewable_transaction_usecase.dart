import 'package:bb_mobile/core/transactions/domain/domain_errors.dart';
import 'package:bb_mobile/core/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/transaction_port.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/domain_errors.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';

/// Build a [ReviewableTransaction] from a domain [Transaction], resolving
/// each input's value by fetching the parent transaction via [TransactionPort].
///
/// Change output is left unresolved (`null`) since external transactions
/// don't carry wallet-side ownership data.
class BuildReviewableTransactionUsecase {
  final TransactionPort _transactionPort;

  BuildReviewableTransactionUsecase({required this._transactionPort});

  /// Throws [TransactionReviewError] on failure. Port-layer errors are
  /// translated into feature-layer variants at the boundary so the
  /// presentation layer never sees a foreign error type.
  Future<ReviewableTransaction> execute(Transaction tx) async {
    final resolvedInputs = <ResolvedInput>[];

    for (final input in tx.inputs) {
      try {
        final parentTx = await _transactionPort.fetch(txid: input.previousTxId);

        if (input.previousVout >= parentTx.outputs.length) {
          throw TransactionReviewInputResolutionFailed(
            parentTxId: input.previousTxId,
            vout: input.previousVout,
          );
        }

        final parentOutput = parentTx.outputs[input.previousVout];
        resolvedInputs.add(
          ResolvedInput(
            valueSat: parentOutput.valueSat,
            previousTxId: input.previousTxId,
            previousVout: input.previousVout,
            address: parentOutput.address,
          ),
        );
      } on TransactionReviewError {
        rethrow;
      } on TransactionPortError catch (e) {
        throw _mapPortError(e);
      } catch (e, st) {
        // Genuinely unexpected escape — the raw reason is born here, so it is
        // logged here (Sentry) and the UI shows a generic message.
        log.severe(
          message: 'Unexpected failure building reviewable transaction',
          error: e,
          trace: st,
        );
        throw UnexpectedTransactionReviewError(e.toString());
      }
    }

    return ReviewableTransaction(
      transaction: tx,
      resolvedInputs: resolvedInputs,
    );
  }

  TransactionReviewError _mapPortError(TransactionPortError e) =>
      switch (e) {
        TransactionPortFetchFailed(:final txid, :final message) =>
          TransactionReviewFetchFailed(txid: txid, message: message),
        TransactionPortNoServersAvailable(:final network) =>
          TransactionReviewNoServersAvailable(network: network),
      };
}
